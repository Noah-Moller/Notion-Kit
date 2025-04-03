import Foundation
import Vapor
@preconcurrency import NotionKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A Vapor controller for handling Notion API requests
public struct NotionController {
    
    // MARK: - Routes
    
    /// Register all routes for the Notion API
    /// - Parameters:
    ///   - routes: The route builder
    ///   - authMiddleware: An optional authentication middleware
    public static func registerRoutes(
        on routes: RoutesBuilder,
        authMiddleware: Middleware? = nil
    ) {
        // Create a route group with authentication if provided
        let routeGroup: RoutesBuilder
        if let authMiddleware = authMiddleware {
            routeGroup = routes.grouped(authMiddleware)
        } else {
            routeGroup = routes
        }
        
        // Register standard routes
        routeGroup.get("notion", "authorize", use: authorize)
        routeGroup.get("notion", "callback", use: callback)
        routeGroup.post("notion", "token", use: exchangeToken)
        routeGroup.get("notion", "databases", use: listDatabases)
        routeGroup.get("notion", "pages", use: listPages)
        routeGroup.post("notion", "databases", ":databaseId", "query", use: queryDatabase)
        
        // Register client-compatible routes
        let apiGroup = routeGroup.grouped("api")
        apiGroup.post("notion", "token", use: exchangeToken)
        apiGroup.get("notion", "databases", use: listDatabases)
        apiGroup.get("notion", "pages", use: listPages)
        apiGroup.post("notion", "databases", ":databaseId", "query", use: queryDatabase)
        
        // Register diagnostic routes
        apiGroup.get("notion", "diagnostic", use: diagnostic)
        
        // Register new routes
        routeGroup.get("notion", "auth", "url", use: authURL)
        routeGroup.get("notion", "pages", ":pageId", "blocks", use: getPageBlocks)
        routeGroup.get("notion", "blocks", ":blockId", "children", use: getChildBlocks)
    }
    
    // MARK: - Handlers
    
    /// Handle authorize request
    /// - Parameter req: The request
    /// - Returns: A redirect response
    public static func authorize(req: Request) throws -> Response {
        // Generate state for CSRF protection
        let state = UUID().uuidString
        req.session.data["notion_state"] = state
        
        // Get OAuth URL
        let oauthURL = req.application.notion.getOAuthURL(state: state)
        
        // Redirect to OAuth URL
        return req.redirect(to: oauthURL.absoluteString)
    }
    
    /// Handle OAuth callback
    /// - Parameter req: The request
    /// - Returns: A response
    public static func callback(req: Request) async throws -> Response {
        // Get user ID from authenticated user or request
        let userId: String
        if let authenticatedUser = req.auth.get(SimpleUser.self) {
            userId = authenticatedUser.id
        } else if let userIdParam = req.query[String.self, at: "user_id"] {
            userId = userIdParam
        } else {
            throw Abort(.badRequest, reason: "User ID not provided")
        }
        
        // Handle callback and exchange code for token
        let token = try await req.application.notion.handleCallback(request: req, userId: userId)
        
        // Populate NotionData
        try await populateNotionData(req: req, userId: userId, token: token)
        
        // Determine redirect URL
        let redirectURL: String
        if let successURL = req.query[String.self, at: "success_url"] {
            redirectURL = successURL
        } else {
            redirectURL = "/notion/success"
        }
        
        // Redirect to success URL
        return req.redirect(to: redirectURL)
    }
    
    /// Handle token exchange request
    /// - Parameter req: The request
    /// - Returns: The token response
    public static func exchangeToken(req: Request) async throws -> Response {
        // Parse request body
        struct TokenRequest: Content, Sendable {
            let code: String
            let redirectUri: String
            
            enum CodingKeys: String, CodingKey {
                case code
                case redirectUri = "redirect_uri"
            }
        }
        
        do {
            let tokenRequest = try req.content.decode(TokenRequest.self)
            
            // Get user ID from authenticated user or request
            let userId: String
            if let authenticatedUser = req.auth.get(SimpleUser.self) {
                userId = authenticatedUser.id
                req.logger.debug("Using user ID from authenticated user: \(userId)")
            } else if let userIdParam = req.query[String.self, at: "user_id"] {
                userId = userIdParam
                req.logger.debug("Using user ID from query parameter: \(userId)")
            } else {
                req.logger.error("No user ID provided in request")
                throw Abort(.badRequest, reason: "User ID not provided")
            }
            
            req.logger.info("Exchanging code for token for user: \(userId)")
            req.logger.debug("Redirect URI: \(tokenRequest.redirectUri)")
            
            // Exchange code for token
            let token = try await req.application.notion.exchangeCodeForToken(
                userId: userId, 
                code: tokenRequest.code,
                redirectURI: tokenRequest.redirectUri
            )
            
            req.logger.info("Successfully exchanged code for token")
            req.logger.debug("Workspace: \(token.workspaceName)")
            
            // Immediately populate Notion data after token exchange
            try await populateNotionData(req: req, userId: userId, token: token)
            req.logger.info("Successfully populated Notion data for user: \(userId)")
            
            // Create response
            struct TokenResponse: Content {
                let accessToken: String
                let botId: String
                let workspaceId: String
                let workspaceName: String
                let workspaceIcon: String?
                let success: Bool
                let message: String
                
                enum CodingKeys: String, CodingKey {
                    case accessToken = "access_token"
                    case botId = "bot_id"
                    case workspaceId = "workspace_id"
                    case workspaceName = "workspace_name"
                    case workspaceIcon = "workspace_icon"
                    case success
                    case message
                }
            }
            
            let response = TokenResponse(
                accessToken: token.accessToken,
                botId: token.botId,
                workspaceId: token.workspaceId,
                workspaceName: token.workspaceName,
                workspaceIcon: token.workspaceIcon,
                success: true,
                message: "Successfully authenticated and loaded Notion data"
            )
            
            return try await response.encodeResponse(for: req)
        } catch {
            req.logger.error("Error exchanging token: \(error)")
            throw error
        }
    }
    
    // Helper function to extract readable details from DecodingError
    private static func extractDecodingErrorDetails(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Required field missing: \(key.stringValue)"
        case .valueNotFound(_, let context):
            return "Value missing for: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .typeMismatch(_, let context):
            return "Type mismatch at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Data corrupted: \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error"
        }
    }
    
    /// Get the OAuth URL for client-side authentication
    /// - Parameter req: The request
    /// - Returns: A response with the OAuth URL
    public static func authURL(req: Request) async throws -> Response {
        // Generate state for CSRF protection
        let state = UUID().uuidString
        
        // Get OAuth URL
        let oauthURL = req.application.notion.getOAuthURL(state: state)
        
        // Return the URL as JSON
        let response = ["url": oauthURL.absoluteString, "state": state]
        let data = try JSONEncoder().encode(response)
        return Response(
            status: .ok,
            body: .init(data: data)
        )
    }
    
    /// Handle list databases request
    /// - Parameter req: The request
    /// - Returns: The databases response
    public static func listDatabases(req: Request) async throws -> Response {
        // Get user ID from authenticated user or request
        let userId: String
        if let authenticatedUser = req.auth.get(SimpleUser.self) {
            userId = authenticatedUser.id
        } else if let userIdParam = req.query[String.self, at: "user_id"] {
            userId = userIdParam
        } else {
            throw Abort(.badRequest, reason: "User ID not provided")
        }
        
        // Get databases
        let databases = try await req.application.notion.listDatabases(for: userId)
        
        // Create response
        struct DatabasesResponse: Content, Sendable {
            let databases: [NotionDatabase]
        }
        
        let databasesResponse = DatabasesResponse(databases: databases)
        
        return try await databasesResponse.encodeResponse(for: req)
    }
    
    /// Handle query database request
    /// - Parameter req: The request
    /// - Returns: The query response
    public static func queryDatabase(req: Request) async throws -> Response {
        // Get user ID from authenticated user or request
        let userId: String
        if let authenticatedUser = req.auth.get(SimpleUser.self) {
            userId = authenticatedUser.id
        } else if let userIdParam = req.query[String.self, at: "user_id"] {
            userId = userIdParam
        } else {
            throw Abort(.badRequest, reason: "User ID not provided")
        }
        
        // Get database ID from path
        guard let databaseId = req.parameters.get("databaseId") else {
            throw Abort(.badRequest, reason: "Database ID not provided")
        }
        
        // Parse query from request body (if provided)
        let query: NotionDatabaseQueryRequest?
        if req.headers.contentType == .json {
            query = try? req.content.decode(NotionDatabaseQueryRequest.self)
        } else {
            query = nil
        }
        
        // Query database
        let response = try await req.application.notion.queryDatabase(
            databaseId: databaseId,
            for: userId,
            query: query
        )
        
        // Create response
        struct QueryResponse: Content, Sendable {
            let object: String
            let results: [NotionDatabaseItem]
            let nextCursor: String?
            let hasMore: Bool
            
            enum CodingKeys: String, CodingKey {
                case object
                case results
                case nextCursor = "next_cursor"
                case hasMore = "has_more"
            }
        }
        
        let queryResponse = QueryResponse(
            object: response.object,
            results: response.results,
            nextCursor: response.nextCursor,
            hasMore: response.hasMore
        )
        
        return try await queryResponse.encodeResponse(for: req)
    }
    
    /// Handle list pages request
    /// - Parameter req: The request
    /// - Returns: The pages response
    public static func listPages(req: Request) async throws -> Response {
        // Get user ID from authenticated user or request
        let userId: String
        if let authenticatedUser = req.auth.get(SimpleUser.self) {
            userId = authenticatedUser.id
            req.logger.debug("Using user ID from authenticated user: \(userId)")
        } else if let userIdParam = req.query[String.self, at: "user_id"] {
            userId = userIdParam
            req.logger.debug("Using user ID from query parameter: \(userId)")
        } else {
            req.logger.error("No user ID provided in request")
            throw Abort(.badRequest, reason: "User ID not provided")
        }
        
        req.logger.info("Listing pages for user: \(userId)")
        
        // Get pages
        let pages = try await req.application.notion.listPages(for: userId)
        
        // Create response
        struct PagesResponse: Content, Sendable {
            let count: Int
            let pages: [NotionPage]
        }
        
        let pagesResponse = PagesResponse(
            count: pages.count,
            pages: pages
        )
        
        return try await pagesResponse.encodeResponse(for: req)
    }
    
    /// Handle request to get page blocks
    public static func getPageBlocks(req: Request) async throws -> Response {
        // Get the user ID from the authenticated user or from query parameters
        let userId = getUserId(from: req) ?? req.query[String.self, at: "user_id"]
        let pageId = req.parameters.get("pageId")!
        
        req.logger.info("Getting blocks for page \(pageId) for user \(userId ?? "unknown")")
        
        if userId == nil {
            return Response(
                status: .badRequest,
                body: .init(string: "Missing user_id parameter")
            )
        }
        
        do {
            let blocks = try await req.application.notion.getPageBlocks(for: userId!, pageId: pageId)
            
            struct BlocksResponse: Content {
                let count: Int
                let blocks: [NotionBlock]
            }
            
            let response = BlocksResponse(
                count: blocks.count,
                blocks: blocks
            )
            
            return try await response.encodeResponse(for: req)
        } catch {
            if let abort = error as? Abort {
                let errorResponse = ["error": abort.reason]
                let data = try JSONEncoder().encode(errorResponse)
                return Response(
                    status: abort.status,
                    body: .init(data: data)
                )
            } else {
                req.logger.error("Error getting page blocks: \(error)")
                
                let errorResponse = ["error": error.localizedDescription]
                let data = try JSONEncoder().encode(errorResponse)
                return Response(
                    status: .internalServerError,
                    body: .init(data: data)
                )
            }
        }
    }
    
    /// Handle request to get child blocks
    public static func getChildBlocks(req: Request) async throws -> Response {
        // Get the user ID from the authenticated user or from query parameters
        let userId = getUserId(from: req) ?? req.query[String.self, at: "user_id"]
        let blockId = req.parameters.get("blockId")!
        
        req.logger.info("Getting child blocks for block \(blockId) for user \(userId ?? "unknown")")
        
        if userId == nil {
            return Response(
                status: .badRequest,
                body: .init(string: "Missing user_id parameter")
            )
        }
        
        do {
            let blocks = try await req.application.notion.getChildBlocks(for: userId!, blockId: blockId)
            
            struct BlocksResponse: Content {
                let count: Int
                let blocks: [NotionBlock]
            }
            
            let response = BlocksResponse(
                count: blocks.count,
                blocks: blocks
            )
            
            return try await response.encodeResponse(for: req)
        } catch {
            if let abort = error as? Abort {
                let errorResponse = ["error": abort.reason]
                let data = try JSONEncoder().encode(errorResponse)
                return Response(
                    status: abort.status,
                    body: .init(data: data)
                )
            } else {
                req.logger.error("Error getting child blocks: \(error)")
                
                let errorResponse = ["error": error.localizedDescription]
                let data = try JSONEncoder().encode(errorResponse)
                return Response(
                    status: .internalServerError,
                    body: .init(data: data)
                )
            }
        }
    }
    
    // MARK: - Diagnostic
    
    /// Diagnostic endpoint to check configuration
    /// - Parameter req: The request
    /// - Returns: The diagnostic response
    public static func diagnostic(req: Request) async throws -> Response {
        struct DiagnosticResponse: Content, Sendable {
            let clientId: String
            let redirectUri: String
            let serverTime: Date
            let serverVersion: String
        }
        
        // Get masked client ID (first 5 chars)
        let clientId = req.application.notion.getClientId()
        let maskedClientId = clientId.count > 5 
            ? String(clientId.prefix(5)) + "..." 
            : "Invalid"
        
        let redirectUri = req.application.notion.getRedirectUri()
        
        let response = DiagnosticResponse(
            clientId: maskedClientId,
            redirectUri: redirectUri,
            serverTime: Date(),
            serverVersion: "NotionKit 1.0"
        )
        
        return try await response.encodeResponse(for: req)
    }
    
    // MARK: - NotionData Population
    
    /// Populate NotionData for a user
    /// - Parameters:
    ///   - req: The request
    ///   - userId: The ID of the user
    ///   - token: The Notion token
    private static func populateNotionData(req: Request, userId: String, token: NotionToken) async throws {
        // Create workspace info
        let workspace = WorkspaceInfo(
            id: token.workspaceId,
            name: token.workspaceName,
            icon: token.workspaceIcon
        )
        
        // Create token info
        let tokenInfo = TokenInfo(
            accessToken: token.accessToken,
            botId: token.botId,
            workspaceId: token.workspaceId,
            workspaceName: token.workspaceName,
            workspaceIcon: token.workspaceIcon,
            expiresAt: token.expiresAt
        )
        
        // Create user info
        let user = UserInfo(
            id: userId,
            token: tokenInfo,
            workspace: workspace
        )
        
        // Fetch databases
        let databases = try await req.application.notion.listDatabases(for: userId)
        let databaseInfos = try await withThrowingTaskGroup(of: DatabaseInfo.self) { group in
            for database in databases {
                group.addTask {
                    let items = try await req.application.notion.queryDatabase(
                        databaseId: database.id,
                        for: userId
                    ).results
                    
                    // Convert PropertyDefinition to NotionProperty
                    _ = try database.properties.mapValues { definition -> NotionProperty in
                        let propertyData = try JSONEncoder().encode(definition)
                        return try JSONDecoder().decode(NotionProperty.self, from: propertyData)
                    }
                    
                    return DatabaseInfo(
                        id: database.id,
                        name: database.title?.first?.plainText ?? "",
                        url: database.url ?? "",
                        title: (database.title ?? []).map { richText in
                            let data = try! JSONEncoder().encode(richText)
                            return try! JSONDecoder().decode(RichTextItem.self, from: data)
                        },
                        properties: try database.properties.mapValues { property in
                            let data = try JSONEncoder().encode(property)
                            return try JSONDecoder().decode(PropertyValue.self, from: data)
                        },
                        items: items.map { item in
                            NotionPage(
                                id: item.id,
                                url: item.url,
                                properties: Dictionary(uniqueKeysWithValues: item.properties.map { key, value in
                                    (key, value.values.first ?? "")
                                })
                            )
                        }
                    )
                }
            }
            
            var results: [DatabaseInfo] = []
            for try await info in group {
                results.append(info)
            }
            return results
        }
        
        // Fetch pages
        let pages = try await req.application.notion.listPages(for: userId)
        let pageInfos = try await withThrowingTaskGroup(of: PageInfo.self) { group in
            for page in pages {
                group.addTask {
                    let blocks = try await req.application.notion.getPageBlocks(for: userId, pageId: page.id)
                    
                    // Extract title from page properties
                    let titleProperty = page.properties["Name"] ?? page.properties["Title"] ?? page.properties["title"]
                    let title = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(titleProperty)) as? [String: Any]
                    let titleArray = title?["title"] as? [[String: Any]]
                    let plainText = titleArray?.first?["plain_text"] as? String ?? ""
                    
                    // Convert page properties to PropertyValue dictionary
                    let properties = try page.properties.mapValues { value -> PropertyValue in
                        let propertyData = try JSONEncoder().encode(value)
                        return try JSONDecoder().decode(PropertyValue.self, from: propertyData)
                    }
                    
                    return PageInfo(
                        id: page.id,
                        url: page.url,
                        title: plainText,
                        icon: nil, // NotionPage doesn't have icon
                        cover: nil, // NotionPage doesn't have cover
                        properties: properties,
                        blocks: blocks,
                        lastEditedTime: Date(), // NotionPage doesn't have lastEditedTime
                        createdTime: Date() // NotionPage doesn't have createdTime
                    )
                }
            }
            
            var results: [PageInfo] = []
            for try await info in group {
                results.append(info)
            }
            return results
        }
        
        // Create metadata
        let metadata = Metadata(
            syncedAt: Date(),
            version: "1.0",
            lastSyncStatus: .success
        )
        
        // Create and store NotionUserData
        let notionData = NotionUserData(
            user: user,
            databases: databaseInfos,
            pages: pageInfos,
            metadata: metadata
        )
        
        req.application.notionData.store(notionData, for: userId)
    }
    
    // MARK: - Helper Methods
    
    /// Helper to get the user ID from an authenticated user
    /// - Parameter req: The request
    /// - Returns: The user ID if available
    private static func getUserId(from req: Request) -> String? {
        if let authenticatedUser = req.auth.get(SimpleUser.self) {
            return authenticatedUser.id
        }
        return nil
    }
} 

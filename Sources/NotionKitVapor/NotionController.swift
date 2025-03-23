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
        _ = try await req.application.notion.handleCallback(request: req, userId: userId)
        
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
            
            // Exchange code for token directly without creating a mock request
            let token = try await req.application.notion.exchangeCodeForToken(
                userId: userId, 
                code: tokenRequest.code
            )
            
            req.logger.info("Successfully exchanged code for token")
            req.logger.debug("Workspace: \(token.workspaceName)")
            
            // Create response
            struct TokenResponse: Content, Sendable {
                let accessToken: String
                let botId: String
                let workspaceId: String
                let workspaceName: String
                let workspaceIcon: String?
                
                enum CodingKeys: String, CodingKey {
                    case accessToken = "access_token"
                    case botId = "bot_id"
                    case workspaceId = "workspace_id"
                    case workspaceName = "workspace_name"
                    case workspaceIcon = "workspace_icon"
                }
            }
            
            let tokenResponse = TokenResponse(
                accessToken: token.accessToken,
                botId: token.botId,
                workspaceId: token.workspaceId,
                workspaceName: token.workspaceName,
                workspaceIcon: token.workspaceIcon
            )
            
            return try await tokenResponse.encodeResponse(for: req)
        } catch let error as DecodingError {
            req.logger.error("Failed to decode request: \(error)")
            let details = extractDecodingErrorDetails(error)
            throw Abort(.badRequest, reason: "Invalid request format: \(details)")
        } catch let error as Abort {
            req.logger.error("Abort error: \(error.reason)")
            throw error
        } catch {
            req.logger.error("Failed to exchange code for token: \(error)")
            throw Abort(.internalServerError, reason: "Failed to exchange code for token: \(error.localizedDescription)")
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
            let pages: [NotionPage]
        }
        
        let pagesResponse = PagesResponse(pages: pages)
        
        return try await pagesResponse.encodeResponse(for: req)
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
} 

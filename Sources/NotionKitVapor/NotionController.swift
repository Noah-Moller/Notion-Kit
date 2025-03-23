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
        routeGroup.post("notion", "databases", ":databaseId", "query", use: queryDatabase)
        
        // Register client-compatible routes
        let apiGroup = routeGroup.grouped("api")
        apiGroup.post("notion", "token", use: exchangeToken)
        apiGroup.get("notion", "databases", use: listDatabases)
        apiGroup.post("notion", "databases", ":databaseId", "query", use: queryDatabase)
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
        
        let tokenRequest = try req.content.decode(TokenRequest.self)
        
        // Get user ID from authenticated user or request
        let userId: String
        if let authenticatedUser = req.auth.get(SimpleUser.self) {
            userId = authenticatedUser.id
        } else if let userIdParam = req.query[String.self, at: "user_id"] {
            userId = userIdParam
        } else {
            throw Abort(.badRequest, reason: "User ID not provided")
        }
        
        // Create URL components for the callback
        var components = URLComponents()
        if let redirectUrl = URL(string: tokenRequest.redirectUri) {
            components.scheme = redirectUrl.scheme
            components.host = redirectUrl.host
            components.path = redirectUrl.path
        }
        components.queryItems = [URLQueryItem(name: "code", value: tokenRequest.code)]
        
        guard let callbackUrl = components.url else {
            throw Abort(.badRequest, reason: "Invalid redirect URI")
        }
        
        // Mock a request for the callback
        let mockRequest = Request(
            application: req.application,
            method: HTTPMethod.GET,
            url: URI(string: callbackUrl.absoluteString),
            on: req.eventLoop
        )
        if let host = components.host {
            mockRequest.headers.replaceOrAdd(name: HTTPHeaders.Name.host, value: host)
        }
        
        // Handle callback and exchange code for token
        let token = try await req.application.notion.handleCallback(request: mockRequest, userId: userId)
        
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
} 

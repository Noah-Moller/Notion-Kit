import Vapor
import NotionKitVapor
import AsyncHTTPClient
import Fluent
import FluentSQLiteDriver
import NotionKit

// Shared HTTPClient for use across the application
var sharedHTTPClient: HTTPClient?

public func configure(_ app: Application) throws {
    // Configure SQLite database
    app.databases.use(.sqlite(.file("notion.sqlite")), as: .sqlite)
    
    // Run migrations
    app.migrations.add(CreateNotionTokens())
    try app.autoMigrate().wait()
    
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Set up sessions (required for OAuth flow)
    app.middleware.use(app.sessions.middleware)
    
    // Configure Notion client
    NotionVaporClient.configure(
        app: app,
        clientId: Environment.get("NOTION_CLIENT_ID")!,
        clientSecret: Environment.get("NOTION_CLIENT_SECRET")!,
        redirectUri: Environment.get("NOTION_REDIRECT_URI")!
    )
    
    // Register routes with UserIDMiddleware to handle client requests
    let userIDMiddleware = UserIDMiddleware()
    // Create a route group with both sessions middleware and user ID middleware
    let routesWithSessionAndAuth = app.grouped([app.sessions.middleware, userIDMiddleware])
    NotionController.registerRoutes(on: routesWithSessionAndAuth)
    
    // Example of how to access NotionData in your routes
    routesWithSessionAndAuth.get("notion", "data") { req async throws -> NotionUserData in
        guard let userId = req.auth.get(SimpleUser.self)?.id else {
            throw Abort(.unauthorized)
        }
        
        guard let notionData = req.application.notionData.getData(for: userId) else {
            throw Abort(.notFound, reason: "Notion data not found. Please authenticate first.")
        }
        
        return notionData
    }
    
    app.routes.defaultMaxBodySize = "10mb"
    // Create a shared HTTPClient with a shared event loop group
    let httpClient = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
    sharedHTTPClient = httpClient

    // Register the lifecycle handler to shut down the HTTP client on application shutdown
    app.lifecycle.use(ClientLifecycle(httpClient: httpClient))
    
    // Optional: Set server hostname and port
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8080
    
    // Configure your routes (pass the app for route setup)
    try routes(app)
} 
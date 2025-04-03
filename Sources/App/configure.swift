import Vapor
import NotionKitVapor
import AsyncHTTPClient
import Fluent
import FluentSQLiteDriver
import NotionKit

// Shared HTTPClient for use across the application
var sharedHTTPClient: HTTPClient?

/// Manages the lifecycle of the shared HTTPClient
fileprivate final class ClientLifecycle: LifecycleHandler {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }
    
    func shutdown(_ application: Application) {
        // Attempt to shut down the HTTP client gracefully
        try? httpClient.syncShutdown()
    }
}

public func configure(_ app: Application) throws {
    // Configure SQLite database
    app.databases.use(.sqlite(.file("notion.sqlite")), as: .sqlite)
    
    // Run migrations
    let migration = NotionKitVapor.CreateNotionTokens()
    app.migrations.add(migration)
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
    
    // Register the package's routes with UserIDMiddleware
    let userIDMiddleware = UserIDMiddleware()
    NotionController.registerRoutes(on: app, authMiddleware: userIDMiddleware)
    
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
import Vapor
import NotionKitVapor
import AsyncHTTPClient
import Fluent
import FluentSQLiteDriver

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
    
    // Create SQLite token storage
    let tokenStorage = SQLiteNotionTokenStorage(app: app)
    
    // Create and store the client
    let client = NotionVaporClient(
        clientId: Environment.get("NOTION_CLIENT_ID")!,
        clientSecret: Environment.get("NOTION_CLIENT_SECRET")!,
        redirectUri: Environment.get("NOTION_REDIRECT_URI")!,
        tokenStorage: tokenStorage
    )
    
    app.notion = client
    
    // Register routes with UserIDMiddleware to handle client requests
    // Make sure we also include the sessions middleware in the route group
    let userIDMiddleware = UserIDMiddleware()
    let routesWithSessionAndAuth = app.grouped([app.sessions.middleware, userIDMiddleware])
    NotionController.registerRoutes(on: routesWithSessionAndAuth)
    
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
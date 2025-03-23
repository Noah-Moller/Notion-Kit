import Vapor
import NotionKitVapor

// Configure your Vapor application
public func configure(_ app: Application) throws {
    // Basic configurations
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Set up sessions (required for OAuth flow)
    app.middleware.use(app.sessions.middleware)
    
    // Configure Notion client
    NotionVaporClient.configure(
        app: app,
        clientId: Environment.get("NOTION_CLIENT_ID") ?? "your-notion-client-id",
        clientSecret: Environment.get("NOTION_CLIENT_SECRET") ?? "your-notion-client-secret",
        redirectUri: Environment.get("NOTION_REDIRECT_URI") ?? "https://your-app.com/notion/callback"
    )
    
    // Register routes with UserIDMiddleware to handle client requests
    let userIDMiddleware = UserIDMiddleware()
    NotionController.registerRoutes(on: app, authMiddleware: userIDMiddleware)
    
    // Register your app routes
    try routes(app)
} 
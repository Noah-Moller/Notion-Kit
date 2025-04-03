// Configure Notion client
NotionVaporClient.configure(
    app: app,
    clientId: Environment.get("NOTION_CLIENT_ID")!,
    clientSecret: Environment.get("NOTION_CLIENT_SECRET")!,
    redirectUri: Environment.get("NOTION_REDIRECT_URI")!
)

// Debug configuration
print("=== Server Configuration ===")
print("Client ID: \(Environment.get("NOTION_CLIENT_ID") ?? "not set")")
print("Redirect URI: \(Environment.get("NOTION_REDIRECT_URI") ?? "not set")")
print("Server URL: http://\(app.http.server.configuration.hostname):\(app.http.server.configuration.port)") 
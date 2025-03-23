# Setting Up NotionKit with Vapor

This example shows how to integrate NotionKit into your Vapor application, enabling both server-side API usage and client-side integrations.

## Prerequisites

1. Create a Notion integration at https://www.notion.so/my-integrations
2. Get your client ID and client secret
3. Set up a redirect URI (e.g., https://your-app.com/notion/callback)

## Setup Steps

### 1. Add NotionKit as a dependency

In your `Package.swift`:

```swift
dependencies: [
    // Other dependencies...
    .package(url: "https://github.com/yourusername/NotionKit.git", from: "1.0.0")
],
targets: [
    .target(
        name: "App",
        dependencies: [
            // Other dependencies...
            .product(name: "NotionKitVapor", package: "NotionKit")
        ]
    )
]
```

### 2. Set environment variables

```bash
export NOTION_CLIENT_ID="your-notion-client-id"
export NOTION_CLIENT_SECRET="your-notion-client-secret"
export NOTION_REDIRECT_URI="https://your-app.com/notion/callback"
```

Or add them to a `.env` file for development.

### 3. Configure NotionKit in your app

See the `configure.swift` example for details on how to set up the Notion client in your Vapor app.

### 4. Use NotionKit in your routes

See the `routes.swift` example for how to create routes that use the NotionKit API.

## Authentication Options

This setup supports three authentication approaches:

1. **User ID from query parameter**: Pass `?user_id=your-user-id` to identify the user
2. **BasicUser protocol**: Implement the `BasicUser` protocol for your user model
3. **Custom authentication**: Create custom middleware for your authentication system

## Client-Side Integration

The NotionKit package also supports client-side (SwiftUI) integration. The server routes registered by `NotionController.registerRoutes(on:authMiddleware:)` are compatible with the client-side `NotionClientManager`.

When initializing the client-side manager, use:

```swift
let notionClient = NotionClientManager(
    apiServerURL: URL(string: "https://your-app.com")!,
    clientId: "your-notion-client-id"
)
```

## Additional Resources

- Check the main NotionKit README for more details on available features
- Explore the NotionKitVapor source code for advanced usage options 
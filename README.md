# NotionKit

A Swift package for integrating with the Notion API, supporting both server-side (Vapor) and client-side (SwiftUI) applications.

## Features

- OAuth integration with Notion API
- Server-side token storage and management
- Client-side authentication flow
- Database listing and querying
- Comprehensive data models for Notion objects
- Type-safe filtering and sorting

## Requirements

- Swift 5.5+
- iOS 15.0+ / macOS 12.0+
- Vapor 4.0+ (for server-side)
- SwiftUI (for client-side)

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/NotionKit.git", from: "1.0.0")
]
```

Then add the specific products to your target:

```swift
// For server-side (Vapor)
.product(name: "NotionKitVapor", package: "NotionKit")

// For client-side (SwiftUI)
.product(name: "NotionKitClient", package: "NotionKit")

// For shared models only
.product(name: "NotionKit", package: "NotionKit")
```

## Usage

### Server-Side (Vapor)

1. **Configure the Notion client in your app:**

```swift
import Vapor
import NotionKitVapor

// Configure the Notion client in configure.swift
public func configure(_ app: Application) throws {
    // Other configurations...
    
    // Set up sessions
    app.middleware.use(app.sessions.middleware)
    
    // Configure Notion client
    NotionVaporClient.configure(
        app: app,
        clientId: Environment.get("NOTION_CLIENT_ID")!,
        clientSecret: Environment.get("NOTION_CLIENT_SECRET")!,
        redirectUri: Environment.get("NOTION_REDIRECT_URI")!
    )
    
    // Register Notion routes
    NotionController.registerRoutes(on: app)
}
```

2. **Use the Notion client in your controllers:**

```swift
import Vapor
import NotionKitVapor

struct UserController {
    func getDatabases(req: Request) async throws -> [NotionDatabase] {
        let userId = req.auth.get(User.self)!.id
        return try await req.application.notion.listDatabases(for: userId.uuidString)
    }
    
    func queryDatabase(req: Request) async throws -> NotionPaginatedResponse<[String: Any]> {
        let userId = req.auth.get(User.self)!.id
        let databaseId = req.parameters.get("databaseId")!
        
        let query = try? req.content.decode(NotionDatabaseQueryRequest.self)
        
        return try await req.application.notion.queryDatabase(
            databaseId: databaseId,
            for: userId.uuidString,
            query: query
        )
    }
}
```

### Client-Side (SwiftUI)

1. **Set up the Notion client manager:**

```swift
import SwiftUI
import NotionKitClient

class AppModel: ObservableObject {
    let notionClient: NotionClientManager
    
    init() {
        self.notionClient = NotionClientManager(
            apiServerURL: URL(string: "https://yourapp.com")!,
            clientId: "your-notion-client-id"
        )
    }
}

@main
struct YourApp: App {
    @StateObject var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
    }
}
```

2. **Use the Notion database view in your app:**

```swift
import SwiftUI
import NotionKitClient

struct ContentView: View {
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        NavigationView {
            NotionDatabaseView(
                clientManager: appModel.notionClient,
                redirectURI: "yourapp://notion-callback",
                onDatabaseSelected: { database in
                    print("Selected database: \(database.name)")
                }
            )
            .navigationTitle("Notion Databases")
        }
    }
}
```

3. **Connect to Notion from a custom button:**

```swift
import SwiftUI
import NotionKitClient

struct CustomConnectView: View {
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        VStack {
            Text("Connect to your Notion account")
                .font(.headline)
            
            Button("Connect to Notion") {
                self.connectToNotion(
                    clientManager: appModel.notionClient,
                    redirectURI: "yourapp://notion-callback"
                )
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}
```

## Setting Up Your Notion Integration

1. Go to [https://www.notion.so/my-integrations](https://www.notion.so/my-integrations)
2. Click "New integration"
3. Name your integration and select the workspace
4. Enable the capabilities you need:
   - Read content
   - Update content
   - Insert content
5. Set the OAuth redirect URL to your app's callback URL
6. Save the client ID and client secret
7. In your Notion workspace, share the databases with your integration

## Security Considerations

- Store the Notion client secret securely on your server
- Use HTTPS for all API calls
- Implement proper user authentication
- Use state parameter in OAuth flow to prevent CSRF attacks
- Securely store tokens with proper encryption

## Advanced Usage

### Custom Token Storage

You can implement your own token storage by conforming to the `NotionTokenStorage` protocol:

```swift
// Server-side custom token storage
struct MyTokenStorage: NotionTokenStorage {
    func saveToken(userId: String, token: NotionToken) async throws {
        // Custom implementation
    }
    
    func getToken(userId: String) async throws -> NotionToken? {
        // Custom implementation
    }
    
    func deleteToken(userId: String) async throws {
        // Custom implementation
    }
}

// Client-side custom token storage
class MyClientTokenStorage {
    func saveToken(token: NotionToken) {
        // Custom implementation
    }
    
    func loadToken() -> NotionToken? {
        // Custom implementation
    }
    
    func clearToken() {
        // Custom implementation
    }
}
```

### Custom Filtering and Sorting

```swift
// Create a filter for a database query
let filter = NotionFilter()
filter.property = "Status"
filter.status = NotionStatusFilter(equals: "Done")

// Create sorting
let sort = NotionSort(property: "Due Date", direction: .ascending)

// Create query
let query = NotionDatabaseQueryRequest(
    filter: filter,
    sorts: [sort],
    pageSize: 50
)

// Query the database
let results = try await notionClient.queryDatabase(
    databaseId: "database-id",
    for: "user-id",
    query: query
)
```

## License

MIT License

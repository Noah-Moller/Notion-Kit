import Foundation
import Vapor
@preconcurrency import NotionKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A Vapor-specific implementation of the Notion API client
public class NotionVaporClient: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The base Notion client
    private let notionClient: NotionClientProtocol
    
    /// The application's Notion client ID
    private let clientId: String
    
    /// The application's Notion client secret
    private let clientSecret: String
    
    /// The redirect URI for the OAuth flow
    private let redirectUri: String
    
    /// The token storage implementation
    private let tokenStorage: NotionTokenStorage
    
    // MARK: - Initialization
    
    /// Initialize a new Vapor-specific Notion client
    /// - Parameters:
    ///   - clientId: The Notion OAuth client ID
    ///   - clientSecret: The Notion OAuth client secret
    ///   - redirectUri: The redirect URI for the OAuth flow
    ///   - tokenStorage: The token storage implementation
    ///   - notionClient: An optional custom Notion client implementation
    public init(
        clientId: String,
        clientSecret: String,
        redirectUri: String,
        tokenStorage: NotionTokenStorage,
        notionClient: NotionClientProtocol = NotionClient()
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectUri = redirectUri
        self.tokenStorage = tokenStorage
        self.notionClient = notionClient
    }
    
    // MARK: - OAuth Methods
    
    /// Get the OAuth URL for user authentication
    /// - Parameters:
    ///   - state: An optional state parameter for CSRF protection
    ///   - ownerType: The type of owner (user or workspace)
    /// - Returns: The OAuth URL
    public func getOAuthURL(state: String? = nil, ownerType: String? = nil) -> URL {
        return notionClient.getOAuthURL(
            clientId: clientId,
            redirectUri: redirectUri,
            state: state,
            ownerType: ownerType
        )
    }
    
    /// Handle the OAuth callback and exchange the code for a token
    /// - Parameters:
    ///   - request: The Vapor HTTP request
    ///   - userId: The ID of the user to associate with the token
    /// - Returns: The token
    public func handleCallback(request: Request, userId: String) async throws -> NotionToken {
        // Extract code from query parameters
        guard let code = request.query[String.self, at: "code"] else {
            throw Abort(.badRequest, reason: "Missing code parameter")
        }
        
        // Verify state if provided
        if let expectedState = request.session.data["notion_state"],
           let receivedState = request.query[String.self, at: "state"],
           expectedState != receivedState {
            throw Abort(.badRequest, reason: "Invalid state parameter")
        }
        
        return try await exchangeCodeForToken(userId: userId, code: code)
    }
    
    /// Exchange an authorization code for a token without session validation
    /// - Parameters:
    ///   - userId: The ID of the user to associate with the token
    ///   - code: The authorization code from the OAuth flow
    /// - Returns: The token
    public func exchangeCodeForToken(userId: String, code: String) async throws -> NotionToken {
        // Exchange code for token using the notionClient
        let token = try await notionClient.exchangeCodeForToken(
            code: code,
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUri: redirectUri
        )
        
        // Save token to storage
        try await tokenStorage.saveToken(userId: userId, token: token)
        
        return token
    }
    
    // MARK: - Token Management
    
    /// Get a token for a user
    /// - Parameter userId: The ID of the user
    /// - Returns: The token, if available
    public func getToken(for userId: String) async throws -> NotionToken? {
        return try await tokenStorage.getToken(userId: userId)
    }
    
    /// Delete a token for a user
    /// - Parameter userId: The ID of the user
    public func deleteToken(for userId: String) async throws {
        try await tokenStorage.deleteToken(userId: userId)
    }
    
    // MARK: - Notion API Methods
    
    /// List all databases accessible to a user
    /// - Parameter userId: The ID of the user
    /// - Returns: An array of databases
    public func listDatabases(for userId: String) async throws -> [NotionDatabase] {
        // Get token for user
        guard let token = try await tokenStorage.getToken(userId: userId) else {
            throw Abort(.unauthorized, reason: "User not connected to Notion")
        }
        
        // Check if token is expired
        if token.isExpired {
            throw Abort(.unauthorized, reason: "Notion token expired")
        }
        
        return try await notionClient.listDatabases(token: token.accessToken)
    }
    
    /// Query a database
    /// - Parameters:
    ///   - databaseId: The ID of the database to query
    ///   - userId: The ID of the user
    ///   - query: The query parameters (filters, sorts, etc.)
    /// - Returns: The database items
    public func queryDatabase(
        databaseId: String,
        for userId: String,
        query: NotionDatabaseQueryRequest? = nil
    ) async throws -> NotionPaginatedResponse<NotionDatabaseItem> {
        // Get token for user
        guard let token = try await tokenStorage.getToken(userId: userId) else {
            throw Abort(.unauthorized, reason: "User not connected to Notion")
        }
        
        // Check if token is expired
        if token.isExpired {
            throw Abort(.unauthorized, reason: "Notion token expired")
        }
        
        return try await notionClient.queryDatabase(
            databaseId: databaseId,
            token: token.accessToken,
            query: query
        )
    }
}

// MARK: - Token Storage Implementation

/// A simple in-memory implementation of NotionTokenStorage
public final class InMemoryNotionTokenStorage: NotionTokenStorage, @unchecked Sendable {
    private var storage: [String: NotionToken] = [:]
    private let queue = DispatchQueue(label: "com.notionkit.tokenStorage")
    
    public init() {}
    
    /// Saves a Notion token for a user
    /// - Parameters:
    ///   - userId: The ID of the user
    ///   - token: The token to save
    public func saveToken(userId: String, token: NotionToken) async throws {
        queue.sync {
            storage[userId] = token
        }
    }
    
    /// Gets the Notion token for a user, if available
    /// - Parameter userId: The ID of the user
    /// - Returns: The token, if available
    public func getToken(userId: String) async throws -> NotionToken? {
        return queue.sync {
            storage[userId]
        }
    }
    
    /// Deletes the Notion token for a user
    /// - Parameter userId: The ID of the user
    public func deleteToken(userId: String) async throws {
        _ = queue.sync {
            storage.removeValue(forKey: userId)
        }
    }
}

// MARK: - Vapor Extensions

/// Extension to integrate with Vapor Application
extension Application {
    /// Access to the Notion client
    public var notion: NotionVaporClient {
        get {
            guard let client = self.storage[NotionVaporClientKey.self] else {
                fatalError("Notion client not configured. Use app.notion.configure()")
            }
            return client
        }
        set {
            self.storage[NotionVaporClientKey.self] = newValue
        }
    }
    
    /// Key for storing the Notion client in the Application
    private struct NotionVaporClientKey: StorageKey {
        typealias Value = NotionVaporClient
    }
}

/// Extension to configure the Notion client
extension NotionVaporClient {
    /// Configure the Notion client on a Vapor Application
    /// - Parameters:
    ///   - app: The Vapor Application
    ///   - clientId: The Notion OAuth client ID
    ///   - clientSecret: The Notion OAuth client secret
    ///   - redirectUri: The redirect URI for the OAuth flow
    public static func configure(
        app: Application,
        clientId: String,
        clientSecret: String,
        redirectUri: String
    ) {
        // Create token storage
        let tokenStorage = InMemoryNotionTokenStorage()
        
        // Create and store the client
        let client = NotionVaporClient(
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUri: redirectUri,
            tokenStorage: tokenStorage
        )
        
        app.notion = client
    }
} 

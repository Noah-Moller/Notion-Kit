import XCTest
import SwiftUI
import NotionKit
@testable import NotionKitClient

final class NotionClientManagerTests: XCTestCase {
    var clientManager: NotionClientManager!
    var mockTokenStorage: MockTokenStorage!
    var mockNotionClient: MockNotionClient!
    
    override func setUp() {
        super.setUp()
        mockTokenStorage = MockTokenStorage()
        mockNotionClient = MockNotionClient()
        clientManager = NotionClientManager(
            apiServerURL: URL(string: "https://example.com")!,
            clientId: "test-client-id",
            tokenStorage: mockTokenStorage,
            notionClient: mockNotionClient
        )
        mockTokenStorage.loadTokenCallCount = 0
    }
    
    override func tearDown() {
        clientManager = nil
        mockTokenStorage = nil
        mockNotionClient = nil
        super.tearDown()
    }
    
    func testInitWithExistingToken() {
        // Arrange
        let token = NotionToken(
            accessToken: "test-token",
            botId: "test-bot-id",
            workspaceId: "test-workspace-id",
            workspaceName: "Test Workspace"
        )
        mockTokenStorage.loadTokenResult = token
        
        // Act
        let clientManager = NotionClientManager(
            apiServerURL: URL(string: "https://example.com")!,
            clientId: "test-client-id",
            tokenStorage: mockTokenStorage,
            notionClient: mockNotionClient
        )
        
        // Assert
        XCTAssertTrue(clientManager.isAuthenticated)
        XCTAssertEqual(clientManager.token?.accessToken, "test-token")
        XCTAssertEqual(mockTokenStorage.loadTokenCallCount, 1)
    }
    
    func testInitWithExpiredToken() {
        // Arrange
        let token = NotionToken(
            accessToken: "test-token",
            botId: "test-bot-id",
            workspaceId: "test-workspace-id",
            workspaceName: "Test Workspace",
            expiresAt: Date(timeIntervalSinceNow: -3600) // Expired 1 hour ago
        )
        mockTokenStorage.loadTokenResult = token
        
        // Act
        let clientManager = NotionClientManager(
            apiServerURL: URL(string: "https://example.com")!,
            clientId: "test-client-id",
            tokenStorage: mockTokenStorage,
            notionClient: mockNotionClient
        )
        
        // Assert
        XCTAssertFalse(clientManager.isAuthenticated)
        XCTAssertNotNil(clientManager.token) // Token still exists but is marked as expired
        XCTAssertEqual(mockTokenStorage.loadTokenCallCount, 1)
    }
    
    func testSignOut() {
        // Arrange
        let token = NotionToken(
            accessToken: "test-token",
            botId: "test-bot-id",
            workspaceId: "test-workspace-id",
            workspaceName: "Test Workspace"
        )
        mockTokenStorage.loadTokenResult = token
        clientManager = NotionClientManager(
            apiServerURL: URL(string: "https://example.com")!,
            clientId: "test-client-id",
            tokenStorage: mockTokenStorage,
            notionClient: mockNotionClient
        )
        XCTAssertTrue(clientManager.isAuthenticated) // Verify initial state
        
        // Act
        clientManager.signOut()
        
        // Assert
        XCTAssertFalse(clientManager.isAuthenticated)
        XCTAssertNil(clientManager.token)
        XCTAssertTrue(clientManager.databases.isEmpty)
        XCTAssertEqual(mockTokenStorage.clearTokenCallCount, 1)
    }
}

// MARK: - Mock Classes

final class MockTokenStorage: UserDefaultsNotionTokenStorage, @unchecked Sendable {
    var loadTokenCallCount = 0
    var loadTokenResult: NotionToken?
    
    var saveTokenCallCount = 0
    var lastToken: NotionToken?
    
    var clearTokenCallCount = 0
    
    override func loadToken() -> NotionToken? {
        loadTokenCallCount += 1
        return loadTokenResult
    }
    
    override func saveToken(token: NotionToken) {
        saveTokenCallCount += 1
        lastToken = token
    }
    
    override func clearToken() {
        clearTokenCallCount += 1
    }
}

final class MockNotionClient: NotionClientProtocol, @unchecked Sendable {
    // getOAuthURL
    var getOAuthURLCallCount = 0
    var lastClientId: String?
    var lastRedirectUri: String?
    var lastState: String?
    var lastOwnerType: String?
    var getOAuthURLResult = URL(string: "https://example.com")!
    
    func getOAuthURL(clientId: String, redirectUri: String, state: String?, ownerType: String?) -> URL {
        getOAuthURLCallCount += 1
        lastClientId = clientId
        lastRedirectUri = redirectUri
        lastState = state
        lastOwnerType = ownerType
        return getOAuthURLResult
    }
    
    // exchangeCodeForToken
    var exchangeCodeForTokenCallCount = 0
    var lastCode: String?
    var lastClientSecret: String?
    var exchangeCodeForTokenResult: NotionToken!
    var exchangeCodeForTokenError: Error?
    
    func exchangeCodeForToken(code: String, clientId: String, clientSecret: String, redirectUri: String) async throws -> NotionToken {
        exchangeCodeForTokenCallCount += 1
        lastCode = code
        lastClientId = clientId
        lastClientSecret = clientSecret
        lastRedirectUri = redirectUri
        
        if let error = exchangeCodeForTokenError {
            throw error
        }
        
        return exchangeCodeForTokenResult ?? NotionToken(
            accessToken: "mock-token",
            botId: "mock-bot-id",
            workspaceId: "mock-workspace-id",
            workspaceName: "Mock Workspace"
        )
    }
    
    // listDatabases
    var listDatabasesCallCount = 0
    var lastToken: String?
    var listDatabasesResult: [NotionDatabase] = []
    var listDatabasesError: Error?
    
    func listDatabases(token: String) async throws -> [NotionDatabase] {
        listDatabasesCallCount += 1
        lastToken = token
        
        if let error = listDatabasesError {
            throw error
        }
        
        return listDatabasesResult
    }
    
    // queryDatabase
    var queryDatabaseCallCount = 0
    var lastDatabaseId: String?
    var lastQuery: NotionDatabaseQueryRequest?
    var queryDatabaseResult: NotionPaginatedResponse<NotionDatabaseItem>!
    var queryDatabaseError: Error?
    
    func queryDatabase(databaseId: String, token: String, query: NotionDatabaseQueryRequest?) async throws -> NotionPaginatedResponse<NotionDatabaseItem> {
        queryDatabaseCallCount += 1
        lastDatabaseId = databaseId
        lastToken = token
        lastQuery = query
        
        if let error = queryDatabaseError {
            throw error
        }
        
        return queryDatabaseResult ?? NotionPaginatedResponse<NotionDatabaseItem>(
            object: "list",
            results: [],
            nextCursor: nil,
            hasMore: false
        )
    }
} 
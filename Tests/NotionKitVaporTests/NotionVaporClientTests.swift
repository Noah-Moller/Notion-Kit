import XCTest
import Vapor
import NotionKit
@testable import NotionKitVapor

final class NotionVaporClientTests: XCTestCase {
    var app: Application!
    var mockNotionClient: MockNotionClient!
    var mockTokenStorage: MockTokenStorage!
    var vaporClient: NotionVaporClient!
    
    override func setUp() async throws {
        try await super.setUp()
        app = try await Application.make(.testing)
        
        // Configure sessions middleware for testing
        app.middleware.use(app.sessions.middleware)
        
        mockNotionClient = MockNotionClient()
        mockTokenStorage = MockTokenStorage()
        
        vaporClient = NotionVaporClient(
            clientId: "test-client-id",
            clientSecret: "test-client-secret",
            redirectUri: "http://localhost:8080/notion/callback",
            tokenStorage: mockTokenStorage,
            notionClient: mockNotionClient
        )
    }
    
    override func tearDown() async throws {
        // Use a non-blocking approach to shutdown the app
        app.running?.stop()
        try await super.tearDown()
    }
    
    func testGetOAuthURL() async throws {
        // Arrange
        mockNotionClient.getOAuthURLResult = URL(string: "https://api.notion.com/v1/oauth/authorize?client_id=test-client-id&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fnotion%2Fcallback&response_type=code&state=test-state")!
        
        // Act
        let url = vaporClient.getOAuthURL(state: "test-state")
        
        // Assert
        XCTAssertEqual(url.absoluteString, "https://api.notion.com/v1/oauth/authorize?client_id=test-client-id&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fnotion%2Fcallback&response_type=code&state=test-state")
        XCTAssertEqual(mockNotionClient.getOAuthURLCallCount, 1)
        XCTAssertEqual(mockNotionClient.lastClientId, "test-client-id")
        XCTAssertEqual(mockNotionClient.lastRedirectUri, "http://localhost:8080/notion/callback")
        XCTAssertEqual(mockNotionClient.lastState, "test-state")
    }
    
    func testHandleCallback() async throws {
        // Arrange
        let code = "test-code"
        let userId = "test-user-id"
        let token = NotionToken(
            accessToken: "test-token",
            botId: "test-bot-id",
            workspaceId: "test-workspace-id",
            workspaceName: "Test Workspace"
        )
        
        mockNotionClient.exchangeCodeForTokenResult = token
        
        // Call the exchangeCodeForToken method directly on the vaporClient
        try await vaporClient.exchangeCodeForToken(userId: userId, code: code)
        
        // Assert
        XCTAssertEqual(mockNotionClient.exchangeCodeForTokenCallCount, 1)
        XCTAssertEqual(mockNotionClient.lastCode, code)
        XCTAssertEqual(mockNotionClient.lastClientId, "test-client-id")
        XCTAssertEqual(mockNotionClient.lastClientSecret, "test-client-secret")
        XCTAssertEqual(mockNotionClient.lastRedirectUri, "http://localhost:8080/notion/callback")
    }
    
    func testListDatabases() async throws {
        // Arrange
        let userId = "test-user-id"
        let token = NotionToken(
            accessToken: "test-token",
            botId: "test-bot-id",
            workspaceId: "test-workspace-id",
            workspaceName: "Test Workspace"
        )
        let databases = [
            NotionDatabase(
                id: "db1",
                title: [
                    NotionRichText(
                        plainText: "Test Database",
                        href: nil,
                        annotations: NotionAnnotations(
                            bold: false,
                            italic: false,
                            strikethrough: false,
                            underline: false,
                            code: false,
                            color: "default"
                        ),
                        type: "text",
                        text: NotionTextContent(
                            content: "Test Database",
                            link: nil
                        )
                    )
                ],
                properties: [:],
                url: "https://www.notion.so/test/db1"
            )
        ]
        
        mockTokenStorage.getTokenResult = token
        mockNotionClient.listDatabasesResult = databases
        
        // Act
        let result = try await vaporClient.listDatabases(for: userId)
        
        // Assert
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "db1")
        XCTAssertEqual(result[0].name, "Test Database")
        
        XCTAssertEqual(mockTokenStorage.getTokenCallCount, 1)
        XCTAssertEqual(mockTokenStorage.lastUserId, "test-user-id")
        
        XCTAssertEqual(mockNotionClient.listDatabasesCallCount, 1)
        XCTAssertEqual(mockNotionClient.lastToken, "test-token")
    }
}

// MARK: - Mock Classes

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
    
    func exchangeCodeForToken(code: String, clientId: String, clientSecret: String, redirectUri: String) async throws -> NotionToken {
        exchangeCodeForTokenCallCount += 1
        lastCode = code
        lastClientId = clientId
        lastClientSecret = clientSecret
        lastRedirectUri = redirectUri
        return exchangeCodeForTokenResult
    }
    
    // listDatabases
    var listDatabasesCallCount = 0
    var lastToken: String?
    var listDatabasesResult: [NotionDatabase] = []
    
    func listDatabases(token: String) async throws -> [NotionDatabase] {
        listDatabasesCallCount += 1
        lastToken = token
        return listDatabasesResult
    }
    
    // queryDatabase
    var queryDatabaseCallCount = 0
    var lastDatabaseId: String?
    var lastQuery: NotionDatabaseQueryRequest?
    var queryDatabaseResult: NotionPaginatedResponse<NotionDatabaseItem>!
    
    func queryDatabase(databaseId: String, token: String, query: NotionDatabaseQueryRequest?) async throws -> NotionPaginatedResponse<NotionDatabaseItem> {
        queryDatabaseCallCount += 1
        lastDatabaseId = databaseId
        lastToken = token
        lastQuery = query
        return queryDatabaseResult ?? NotionPaginatedResponse<NotionDatabaseItem>(
            object: "list",
            results: [],
            nextCursor: nil,
            hasMore: false
        )
    }
}

final class MockTokenStorage: NotionTokenStorage, @unchecked Sendable {
    // saveToken
    var saveTokenCallCount = 0
    var lastUserId: String?
    var lastToken: NotionToken?
    
    func saveToken(userId: String, token: NotionToken) async throws {
        saveTokenCallCount += 1
        lastUserId = userId
        lastToken = token
    }
    
    // getToken
    var getTokenCallCount = 0
    var getTokenResult: NotionToken?
    
    func getToken(userId: String) async throws -> NotionToken? {
        getTokenCallCount += 1
        lastUserId = userId
        return getTokenResult
    }
    
    // deleteToken
    var deleteTokenCallCount = 0
    
    func deleteToken(userId: String) async throws {
        deleteTokenCallCount += 1
        lastUserId = userId
    }
} 
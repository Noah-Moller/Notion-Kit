import Foundation
import SwiftUI
import AuthenticationServices
import NotionKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A SwiftUI implementation of the Notion API client manager
public class NotionClientManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the user is authenticated with Notion
    @Published public private(set) var isAuthenticated = false
    
    /// The current token
    @Published public private(set) var token: NotionToken?
    
    /// Workspace information
    @Published public private(set) var workspace: NotionWorkspace?
    
    /// The available databases
    @Published public private(set) var databases: [NotionDatabase] = []
    
    /// The pages retrieved from Notion
    @Published public private(set) var pages: [NotionPage] = []
    
    /// The blocks for the current selected page
    @Published public private(set) var pageBlocks: [NotionBlock] = []
    
    /// The current selected page ID
    @Published public private(set) var selectedPageId: String?
    
    /// Any error that occurred
    @Published public private(set) var error: Error?
    
    /// Whether a request is in progress
    @Published public private(set) var isLoading = false
    
    // MARK: - Private Properties
    
    /// The base Notion client
    private let notionClient: NotionClientProtocol
    
    /// The API server URL for token exchange and API calls
    private let apiServerURL: URL
    
    /// The Notion OAuth client ID
    private let clientId: String
    
    /// The token storage
    private let tokenStorage: UserDefaultsNotionTokenStorage
    
    /// The user ID to use in API requests
    private let userId: String
    
    // MARK: - Initialization
    
    /// Initialize a new client manager
    /// - Parameters:
    ///   - apiServerURL: The API server URL for token exchange and API calls
    ///   - clientId: The Notion OAuth client ID
    ///   - userId: The user ID to use in API requests (defaults to "client-user")
    ///   - tokenStorage: An optional custom token storage
    ///   - notionClient: An optional custom Notion client
    public init(
        apiServerURL: URL,
        clientId: String,
        userId: String = "client-user",
        tokenStorage: UserDefaultsNotionTokenStorage = UserDefaultsNotionTokenStorage(),
        notionClient: NotionClientProtocol? = nil
    ) {
        self.apiServerURL = apiServerURL
        self.clientId = clientId
        self.userId = userId
        self.tokenStorage = tokenStorage
        self.notionClient = notionClient ?? NotionClient(clientId: clientId)
        
        // Load token from storage on init
        self.token = tokenStorage.loadToken()
        self.isAuthenticated = self.token != nil && !(self.token?.isExpired ?? true)
        
        // Debug: Print configuration
        print("=== NotionClientManager Configuration ===")
        print("API Server URL: \(apiServerURL.absoluteString)")
        print("User ID: \(userId)")
        print("Token loaded: \(self.token != nil)")
        print("Is authenticated: \(self.isAuthenticated)")
    }
    
    // MARK: - Public Properties
    
    /// Get the server URL (read-only access to the private apiServerURL)
    public var serverURL: URL {
        return apiServerURL
    }
    
    /// Get the user ID (read-only access to the private userId)
    public func getUserId() -> String {
        return userId
    }
    
    // MARK: - Authentication
    
    /// Start the OAuth flow
    /// - Parameters:
    ///   - redirectURI: The redirect URI for the OAuth flow
    ///   - presentationContextProvider: The presentation context provider for the web authentication session
    public func authenticate(
        redirectURI: String,
        from presentationContextProvider: ASWebAuthenticationPresentationContextProviding
    ) {
        isLoading = true
        error = nil
        
        // Generate a random state for CSRF protection
        let state = UUID().uuidString
        
        // Get the OAuth URL
        let authURL = notionClient.getOAuthURL(
            redirectURI: redirectURI,
            state: state,
            userId: userId
        )
        
        // Start the web authentication session
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: URL(string: redirectURI)?.scheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    self.error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No callback URL"])
                    return
                }
                
                // Parse the callback URL
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
                      let queryItems = components.queryItems else {
                    self.error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid callback URL"])
                    return
                }
                
                // Get code from query parameters
                guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    // Check for error in query parameters
                    if let errorMessage = queryItems.first(where: { $0.name == "error" })?.value {
                        self.error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authorization failed: \(errorMessage)"])
                    } else {
                        self.error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No code parameter in callback URL"])
                    }
                    return
                }
                
                // Verify state
                guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
                      returnedState == state else {
                    self.error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid state parameter"])
                    return
                }
                
                // Exchange code for token on server
                self.exchangeCodeForToken(code: code, redirectURI: redirectURI)
            }
        }
        
        session.presentationContextProvider = presentationContextProvider
        session.prefersEphemeralWebBrowserSession = true
        
        if !session.start() {
            isLoading = false
            error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start authentication session"])
        }
    }
    
    /// Exchange the authorization code for a token
    /// - Parameters:
    ///   - code: The authorization code
    ///   - redirectURI: The redirect URI used in the OAuth flow
    private func exchangeCodeForToken(code: String, redirectURI: String) {
        isLoading = true
        
        // Build the URL for the token exchange endpoint on our server
        var components = URLComponents(url: apiServerURL.appendingPathComponent("api/notion/token"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        
        guard let tokenURL = components.url else {
            self.error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create token URL"])
            self.isLoading = false
            return
        }
        
        // Create request
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body
        let body: [String: String] = [
            "code": code,
            "redirect_uri": redirectURI
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.error = error
            self.isLoading = false
            return
        }
        
        // Make request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let data = data else {
                    self.error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
                    return
                }
                
                // Decode token response
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(TokenResponse.self, from: data)
                    
                    // Create token
                    let token = NotionToken(
                        accessToken: response.accessToken,
                        botId: response.botId,
                        workspaceId: response.workspaceId,
                        workspaceName: response.workspaceName,
                        workspaceIcon: response.workspaceIcon
                    )
                    
                    // Save token
                    self.token = token
                    self.tokenStorage.saveToken(token: token)
                    self.isAuthenticated = true
                    
                    // Load databases
                    self.loadDatabases()
                } catch {
                    self.error = error
                }
            }
        }.resume()
    }
    
    /// Sign out from Notion
    public func signOut() {
        // Clear token from storage
        tokenStorage.clearToken()
        
        // Update state
        token = nil
        isAuthenticated = false
        databases = []
        pages = []
        pageBlocks = []
        selectedPageId = nil
    }
    
    // MARK: - API Methods
    
    /// Load the databases accessible to the user
    public func loadDatabases() {
        guard let token = token, !token.isExpired else {
            error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated or token expired"])
            return
        }
        
        isLoading = true
        
        // Build the URL for the databases endpoint on our server
        var components = URLComponents(url: apiServerURL.appendingPathComponent("api/notion/databases"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        
        guard let databasesURL = components.url else {
            self.error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create databases URL"])
            self.isLoading = false
            return
        }
        
        // Create request
        var request = URLRequest(url: databasesURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        // Make request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let data = data else {
                    self.error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
                    return
                }
                
                // Decode databases response
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(DatabasesResponse.self, from: data)
                    self.databases = response.databases
                } catch {
                    self.error = error
                }
            }
        }.resume()
    }
    
    /// Fetch pages from Notion API
    public func fetchPages() {
        guard isAuthenticated else {
            self.error = NSError(
                domain: "com.notionkit.client",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated with Notion"]
            )
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let pagesUrl = apiServerURL.appendingPathComponent("notion/pages")
                var components = URLComponents(url: pagesUrl, resolvingAgainstBaseURL: true)!
                components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
                
                guard let url = components.url else {
                    print("Error: Failed to construct pages URL")
                    throw NSError(
                        domain: "com.notionkit.client",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"]
                    )
                }
                
                print("Fetching pages from URL: \(url.absoluteString)")
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("Error: Invalid response type")
                        throw NSError(
                            domain: "com.notionkit.client",
                            code: 400,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                        )
                    }
                    
                    print("Pages response status: \(httpResponse.statusCode)")
                    
                    guard httpResponse.statusCode == 200 else {
                        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                        print("HTTP Error \(httpResponse.statusCode): \(errorMessage)")
                        throw NSError(
                            domain: "com.notionkit.client",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode): \(errorMessage)"]
                        )
                    }
                    
                    let decoder = JSONDecoder()
                    
                    struct PagesResponse: Decodable {
                        var count: Int
                        let pages: [NotionPage]
                        
                        // Add custom decoding to handle both formats
                        init(from decoder: Decoder) throws {
                            do {
                                // Try to decode as object with count and pages
                                let container = try decoder.container(keyedBy: CodingKeys.self)
                                self.count = try container.decode(Int.self, forKey: .count)
                                self.pages = try container.decode([NotionPage].self, forKey: .pages)
                            } catch {
                                // Try to decode as direct array of pages
                                let pages = try [NotionPage].init(from: decoder)
                                self.count = pages.count
                                self.pages = pages
                            }
                        }
                        
                        private enum CodingKeys: String, CodingKey {
                            case count, pages
                        }
                    }
                    
                    do {
                        let pagesResponse = try decoder.decode(PagesResponse.self, from: data)
                        print("Successfully decoded \(pagesResponse.pages.count) pages")
                        
                        DispatchQueue.main.async { [weak self] in
                            self?.pages = pagesResponse.pages
                            self?.isLoading = false
                        }
                    } catch {
                        print("Decoding error: \(error)")
                        // Try to decode as direct array
                        do {
                            let pages = try decoder.decode([NotionPage].self, from: data)
                            print("Successfully decoded \(pages.count) pages (direct array)")
                            DispatchQueue.main.async { [weak self] in
                                self?.pages = pages
                                self?.isLoading = false
                            }
                            return
                        } catch {
                            print("Failed to decode even as direct array: \(error)")
                            throw error
                        }
                    }
                } catch let urlError as URLError {
                    print("Network error: \(urlError.localizedDescription)")
                    print("Error code: \(urlError.errorCode)")
                    
                    // Add specific diagnosis for connection errors
                    if urlError.code == .cannotConnectToHost || urlError.code == .networkConnectionLost {
                        print("Connection error: Make sure the server is running at \(url.host ?? "unknown host"):\(url.port ?? 0)")
                        print("Check firewall settings and network connectivity.")
                    }
                    
                    throw urlError
                }
            } catch {
                print("Error fetching pages: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.error = error as NSError
                    self?.isLoading = false
                }
            }
        }
    }
    
    /// Fetch blocks for a specific page
    public func fetchPageBlocks(pageId: String) {
        guard isAuthenticated else {
            self.error = NSError(
                domain: "com.notionkit.client",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated with Notion"]
            )
            return
        }
        
        isLoading = true
        selectedPageId = pageId
        
        Task {
            do {
                let blocksUrl = apiServerURL.appendingPathComponent("notion/pages/\(pageId)/blocks")
                var components = URLComponents(url: blocksUrl, resolvingAgainstBaseURL: true)!
                components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
                
                guard let url = components.url else {
                    throw NSError(
                        domain: "com.notionkit.client",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"]
                    )
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(
                        domain: "com.notionkit.client",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                    )
                }
                
                print("Page blocks response status: \(httpResponse.statusCode)")
                
                // Debug: Print the response body
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseString.prefix(200))...")
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw NSError(
                        domain: "com.notionkit.client",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode): \(errorMessage)"]
                    )
                }
                
                let decoder = JSONDecoder()
                
                struct BlocksResponse: Decodable {
                    var count: Int
                    let blocks: [NotionBlock]
                    
                    // Add custom decoding to handle both formats
                    init(from decoder: Decoder) throws {
                        do {
                            // Try to decode as object with count and blocks
                            let container = try decoder.container(keyedBy: CodingKeys.self)
                            self.count = try container.decode(Int.self, forKey: .count)
                            self.blocks = try container.decode([NotionBlock].self, forKey: .blocks)
                        } catch {
                            // Try to decode as direct array of blocks
                            let blocks = try [NotionBlock].init(from: decoder)
                            self.count = blocks.count
                            self.blocks = blocks
                        }
                    }
                    
                    private enum CodingKeys: String, CodingKey {
                        case count, blocks
                    }
                }
                
                do {
                    let blocksResponse = try decoder.decode(BlocksResponse.self, from: data)
                    print("Successfully decoded \(blocksResponse.blocks.count) blocks")
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.pageBlocks = blocksResponse.blocks
                        self?.isLoading = false
                    }
                } catch {
                    print("Decoding error: \(error)")
                    // Try to decode as direct array
                    do {
                        let blocks = try decoder.decode([NotionBlock].self, from: data)
                        print("Successfully decoded \(blocks.count) blocks (direct array)")
                        DispatchQueue.main.async { [weak self] in
                            self?.pageBlocks = blocks
                            self?.isLoading = false
                        }
                    } catch {
                        print("Failed to decode blocks: \(error)")
                        throw error
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.error = error as NSError
                    self?.isLoading = false
                }
            }
        }
    }
    
    /// Query a database
    /// - Parameters:
    ///   - databaseId: The ID of the database to query
    ///   - query: The query parameters (filters, sorts, etc.)
    ///   - completion: A completion handler called when the query is complete
    public func queryDatabase(
        databaseId: String,
        query: NotionDatabaseQueryRequest? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let token = token, !token.isExpired else {
            completion(.failure(NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated or token expired"])))
            return
        }
        
        isLoading = true
        
        // Build the URL for the database query endpoint on our server
        var components = URLComponents(url: apiServerURL.appendingPathComponent("api/notion/databases/\(databaseId)/query"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        
        guard let queryURL = components.url else {
            let error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create query URL"])
            self.error = error
            self.isLoading = false
            completion(.failure(error))
            return
        }
        
        // Create request
        var request = URLRequest(url: queryURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add query body if provided
        if let query = query {
            do {
                let encoder = JSONEncoder()
                request.httpBody = try encoder.encode(query)
            } catch {
                self.error = error
                self.isLoading = false
                completion(.failure(error))
                return
            }
        }
        
        // Make request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
                    self.error = error
                    completion(.failure(error))
                    return
                }
                
                // Parse response
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        let error = NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response as JSON"])
                        self.error = error
                        completion(.failure(error))
                        return
                    }
                    
                    completion(.success(json))
                } catch {
                    self.error = error
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Reset the current error
    public func resetError() {
        self.error = nil
    }
    
    /// Gets the OAuth URL for Notion authentication
    /// - Parameter redirectURI: The redirect URI for the OAuth flow
    /// - Returns: The OAuth URL
    public func getAuthURL(redirectURI: String) -> URL {
        return URL(string: "\(apiServerURL.absoluteString)/notion/auth/url?redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI)&user_id=\(userId)")!
    }
    
    /// Handles the OAuth callback from Notion
    /// - Parameters:
    ///   - url: The callback URL
    ///   - redirectURI: The redirect URI used for the OAuth flow
    public func handleCallback(url: URL, redirectURI: String) {
        // Extract the code from the URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            // Handle error - no code found
            self.error = NSError(
                domain: "com.notionkit.client",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "No authorization code found in callback URL"]
            )
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Build the token exchange URL
                let tokenURL = apiServerURL.appendingPathComponent("notion/token")
                
                // Create the request
                var request = URLRequest(url: tokenURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Create the request body
                struct TokenRequest: Codable {
                    let code: String
                    let redirectUri: String
                    let userId: String
                }
                
                let tokenRequest = TokenRequest(
                    code: code,
                    redirectUri: redirectURI,
                    userId: userId
                )
                
                let encoder = JSONEncoder()
                request.httpBody = try encoder.encode(tokenRequest)
                
                // Make the request
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(
                        domain: "com.notionkit.client",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                    )
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw NSError(
                        domain: "com.notionkit.client",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode): \(errorMessage)"]
                    )
                }
                
                // Decode the response
                let decoder = JSONDecoder()
                
                struct TokenResponse: Decodable {
                    let success: Bool
                    let workspace: String
                }
                
                let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
                
                // Update state
                DispatchQueue.main.async { [weak self] in
                    self?.isAuthenticated = tokenResponse.success
                    // Create workspace from token if available
                    if tokenResponse.success, let token = self?.token {
                        self?.workspace = NotionWorkspace(
                            id: token.workspaceId,
                            name: token.workspaceName,
                            icon: token.workspaceIcon
                        )
                    }
                    self?.isLoading = false
                    
                    // Load databases if we're authenticated
                    if tokenResponse.success {
                        self?.loadDatabases()
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.error = error as NSError
                    self?.isLoading = false
                }
            }
        }
    }
    
    /// Fetch databases from the API server
    /// - Returns: An array of databases
    public func fetchDatabases() async throws -> [NotionDatabase] {
        // No need to check if userId is nil since it's not optional
        
        var components = URLComponents(url: apiServerURL.appendingPathComponent("api/notion/databases"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userId)
        ]
        
        guard let url = components.url else {
            print("Error: Failed to create databases URL")
            throw NotionClientError.invalidURL
        }
        
        print("Fetching databases from: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Invalid response type")
                throw NotionClientError.invalidResponse
            }
            
            print("Databases response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Error response: \(errorString)")
                throw NotionClientError.httpError(statusCode: httpResponse.statusCode, message: errorString)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode([NotionDatabase].self, from: data)
        } catch let urlError as URLError {
            print("Network error: \(urlError.localizedDescription)")
            print("Error code: \(urlError.errorCode)")
            
            // Add specific diagnosis for connection errors
            if urlError.code == .cannotConnectToHost || urlError.code == .networkConnectionLost {
                print("Connection error: Make sure the server is running at \(url.host ?? "unknown host"):\(url.port ?? 0)")
                print("Check firewall settings and network connectivity.")
            }
            
            throw urlError
        } catch {
            print("Decoding error: \(error)")
            throw error
        }
    }
    
    /// Fetch blocks for a specific block (used for nested blocks)
    public func fetchChildBlocks(blockId: String) async throws -> [NotionBlock] {
        guard isAuthenticated else {
            throw NSError(
                domain: "com.notionkit.client",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated with Notion"]
            )
        }
        
        let blocksUrl = apiServerURL.appendingPathComponent("notion/blocks/\(blockId)/children")
        var components = URLComponents(url: blocksUrl, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        
        guard let url = components.url else {
            throw NSError(
                domain: "com.notionkit.client",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "com.notionkit.client",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
            )
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "com.notionkit.client",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode): \(errorMessage)"]
            )
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([NotionBlock].self, from: data)
    }
}

// MARK: - Token Storage

/// A UserDefaults implementation of token storage
public class UserDefaultsNotionTokenStorage {
    
    // MARK: - Properties
    
    /// The UserDefaults suite
    private let userDefaults: UserDefaults
    
    /// The key for storing the token
    private let tokenKey: String
    
    // MARK: - Initialization
    
    /// Initialize a new UserDefaults token storage
    /// - Parameters:
    ///   - userDefaults: The UserDefaults suite (defaults to standard)
    ///   - tokenKey: The key for storing the token (defaults to "com.notionkit.token")
    public init(
        userDefaults: UserDefaults = .standard,
        tokenKey: String = "com.notionkit.token"
    ) {
        self.userDefaults = userDefaults
        self.tokenKey = tokenKey
    }
    
    // MARK: - Methods
    
    /// Save a token to UserDefaults
    /// - Parameter token: The token to save
    public func saveToken(token: NotionToken) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(token) {
            userDefaults.set(data, forKey: tokenKey)
        }
    }
    
    /// Load a token from UserDefaults
    /// - Returns: The token, if available
    public func loadToken() -> NotionToken? {
        guard let data = userDefaults.data(forKey: tokenKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(NotionToken.self, from: data)
    }
    
    /// Clear the token from UserDefaults
    public func clearToken() {
        userDefaults.removeObject(forKey: tokenKey)
    }
}

// MARK: - Response Models

/// Response for token exchange
private struct TokenResponse: Decodable {
    let accessToken: String
    let botId: String
    let workspaceId: String
    let workspaceName: String
    let workspaceIcon: String?
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case botId = "bot_id"
        case workspaceId = "workspace_id"
        case workspaceName = "workspace_name"
        case workspaceIcon = "workspace_icon"
    }
}

/// Response for databases list
private struct DatabasesResponse: Decodable {
    let databases: [NotionDatabase]
}

// MARK: - View Extensions

#if os(iOS)
/// Extension to provide AuthenticationServices convenience methods
extension View {
    /// Present the Notion OAuth flow
    /// - Parameters:
    ///   - clientManager: The Notion client manager
    ///   - redirectURI: The redirect URI for the OAuth flow
    public func connectToNotion(
        clientManager: NotionClientManager,
        redirectURI: String
    ) {
        // Get the current window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Create a presentation context provider
        let contextProvider = WebAuthenticationPresentationContextProvider(presentingViewController: rootViewController)
        
        // Start authentication
        clientManager.authenticate(redirectURI: redirectURI, from: contextProvider)
    }
}

/// Provider for ASWebAuthenticationSession presentation context
private class WebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    
    /// The view controller that will present the authentication session
    private let presentingViewController: UIViewController
    
    /// Initialize a new presentation context provider
    /// - Parameter presentingViewController: The view controller that will present the authentication session
    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        super.init()
    }
    
    /// Provide the presentation anchor for the authentication session
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return presentingViewController.view.window ?? ASPresentationAnchor()
    }
}
#endif

#if os(macOS)
/// Extension to provide AuthenticationServices convenience methods for macOS
extension View {
    /// Present the Notion OAuth flow
    /// - Parameters:
    ///   - clientManager: The Notion client manager
    ///   - redirectURI: The redirect URI for the OAuth flow
    public func connectToNotion(
        clientManager: NotionClientManager,
        redirectURI: String
    ) {
        // Get the current window
        guard let window = NSApplication.shared.keyWindow else {
            return
        }
        
        // Create a presentation context provider
        let contextProvider = MacWebAuthenticationPresentationContextProvider(window: window)
        
        // Start authentication
        clientManager.authenticate(redirectURI: redirectURI, from: contextProvider)
    }
}

/// Provider for ASWebAuthenticationSession presentation context for macOS
private class MacWebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    
    /// The window that will present the authentication session
    private let window: NSWindow
    
    /// Initialize a new presentation context provider
    /// - Parameter window: The window that will present the authentication session
    init(window: NSWindow) {
        self.window = window
        super.init()
    }
    
    /// Provide the presentation anchor for the authentication session
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return window
    }
}
#endif

/// A struct representing a Notion workspace
public struct NotionWorkspace: Identifiable {
    public let id: String
    public let name: String
    public let icon: String?
    
    public init(id: String, name: String, icon: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
    }
} 

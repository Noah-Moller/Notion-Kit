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
    
    /// The available databases
    @Published public private(set) var databases: [NotionDatabase] = []
    
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
        notionClient: NotionClientProtocol = NotionClient()
    ) {
        self.apiServerURL = apiServerURL
        self.clientId = clientId
        self.userId = userId
        self.tokenStorage = tokenStorage
        self.notionClient = notionClient
        
        // Load token from storage on init
        self.token = tokenStorage.loadToken()
        self.isAuthenticated = self.token != nil && !(self.token?.isExpired ?? true)
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
            clientId: clientId,
            redirectUri: redirectURI,
            state: state,
            ownerType: nil
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

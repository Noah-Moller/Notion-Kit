import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Implementation of the Notion API client
public class NotionClient: NotionClientProtocol, @unchecked Sendable {
    // MARK: - Properties
    
    /// The base URL for the Notion API
    public let baseURL: URL
    
    /// The base URL for the Notion OAuth endpoints
    public let oauthURL: URL
    
    // MARK: - Initialization
    
    /// Initialize a new Notion client
    /// - Parameters:
    ///   - baseURL: The base URL for the Notion API (defaults to "https://api.notion.com/v1")
    ///   - oauthURL: The base URL for the Notion OAuth endpoints (defaults to "https://api.notion.com/v1/oauth")
    public init(
        baseURL: URL = URL(string: "https://api.notion.com/v1")!,
        oauthURL: URL = URL(string: "https://api.notion.com/v1/oauth")!
    ) {
        self.baseURL = baseURL
        self.oauthURL = oauthURL
    }
    
    // MARK: - OAuth Methods
    
    /// Get the OAuth URL for user authentication
    /// - Parameters:
    ///   - clientId: The Notion OAuth client ID
    ///   - redirectUri: The redirect URI for the OAuth flow
    ///   - state: An optional state parameter for CSRF protection
    ///   - ownerType: The type of owner (user or workspace)
    /// - Returns: The OAuth URL
    public func getOAuthURL(clientId: String, redirectUri: String, state: String? = nil, ownerType: String? = nil) -> URL {
        var components = URLComponents(string: "https://api.notion.com/v1/oauth/authorize")!
        
        var queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code")
        ]
        
        if let state = state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        
        if let ownerType = ownerType {
            queryItems.append(URLQueryItem(name: "owner", value: ownerType))
        }
        
        components.queryItems = queryItems
        return components.url!
    }
    
    /// Exchange an OAuth code for a token
    /// - Parameters:
    ///   - code: The authorization code from the OAuth flow
    ///   - clientId: The Notion OAuth client ID
    ///   - clientSecret: The Notion OAuth client secret
    ///   - redirectUri: The redirect URI used in the OAuth flow
    /// - Returns: A token object
    public func exchangeCodeForToken(code: String, clientId: String, clientSecret: String, redirectUri: String) async throws -> NotionToken {
        let tokenURL = URL(string: "https://api.notion.com/v1/oauth/token")!
        
        // Create request with authorization header
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create Basic Auth header with client ID and secret
        let credentials = "\(clientId):\(clientSecret)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        // Create request body
        let tokenRequest = NotionTokenRequest(code: code, redirectUri: redirectUri)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(tokenRequest)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Handle error responses
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            // Try to decode error
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(NotionError.self, from: data) {
                throw error
            } else {
                throw NSError(domain: "NotionKitError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"])
            }
        }
        
        // Decode token response
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(NotionTokenResponse.self, from: data)
        return tokenResponse.token
    }
    
    // MARK: - API Methods
    
    /// List all databases accessible to the token
    /// - Parameter token: The access token
    /// - Returns: An array of databases
    public func listDatabases(token: String) async throws -> [NotionDatabase] {
        let url = baseURL.appendingPathComponent("databases")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version") // Use appropriate version
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Handle error responses
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            // Try to decode error
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(NotionError.self, from: data) {
                throw error
            } else {
                throw NSError(domain: "NotionKitError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"])
            }
        }
        
        // Decode database list
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(NotionPaginatedResponse<NotionDatabase>.self, from: data)
        return apiResponse.results
    }
    
    /// Query a database
    /// - Parameters:
    ///   - databaseId: The ID of the database to query
    ///   - token: The access token
    ///   - query: The query parameters (filters, sorts, etc.)
    /// - Returns: A paginated response with database items
    public func queryDatabase(databaseId: String, token: String, query: NotionDatabaseQueryRequest? = nil) async throws -> NotionPaginatedResponse<NotionDatabaseItem> {
        let url = baseURL.appendingPathComponent("databases").appendingPathComponent(databaseId).appendingPathComponent("query")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version") // Use appropriate version
        
        // Add query body if provided
        if let query = query {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(query)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Handle error responses
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            // Try to decode error
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(NotionError.self, from: data) {
                throw error
            } else {
                throw NSError(domain: "NotionKitError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"])
            }
        }
        
        // Try to decode the response directly
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(NotionPaginatedResponse<NotionDatabaseItem>.self, from: data)
        } catch {
            // Fallback to manual parsing if direct decoding fails
            guard let json = try? JSONSerialization.jsonObject(with: data),
                  let responseDictionary = json as? [String: Any],
                  let resultsArray = responseDictionary["results"] as? [[String: Any]],
                  let object = responseDictionary["object"] as? String,
                  let hasMore = responseDictionary["has_more"] as? Bool else {
                throw NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
            }
            
            let nextCursor = responseDictionary["next_cursor"] as? String
            
            // Convert the raw dictionaries to our structured type
            var items: [NotionDatabaseItem] = []
            for result in resultsArray {
                guard let id = result["id"] as? String,
                      let url = result["url"] as? String,
                      let properties = result["properties"] as? [String: [String: Any]] else {
                    continue
                }
                
                // Simplify properties to make them Codable
                // This is a simplified approach - in a real app you'd want to properly map all property types
                var simplifiedProperties: [String: [String: String]] = [:]
                for (key, value) in properties {
                    var simpleProp: [String: String] = [:]
                    if let type = value["type"] as? String {
                        simpleProp["type"] = type
                    }
                    simplifiedProperties[key] = simpleProp
                }
                
                let item = NotionDatabaseItem(properties: simplifiedProperties, id: id, url: url)
                items.append(item)
            }
            
            return NotionPaginatedResponse<NotionDatabaseItem>(
                object: object,
                results: items,
                nextCursor: nextCursor,
                hasMore: hasMore
            )
        }
    }
} 

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Extension to provide URL encoding functionality
extension String {
    func urlEncoded() -> String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

/// Errors that can occur when using the Notion API
public enum NotionClientError: Error {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case encodingError(Error)
    case invalidURL
    case missingParameters
    case unauthorized
}

/// Response structure for error messages from the Notion API
public struct ErrorResponse: Codable {
    public let status: Int?
    public let code: String?
    public let message: String
}

extension URLSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            task.resume()
        }
    }
}

/// Implementation of the Notion API client
public class NotionClient: NotionClientProtocol, @unchecked Sendable {
    // MARK: - Properties
    
    /// The base URL for the Notion API
    public let baseURL: URL
    
    /// The base URL for the Notion OAuth endpoints
    public let oauthURL: URL
    
    /// The client ID for the Notion integration
    private let clientId: String
    
    /// The client secret for the Notion integration
    private let clientSecret: String
    
    // MARK: - Initialization
    
    /// Initialize a new Notion client
    /// - Parameters:
    ///   - baseURL: The base URL for the Notion API (defaults to "https://api.notion.com/v1")
    ///   - oauthURL: The base URL for the Notion OAuth endpoints (defaults to "https://api.notion.com/v1/oauth")
    ///   - clientId: The client ID for the Notion integration
    ///   - clientSecret: The client secret for the Notion integration
    public init(
        baseURL: URL = URL(string: "https://api.notion.com/v1")!,
        oauthURL: URL = URL(string: "https://api.notion.com/v1/oauth")!,
        clientId: String = "",
        clientSecret: String = ""
    ) {
        self.baseURL = baseURL
        self.oauthURL = oauthURL
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
    
    // MARK: - OAuth Methods
    
    /// Get the OAuth URL to connect to Notion
    /// - Parameters:
    ///   - redirectURI: The redirect URI for OAuth
    ///   - state: Optional state parameter for OAuth
    ///   - userId: Optional user ID to associate with the connection
    /// - Returns: The OAuth URL
    public func getOAuthURL(redirectURI: String, state: String?, userId: String?) -> URL {
        var params = [
            "client_id": clientId,
            "redirect_uri": redirectURI,
            "response_type": "code",
            "owner": "user"
        ]
        
        if let state = state {
            params["state"] = state
        }
        
        if let userId = userId {
            params["user_id"] = userId
        }
        
        let queryString = params.map { "\($0.key)=\($0.value.urlEncoded())" }.joined(separator: "&")
        let urlString = "https://api.notion.com/v1/oauth/authorize?\(queryString)"
        
        return URL(string: urlString)!
    }
    
    /// Exchange an authorization code for an access token
    /// - Parameters:
    ///   - userId: Optional user ID to associate with the token
    ///   - code: The authorization code from Notion
    /// - Returns: The Notion token
    public func exchangeCodeForToken(userId: String?, code: String) async throws -> NotionToken {
        let url = oauthURL.appendingPathComponent("token")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Basic auth header for client ID and secret
        if !clientId.isEmpty && !clientSecret.isEmpty {
            let authString = "\(clientId):\(clientSecret)"
            if let data = authString.data(using: .utf8) {
                let base64Auth = data.base64EncodedString()
                request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
            }
        }
        
        // Create request body
        struct TokenRequest: Codable {
            let grant_type: String
            let code: String
            let redirect_uri: String
        }
        
        let tokenRequest = TokenRequest(
            grant_type: "authorization_code",
            code: code,
            redirect_uri: "https://example.com/callback" // This should match the redirect URI used for the auth URL
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(tokenRequest)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionClientError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NotionClientError.httpError(statusCode: httpResponse.statusCode, message: errorResponse?.message ?? "Unknown error")
        }
        
        // Decode response
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(NotionTokenResponse.self, from: data)
        
        // Create token
        return NotionToken(
            accessToken: tokenResponse.access_token,
            botId: tokenResponse.bot_id,
            workspaceId: tokenResponse.workspace_id,
            workspaceName: tokenResponse.workspace_name,
            workspaceIcon: tokenResponse.workspace_icon
        )
    }
    
    // MARK: - API Methods
    
    /// List all databases accessible to the token
    /// - Parameter token: The access token
    /// - Returns: An array of databases
    public func listDatabases(token: String) async throws -> [NotionDatabase] {
        // Use the search endpoint instead of the deprecated databases endpoint
        let searchURL = baseURL.appendingPathComponent("search")
        
        // Create request
        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")  // Using a recent Notion API version
        
        // Create body to filter for databases only
        let requestBody: [String: Any] = [
            "filter": ["value": "database", "property": "object"]
        ]
        
        // Encode body
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("=== Database List Request ===")
        print("URL: \(searchURL)")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Handle error responses
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("Database List Response Status: \(httpResponse.statusCode)")
        print("Response Body: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
        
        if httpResponse.statusCode != 200 {
            // Try to decode error
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(NotionError.self, from: data) {
                throw error
            } else {
                throw NSError(domain: "NotionKitError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"])
            }
        }
        
        // Parse the search response
        struct SearchResponse: Decodable {
            let results: [DatabaseResult]
            let hasMore: Bool
            let nextCursor: String?
            
            enum CodingKeys: String, CodingKey {
                case results
                case hasMore = "has_more"
                case nextCursor = "next_cursor"
            }
        }
        
        struct DatabaseResult: Decodable {
            let id: String
            let object: String
            let title: [TitleItem]?
            let properties: [String: PropertyDefinition]
            
            // Add any other fields you need from the database object
        }
        
        struct TitleItem: Decodable {
            let plainText: String?
            
            enum CodingKeys: String, CodingKey {
                case plainText = "plain_text"
            }
        }
        
        // Decode the response
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(SearchResponse.self, from: data)
        
        // Map to NotionDatabase objects
        return searchResponse.results.compactMap { result in
            guard result.object == "database" else {
                return nil
            }
            
            // Extract the database name from title
            let name = result.title?.first?.plainText ?? "Untitled Database"
            
            return NotionDatabase(
                id: result.id,
                name: name,
                properties: result.properties
            )
        }
    }
    
    /// Query a database with filters, sorts, and pagination
    /// - Parameters:
    ///   - databaseId: The ID of the database to query
    ///   - token: The access token
    ///   - query: Optional query parameters
    /// - Returns: A paginated response with database items
    public func queryDatabase(
        databaseId: String,
        token: String,
        query: NotionDatabaseQueryRequest?
    ) async throws -> NotionPaginatedResponse<NotionDatabaseItem> {
        // Create URL for database query
        let url = baseURL.appendingPathComponent("databases/\(databaseId)/query")
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        
        // Add request body with query parameters if provided
        if let query = query {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(query)
        } else {
            // Empty query body
            request.httpBody = try JSONEncoder().encode(EmptyBody())
        }
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionClientError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NotionClientError.httpError(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.message ?? "Error querying database"
            )
        }
        
        // Decode response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(NotionPaginatedResponse<NotionDatabaseItem>.self, from: data)
    }
    
    /// Search for pages across the workspace
    /// - Parameter token: The access token
    /// - Returns: An array of Notion pages
    public func listPages(token: String) async throws -> [NotionPage] {
        // Use the search endpoint with a filter for pages
        let searchURL = baseURL.appendingPathComponent("search")
        
        // Create request
        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        
        // Create body to filter for pages only
        let requestBody: [String: Any] = [
            "filter": ["value": "page", "property": "object"]
        ]
        
        // Encode body
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("=== Page List Request ===")
        print("URL: \(searchURL)")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Handle error responses
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NotionKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("Page List Response Status: \(httpResponse.statusCode)")
        print("Response Body: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
        
        if httpResponse.statusCode != 200 {
            // Try to decode error
            let decoder = JSONDecoder()
            if let error = try? decoder.decode(NotionError.self, from: data) {
                throw error
            } else {
                throw NSError(domain: "NotionKitError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"])
            }
        }
        
        // Parse the search response
        struct SearchResponse: Decodable {
            let results: [PageResult]
            let hasMore: Bool
            let nextCursor: String?
            
            enum CodingKeys: String, CodingKey {
                case results
                case hasMore = "has_more"
                case nextCursor = "next_cursor"
            }
        }
        
        struct PageResult: Decodable {
            let id: String
            let object: String
            let url: String
            let properties: [String: [String: Any]]?
            
            // Add any other fields you need from the page object
            private enum CodingKeys: String, CodingKey {
                case id
                case object
                case url
                case properties
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                object = try container.decode(String.self, forKey: .object)
                url = try container.decode(String.self, forKey: .url)
                
                // For properties, we'll decode to a generic structure
                if let propertiesData = try? container.decodeIfPresent(Data.self, forKey: .properties) {
                    properties = try JSONSerialization.jsonObject(with: propertiesData) as? [String: [String: Any]]
                } else {
                    properties = nil
                }
            }
        }
        
        // Decode the response
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(SearchResponse.self, from: data)
        
        // Map to NotionPage objects
        return searchResponse.results.compactMap { result in
            guard result.object == "page" else {
                return nil
            }
            
            // Extract page properties
            let pageProperties: [String: String] = [:]
            
            return NotionPage(
                id: result.id,
                url: result.url,
                properties: pageProperties
            )
        }
    }
    
    /// Retrieve blocks for a specific page
    public func getPageBlocks(token: String, pageId: String) async throws -> [NotionBlock] {
        let url = URL(string: "https://api.notion.com/v1/blocks/\(pageId)/children")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionClientError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NotionClientError.httpError(statusCode: httpResponse.statusCode, message: errorResponse?.message ?? "Unknown error")
        }
        
        let decoder = JSONDecoder()
        
        struct BlocksResponse: Decodable {
            let results: [NotionBlock]
            let has_more: Bool
            let next_cursor: String?
        }
        
        do {
            let blocksResponse = try decoder.decode(BlocksResponse.self, from: data)
            return blocksResponse.results
        } catch {
            print("Error decoding blocks: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
            throw NotionClientError.decodingError(error)
        }
    }
    
    // Helper empty body struct for requests
    private struct EmptyBody: Encodable {}
} 

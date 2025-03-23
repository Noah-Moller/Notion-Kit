import XCTest
import NotionKit

final class NotionClientTests: XCTestCase {
    var client: NotionClient!
    
    override func setUp() {
        super.setUp()
        client = NotionClient()
    }
    
    override func tearDown() {
        client = nil
        super.tearDown()
    }
    
    func testGetOAuthURL() {
        // Test with minimal parameters
        let url1 = client.getOAuthURL(
            clientId: "test-client-id",
            redirectUri: "https://example.com/callback",
            state: nil,
            ownerType: nil
        )
        
        // Debug output
        print("URL1: \(url1.absoluteString)")
        
        XCTAssertTrue(url1.absoluteString.contains("client_id=test-client-id"), "URL doesn't contain client_id: \(url1.absoluteString)")
        XCTAssertTrue(url1.absoluteString.contains("redirect_uri=https://example.com/callback"), "URL doesn't contain redirect_uri: \(url1.absoluteString)")
        XCTAssertTrue(url1.absoluteString.contains("response_type=code"), "URL doesn't contain response_type: \(url1.absoluteString)")
        XCTAssertFalse(url1.absoluteString.contains("state="), "URL contains state when it shouldn't: \(url1.absoluteString)")
        XCTAssertFalse(url1.absoluteString.contains("owner="), "URL contains owner when it shouldn't: \(url1.absoluteString)")
        
        // Test with all parameters
        let url2 = client.getOAuthURL(
            clientId: "test-client-id",
            redirectUri: "https://example.com/callback",
            state: "test-state",
            ownerType: "user"
        )
        
        // Debug output
        print("URL2: \(url2.absoluteString)")
        
        XCTAssertTrue(url2.absoluteString.contains("client_id=test-client-id"), "URL doesn't contain client_id: \(url2.absoluteString)")
        XCTAssertTrue(url2.absoluteString.contains("redirect_uri=https://example.com/callback"), "URL doesn't contain redirect_uri: \(url2.absoluteString)")
        XCTAssertTrue(url2.absoluteString.contains("response_type=code"), "URL doesn't contain response_type: \(url2.absoluteString)")
        XCTAssertTrue(url2.absoluteString.contains("state=test-state"), "URL doesn't contain state: \(url2.absoluteString)")
        XCTAssertTrue(url2.absoluteString.contains("owner=user"), "URL doesn't contain owner: \(url2.absoluteString)")
    }
    
    // Mock classes and helpers for testing
    
    class MockURLProtocol: URLProtocol {
        static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
        
        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func startLoading() {
            guard let handler = MockURLProtocol.requestHandler else {
                XCTFail("MockURLProtocol handler not set")
                return
            }
            
            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                
                if let data = data {
                    client?.urlProtocol(self, didLoad: data)
                }
                
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        
        override func stopLoading() {}
    }
    
    // Helper method to create a test URLSession
    func makeTestURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
    
    // Helper method to create a test response
    func makeTestResponse(statusCode: Int, url: URL) -> HTTPURLResponse {
        return HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }
    
    // Additional tests for token exchange, listDatabases, and queryDatabase
    // would require more extensive mocking of the URLSession responses.
    // In a real implementation, you should add these tests with proper mocks.
} 
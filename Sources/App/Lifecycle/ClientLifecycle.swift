import Vapor
import AsyncHTTPClient

/// Manages the lifecycle of the shared HTTPClient
final class ClientLifecycle: LifecycleHandler {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }
    
    func shutdown(_ application: Application) {
        // Attempt to shut down the HTTP client gracefully
        try? httpClient.syncShutdown()
    }
}
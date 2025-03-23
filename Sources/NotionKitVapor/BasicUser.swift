import Foundation
import Vapor

/// Protocol for an authenticated user
public protocol BasicUser: Authenticatable {
    /// The user's ID as a string
    var id: String { get }
}

/// A simple implementation of BasicUser for testing
public struct SimpleUser: BasicUser {
    /// The user's ID
    public let id: String
    
    /// Initialize a new simple user
    /// - Parameter id: The user's ID
    public init(id: String) {
        self.id = id
    }
}

// Make SimpleUser conform to Authenticatable
extension SimpleUser: Authenticatable {}

/// Middleware to authenticate a user using a query parameter
public struct UserIDMiddleware: Middleware {
    /// The user ID query parameter name
    let userIdKey: String
    
    /// Initialize a new middleware
    /// - Parameter userIdKey: The user ID query parameter name (defaults to "user_id")
    public init(userIdKey: String = "user_id") {
        self.userIdKey = userIdKey
    }
    
    /// Respond to the request
    /// - Parameters:
    ///   - request: The request
    ///   - next: The next responder
    /// - Returns: The response
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // If user already authenticated, continue
        if request.auth.has(SimpleUser.self) {
            return next.respond(to: request)
        }
        
        // Try to get user ID from query parameter
        if let userId = request.query[String.self, at: userIdKey] {
            // Create a simple user and authenticate
            let user = SimpleUser(id: userId)
            request.auth.login(user)
        }
        
        // Continue with request
        return next.respond(to: request)
    }
} 
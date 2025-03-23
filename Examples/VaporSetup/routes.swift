import Vapor
import NotionKitVapor

// Register your application's routes
func routes(_ app: Application) throws {
    // Basic welcome route
    app.get { req in
        return "Welcome to your Notion-integrated Vapor app!"
    }
    
    // Example of a custom route using NotionKit
    app.get("my-databases") { req -> EventLoopFuture<Response> in
        // Get user ID from query or session
        let userId = req.query[String.self, at: "user_id"] ?? "default-user-id"
        
        // If you've configured authentication, you might get user ID like this:
        // let userId = req.auth.get(User.self)?.id.uuidString ?? "default-user-id"
        
        // Async perform the database query
        return req.eventLoop.performAsync {
            do {
                // Get databases from Notion
                let databases = try await req.application.notion.listDatabases(for: userId)
                
                // Create a response
                struct DatabasesResponse: Content {
                    let count: Int
                    let databases: [NotionDatabase]
                }
                
                let response = DatabasesResponse(
                    count: databases.count,
                    databases: databases
                )
                
                return try await response.encodeResponse(for: req)
            } catch {
                // Handle errors
                struct ErrorResponse: Content {
                    let error: String
                }
                
                let response = ErrorResponse(error: error.localizedDescription)
                return try await response.encodeResponse(status: .internalServerError, for: req)
            }
        }
    }
    
    // Register custom routes for authenticated users
    let protected = app.grouped(UserAuthMiddleware())
    
    protected.get("protected-databases") { req -> EventLoopFuture<String> in
        return req.eventLoop.performAsync {
            // Using SimpleUser protocol
            let userId = req.auth.get(SimpleUser.self)!.id
            
            do {
                let databases = try await req.application.notion.listDatabases(for: userId)
                return "You have \(databases.count) databases"
            } catch {
                throw error
            }
        }
    }
}

// Example of a custom authentication middleware
struct UserAuthMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // Check if user is authenticated via SimpleUser
        if request.auth.has(SimpleUser.self) {
            return next.respond(to: request)
        }
        
        // In a real app, you would check session/token/etc.
        // For this example, we'll just deny access
        return request.eventLoop.makeFailedFuture(
            Abort(.unauthorized, reason: "You must be logged in to access this resource")
        )
    }
} 
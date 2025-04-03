import Vapor
import NotionKitVapor
import NotionKit

func routes(_ app: Application) throws {
    // Route to get Notion data
    app.get("notion", "data", ":userId") { req async throws -> NotionKitVapor.NotionUserData in
        guard let userId = req.parameters.get("userId") else {
            throw Abort(.badRequest, reason: "Missing user_id parameter")
        }
        
        guard let notionData = req.application.notionData.getData(for: userId) else {
            throw Abort(.notFound, reason: "Notion data not found for user. Please authenticate first.")
        }
        
        return notionData
    }
} 
import Foundation
import Vapor
import Fluent
import NotionKit

/// A SQLite-based implementation of NotionTokenStorage
public final class SQLiteNotionTokenStorage: NotionTokenStorage, @unchecked Sendable {
    private let app: Application
    
    public init(app: Application) {
        self.app = app
    }
    
    /// Saves a Notion token for a user
    /// - Parameters:
    ///   - userId: The ID of the user
    ///   - token: The token to save
    public func saveToken(userId: String, token: NotionToken) async throws {
        // Check if token already exists
        if let existingToken = try await NotionTokenModel.query(on: app.db)
            .filter(\.$userId == userId)
            .first() {
            // Update existing token using a transaction
            try await app.db.transaction { database in
                existingToken.accessToken = token.accessToken
                existingToken.botId = token.botId
                existingToken.workspaceId = token.workspaceId
                existingToken.workspaceName = token.workspaceName
                existingToken.workspaceIcon = token.workspaceIcon
                existingToken.expiresAt = token.expiresAt
                try await existingToken.save(on: database)
            }
        } else {
            // Create new token using a transaction
            try await app.db.transaction { database in
                let tokenModel = NotionTokenModel(
                    userId: userId,
                    accessToken: token.accessToken,
                    botId: token.botId,
                    workspaceId: token.workspaceId,
                    workspaceName: token.workspaceName,
                    workspaceIcon: token.workspaceIcon,
                    expiresAt: token.expiresAt
                )
                try await tokenModel.save(on: database)
            }
        }
    }
    
    /// Gets the Notion token for a user, if available
    /// - Parameter userId: The ID of the user
    /// - Returns: The token, if available
    public func getToken(userId: String) async throws -> NotionToken? {
        guard let tokenModel = try await NotionTokenModel.query(on: app.db)
            .filter(\.$userId == userId)
            .first() else {
            return nil
        }
        
        return NotionToken(
            accessToken: tokenModel.accessToken,
            botId: tokenModel.botId,
            workspaceId: tokenModel.workspaceId,
            workspaceName: tokenModel.workspaceName,
            workspaceIcon: tokenModel.workspaceIcon,
            expiresAt: tokenModel.expiresAt
        )
    }
    
    /// Deletes the Notion token for a user
    /// - Parameter userId: The ID of the user
    public func deleteToken(userId: String) async throws {
        try await NotionTokenModel.query(on: app.db)
            .filter(\.$userId == userId)
            .delete()
    }
}

/// Fluent model for storing Notion tokens
final class NotionTokenModel: Model, @unchecked Sendable {
    static let schema = "notion_tokens"
    
    @ID(custom: .id)
    var id: UUID?
    
    @Field(key: "user_id")
    var userId: String
    
    @Field(key: "access_token")
    var accessToken: String
    
    @Field(key: "bot_id")
    var botId: String
    
    @Field(key: "workspace_id")
    var workspaceId: String
    
    @Field(key: "workspace_name")
    var workspaceName: String
    
    @Field(key: "workspace_icon")
    var workspaceIcon: String?
    
    @Field(key: "expires_at")
    var expiresAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userId: String,
        accessToken: String,
        botId: String,
        workspaceId: String,
        workspaceName: String,
        workspaceIcon: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.accessToken = accessToken
        self.botId = botId
        self.workspaceId = workspaceId
        self.workspaceName = workspaceName
        self.workspaceIcon = workspaceIcon
        self.expiresAt = expiresAt
    }
} 
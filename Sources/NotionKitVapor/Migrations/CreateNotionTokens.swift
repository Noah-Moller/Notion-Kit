import Fluent

/// Migration for creating the notion_tokens table
public struct CreateNotionTokens: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema("notion_tokens")
            .id()
            .field("user_id", .string, .required)
            .field("access_token", .string, .required)
            .field("bot_id", .string, .required)
            .field("workspace_id", .string, .required)
            .field("workspace_name", .string, .required)
            .field("workspace_icon", .string)
            .field("expires_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema("notion_tokens").delete()
    }
} 
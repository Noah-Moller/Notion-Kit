import Foundation

// MARK: - Root Structure
public struct NotionUserData: Codable {
    public let user: UserInfo
    public let databases: [DatabaseInfo]
    public let pages: [PageInfo]
    public let metadata: Metadata
    
    public init(user: UserInfo, databases: [DatabaseInfo], pages: [PageInfo], metadata: Metadata) {
        self.user = user
        self.databases = databases
        self.pages = pages
        self.metadata = metadata
    }
}

// MARK: - User Information
public struct UserInfo: Codable {
    public let id: String
    public let token: TokenInfo
    public let workspace: WorkspaceInfo
    
    public init(id: String, token: TokenInfo, workspace: WorkspaceInfo) {
        self.id = id
        self.token = token
        self.workspace = workspace
    }
}

public struct TokenInfo: Codable {
    public let accessToken: String
    public let botId: String
    public let workspaceId: String
    public let workspaceName: String
    public let workspaceIcon: String?
    public let expiresAt: Date?
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case botId = "bot_id"
        case workspaceId = "workspace_id"
        case workspaceName = "workspace_name"
        case workspaceIcon = "workspace_icon"
        case expiresAt = "expires_at"
    }
    
    public init(
        accessToken: String,
        botId: String,
        workspaceId: String,
        workspaceName: String,
        workspaceIcon: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.accessToken = accessToken
        self.botId = botId
        self.workspaceId = workspaceId
        self.workspaceName = workspaceName
        self.workspaceIcon = workspaceIcon
        self.expiresAt = expiresAt
    }
}

public struct WorkspaceInfo: Codable {
    public let id: String
    public let name: String
    public let icon: String?
    
    public init(id: String, name: String, icon: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

// MARK: - Database Information
public struct DatabaseInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let url: String?
    public let title: [NotionRichText]
    public let properties: [String: NotionProperty]
    public let items: [NotionDatabaseItem]
    
    private enum CodingKeys: String, CodingKey {
        case id, name, url, title, properties, items
    }
    
    public init(
        id: String,
        name: String,
        url: String?,
        title: [NotionRichText],
        properties: [String: NotionProperty],
        items: [NotionDatabaseItem]
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.title = title
        self.properties = properties
        self.items = items
    }
}

// MARK: - Page Information
public struct PageInfo: Codable, Identifiable {
    public let id: String
    public let url: String
    public let title: String
    public let icon: Icon?
    public let cover: FileBlock?
    public let properties: [String: PropertyValue]
    public let blocks: [NotionBlock]
    public let lastEditedTime: Date
    public let createdTime: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, url, title, icon, cover, properties, blocks
        case lastEditedTime = "last_edited_time"
        case createdTime = "created_time"
    }
    
    public init(
        id: String,
        url: String,
        title: String,
        icon: Icon?,
        cover: FileBlock?,
        properties: [String: PropertyValue],
        blocks: [NotionBlock],
        lastEditedTime: Date,
        createdTime: Date
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.icon = icon
        self.cover = cover
        self.properties = properties
        self.blocks = blocks
        self.lastEditedTime = lastEditedTime
        self.createdTime = createdTime
    }
}

// MARK: - Metadata
public struct Metadata: Codable {
    public let syncedAt: Date
    public let version: String
    public let lastSyncStatus: SyncStatus
    
    private enum CodingKeys: String, CodingKey {
        case syncedAt = "synced_at"
        case version
        case lastSyncStatus = "last_sync_status"
    }
    
    public init(syncedAt: Date, version: String, lastSyncStatus: SyncStatus) {
        self.syncedAt = syncedAt
        self.version = version
        self.lastSyncStatus = lastSyncStatus
    }
}

public enum SyncStatus: String, Codable {
    case success
    case partial
    case failed
}
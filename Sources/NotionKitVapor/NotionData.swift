import Foundation
import Vapor
import NotionKit

/// Represents the Notion data for a user
public struct NotionUserData: Content {
    /// The user's information
    public let user: UserInfo
    
    /// The user's databases
    public let databases: [DatabaseInfo]
    
    /// The user's pages
    public let pages: [PageInfo]
    
    /// Metadata about the data
    public let metadata: Metadata
    
    public init(
        user: UserInfo,
        databases: [DatabaseInfo],
        pages: [PageInfo],
        metadata: Metadata
    ) {
        self.user = user
        self.databases = databases
        self.pages = pages
        self.metadata = metadata
    }
}

/// Represents a user's information
public struct UserInfo: Content {
    /// The user's ID
    public let id: String
    
    /// The user's token information
    public let token: TokenInfo
    
    /// The user's workspace information
    public let workspace: WorkspaceInfo
    
    public init(
        id: String,
        token: TokenInfo,
        workspace: WorkspaceInfo
    ) {
        self.id = id
        self.token = token
        self.workspace = workspace
    }
}

/// Represents a token's information
public struct TokenInfo: Content {
    /// The access token
    public let accessToken: String
    
    /// The bot ID
    public let botId: String
    
    /// The workspace ID
    public let workspaceId: String
    
    /// The workspace name
    public let workspaceName: String
    
    /// The workspace icon
    public let workspaceIcon: String?
    
    /// When the token expires
    public let expiresAt: Date?
    
    public init(
        accessToken: String,
        botId: String,
        workspaceId: String,
        workspaceName: String,
        workspaceIcon: String?,
        expiresAt: Date?
    ) {
        self.accessToken = accessToken
        self.botId = botId
        self.workspaceId = workspaceId
        self.workspaceName = workspaceName
        self.workspaceIcon = workspaceIcon
        self.expiresAt = expiresAt
    }
}

/// Represents a workspace's information
public struct WorkspaceInfo: Content {
    /// The workspace ID
    public let id: String
    
    /// The workspace name
    public let name: String
    
    /// The workspace icon
    public let icon: String?
    
    public init(
        id: String,
        name: String,
        icon: String?
    ) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

/// Represents a database's information
public struct DatabaseInfo: Content {
    /// The database ID
    public let id: String
    
    /// The database name
    public let name: String
    
    /// The database URL
    public let url: String
    
    /// The database title
    public let title: [RichTextItem]
    
    /// The database properties
    public let properties: [String: PropertyValue]
    
    /// The database items
    public let items: [NotionPage]
    
    public init(
        id: String,
        name: String,
        url: String,
        title: [RichTextItem],
        properties: [String: PropertyValue],
        items: [NotionPage]
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.title = title
        self.properties = properties
        self.items = items
    }
}

/// Represents a page's information
public struct PageInfo: Content {
    /// The page ID
    public let id: String
    
    /// The page URL
    public let url: String
    
    /// The page title
    public let title: String
    
    /// The page icon
    public let icon: String?
    
    /// The page cover
    public let cover: String?
    
    /// The page properties
    public let properties: [String: PropertyValue]
    
    /// The page blocks
    public let blocks: [NotionBlock]
    
    /// When the page was last edited
    public let lastEditedTime: Date
    
    /// When the page was created
    public let createdTime: Date
    
    public init(
        id: String,
        url: String,
        title: String,
        icon: String?,
        cover: String?,
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

/// Metadata about the Notion data
public struct Metadata: Content {
    /// When the data was last synced
    public let syncedAt: Date
    
    /// The version of the data
    public let version: String
    
    /// The status of the last sync
    public let lastSyncStatus: SyncStatus
    
    public init(
        syncedAt: Date,
        version: String,
        lastSyncStatus: SyncStatus
    ) {
        self.syncedAt = syncedAt
        self.version = version
        self.lastSyncStatus = lastSyncStatus
    }
}

/// The status of a sync operation
public enum SyncStatus: String, Codable, Sendable {
    case success
    case failure
    case inProgress
} 
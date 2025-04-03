import Foundation
import NotionKit

// MARK: - NotionKitVapor to NotionKit Conversion
extension NotionKitVapor.NotionUserData {
    public func toNotionKit() -> NotionUserData {
        return NotionUserData(
            user: user.toNotionKit(),
            databases: databases.map { DatabaseInfo(from: $0.toNotionKit()) },
            pages: pages.map { PageInfo(from: $0.toNotionKit()) },
            metadata: metadata.toNotionKit()
        )
    }
}

extension NotionKitVapor.UserInfo {
    public func toNotionKit() -> UserInfo {
        return UserInfo(
            id: id,
            token: token.toNotionKit(),
            workspace: workspace.toNotionKit()
        )
    }
}

extension NotionKitVapor.TokenInfo {
    public func toNotionKit() -> TokenInfo {
        return TokenInfo(
            accessToken: accessToken,
            botId: botId,
            workspaceId: workspaceId,
            workspaceName: workspaceName,
            workspaceIcon: workspaceIcon,
            expiresAt: expiresAt
        )
    }
}

extension NotionKitVapor.WorkspaceInfo {
    public func toNotionKit() -> WorkspaceInfo {
        return WorkspaceInfo(
            id: id,
            name: name,
            icon: icon
        )
    }
}

extension NotionKitVapor.DatabaseInfo {
    public func toNotionKit() -> NotionDatabase {
        return NotionDatabase(
            id: id,
            name: name,
            properties: convertToProperties(properties)
        )
    }
    
    private func convertToProperties(_ properties: [String: PropertyValue]) -> [String: PropertyDefinition] {
        var result: [String: PropertyDefinition] = [:]
        for (key, value) in properties {
            let definition = try! JSONDecoder().decode(PropertyDefinition.self, from: try! JSONEncoder().encode([
                "id": key,
                "name": key,
                "type": value.type
            ]))
            result[key] = definition
        }
        return result
    }
}

extension NotionKitVapor.PageInfo {
    public func toNotionKit() -> NotionPage {
        return NotionPage(
            id: id,
            url: url,
            properties: convertToProperties(properties)
        )
    }
    
    private func convertToProperties(_ properties: [String: PropertyValue]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in properties {
            result[key] = value.displayValue
        }
        return result
    }
}

extension NotionKitVapor.Metadata {
    public func toNotionKit() -> Metadata {
        return Metadata(
            syncedAt: syncedAt,
            version: version,
            lastSyncStatus: lastSyncStatus.toNotionKit()
        )
    }
}

extension NotionKitVapor.SyncStatus {
    public func toNotionKit() -> SyncStatus {
        switch self {
        case .success: return .success
        case .failure: return .failure
        case .inProgress: return .inProgress
        }
    }
}

// MARK: - Supporting Types
public struct RichTextItem: Codable, Sendable {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public func toNotionKit() -> NotionRichText {
        return NotionRichText(
            plainText: text,
            href: nil,
            annotations: NotionAnnotations(
                bold: false,
                italic: false,
                strikethrough: false,
                underline: false,
                code: false,
                color: "default"
            ),
            type: "text",
            text: NotionTextContent(content: text, link: nil)
        )
    }
}

public struct PropertyValue: Codable, Sendable {
    public let type: String
    public let value: String
    
    public init(type: String, value: String) {
        self.type = type
        self.value = value
    }
    
    public var displayValue: String {
        return value
    }
}

// MARK: - NotionKit to NotionKitVapor Conversion
extension DatabaseInfo {
    public init(from database: NotionDatabase) {
        self.id = database.id
        self.name = database.name
        self.url = database.url ?? ""
        self.title = database.title?.map { RichTextItem(text: $0.plainText) } ?? []
        self.properties = [:] // TODO: Implement property conversion
        self.items = [] // TODO: Implement items conversion
    }
}

extension PageInfo {
    public init(from page: NotionPage) {
        self.id = page.id
        self.url = page.url
        self.title = page.properties["title"] ?? ""
        self.icon = nil // TODO: Implement icon conversion
        self.cover = nil // TODO: Implement cover conversion
        self.properties = [:] // TODO: Implement property conversion
        self.blocks = [] // TODO: Implement blocks conversion
        self.lastEditedTime = Date()
        self.createdTime = Date()
    }
}

// MARK: - Rich Text Types
struct Icon: Codable {
    let type: String
    let emoji: String
}

struct FileBlock: Codable {
    let type: String
    let external: ExternalFile
}

struct ExternalFile: Codable {
    let url: String
} 
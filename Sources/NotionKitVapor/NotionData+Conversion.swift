import Foundation
import NotionKit

// MARK: - NotionKitVapor to NotionKit Conversion
extension NotionKitVapor.NotionUserData {
    public func toNotionKit() -> NotionUserData {
        return NotionUserData(
            user: user.toNotionKit(),
            databases: databases.map { db -> DatabaseInfo in
                DatabaseInfo(
                    id: db.id,
                    name: db.name,
                    url: db.url,
                    title: db.title.map { richText in
                        RichTextItem(
                            type: richText.type,
                            text: TextContent(
                                content: richText.text?.content ?? "",
                                link: richText.text?.link.map { Link(url: $0.url) }
                            ),
                            annotations: Annotations(
                                bold: richText.annotations?.bold ?? false,
                                italic: richText.annotations?.italic ?? false,
                                strikethrough: richText.annotations?.strikethrough ?? false,
                                underline: richText.annotations?.underline ?? false,
                                code: richText.annotations?.code ?? false,
                                color: richText.annotations?.color ?? "default"
                            ),
                            plain_text: richText.plain_text,
                            href: richText.href
                        )
                    },
                    properties: db.properties,
                    items: db.items
                )
            },
            pages: pages.map { page -> PageInfo in
                PageInfo(
                    id: page.id,
                    url: page.url,
                    title: page.title,
                    icon: page.icon,
                    cover: page.cover,
                    properties: page.properties,
                    blocks: page.blocks,
                    lastEditedTime: page.lastEditedTime,
                    createdTime: page.createdTime
                )
            },
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
            title: title.map { richText in
                NotionRichText(
                    plainText: richText.plain_text,
                    href: richText.href,
                    annotations: NotionAnnotations(
                        bold: richText.annotations?.bold ?? false,
                        italic: richText.annotations?.italic ?? false,
                        strikethrough: richText.annotations?.strikethrough ?? false,
                        underline: richText.annotations?.underline ?? false,
                        code: richText.annotations?.code ?? false,
                        color: richText.annotations?.color ?? "default"
                    ),
                    type: richText.type,
                    text: NotionTextContent(
                        content: richText.text?.content ?? "",
                        link: richText.text?.link.map { NotionLink(url: $0.url) }
                    )
                )
            },
            properties: convertToProperties(properties),
            url: url
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
        case .failed: return .failed
        case .partial: return .partial
        }
    }
}

// MARK: - Supporting Types
public struct RichTextItem: Codable, Sendable {
    public let type: String
    public let text: TextContent?
    public let annotations: Annotations?
    public let plain_text: String
    public let href: String?
    
    public init(text: String) {
        self.type = "text"
        self.text = TextContent(content: text, link: nil)
        self.annotations = Annotations(bold: false, italic: false, strikethrough: false, underline: false, code: false, color: "default")
        self.plain_text = text
        self.href = nil
    }
    
    public init(type: String, text: TextContent?, annotations: Annotations?, plain_text: String, href: String?) {
        self.type = type
        self.text = text
        self.annotations = annotations
        self.plain_text = plain_text
        self.href = href
    }
}

public struct TextContent: Codable, Sendable {
    public let content: String
    public let link: Link?
    
    public init(content: String, link: Link? = nil) {
        self.content = content
        self.link = link
    }
}

public struct Link: Codable, Sendable {
    public let url: String
    
    public init(url: String) {
        self.url = url
    }
}

public struct Annotations: Codable, Sendable {
    public let bold: Bool
    public let italic: Bool
    public let strikethrough: Bool
    public let underline: Bool
    public let code: Bool
    public let color: String
    
    public init(bold: Bool, italic: Bool, strikethrough: Bool, underline: Bool, code: Bool, color: String) {
        self.bold = bold
        self.italic = italic
        self.strikethrough = strikethrough
        self.underline = underline
        self.code = code
        self.color = color
    }
}

extension NotionRichText {
    public func toVapor() -> RichTextItem {
        return RichTextItem(text: plainText)
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
extension NotionUserData {
    public func toVapor() -> NotionKitVapor.NotionUserData {
        // Convert user info
        let vaporToken = NotionKitVapor.TokenInfo(
            accessToken: user.token.accessToken,
            botId: user.token.botId,
            workspaceId: user.token.workspaceId,
            workspaceName: user.token.workspaceName,
            workspaceIcon: user.token.workspaceIcon,
            expiresAt: user.token.expiresAt
        )
        
        let vaporWorkspace = NotionKitVapor.WorkspaceInfo(
            id: user.workspace.id,
            name: user.workspace.name,
            icon: user.workspace.icon
        )
        
        let vaporUser = NotionKitVapor.UserInfo(
            id: user.id,
            token: vaporToken,
            workspace: vaporWorkspace
        )
        
        // Convert databases
        let vaporDatabases = databases.map { db in
            NotionKitVapor.DatabaseInfo(
                id: db.id,
                name: db.name,
                url: db.url ?? "",
                title: (db.title ?? []).map { richText in
                    RichTextItem(
                        type: richText.type,
                        text: TextContent(
                            content: richText.text?.content ?? "",
                            link: richText.text?.link.map { Link(url: $0.url) }
                        ),
                        annotations: Annotations(
                            bold: richText.annotations?.bold ?? false,
                            italic: richText.annotations?.italic ?? false,
                            strikethrough: richText.annotations?.strikethrough ?? false,
                            underline: richText.annotations?.underline ?? false,
                            code: richText.annotations?.code ?? false,
                            color: richText.annotations?.color ?? "default"
                        ),
                        plain_text: richText.plain_text,
                        href: richText.href
                    )
                },
                properties: [:], // TODO: Implement property conversion
                items: [] // TODO: Implement items conversion
            )
        }
        
        // Convert pages
        let vaporPages = pages.map { page in
            NotionKitVapor.PageInfo(
                id: page.id,
                url: page.url,
                title: page.title,
                icon: nil,
                cover: nil,
                properties: [:], // TODO: Implement property conversion
                blocks: [], // TODO: Implement blocks conversion
                lastEditedTime: page.lastEditedTime,
                createdTime: page.createdTime
            )
        }
        
        // Convert metadata
        let vaporMetadata = NotionKitVapor.Metadata(
            syncedAt: metadata.syncedAt,
            version: metadata.version,
            lastSyncStatus: metadata.lastSyncStatus.toVapor()
        )
        
        // Create final NotionUserData
        return NotionKitVapor.NotionUserData(
            user: vaporUser,
            databases: vaporDatabases,
            pages: vaporPages,
            metadata: vaporMetadata
        )
    }
}

extension SyncStatus {
    public func toVapor() -> NotionKitVapor.SyncStatus {
        switch self {
        case .success: return .success
        case .failed: return .failed
        case .partial: return .partial
        }
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
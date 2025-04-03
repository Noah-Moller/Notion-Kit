import Foundation
import NotionKit

// MARK: - NotionKitVapor to NotionKit Conversion
extension NotionKitVapor.NotionUserData {
    public func toNotionKit() -> NotionKit.NotionUserData {
        return NotionKit.NotionUserData(
            user: user.toNotionKit(),
            databases: databases.map { $0.toNotionKit() },
            pages: pages.map { $0.toNotionKit() },
            metadata: metadata.toNotionKit()
        )
    }
}

extension NotionKitVapor.UserInfo {
    func toNotionKit() -> NotionKit.UserInfo {
        return NotionKit.UserInfo(
            id: id,
            token: token.toNotionKit(),
            workspace: workspace.toNotionKit()
        )
    }
}

extension NotionKitVapor.TokenInfo {
    func toNotionKit() -> NotionKit.TokenInfo {
        return NotionKit.TokenInfo(
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
    func toNotionKit() -> NotionKit.WorkspaceInfo {
        return NotionKit.WorkspaceInfo(
            id: id,
            name: name,
            icon: icon
        )
    }
}

extension NotionKitVapor.DatabaseInfo {
    func toNotionKit() -> NotionKit.DatabaseInfo {
        return NotionKit.DatabaseInfo(
            id: id,
            name: name,
            url: url,
            title: title.map { $0.toNotionKit() },
            properties: properties,
            items: items
        )
    }
}

extension NotionKitVapor.PageInfo {
    func toNotionKit() -> NotionKit.PageInfo {
        return NotionKit.PageInfo(
            id: id,
            url: url,
            title: title,
            icon: nil, // Convert if needed
            cover: nil, // Convert if needed
            properties: properties,
            blocks: blocks,
            lastEditedTime: lastEditedTime,
            createdTime: createdTime
        )
    }
}

extension NotionKitVapor.Metadata {
    func toNotionKit() -> NotionKit.Metadata {
        return NotionKit.Metadata(
            syncedAt: syncedAt,
            version: version,
            lastSyncStatus: lastSyncStatus.toNotionKit()
        )
    }
}

extension NotionKitVapor.SyncStatus {
    func toNotionKit() -> NotionKit.SyncStatus {
        switch self {
        case .success: return .success
        case .failure: return .failed
        case .inProgress: return .partial
        }
    }
}

extension RichTextItem {
    func toNotionKit() -> NotionRichText {
        // Implement conversion from RichTextItem to NotionRichText
        // You'll need to add this based on your RichTextItem structure
        fatalError("Implement RichTextItem conversion")
    }
} 
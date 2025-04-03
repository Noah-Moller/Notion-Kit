import Vapor
import NotionKit

/// Service for managing Notion data outside of routes
public final class NotionDataService {
    private let app: Application
    
    public init(app: Application) {
        self.app = app
    }
    
    /// Updates Notion data for a user
    /// - Parameters:
    ///   - userId: The ID of the user
    ///   - force: Whether to force update even if data is recent
    @MainActor
    public func updateNotionData(for userId: String, force: Bool = false) async throws {
        // Get the user's token
        guard let token = try await self.app.notion.getToken(for: userId) else {
            throw Abort(.notFound, reason: "No Notion token found for user")
        }
        
        // Get user info
        let userInfo = UserInfo(
            id: userId,
            token: TokenInfo(
                accessToken: token.accessToken,
                botId: token.botId,
                workspaceId: token.workspaceId,
                workspaceName: token.workspaceName,
                workspaceIcon: token.workspaceIcon,
                expiresAt: token.expiresAt
            ),
            workspace: WorkspaceInfo(
                id: token.workspaceId,
                name: token.workspaceName,
                icon: token.workspaceIcon
            )
        )
        
        // Get databases
        let databases = try await self.app.notion.listDatabases(for: userId)
        let databaseInfos = try await withThrowingTaskGroup(of: DatabaseInfo.self) { [app] group in
            for database in databases {
                group.addTask {
                    let response = try await app.notion.queryDatabase(databaseId: database.id, for: userId)
                    return DatabaseInfo(
                        id: database.id,
                        name: database.title?.first?.plainText ?? "",
                        url: database.url ?? "",
                        title: (database.title ?? []).map { richText in
                            let data = try! JSONEncoder().encode(richText)
                            return try! JSONDecoder().decode(RichTextItem.self, from: data)
                        },
                        properties: try database.properties.mapValues { property in
                            let data = try JSONEncoder().encode(property)
                            return try JSONDecoder().decode(PropertyValue.self, from: data)
                        },
                        items: response.results.map { item in
                            NotionPage(
                                id: item.id,
                                url: item.url,
                                properties: Dictionary(uniqueKeysWithValues: item.properties.map { key, value in
                                    (key, value.values.first ?? "")
                                })
                            )
                        }
                    )
                }
            }
            
            var databaseInfos: [DatabaseInfo] = []
            for try await databaseInfo in group {
                databaseInfos.append(databaseInfo)
            }
            return databaseInfos
        }
        
        // Get pages
        let pages = try await self.app.notion.listPages(for: userId)
        let pageInfos = try await withThrowingTaskGroup(of: PageInfo.self) { [app] group in
            for page in pages {
                group.addTask {
                    let blocks = try await app.notion.getPageBlocks(for: userId, pageId: page.id)
                    
                    // Extract title from page properties
                    let titleProperty = page.properties["Name"] ?? page.properties["Title"] ?? page.properties["title"]
                    let title: String
                    if let titleData = try? JSONEncoder().encode(titleProperty),
                       let titleJson = try? JSONSerialization.jsonObject(with: titleData) as? [String: Any],
                       let titleArray = titleJson["title"] as? [[String: Any]],
                       let plainText = titleArray.first?["plain_text"] as? String {
                        title = plainText
                    } else {
                        title = ""
                    }
                    
                    return PageInfo(
                        id: page.id,
                        url: page.url,
                        title: title,
                        icon: nil,
                        cover: nil,
                        properties: try page.properties.mapValues { property in
                            let data = try JSONEncoder().encode(property)
                            return try JSONDecoder().decode(PropertyValue.self, from: data)
                        },
                        blocks: blocks,
                        lastEditedTime: Date(),
                        createdTime: Date()
                    )
                }
            }
            
            var pageInfos: [PageInfo] = []
            for try await pageInfo in group {
                pageInfos.append(pageInfo)
            }
            return pageInfos
        }
        
        // Create NotionUserData
        let notionData = NotionUserData(
            user: userInfo,
            databases: databaseInfos,
            pages: pageInfos,
            metadata: Metadata(
                syncedAt: Date(),
                version: "1.0",
                lastSyncStatus: .success
            )
        )
        
        // Store the data
        self.app.notionData.store(notionData, for: userId)
    }
    
    /// Gets Notion data for a user
    /// - Parameter userId: The ID of the user
    /// - Returns: The user's Notion data, if available
    public func getNotionData(for userId: String) -> NotionUserData? {
        return self.app.notionData.getData(for: userId)
    }
    
    /// Deletes Notion data for a user
    /// - Parameter userId: The ID of the user
    public func deleteNotionData(for userId: String) {
        self.app.notionData.removeData(for: userId)
    }
} 
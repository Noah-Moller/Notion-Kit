import Foundation

// MARK: - Root Structure
public struct NotionUserData: Codable {
    let user: UserInfo
    let databases: [DatabaseInfo]
    let pages: [PageInfo]
    let metadata: Metadata
}

// MARK: - User Information
struct UserInfo: Codable {
    let id: String
    let token: TokenInfo
    let workspace: WorkspaceInfo
}

struct TokenInfo: Codable {
    let accessToken: String
    let botId: String
    let workspaceId: String
    let workspaceName: String
    let workspaceIcon: String?
    let expiresAt: Date?
}

struct WorkspaceInfo: Codable {
    let id: String
    let name: String
    let icon: String?
}

// MARK: - Database Information
struct DatabaseInfo: Codable, Identifiable {
    let id: String
    let name: String
    let url: String?
    let title: [RichText]
    let properties: [String: PropertyDefinition]
}

struct RichText: Codable {
    let plainText: String
    let href: String?
    let annotations: Annotations
    let type: String
    let text: TextContent?
}

struct Annotations: Codable {
    let bold: Bool
    let italic: Bool
    let strikethrough: Bool
    let underline: Bool
    let code: Bool
    let color: String
}

struct TextContent: Codable {
    let content: String
    let link: NotionLink?
}

struct NotionLink: Codable {
    let url: String
}

// MARK: - Property Definitions
struct PropertyDefinition: Codable {
    let id: String
    let name: String
    let type: String
    let title: EmptyObject?
    let richText: EmptyObject?
    let number: NumberProperty?
    let select: SelectProperty?
    let multiSelect: SelectProperty?
    let date: EmptyObject?
    let people: EmptyObject?
    let files: EmptyObject?
    let checkbox: EmptyObject?
    let url: EmptyObject?
    let email: EmptyObject?
    let phoneNumber: EmptyObject?
    let formula: FormulaProperty?
    let relation: RelationProperty?
    let rollup: RollupProperty?
    let status: StatusProperty?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, type, title
        case richText = "rich_text"
        case number, select, multiSelect = "multi_select"
        case date, people, files, checkbox, url, email
        case phoneNumber = "phone_number"
        case formula, relation, rollup, status
    }
}

struct EmptyObject: Codable {}

struct NumberProperty: Codable {
    let format: String
}

struct SelectProperty: Codable {
    let options: [SelectOption]
}

struct SelectOption: Codable {
    let id: String?
    let name: String
    let color: String?
}

struct FormulaProperty: Codable {
    let expression: String
}

struct RelationProperty: Codable {
    let databaseId: String
    let syncedPropertyName: String?
    
    private enum CodingKeys: String, CodingKey {
        case databaseId = "database_id"
        case syncedPropertyName = "synced_property_name"
    }
}

struct RollupProperty: Codable {
    let relationPropertyName: String
    let relationPropertyId: String
    let rollupPropertyName: String
    let rollupPropertyId: String
    let function: String
    
    private enum CodingKeys: String, CodingKey {
        case relationPropertyName = "relation_property_name"
        case relationPropertyId = "relation_property_id"
        case rollupPropertyName = "rollup_property_name"
        case rollupPropertyId = "rollup_property_id"
        case function
    }
}

struct StatusProperty: Codable {
    let options: [SelectOption]
    let groups: [StatusGroup]
}

struct StatusGroup: Codable {
    let id: String?
    let name: String
    let color: String?
    let optionIds: [String]
}

// MARK: - Page Information
struct PageInfo: Codable, Identifiable {
    let id: String
    let url: String
    let properties: [String: String]
    let blocks: [Block]
}

// MARK: - Block Information
struct Block: Codable, Identifiable {
    let id: String
    let type: String
    let hasChildren: Bool
    let createdTime: String
    let lastEditedTime: String
    
    // Block type-specific content
    let paragraph: ParagraphBlock?
    let heading1: HeadingBlock?
    let heading2: HeadingBlock?
    let heading3: HeadingBlock?
    let bulletedListItem: ListItemBlock?
    let numberedListItem: ListItemBlock?
    let toDo: ToDoBlock?
    let toggle: ToggleBlock?
    let code: CodeBlock?
    let quote: QuoteBlock?
    let callout: CalloutBlock?
    let image: FileBlock?
    let divider: EmptyObject?
    let tableOfContents: TableOfContentsBlock?
    let children: [Block]?
    
    private enum CodingKeys: String, CodingKey {
        case id, type
        case hasChildren = "has_children"
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case paragraph
        case heading1 = "heading_1"
        case heading2 = "heading_2"
        case heading3 = "heading_3"
        case bulletedListItem = "bulleted_list_item"
        case numberedListItem = "numbered_list_item"
        case toDo = "to_do"
        case toggle, code, quote, callout, image, divider
        case tableOfContents = "table_of_contents"
        case children
    }
}

struct ParagraphBlock: Codable {
    let richText: [RichTextItem]
    let color: String
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}

struct HeadingBlock: Codable {
    let richText: [RichTextItem]
    let color: String
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}

struct ListItemBlock: Codable {
    let richText: [RichTextItem]
    let color: String
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}

struct ToDoBlock: Codable {
    let richText: [RichTextItem]
    let color: String
    let checked: Bool
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color, checked
    }
}

struct ToggleBlock: Codable {
    let richText: [RichTextItem]
    let color: String
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}

struct CodeBlock: Codable {
    let richText: [RichTextItem]
    let language: String
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case language
    }
}

struct QuoteBlock: Codable {
    let richText: [RichTextItem]
    let color: String
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}

struct CalloutBlock: Codable {
    let richText: [RichTextItem]
    let icon: Icon
    let color: String
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case icon, color
    }
}

struct Icon: Codable {
    let type: String
    let emoji: String?
}

struct FileBlock: Codable {
    let type: String
    let file: FileDetails?
    let external: ExternalFile?
}

struct FileDetails: Codable {
    let url: String
    let expiryTime: String?
    
    private enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

struct ExternalFile: Codable {
    let url: String
}

struct TableOfContentsBlock: Codable {
    let color: String
}

struct RichTextItem: Codable {
    let type: String
    let text: TextContent?
    let annotations: Annotations?
    let plainText: String
    let href: String?
    
    private enum CodingKeys: String, CodingKey {
        case type, text, annotations
        case plainText = "plain_text"
        case href
    }
}

// MARK: - Metadata
struct Metadata: Codable {
    let syncedAt: Date
    let version: String
}

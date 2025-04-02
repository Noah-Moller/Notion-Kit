// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The main entry point for the NotionKit package that provides shared functionality
/// for both client and server implementations.
public struct NotionKit {
    public static let version = "1.0.0"
}

// MARK: - Authentication Models

/// Represents the OAuth token and related information from Notion
public struct NotionToken: Codable {
    public let accessToken: String
    public let botId: String
    public let workspaceId: String
    public let workspaceName: String
    public let workspaceIcon: String?
    public let expiresAt: Date?
    
    public init(accessToken: String, botId: String, workspaceId: String, 
                workspaceName: String, workspaceIcon: String? = nil, expiresAt: Date? = nil) {
        self.accessToken = accessToken
        self.botId = botId
        self.workspaceId = workspaceId
        self.workspaceName = workspaceName
        self.workspaceIcon = workspaceIcon
        self.expiresAt = expiresAt
    }
    
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

/// Model for the OAuth token request
public struct NotionTokenRequest: Codable {
    public let grantType: String
    public let code: String
    public let redirectUri: String
    
    private enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case redirectUri = "redirect_uri"
    }
    
    public init(code: String, redirectUri: String) {
        self.grantType = "authorization_code"
        self.code = code
        self.redirectUri = redirectUri
    }
}

/// Model for the OAuth token response
public struct NotionTokenResponse: Codable, Sendable {
    public let access_token: String
    public let token_type: String
    public let bot_id: String
    public let workspace_id: String
    public let workspace_name: String
    public let workspace_icon: String?
}

public struct NotionOwner: Codable {
    public let type: String
    public let user: NotionUser?
    public let workspace: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case user
        case workspace
    }
}

public struct NotionUser: Codable {
    public let id: String
    public let name: String?
    public let avatarUrl: String?
    public let person: NotionPerson?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarUrl = "avatar_url"
        case person
    }
}

public struct NotionPerson: Codable {
    public let email: String
    
    private enum CodingKeys: String, CodingKey {
        case email
    }
}

public struct NotionBot: Codable {
    public let ownerType: String?
    
    private enum CodingKeys: String, CodingKey {
        case ownerType = "owner_type"
    }
}

// MARK: - Database Models

/// Represents a Notion database
public struct NotionDatabase: Codable, Identifiable, Sendable {
    public typealias ID = String
    
    public let id: String
    public let title: [NotionRichText]?
    public let properties: [String: PropertyDefinition]
    public let url: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case properties
        case url
    }
    
    public init(id: String, name: String, properties: [String: PropertyDefinition]) {
        self.id = id
        // Create a simple title from the name
        self.title = [NotionRichText(
            plainText: name,
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
            text: NotionTextContent(content: name, link: nil)
        )]
        self.properties = properties
        self.url = nil
    }
    
    public init(id: String, title: [NotionRichText], properties: [String: PropertyDefinition], url: String) {
        self.id = id
        self.title = title
        self.properties = properties
        self.url = url
    }
    
    public var name: String {
        title?.map { $0.plainText }.joined() ?? "Untitled Database"
    }
}

/// A property definition in a Notion database
public struct PropertyDefinition: Codable, Sendable {
    public let id: String
    public let name: String
    public let type: String
    
    // Add other property type-specific fields as needed
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
    }
}

/// Represents a property in a Notion database
public struct NotionProperty: Codable, Sendable {
    public let id: String
    public let name: String
    public let type: String
    
    // Property-specific types (partial implementation)
    public let title: NotionEmptyObject?
    public let richText: NotionEmptyObject?
    public let number: NotionNumberProperty?
    public let select: NotionSelectProperty?
    public let multiSelect: NotionMultiSelectProperty?
    public let date: NotionEmptyObject?
    public let people: NotionEmptyObject?
    public let files: NotionEmptyObject?
    public let checkbox: NotionEmptyObject?
    public let url: NotionEmptyObject?
    public let email: NotionEmptyObject?
    public let phoneNumber: NotionEmptyObject?
    public let formula: NotionFormulaProperty?
    public let relation: NotionRelationProperty?
    public let rollup: NotionRollupProperty?
    public let createdTime: NotionEmptyObject?
    public let createdBy: NotionEmptyObject?
    public let lastEditedTime: NotionEmptyObject?
    public let lastEditedBy: NotionEmptyObject?
    public let status: NotionStatusProperty?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, type, title
        case richText = "rich_text"
        case number, select
        case multiSelect = "multi_select"
        case date, people, files, checkbox, url, email
        case phoneNumber = "phone_number"
        case formula, relation, rollup
        case createdTime = "created_time"
        case createdBy = "created_by"
        case lastEditedTime = "last_edited_time"
        case lastEditedBy = "last_edited_by"
        case status
    }
}

// Empty object for unsupported property types
public struct NotionEmptyObject: Codable, Sendable {}

// Number property configuration
public struct NotionNumberProperty: Codable, Sendable {
    public let format: String?
}

// Select property configuration
public struct NotionSelectProperty: Codable, Sendable {
    public let options: [NotionSelectOption]
}

// Multi-select property configuration
public struct NotionMultiSelectProperty: Codable, Sendable {
    public let options: [NotionSelectOption]
}

// Select option used in select, multi-select, and status properties
public struct NotionSelectOption: Codable, Sendable {
    public let id: String?
    public let name: String
    public let color: String?
}

// Status property configuration
public struct NotionStatusProperty: Codable, Sendable {
    public let options: [NotionSelectOption]
    public let groups: [NotionStatusGroup]
}

// Status group in status properties
public struct NotionStatusGroup: Codable, Sendable {
    public let id: String?
    public let name: String
    public let color: String?
    public let optionIds: [String]
}

// Formula property
public struct NotionFormulaProperty: Codable, Sendable {
    public let expression: String
}

// Relation property
public struct NotionRelationProperty: Codable, Sendable {
    public let databaseId: String
    public let syncedPropertyName: String?
    
    private enum CodingKeys: String, CodingKey {
        case databaseId = "database_id"
        case syncedPropertyName = "synced_property_name"
    }
}

// Rollup property
public struct NotionRollupProperty: Codable, Sendable {
    public let relationPropertyName: String
    public let relationPropertyId: String
    public let rollupPropertyName: String
    public let rollupPropertyId: String
    public let function: String
    
    private enum CodingKeys: String, CodingKey {
        case relationPropertyName = "relation_property_name"
        case relationPropertyId = "relation_property_id"
        case rollupPropertyName = "rollup_property_name"
        case rollupPropertyId = "rollup_property_id"
        case function
    }
}

// MARK: - Rich Text Models

/// Represents rich text in Notion
public struct NotionRichText: Codable, Sendable {
    public let plainText: String
    public let href: String?
    public let annotations: NotionAnnotations
    public let type: String
    public let text: NotionTextContent?
    
    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
        case href
        case annotations
        case type
        case text
    }
    
    public init(plainText: String, href: String?, annotations: NotionAnnotations, type: String, text: NotionTextContent?) {
        self.plainText = plainText
        self.href = href
        self.annotations = annotations
        self.type = type
        self.text = text
    }
}

/// Represents text content
public struct NotionTextContent: Codable, Sendable {
    public let content: String
    public let link: NotionLink?
    
    enum CodingKeys: String, CodingKey {
        case content
        case link
    }
    
    public init(content: String, link: NotionLink?) {
        self.content = content
        self.link = link
    }
}

/// Represents a link
public struct NotionLink: Codable, Sendable {
    public let url: String
    
    enum CodingKeys: String, CodingKey {
        case url
    }
    
    public init(url: String) {
        self.url = url
    }
}

/// Represents text annotations
public struct NotionAnnotations: Codable, Sendable {
    public let bold: Bool
    public let italic: Bool
    public let strikethrough: Bool
    public let underline: Bool
    public let code: Bool
    public let color: String
    
    enum CodingKeys: String, CodingKey {
        case bold
        case italic
        case strikethrough
        case underline
        case code
        case color
    }
    
    public init(bold: Bool, italic: Bool, strikethrough: Bool, underline: Bool, code: Bool, color: String) {
        self.bold = bold
        self.italic = italic
        self.strikethrough = strikethrough
        self.underline = underline
        self.code = code
        self.color = color
    }
}

// MARK: - Query Models

/// Represents a database query request
public struct NotionDatabaseQueryRequest: Codable {
    public var filter: NotionFilter?
    public var sorts: [NotionSort]?
    public var startCursor: String?
    public var pageSize: Int?
    
    public init(filter: NotionFilter? = nil, sorts: [NotionSort]? = nil, 
                startCursor: String? = nil, pageSize: Int? = nil) {
        self.filter = filter
        self.sorts = sorts
        self.startCursor = startCursor
        self.pageSize = pageSize
    }
    
    private enum CodingKeys: String, CodingKey {
        case filter
        case sorts
        case startCursor = "start_cursor"
        case pageSize = "page_size"
    }
}

/// Represents a filter for database queries
public struct NotionFilter: Codable {
    // Compound filters
    public var and: [NotionFilter]?
    public var or: [NotionFilter]?
    
    // Property filters
    public var property: String?
    public var title: NotionTextFilter?
    public var richText: NotionTextFilter?
    public var number: NotionNumberFilter?
    public var checkbox: NotionCheckboxFilter?
    public var select: NotionSelectFilter?
    public var multiSelect: NotionMultiSelectFilter?
    public var date: NotionDateFilter?
    public var status: NotionStatusFilter?
    
    private enum CodingKeys: String, CodingKey {
        case and, or, property, title
        case richText = "rich_text"
        case number, checkbox, select
        case multiSelect = "multi_select"
        case date, status
    }
}

/// Text filter
public struct NotionTextFilter: Codable {
    public var equals: String?
    public var doesNotEqual: String?
    public var contains: String?
    public var doesNotContain: String?
    public var startsWith: String?
    public var endsWith: String?
    public var isEmpty: Bool?
    public var isNotEmpty: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case equals
        case doesNotEqual = "does_not_equal"
        case contains
        case doesNotContain = "does_not_contain"
        case startsWith = "starts_with"
        case endsWith = "ends_with"
        case isEmpty = "is_empty"
        case isNotEmpty = "is_not_empty"
    }
}

/// Number filter
public struct NotionNumberFilter: Codable {
    public var equals: Double?
    public var doesNotEqual: Double?
    public var greaterThan: Double?
    public var lessThan: Double?
    public var greaterThanOrEqualTo: Double?
    public var lessThanOrEqualTo: Double?
    public var isEmpty: Bool?
    public var isNotEmpty: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case equals
        case doesNotEqual = "does_not_equal"
        case greaterThan = "greater_than"
        case lessThan = "less_than"
        case greaterThanOrEqualTo = "greater_than_or_equal_to"
        case lessThanOrEqualTo = "less_than_or_equal_to"
        case isEmpty = "is_empty"
        case isNotEmpty = "is_not_empty"
    }
}

/// Checkbox filter
public struct NotionCheckboxFilter: Codable {
    public var equals: Bool?
    public var doesNotEqual: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case equals
        case doesNotEqual = "does_not_equal"
    }
}

/// Select filter
public struct NotionSelectFilter: Codable {
    public var equals: String?
    public var doesNotEqual: String?
    public var isEmpty: Bool?
    public var isNotEmpty: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case equals
        case doesNotEqual = "does_not_equal"
        case isEmpty = "is_empty"
        case isNotEmpty = "is_not_empty"
    }
}

/// Multi-select filter
public struct NotionMultiSelectFilter: Codable {
    public var contains: String?
    public var doesNotContain: String?
    public var isEmpty: Bool?
    public var isNotEmpty: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case contains
        case doesNotContain = "does_not_contain"
        case isEmpty = "is_empty"
        case isNotEmpty = "is_not_empty"
    }
}

/// Status filter
public struct NotionStatusFilter: Codable {
    public var equals: String?
    public var doesNotEqual: String?
    public var isEmpty: Bool?
    public var isNotEmpty: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case equals
        case doesNotEqual = "does_not_equal"
        case isEmpty = "is_empty"
        case isNotEmpty = "is_not_empty"
    }
}

/// Date filter
public struct NotionDateFilter: Codable {
    public var equals: String?
    public var before: String?
    public var after: String?
    public var onOrBefore: String?
    public var onOrAfter: String?
    public var isEmpty: Bool?
    public var isNotEmpty: Bool?
    public var pastWeek: NotionEmptyObject?
    public var pastMonth: NotionEmptyObject?
    public var pastYear: NotionEmptyObject?
    public var nextWeek: NotionEmptyObject?
    public var nextMonth: NotionEmptyObject?
    public var nextYear: NotionEmptyObject?
    
    private enum CodingKeys: String, CodingKey {
        case equals, before, after
        case onOrBefore = "on_or_before"
        case onOrAfter = "on_or_after"
        case isEmpty = "is_empty"
        case isNotEmpty = "is_not_empty"
        case pastWeek = "past_week"
        case pastMonth = "past_month"
        case pastYear = "past_year"
        case nextWeek = "next_week"
        case nextMonth = "next_month"
        case nextYear = "next_year"
    }
}

/// Sort direction
public enum NotionSortDirection: String, Codable {
    case ascending
    case descending
}

/// Sort object
public struct NotionSort: Codable {
    public var property: String?
    public var timestamp: String?
    public var direction: NotionSortDirection
    
    public init(property: String? = nil, timestamp: String? = nil, 
                direction: NotionSortDirection = .ascending) {
        self.property = property
        self.timestamp = timestamp
        self.direction = direction
    }
}

// MARK: - Response Models

/// Represents a Notion API response with pagination
public struct NotionPaginatedResponse<T: Codable>: Codable {
    public let object: String
    public let results: [T]
    public let nextCursor: String?
    public let hasMore: Bool
    
    // Custom initializer for testing and manual creation
    public init(object: String, results: [T], nextCursor: String?, hasMore: Bool) {
        self.object = object
        self.results = results
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
    
    private enum CodingKeys: String, CodingKey {
        case object
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// Represents a Notion API error
public struct NotionError: Codable, Error {
    public let object: String
    public let status: Int
    public let code: String
    public let message: String
}

// Create a simple codable dictionary type to replace [String: Any]
public struct NotionDatabaseItem: Codable, Sendable {
    public let properties: [String: [String: String]]
    public let id: String
    public let url: String
    // Add other common fields as needed
    
    // Custom coding keys to match Notion's response format
    private enum CodingKeys: String, CodingKey {
        case properties, id, url
    }
}

// MARK: - Page Models

/// Represents a Notion page
public struct NotionPage: Codable, Identifiable, Sendable {
    public let id: String
    public let url: String
    public var properties: [String: String]
    
    public init(id: String, url: String, properties: [String: String]) {
        self.id = id
        self.url = url
        self.properties = properties
    }
}

// MARK: - Property Value Models

public struct PropertyValue: Codable, Sendable {
    public let type: String
    public let id: String?
    public let title: [RichTextItem]?
    public let rich_text: [RichTextItem]?
    public let number: Double?
    public let select: SelectOption?
    public let multi_select: [SelectOption]?
    public let date: DateValue?
    public let formula: FormulaValue?
    public let checkbox: Bool?
    public let url: String?
    public let email: String?
    public let phone_number: String?
    public let people: [Person]?
    public let relation: [Relation]?
    public let rollup: RollupValue?
    
    public var displayValue: String {
        switch type {
        case "title":
            return title?.map { $0.plain_text }.joined() ?? ""
        case "rich_text":
            return rich_text?.map { $0.plain_text }.joined() ?? ""
        case "number":
            return number?.description ?? ""
        case "select":
            return select?.name ?? ""
        case "multi_select":
            return multi_select?.map { $0.name }.joined(separator: ", ") ?? ""
        case "date":
            return date?.start ?? ""
        case "checkbox":
            return checkbox == true ? "Yes" : "No"
        case "url":
            return url ?? ""
        case "email":
            return email ?? ""
        case "phone_number":
            return phone_number ?? ""
        case "formula":
            return formula?.displayValue ?? ""
        default:
            return ""
        }
    }
}

public struct SelectOption: Codable, Sendable {
    public let id: String
    public let name: String
    public let color: String
}

public struct DateValue: Codable, Sendable {
    public let start: String
    public let end: String?
    public let time_zone: String?
}

public struct FormulaValue: Codable, Sendable {
    public let type: String
    public let string: String?
    public let number: Double?
    public let boolean: Bool?
    public let date: DateValue?
    
    public var displayValue: String {
        switch type {
        case "string":
            return string ?? ""
        case "number":
            return number?.description ?? ""
        case "boolean":
            return boolean == true ? "Yes" : "No"
        case "date":
            return date?.start ?? ""
        default:
            return ""
        }
    }
}

public struct Person: Codable, Sendable {
    public let id: String
    public let name: String?
    public let avatar_url: String?
    public let object: String
}

public struct Relation: Codable, Sendable {
    public let id: String
}

public struct RollupValue: Codable, Sendable {
    public let type: String
    public let number: Double?
    public let date: DateValue?
    public let array: [RollupArrayItem]?
    
    public var displayValue: String {
        switch type {
        case "number":
            return number?.description ?? ""
        case "date":
            return date?.start ?? ""
        default:
            return ""
        }
    }
}

public struct RollupArrayItem: Codable, Sendable {
    public let type: String
}

// MARK: - Block Models

public struct NotionBlock: Codable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public var has_children: Bool
    public let created_time: String
    public let last_edited_time: String
    
    // Different block types
    public var paragraph: ParagraphBlock?
    public var heading_1: HeadingBlock?
    public var heading_2: HeadingBlock?
    public var heading_3: HeadingBlock?
    public var bulleted_list_item: ListItemBlock?
    public var numbered_list_item: ListItemBlock?
    public var to_do: ToDoBlock?
    public var toggle: ToggleBlock?
    public var code: CodeBlock?
    public var image: FileBlock?
    public var divider: EmptyBlock?
    public var callout: CalloutBlock?
    public var quote: QuoteBlock?
    public var table_of_contents: TableOfContentsBlock?
    public var unsupported: EmptyBlock?
    
    public var content: String {
        switch type {
        case "paragraph":
            return paragraph?.richText ?? ""
        case "heading_1":
            return heading_1?.richText ?? ""
        case "heading_2":
            return heading_2?.richText ?? ""
        case "heading_3":
            return heading_3?.richText ?? ""
        case "bulleted_list_item":
            return bulleted_list_item?.richText ?? ""
        case "numbered_list_item":
            return numbered_list_item?.richText ?? ""
        case "to_do":
            return to_do?.richText ?? ""
        case "toggle":
            return toggle?.richText ?? ""
        case "code":
            return code?.richText ?? ""
        case "callout":
            return callout?.richText ?? ""
        case "quote":
            return quote?.richText ?? ""
        case "table_of_contents":
            return "Table of Contents"
        case "unsupported":
            return "Unsupported block type"
        default:
            return ""
        }
    }
}

public struct ParagraphBlock: Codable, Sendable {
    public var rich_text: [RichTextItem]
    public var color: String
    
    public var richText: String {
        rich_text.map { $0.plain_text }.joined()
    }
}

public struct HeadingBlock: Codable, Sendable {
    public var rich_text: [RichTextItem]
    public var color: String
    
    public var richText: String {
        rich_text.map { $0.plain_text }.joined()
    }
}

public struct ListItemBlock: Codable, Sendable {
    public var rich_text: [RichTextItem]
    public var color: String
    
    public var richText: String {
        rich_text.map { $0.plain_text }.joined()
    }
}

public struct ToDoBlock: Codable, Sendable {
    public var rich_text: [RichTextItem]
    public var color: String
    public var checked: Bool
    
    public var richText: String {
        rich_text.map { $0.plain_text }.joined()
    }
}

public struct ToggleBlock: Codable, Sendable {
    public var rich_text: [RichTextItem]
    public var color: String
    
    public var richText: String {
        rich_text.map { $0.plain_text }.joined()
    }
}

public struct CodeBlock: Codable, Sendable {
    public var rich_text: [RichTextItem]
    public var language: String
    
    public var richText: String {
        rich_text.map { $0.plain_text }.joined()
    }
}

public struct QuoteBlock: Codable, Sendable {
    public var rich_text: [RichTextItem]
    public var color: String
    
    public var richText: String {
        rich_text.map { $0.plain_text }.joined()
    }
}

public struct CalloutBlock: Codable, Sendable {
    public var rich_text: [RichTextItem]
    public var icon: Icon
    public var color: String
    
    public var richText: String {
        rich_text.map { $0.plain_text }.joined()
    }
}

public struct Icon: Codable, Sendable {
    public var type: String
    public var emoji: String?
}

public struct FileBlock: Codable, Sendable {
    public var type: String
    public var file: FileDetails?
    public var external: ExternalFile?
    
    public var url: String? {
        if type == "file" {
            return file?.url
        } else if type == "external" {
            return external?.url
        }
        return nil
    }
}

public struct FileDetails: Codable, Sendable {
    public var url: String
    public var expiry_time: String?
}

public struct ExternalFile: Codable, Sendable {
    public var url: String
}

public struct EmptyBlock: Codable, Sendable {
    // This is used for blocks that don't have any content (like dividers)
}

public struct RichTextItem: Codable, Sendable {
    public var type: String
    public var text: TextContent?
    public var annotations: Annotations?
    public var plain_text: String
    public var href: String?
}

public struct TextContent: Codable, Sendable {
    public var content: String
    public var link: Link?
}

public struct Link: Codable, Sendable {
    public var url: String
}

public struct Annotations: Codable, Sendable {
    public var bold: Bool
    public var italic: Bool
    public var strikethrough: Bool
    public var underline: Bool
    public var code: Bool
    public var color: String
}

public struct TableOfContentsBlock: Codable, Sendable {
    public var color: String
}

// MARK: - Protocols

/// Protocol for the Notion client
public protocol NotionClientProtocol {
    /// Get the OAuth URL for a user to connect to Notion
    func getOAuthURL(redirectURI: String, state: String?, userId: String?) -> URL
    
    /// Exchange a code for an access token
    func exchangeCodeForToken(userId: String?, code: String, redirectURI: String?) async throws -> NotionToken
    
    /// List databases accessible to the token
    func listDatabases(token: String) async throws -> [NotionDatabase]
    
    /// List pages accessible to the token
    func listPages(token: String) async throws -> [NotionPage]
    
    /// Retrieve blocks for a specific page
    func getPageBlocks(token: String, pageId: String) async throws -> [NotionBlock]
    
    /// Retrieve child blocks for a specific block
    func getChildBlocks(token: String, blockId: String) async throws -> [NotionBlock]
    
    /// Query a database with optional filter, sort, and pagination
    func queryDatabase(databaseId: String, token: String, query: NotionDatabaseQueryRequest?) async throws -> NotionPaginatedResponse<NotionDatabaseItem>
}

/// Protocol for Notion token storage
public protocol NotionTokenStorage: Sendable {
    /// Save a token
    func saveToken(userId: String, token: NotionToken) async throws
    
    /// Get a token for a user
    func getToken(userId: String) async throws -> NotionToken?
    
    /// Delete a token for a user
    func deleteToken(userId: String) async throws
}

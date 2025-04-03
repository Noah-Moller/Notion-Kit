import Vapor

extension Application {
    private struct NotionDataServiceKey: StorageKey {
        typealias Value = NotionDataService
    }
    
    public var notionDataService: NotionDataService {
        get {
            guard let service = storage[NotionDataServiceKey.self] else {
                fatalError("NotionDataService not configured. Use app.notionDataService = NotionDataService(app: app)")
            }
            return service
        }
        set {
            storage[NotionDataServiceKey.self] = newValue
        }
    }
} 
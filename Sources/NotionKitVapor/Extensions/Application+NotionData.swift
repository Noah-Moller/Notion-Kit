import Vapor

extension Application {
    private struct NotionDataKey: StorageKey {
        typealias Value = NotionDataStorage
    }
    
    public var notionData: NotionDataStorage {
        get {
            guard let storage = storage[NotionDataKey.self] else {
                let storage = NotionDataStorage()
                self.storage[NotionDataKey.self] = storage
                return storage
            }
            return storage
        }
        set {
            storage[NotionDataKey.self] = newValue
        }
    }
}

/// Storage for Notion data
public final class NotionDataStorage {
    private var storage: [String: NotionUserData] = [:]
    private let lock = NSLock()
    
    public init() {}
    
    public func store(_ data: NotionUserData, for userId: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[userId] = data
    }
    
    public func getData(for userId: String) -> NotionUserData? {
        lock.lock()
        defer { lock.unlock() }
        return storage[userId]
    }
    
    public func removeData(for userId: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: userId)
    }
} 
import Foundation
import Vapor
import NotionKit

/// A service for managing NotionData state
public final class NotionDataService {
    private var storage: [String: NotionUserData] = [:]
    private let lock = NSLock()
    
    public init() {}
    
    /// Store NotionData for a user
    /// - Parameters:
    ///   - data: The NotionUserData to store
    ///   - userId: The ID of the user
    public func store(_ data: NotionUserData, for userId: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[userId] = data
    }
    
    /// Get NotionData for a user
    /// - Parameter userId: The ID of the user
    /// - Returns: The stored NotionUserData, if available
    public func getData(for userId: String) -> NotionUserData? {
        lock.lock()
        defer { lock.unlock() }
        return storage[userId]
    }
    
    /// Remove NotionData for a user
    /// - Parameter userId: The ID of the user
    public func remove(for userId: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: userId)
    }
}

// MARK: - Application Extensions

extension Application {
    private struct NotionDataServiceKey: StorageKey {
        typealias Value = NotionDataService
    }
    
    public var notionData: NotionDataService {
        get {
            if let existing = storage[NotionDataServiceKey.self] {
                return existing
            }
            let new = NotionDataService()
            storage[NotionDataServiceKey.self] = new
            return new
        }
        set {
            storage[NotionDataServiceKey.self] = newValue
        }
    }
} 
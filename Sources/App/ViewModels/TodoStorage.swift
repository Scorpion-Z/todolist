import CloudKit
import Foundation


protocol TodoStorage {
    func loadItems() async -> [TodoItem]
    func persistItems(_ items: [TodoItem]) async
}

struct LocalTodoStorage: TodoStorage, TodoSnapshotStorage {
    private static let storageFilename = "todos.json"
    private static let currentSchemaVersion = 3

    private struct StoredPayloadV2: Codable {
        var schemaVersion: Int
        var items: [TodoItem]
    }

    private struct StoredPayloadV3: Codable {
        var schemaVersion: Int
        var tasks: [TodoItem]
        var lists: [TodoListEntity]
        var groups: [ListGroupEntity]
        var profile: ProfileSettings
        var appPrefs: AppPreferences
    }

    func loadItems() async -> [TodoItem] {
        await loadSnapshot().tasks
    }

    func persistItems(_ items: [TodoItem]) async {
        var snapshot = await loadSnapshot()
        snapshot.tasks = items
        await persistSnapshot(snapshot)
    }

    func loadSnapshot() async -> TodoAppSnapshot {
        guard let url = Self.storageURL,
              let data = try? Data(contentsOf: url) else {
            return Self.normalizedSnapshot(TodoAppSnapshot())
        }

        if let payload = try? JSONDecoder().decode(StoredPayloadV3.self, from: data) {
            return Self.normalizedSnapshot(
                TodoAppSnapshot(
                    schemaVersion: payload.schemaVersion,
                    tasks: payload.tasks,
                    lists: payload.lists,
                    groups: payload.groups,
                    profile: payload.profile,
                    appPrefs: payload.appPrefs
                )
            )
        }

        if let payload = try? JSONDecoder().decode(StoredPayloadV2.self, from: data) {
            return Self.normalizedSnapshot(
                TodoAppSnapshot(
                    schemaVersion: Self.currentSchemaVersion,
                    tasks: payload.items,
                    lists: [TodoListEntity.defaultTasks],
                    groups: [],
                    profile: ProfileSettings(),
                    appPrefs: AppPreferences()
                )
            )
        }

        if let legacyItems = try? JSONDecoder().decode([TodoItem].self, from: data) {
            return Self.normalizedSnapshot(
                TodoAppSnapshot(
                    schemaVersion: Self.currentSchemaVersion,
                    tasks: legacyItems,
                    lists: [TodoListEntity.defaultTasks],
                    groups: [],
                    profile: ProfileSettings(),
                    appPrefs: AppPreferences()
                )
            )
        }

        return Self.normalizedSnapshot(TodoAppSnapshot())
    }

    func persistSnapshot(_ snapshot: TodoAppSnapshot) async {
        guard let url = Self.storageURL else { return }
        let directory = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let normalized = Self.normalizedSnapshot(snapshot)
            let payload = StoredPayloadV3(
                schemaVersion: Self.currentSchemaVersion,
                tasks: normalized.tasks,
                lists: normalized.lists,
                groups: normalized.groups,
                profile: normalized.profile,
                appPrefs: normalized.appPrefs
            )
            let data = try JSONEncoder().encode(payload)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist todos:", error.localizedDescription)
        }
    }

    private static func normalizedSnapshot(_ input: TodoAppSnapshot) -> TodoAppSnapshot {
        var snapshot = input

        if !snapshot.lists.contains(where: { $0.id == TodoListEntity.defaultTasksListID }) {
            snapshot.lists.insert(TodoListEntity.defaultTasks, at: 0)
        }

        let validListIDs = Set(snapshot.lists.map(\.id))
        var orderByList: [UUID: Double] = [:]

        snapshot.tasks = snapshot.tasks.enumerated().map { _, task in
            var updated = task
            if !validListIDs.contains(updated.listID) {
                updated.listID = TodoListEntity.defaultTasksListID
            }

            if updated.manualOrder == 0 {
                let next = (orderByList[updated.listID] ?? 0) + 1
                orderByList[updated.listID] = next
                updated.manualOrder = next
            }
            return updated
        }

        snapshot.lists = snapshot.lists.sorted { lhs, rhs in
            if lhs.manualOrder != rhs.manualOrder {
                return lhs.manualOrder < rhs.manualOrder
            }
            return lhs.createdAt < rhs.createdAt
        }

        snapshot.groups = snapshot.groups.sorted { lhs, rhs in
            if lhs.manualOrder != rhs.manualOrder {
                return lhs.manualOrder < rhs.manualOrder
            }
            return lhs.createdAt < rhs.createdAt
        }

        snapshot.schemaVersion = Self.currentSchemaVersion
        return snapshot
    }

    private static var storageURL: URL? {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        return baseURL
            .appendingPathComponent("Todolist", isDirectory: true)
            .appendingPathComponent(storageFilename)
    }
}

struct CloudTodoStorage: TodoStorage, TodoSnapshotStorage {
    private let database: CKDatabase

    private static let taskRecordType = "TodoItem"
    private static let listRecordType = "TodoList"
    private static let groupRecordType = "TodoGroup"
    private static let profileRecordType = "TodoProfile"
    private static let prefsRecordType = "TodoPrefs"

    private enum Field {
        static let payload = "payload"
        static let updatedAt = "updatedAt"

        // Legacy fields kept for backward compatibility.
        static let title = "title"
        static let descriptionMarkdown = "descriptionMarkdown"
        static let isCompleted = "isCompleted"
        static let priority = "priority"
        static let dueDate = "dueDate"
        static let repeatRule = "repeatRule"
        static let isImportant = "isImportant"
        static let myDayDate = "myDayDate"
        static let completedAt = "completedAt"
        static let createdAt = "createdAt"
    }

    init(container: CKContainer) {
        database = container.privateCloudDatabase
    }

    func loadItems() async -> [TodoItem] {
        await loadSnapshot().tasks
    }

    func persistItems(_ items: [TodoItem]) async {
        var snapshot = await loadSnapshot()
        snapshot.tasks = items
        await persistSnapshot(snapshot)
    }

    func loadSnapshot() async -> TodoAppSnapshot {
        async let tasks = loadTasks()
        async let lists: [TodoListEntity] = loadEntities(recordType: Self.listRecordType)
        async let groups: [ListGroupEntity] = loadEntities(recordType: Self.groupRecordType)
        async let profile: ProfileSettings? = loadSingleton(recordType: Self.profileRecordType)
        async let prefs: AppPreferences? = loadSingleton(recordType: Self.prefsRecordType)

        var snapshot = TodoAppSnapshot(
            schemaVersion: 3,
            tasks: await tasks,
            lists: await lists,
            groups: await groups,
            profile: await profile ?? ProfileSettings(),
            appPrefs: await prefs ?? AppPreferences()
        )

        if snapshot.lists.isEmpty {
            snapshot.lists = [TodoListEntity.defaultTasks]
        }

        return snapshot
    }

    func persistSnapshot(_ snapshot: TodoAppSnapshot) async {
        let normalized = normalizeSnapshot(snapshot)

        await persistTasks(normalized.tasks)
        await persistEntities(normalized.lists, recordType: Self.listRecordType)
        await persistEntities(normalized.groups, recordType: Self.groupRecordType)
        await persistSingleton(normalized.profile, recordType: Self.profileRecordType, recordName: "profile")
        await persistSingleton(normalized.appPrefs, recordType: Self.prefsRecordType, recordName: "prefs")
    }

    private func loadTasks() async -> [TodoItem] {
        let query = CKQuery(recordType: Self.taskRecordType, predicate: NSPredicate(value: true))

        do {
            let (matchResults, _) = try await database.records(matching: query)
            return matchResults.compactMap { _, result in
                guard case let .success(record) = result else { return nil }
                return Self.todoItem(from: record)
            }
        } catch {
            print("Failed to load todos from CloudKit:", error.localizedDescription)
            return []
        }
    }

    private func persistTasks(_ items: [TodoItem]) async {
        let records = items.map { Self.record(from: $0) }
        let itemIDs = Set(items.map { $0.id.uuidString })

        do {
            let query = CKQuery(recordType: Self.taskRecordType, predicate: NSPredicate(value: true))
            let (matchResults, _) = try await database.records(matching: query)
            let existingIDs = matchResults.compactMap { _, result -> CKRecord.ID? in
                guard case let .success(record) = result else { return nil }
                return record.recordID
            }
            let toDelete = existingIDs.filter { !itemIDs.contains($0.recordName) }
            _ = try await database.modifyRecords(saving: records, deleting: toDelete)
        } catch {
            print("Failed to persist todos to CloudKit:", error.localizedDescription)
        }
    }

    private func loadEntities<T: Codable & Identifiable>(recordType: String) async -> [T] where T.ID == UUID {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        do {
            let (matchResults, _) = try await database.records(matching: query)
            return matchResults.compactMap { _, result in
                guard case let .success(record) = result,
                      let payloadData = record[Field.payload] as? Data,
                      let decoded = try? JSONDecoder().decode(T.self, from: payloadData) else {
                    return nil
                }
                return decoded
            }
        } catch {
            print("Failed to load record type \(recordType):", error.localizedDescription)
            return []
        }
    }

    private func persistEntities<T: Codable & Identifiable>(_ values: [T], recordType: String) async where T.ID == UUID {
        let records = values.compactMap { value -> CKRecord? in
            guard let payload = try? JSONEncoder().encode(value) else { return nil }
            let recordID = CKRecord.ID(recordName: value.id.uuidString)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            record[Field.payload] = payload as CKRecordValue
            record[Field.updatedAt] = Date() as CKRecordValue
            return record
        }

        do {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let (matchResults, _) = try await database.records(matching: query)
            let existingIDs = matchResults.compactMap { _, result -> CKRecord.ID? in
                guard case let .success(record) = result else { return nil }
                return record.recordID
            }
            let keepIDs = Set(values.map { $0.id.uuidString })
            let toDelete = existingIDs.filter { !keepIDs.contains($0.recordName) }
            _ = try await database.modifyRecords(saving: records, deleting: toDelete)
        } catch {
            print("Failed to persist record type \(recordType):", error.localizedDescription)
        }
    }

    private func loadSingleton<T: Codable>(recordType: String) async -> T? {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        do {
            let (matchResults, _) = try await database.records(matching: query)
            for (_, result) in matchResults {
                guard case let .success(record) = result,
                      let payloadData = record[Field.payload] as? Data,
                      let decoded = try? JSONDecoder().decode(T.self, from: payloadData) else {
                    continue
                }
                return decoded
            }
        } catch {
            print("Failed to load singleton \(recordType):", error.localizedDescription)
        }

        return nil
    }

    private func persistSingleton<T: Codable>(_ value: T, recordType: String, recordName: String) async {
        guard let payload = try? JSONEncoder().encode(value) else { return }

        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record[Field.payload] = payload as CKRecordValue
        record[Field.updatedAt] = Date() as CKRecordValue

        do {
            _ = try await database.modifyRecords(saving: [record], deleting: [])
        } catch {
            print("Failed to persist singleton \(recordType):", error.localizedDescription)
        }
    }

    private func normalizeSnapshot(_ snapshot: TodoAppSnapshot) -> TodoAppSnapshot {
        var output = snapshot

        if !output.lists.contains(where: { $0.id == TodoListEntity.defaultTasksListID }) {
            output.lists.insert(TodoListEntity.defaultTasks, at: 0)
        }

        let validListIDs = Set(output.lists.map(\.id))
        output.tasks = output.tasks.map { item in
            var updated = item
            if !validListIDs.contains(updated.listID) {
                updated.listID = TodoListEntity.defaultTasksListID
            }
            return updated
        }

        return output
    }

    private static func todoItem(from record: CKRecord) -> TodoItem? {
        if let payloadData = record[Field.payload] as? Data,
           let decoded = try? JSONDecoder().decode(TodoItem.self, from: payloadData) {
            return decoded
        }

        guard let title = record[Field.title] as? String else { return nil }
        let description = record[Field.descriptionMarkdown] as? String ?? ""
        let isCompleted = record[Field.isCompleted] as? Bool ?? false
        let priorityRawValue = record[Field.priority] as? String ?? TodoItem.Priority.medium.rawValue
        let priority = TodoItem.Priority(rawValue: priorityRawValue) ?? .medium
        let dueDate = record[Field.dueDate] as? Date
        let repeatRuleRawValue = record[Field.repeatRule] as? String ?? TodoItem.RepeatRule.none.rawValue
        let repeatRule = TodoItem.RepeatRule(rawValue: repeatRuleRawValue) ?? .none
        let isImportant = record[Field.isImportant] as? Bool ?? false
        let myDayDate = record[Field.myDayDate] as? Date
        let completedAt = record[Field.completedAt] as? Date
        let createdAt = record[Field.createdAt] as? Date ?? Date()
        let updatedAt = record[Field.updatedAt] as? Date ?? createdAt
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()

        return TodoItem(
            id: id,
            title: title,
            descriptionMarkdown: description,
            isCompleted: isCompleted,
            listID: TodoListEntity.defaultTasksListID,
            manualOrder: 0,
            priority: priority,
            dueDate: dueDate,
            isImportant: isImportant,
            myDayDate: myDayDate,
            completedAt: completedAt,
            updatedAt: updatedAt,
            createdAt: createdAt,
            repeatRule: repeatRule
        )
    }

    private static func record(from item: TodoItem) -> CKRecord {
        let recordID = CKRecord.ID(recordName: item.id.uuidString)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        if let payloadData = try? JSONEncoder().encode(item) {
            record[Field.payload] = payloadData as CKRecordValue
        }
        record[Field.updatedAt] = item.updatedAt as CKRecordValue

        record[Field.title] = item.title as CKRecordValue
        record[Field.descriptionMarkdown] = item.descriptionMarkdown as CKRecordValue
        record[Field.isCompleted] = item.isCompleted as CKRecordValue
        record[Field.priority] = item.priority.rawValue as CKRecordValue
        record[Field.repeatRule] = item.repeatRule.rawValue as CKRecordValue
        record[Field.isImportant] = item.isImportant as CKRecordValue
        if let dueDate = item.dueDate {
            record[Field.dueDate] = dueDate as CKRecordValue
        }
        if let myDayDate = item.myDayDate {
            record[Field.myDayDate] = myDayDate as CKRecordValue
        }
        if let completedAt = item.completedAt {
            record[Field.completedAt] = completedAt as CKRecordValue
        }
        record[Field.createdAt] = item.createdAt as CKRecordValue
        return record
    }
}

struct DualWriteStorage: TodoStorage, TodoSnapshotStorage {
    let primary: TodoStorage
    let secondary: TodoStorage

    func loadItems() async -> [TodoItem] {
        await primary.loadItems()
    }

    func persistItems(_ items: [TodoItem]) async {
        await primary.persistItems(items)
        await secondary.persistItems(items)
    }

    func loadSnapshot() async -> TodoAppSnapshot {
        if let primary = primary as? any TodoSnapshotStorage {
            return await primary.loadSnapshot()
        }
        return TodoAppSnapshot(tasks: await primary.loadItems())
    }

    func persistSnapshot(_ snapshot: TodoAppSnapshot) async {
        if let primary = primary as? any TodoSnapshotStorage {
            await primary.persistSnapshot(snapshot)
        } else {
            await primary.persistItems(snapshot.tasks)
        }

        if let secondary = secondary as? any TodoSnapshotStorage {
            await secondary.persistSnapshot(snapshot)
        } else {
            await secondary.persistItems(snapshot.tasks)
        }
    }
}

struct ConflictAwareDualStorage: TodoStorage, TodoSnapshotStorage {
    let local: TodoStorage
    let cloud: TodoStorage

    func loadItems() async -> [TodoItem] {
        await loadSnapshot().tasks
    }

    func persistItems(_ items: [TodoItem]) async {
        var snapshot = await loadSnapshot()
        snapshot.tasks = items
        await persistSnapshot(snapshot)
    }

    func loadSnapshot() async -> TodoAppSnapshot {
        async let localSnapshot = loadSnapshot(from: local)
        async let cloudSnapshot = loadSnapshot(from: cloud)

        let merged = Self.merge(local: await localSnapshot, remote: await cloudSnapshot)

        await persistSnapshot(to: local, snapshot: merged)
        await persistSnapshot(to: cloud, snapshot: merged)
        return merged
    }

    func persistSnapshot(_ snapshot: TodoAppSnapshot) async {
        let localSnapshot = await loadSnapshot(from: local)
        let cloudSnapshot = await loadSnapshot(from: cloud)
        let merged = Self.merge(local: snapshot, remote: Self.merge(local: localSnapshot, remote: cloudSnapshot))

        await persistSnapshot(to: local, snapshot: merged)
        await persistSnapshot(to: cloud, snapshot: merged)
    }

    private func loadSnapshot(from storage: TodoStorage) async -> TodoAppSnapshot {
        if let snapshotStorage = storage as? any TodoSnapshotStorage {
            return await snapshotStorage.loadSnapshot()
        }
        return TodoAppSnapshot(tasks: await storage.loadItems())
    }

    private func persistSnapshot(to storage: TodoStorage, snapshot: TodoAppSnapshot) async {
        if let snapshotStorage = storage as? any TodoSnapshotStorage {
            await snapshotStorage.persistSnapshot(snapshot)
        } else {
            await storage.persistItems(snapshot.tasks)
        }
    }

    private static func merge(local: TodoAppSnapshot, remote: TodoAppSnapshot) -> TodoAppSnapshot {
        let mergedTasks = merge(local: local.tasks, remote: remote.tasks)
        let mergedLists = mergeEntities(local.lists, remote: remote.lists)
        let mergedGroups = mergeEntities(local.groups, remote: remote.groups)

        let profile = local.profile.updatedAt >= remote.profile.updatedAt ? local.profile : remote.profile
        let appPrefs = local.appPrefs.updatedAt >= remote.appPrefs.updatedAt ? local.appPrefs : remote.appPrefs

        var snapshot = TodoAppSnapshot(
            schemaVersion: max(local.schemaVersion, remote.schemaVersion),
            tasks: mergedTasks,
            lists: mergedLists,
            groups: mergedGroups,
            profile: profile,
            appPrefs: appPrefs
        )

        if !snapshot.lists.contains(where: { $0.id == TodoListEntity.defaultTasksListID }) {
            snapshot.lists.insert(TodoListEntity.defaultTasks, at: 0)
        }

        return snapshot
    }

    private static func mergeEntities<T: Identifiable>(_ local: [T], remote: [T]) -> [T] where T.ID == UUID {
        var remoteMap = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        var merged: [T] = []

        for entity in local {
            if let remoteEntity = remoteMap.removeValue(forKey: entity.id) {
                merged.append(pickNewer(entity, remoteEntity))
            } else {
                merged.append(entity)
            }
        }

        merged.append(contentsOf: remoteMap.values)
        return merged
    }

    private static func pickNewer<T>(_ lhs: T, _ rhs: T) -> T {
        guard let lhsDate = extractUpdatedAt(lhs), let rhsDate = extractUpdatedAt(rhs) else {
            return lhs
        }
        return lhsDate >= rhsDate ? lhs : rhs
    }

    private static func extractUpdatedAt<T>(_ value: T) -> Date? {
        switch value {
        case let v as TodoListEntity:
            return v.updatedAt
        case let v as ListGroupEntity:
            return v.updatedAt
        default:
            return nil
        }
    }

    private static func merge(local: [TodoItem], remote: [TodoItem]) -> [TodoItem] {
        var remoteMap = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        var merged: [TodoItem] = []
        merged.reserveCapacity(max(local.count, remote.count))

        for localItem in local {
            if let remoteItem = remoteMap.removeValue(forKey: localItem.id) {
                merged.append(merge(local: localItem, remote: remoteItem))
            } else {
                merged.append(localItem)
            }
        }

        if !remoteMap.isEmpty {
            let remaining = remoteMap.values.sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt < rhs.updatedAt
                }
                return lhs.createdAt < rhs.createdAt
            }
            merged.append(contentsOf: remaining)
        }

        return merged
    }

    private static func merge(local: TodoItem, remote: TodoItem) -> TodoItem {
        let newer = local.updatedAt >= remote.updatedAt ? local : remote
        let older = local.updatedAt >= remote.updatedAt ? remote : local
        var merged = newer

        let timestampGap = abs(local.updatedAt.timeIntervalSince(remote.updatedAt))
        if timestampGap <= 1 {
            merged.tags = mergeTags(merged.tags, older.tags)
            merged.subtasks = mergeSubtasks(merged.subtasks, older.subtasks)
            if merged.descriptionMarkdown.isEmpty, !older.descriptionMarkdown.isEmpty {
                merged.descriptionMarkdown = older.descriptionMarkdown
            }
            merged.myDayDate = maxDate(local.myDayDate, remote.myDayDate)
            merged.completedAt = maxDate(local.completedAt, remote.completedAt)
        }

        merged.updatedAt = maxDate(local.updatedAt, remote.updatedAt) ?? merged.updatedAt

        return merged
    }

    private static func mergeTags(_ lhs: [Tag], _ rhs: [Tag]) -> [Tag] {
        var seen = Set<String>()
        var merged: [Tag] = []

        for tag in lhs + rhs {
            let normalized = normalizedTagName(tag.name)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            merged.append(tag)
        }

        return merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func mergeSubtasks(_ lhs: [Subtask], _ rhs: [Subtask]) -> [Subtask] {
        var mergedByID = Dictionary(uniqueKeysWithValues: lhs.map { ($0.id, $0) })
        for subtask in rhs {
            if let existing = mergedByID[subtask.id] {
                mergedByID[subtask.id] = Subtask(
                    id: existing.id,
                    title: existing.title.isEmpty ? subtask.title : existing.title,
                    isCompleted: existing.isCompleted || subtask.isCompleted
                )
            } else {
                mergedByID[subtask.id] = subtask
            }
        }

        return mergedByID.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (left?, right?):
            return max(left, right)
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }

    private static func normalizedTagName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

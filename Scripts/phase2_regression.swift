import Foundation

enum RegressionError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw RegressionError.failed(message)
    }
}

actor MemoryStorage: TodoStorage {
    private var storedItems: [TodoItem]
    private var persistCountValue = 0

    init(items: [TodoItem] = []) {
        self.storedItems = items
    }

    func loadItems() async -> [TodoItem] {
        storedItems
    }

    func persistItems(_ items: [TodoItem]) async {
        storedItems = items
        persistCountValue += 1
    }

    func snapshot() async -> [TodoItem] {
        storedItems
    }

    func persistCount() async -> Int {
        persistCountValue
    }
}

@main
struct Phase2RegressionMain {
    static func main() async {
        do {
            try await runAll()
            print("PASS phase2 regression")
        } catch {
            fputs("FAIL phase2 regression: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    static func runAll() async throws {
        try testTodoItemCompatibility()
        try testListSemanticsAndCrossDayMyDay()
        try testQuickAddParser()
        try await testTaskStoreCompletionAndPersistence()
        try await testMyDaySuggestionsAndStats()
        try await testListDeletionReordersManualOrderAndSelectionFallback()
        try await testAppShellActionDispatch()
        try await testConflictAwareDualStorageMerge()
    }

    static func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        let calendar = fixedCalendar()
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    static func dateParts(_ date: Date, calendar: Calendar) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    static func testTodoItemCompatibility() throws {
        let legacyJSON = """
        {
          "id":"00000000-0000-0000-0000-000000000001",
          "title":"legacy",
          "descriptionMarkdown":"",
          "isCompleted":false,
          "priority":"medium",
          "tags":["work"],
          "subtasks":[],
          "repeatRule":"none"
        }
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode(TodoItem.self, from: data)

        try expect(decoded.isImportant == false, "legacy decode should default isImportant=false")
        try expect(decoded.myDayDate == nil, "legacy decode should default myDayDate=nil")
        try expect(decoded.completedAt == nil, "legacy decode should default completedAt=nil")
        try expect(decoded.updatedAt == decoded.createdAt, "legacy decode should default updatedAt=createdAt")
        try expect(decoded.tags.count == 1 && decoded.tags[0].name == "work", "legacy string tags should migrate to Tag")
    }

    static func testListSemanticsAndCrossDayMyDay() throws {
        let calendar = fixedCalendar()
        let now = makeDate(2026, 2, 9, 10, 0)
        let todayStart = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart)!

        let inbox = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, title: "inbox")
        let myDay = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, title: "myday", myDayDate: todayStart)
        let important = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, title: "important", isImportant: true)
        let planned = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!, title: "planned", dueDate: tomorrow)
        let completed = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!, title: "completed", isCompleted: true, completedAt: now)
        let staleMyDay = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!, title: "stale", myDayDate: yesterday)

        let items = [inbox, myDay, important, planned, completed, staleMyDay]
        let engine = ListQueryEngine()
        let query = TaskQuery(searchText: "", sort: .manual, tagFilter: [], showCompleted: true)

        let inboxIDs = Set(engine.tasks(from: items, list: .inbox, query: query, selectedTag: nil, useGlobalSearch: false, referenceDate: now, calendar: calendar).map(\.id))
        try expect(inboxIDs.contains(inbox.id), "inbox should include plain task")
        try expect(inboxIDs.contains(important.id), "inbox should include important task without due date")
        try expect(inboxIDs.contains(staleMyDay.id), "inbox should include stale myday task on next day")
        try expect(!inboxIDs.contains(myDay.id), "inbox should exclude current myday task")

        let myDayIDs = Set(engine.tasks(from: items, list: .myDay, query: query, selectedTag: nil, useGlobalSearch: false, referenceDate: now, calendar: calendar).map(\.id))
        try expect(myDayIDs == Set([myDay.id]), "myday should only include tasks added for same day")

        let importantIDs = Set(engine.tasks(from: items, list: .important, query: query, selectedTag: nil, useGlobalSearch: false, referenceDate: now, calendar: calendar).map(\.id))
        try expect(importantIDs == Set([important.id]), "important list mismatch")

        let plannedIDs = Set(engine.tasks(from: items, list: .planned, query: query, selectedTag: nil, useGlobalSearch: false, referenceDate: now, calendar: calendar).map(\.id))
        try expect(plannedIDs == Set([planned.id]), "planned list mismatch")

        let completedIDs = Set(engine.tasks(from: items, list: .completed, query: query, selectedTag: nil, useGlobalSearch: false, referenceDate: now, calendar: calendar).map(\.id))
        try expect(completedIDs == Set([completed.id]), "completed list mismatch")

        let allIDs = Set(engine.tasks(from: items, list: .all, query: query, selectedTag: nil, useGlobalSearch: false, referenceDate: now, calendar: calendar).map(\.id))
        try expect(allIDs.count == items.count, "all list should include all tasks")
    }

    static func testQuickAddParser() throws {
        let calendar = fixedCalendar()
        let now = makeDate(2026, 2, 9, 10, 0)
        let parser = QuickAddParser(calendar: calendar, nowProvider: { now })

        let zh = parser.parse("明天下午3点开会 p1 每周")
        try expect(zh.priority == .high, "quick add zh priority parse failed")
        try expect(zh.repeatRule == .weekly, "quick add zh repeat parse failed")
        try expect(zh.title.contains("开会"), "quick add zh title parse failed")
        if let due = zh.dueDate {
            let parts = dateParts(due, calendar: calendar)
            try expect(parts.year == 2026 && parts.month == 2 && parts.day == 10 && parts.hour == 15, "quick add zh due date parse failed")
        } else {
            throw RegressionError.failed("quick add zh due date missing")
        }

        let en = parser.parse("review docs tomorrow 9am every day p2")
        try expect(en.priority == .medium, "quick add en priority parse failed")
        try expect(en.repeatRule == .daily, "quick add en repeat parse failed")
        try expect(en.title.lowercased().contains("review"), "quick add en title parse failed")
        if let due = en.dueDate {
            let parts = dateParts(due, calendar: calendar)
            try expect(parts.year == 2026 && parts.month == 2 && parts.day == 10 && parts.hour == 9, "quick add en due date parse failed")
        } else {
            throw RegressionError.failed("quick add en due date missing")
        }

        let tonight = parser.parse("今晚整理复盘")
        if let due = tonight.dueDate {
            let parts = dateParts(due, calendar: calendar)
            try expect(parts.hour == 20, "quick add tonight implied time should be 20:00")
        } else {
            throw RegressionError.failed("quick add tonight due date missing")
        }
    }

    @MainActor
    static func testTaskStoreCompletionAndPersistence() async throws {
        let storage = MemoryStorage()
        let item = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!, title: "task")
        let store = TaskStore(items: [item], storage: storage)

        store.toggleCompletion(id: item.id)
        guard let afterComplete = store.item(withID: item.id) else {
            throw RegressionError.failed("task store item disappeared after completion")
        }
        try expect(afterComplete.isCompleted, "task should be completed after toggle")
        try expect(afterComplete.completedAt != nil, "completedAt should be set when completed")

        store.toggleCompletion(id: item.id)
        guard let reopened = store.item(withID: item.id) else {
            throw RegressionError.failed("task store item disappeared after reopen")
        }
        try expect(!reopened.isCompleted, "task should reopen after second toggle")
        try expect(reopened.completedAt == nil, "completedAt should clear when reopened")

        _ = store.createQuickTask(rawText: "run tomorrow 7am every day p3")
        guard let quick = store.items.last else {
            throw RegressionError.failed("quick task missing")
        }
        try expect(quick.repeatRule == .daily, "quick task repeat rule should be daily")

        try await Task.sleep(nanoseconds: 500_000_000)
        let persistCount = await storage.persistCount()
        try expect(persistCount >= 1, "task store should persist asynchronously")
    }

    @MainActor
    static func testMyDaySuggestionsAndStats() async throws {
        let calendar = fixedCalendar()
        let now = makeDate(2026, 2, 9, 10, 0)
        let todayStart = calendar.startOfDay(for: now)
        let overdueDate = calendar.date(byAdding: .day, value: -2, to: todayStart)!
        let dueToday = calendar.date(byAdding: .hour, value: 8, to: todayStart)!

        let overdue = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!, title: "overdue", dueDate: overdueDate)
        let due = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!, title: "due", dueDate: dueToday)
        let important = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!, title: "important", isImportant: true)
        let inMyDayDone = TodoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000204")!,
            title: "done",
            isCompleted: true,
            myDayDate: todayStart,
            completedAt: now
        )
        let inMyDayOpen = TodoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000205")!,
            title: "open",
            myDayDate: todayStart
        )

        let storage = MemoryStorage(items: [overdue, due, important, inMyDayDone, inMyDayOpen])
        let store = TaskStore(items: [overdue, due, important, inMyDayDone, inMyDayOpen], storage: storage)

        let suggestions = store.myDaySuggestions(limit: 5, referenceDate: now, calendar: calendar)
        try expect(suggestions.count >= 3, "myday suggestions should include overdue/dueToday/important")
        try expect(suggestions.first?.reason == .overdue, "overdue should rank first")

        let progress = store.myDayProgress(referenceDate: now, calendar: calendar)
        try expect(progress.totalCount == 2 && progress.completedCount == 1, "myday progress should count only myday tasks")

        let streak = store.completionStreak(referenceDate: now, calendar: calendar)
        try expect(streak >= 1, "completion streak should be at least 1 with today's completion")

        let review = store.weeklyReview(referenceDate: now, calendar: calendar)
        try expect(review.completedCount >= 1, "weekly review should count completed tasks")
    }

    @MainActor
    static func testListDeletionReordersManualOrderAndSelectionFallback() async throws {
        let storage = MemoryStorage()
        let store = TaskStore(items: [], storage: storage)

        store.createTask(TaskDraft(title: "default 1"))
        store.createTask(TaskDraft(title: "default 2"))
        store.createList(title: "Project")
        guard let customListID = store.customLists.first?.id else {
            throw RegressionError.failed("custom list should be created")
        }

        store.createTask(TaskDraft(title: "custom 1"), inListID: customListID)
        store.createTask(TaskDraft(title: "custom 2"), inListID: customListID)
        let movedTaskID = store.items.first(where: { $0.listID == customListID })?.id

        let shell = AppShellViewModel(selection: .customList(customListID))
        shell.selectTask(movedTaskID)

        store.deleteList(id: customListID)
        shell.reconcileSelection(validCustomListIDs: Set(store.customLists.map(\.id)))

        try expect(shell.selection == .smartList(.myDay), "selection should fallback to My Day after deleting active custom list")
        try expect(shell.selectedTaskID == nil, "selected task should clear after fallback")

        let defaultListTasks = store.items
            .filter { $0.listID == TodoListEntity.defaultTasksListID }
            .sorted { $0.manualOrder < $1.manualOrder }
        let orders = defaultListTasks.map(\.manualOrder)
        try expect(Set(orders).count == orders.count, "default list manualOrder should remain unique after migration")
        for (offset, order) in orders.enumerated() {
            try expect(order == Double(offset + 1), "default list manualOrder should be compact and continuous after migration")
        }
    }

    @MainActor
    static func testAppShellActionDispatch() async throws {
        let storage = MemoryStorage()
        let item = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!, title: "selected")
        let store = TaskStore(items: [item], storage: storage)
        let shell = AppShellViewModel(selection: .smartList(.myDay), selectedTaskID: item.id)

        shell.toggleSelectedTaskImportant(using: store)
        guard let afterImportant = store.item(withID: item.id) else {
            throw RegressionError.failed("item missing after important toggle")
        }
        try expect(afterImportant.isImportant, "shell action should toggle important state")

        shell.toggleSelectedTaskCompletion(using: store)
        guard let afterCompletion = store.item(withID: item.id) else {
            throw RegressionError.failed("item missing after completion toggle")
        }
        try expect(afterCompletion.isCompleted, "shell action should toggle completion state")

        shell.deleteSelectedTask(from: store)
        try expect(store.item(withID: item.id) == nil, "shell action should delete selected task")
        try expect(shell.selectedTaskID == nil, "shell should clear selected task after deletion")
    }

    static func testConflictAwareDualStorageMerge() async throws {
        let t0 = makeDate(2026, 2, 9, 10, 0)

        let sharedID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        let localOlder = TodoItem(
            id: sharedID,
            title: "local older",
            updatedAt: t0,
            createdAt: t0
        )
        let remoteNewer = TodoItem(
            id: sharedID,
            title: "remote newer",
            updatedAt: t0.addingTimeInterval(10),
            createdAt: t0
        )

        let mergeID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        let localNear = TodoItem(
            id: mergeID,
            title: "local near",
            descriptionMarkdown: "",
            updatedAt: t0,
            createdAt: t0,
            subtasks: [Subtask(title: "a")],
            tags: [Tag(name: "local")]
        )
        let remoteNear = TodoItem(
            id: mergeID,
            title: "remote near",
            descriptionMarkdown: "remote description",
            updatedAt: t0.addingTimeInterval(0.5),
            createdAt: t0,
            subtasks: [Subtask(title: "b")],
            tags: [Tag(name: "remote")]
        )

        let remoteOnly = TodoItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
            title: "remote only",
            updatedAt: t0,
            createdAt: t0
        )

        let local = MemoryStorage(items: [localOlder, localNear])
        let cloud = MemoryStorage(items: [remoteNewer, remoteNear, remoteOnly])
        let dual = ConflictAwareDualStorage(local: local, cloud: cloud)

        let merged = await dual.loadItems()
        try expect(merged.count == 3, "conflict merge should keep union of tasks")

        guard let mergedShared = merged.first(where: { $0.id == sharedID }) else {
            throw RegressionError.failed("shared item missing after merge")
        }
        try expect(mergedShared.title == "remote newer", "newer updatedAt should win")

        guard let mergedNear = merged.first(where: { $0.id == mergeID }) else {
            throw RegressionError.failed("near item missing after merge")
        }
        let tagSet = Set(mergedNear.tags.map { $0.name.lowercased() })
        try expect(tagSet.contains("local") && tagSet.contains("remote"), "near-simultaneous merge should union tags")
        try expect(mergedNear.descriptionMarkdown == "remote description", "near-simultaneous merge should keep richer description")
        try expect(mergedNear.subtasks.count >= 2, "near-simultaneous merge should preserve subtasks")

        let localAfter = await local.snapshot()
        let cloudAfter = await cloud.snapshot()
        try expect(localAfter.count == 3 && cloudAfter.count == 3, "dual storage load should persist merged snapshot to both sides")
    }
}

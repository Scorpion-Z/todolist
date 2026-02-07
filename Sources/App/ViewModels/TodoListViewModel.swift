import Foundation

struct QuickAddFeedback {
    let created: Bool
    let recognizedTokens: [String]
}

final class TodoListViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem]

    private let quickAddParser: QuickAddParser
    private static let storageFilename = "todos.json"

    init(items: [TodoItem] = [], quickAddParser: QuickAddParser = QuickAddParser()) {
        self.quickAddParser = quickAddParser

        if items.isEmpty {
            self.items = Self.loadItems()
        } else {
            self.items = items
        }
    }

    struct DailyCompletionStat: Identifiable {
        let date: Date
        let completedCount: Int

        var id: Date { date }
    }

    func addItem(title: String, priority: TodoItem.Priority, dueDate: Date?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed, priority: priority, dueDate: dueDate))
        persistItems()
    }

    @discardableResult
    func addQuickItem(rawText: String) -> QuickAddFeedback {
        let parsed = quickAddParser.parse(rawText)
        let fallbackTitle = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = parsed.title.isEmpty ? fallbackTitle : parsed.title

        guard !finalTitle.isEmpty else {
            return QuickAddFeedback(created: false, recognizedTokens: parsed.recognizedTokens)
        }

        addItem(title: finalTitle, priority: parsed.priority, dueDate: parsed.dueDate)
        return QuickAddFeedback(created: true, recognizedTokens: parsed.recognizedTokens)
    }

    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persistItems()
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persistItems()
    }

    func toggleCompletion(for item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isCompleted.toggle()
        persistItems()
    }

    func updateItem(_ item: TodoItem, title: String, priority: TodoItem.Priority, dueDate: Date?) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].title = trimmed
        items[index].priority = priority
        items[index].dueDate = dueDate
        persistItems()
    }

    func todayCompletedCount(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let dayRange = dayRange(for: referenceDate, calendar: calendar)
        return items.filter { item in
            item.isCompleted && dayRange.contains(normalizedDate(for: item))
        }.count
    }

    func overdueCount(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        return items.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return !item.isCompleted && dueDate < startOfToday
        }.count
    }

    func sevenDayCompletionTrend(referenceDate: Date = Date(), calendar: Calendar = .current) -> [DailyCompletionStat] {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: startOfToday) else { return nil }
            let dayRange = dayRange(for: day, calendar: calendar)
            let completedCount = items.filter { item in
                item.isCompleted && dayRange.contains(normalizedDate(for: item))
            }.count
            return DailyCompletionStat(date: day, completedCount: completedCount)
        }
    }

    func todayCompletionRate(referenceDate: Date = Date(), calendar: Calendar = .current) -> Double {
        let dayRange = dayRange(for: referenceDate, calendar: calendar)
        let totalCount = items.filter { item in
            dayRange.contains(normalizedDate(for: item))
        }.count
        guard totalCount > 0 else { return 0 }
        let completedCount = items.filter { item in
            item.isCompleted && dayRange.contains(normalizedDate(for: item))
        }.count
        return Double(completedCount) / Double(totalCount)
    }

    private func persistItems() {
        guard let url = Self.storageURL else { return }
        let directory = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist todos:", error.localizedDescription)
        }
    }

    private static func loadItems() -> [TodoItem] {
        guard let url = storageURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return decoded
    }

    private static var storageURL: URL? {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        return baseURL
            .appendingPathComponent("Todolist", isDirectory: true)
            .appendingPathComponent(storageFilename)
    }

    private func normalizedDate(for item: TodoItem) -> Date {
        item.dueDate ?? item.createdAt
    }

    private func dayRange(for date: Date, calendar: Calendar) -> Range<Date> {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return startOfDay..<endOfDay
    }
}

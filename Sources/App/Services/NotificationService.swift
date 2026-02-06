import Foundation
import UserNotifications

final class NotificationService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func fetchAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    func requestAuthorization(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
            self?.fetchAuthorizationStatus(completion: completion)
        }
    }

    func scheduleReminder(for item: TodoItem) {
        guard let remindAt = item.remindAt else { return }

        let content = UNMutableNotificationContent()
        content.title = "Todo Reminder"
        content.body = item.title
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: remindAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request, withCompletionHandler: nil)
    }

    func updateReminder(for item: TodoItem) {
        cancelReminder(for: item.id)
        scheduleReminder(for: item)
    }

    func cancelReminder(for id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}

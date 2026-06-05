import UserNotifications

enum NotificationService {
    static func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleWeeklyDigestReminder() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        // Remove existing to avoid duplicates
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-digest"])

        let content = UNMutableNotificationContent()
        content.title = "New AI lessons available"
        content.body = "Your weekly AI tools update is ready. Keep building."
        content.sound = .default

        // Fire every Monday at 9am
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // Monday
        dateComponents.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weekly-digest",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
}

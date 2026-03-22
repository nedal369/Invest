import Foundation
import UserNotifications

// MARK: - Notification Manager
class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                self.scheduleRecurringNotifications()
            }
        }
    }

    // MARK: - Schedule
    private func scheduleRecurringNotifications() {
        // Monthly fund payment reminder
        scheduleMonthlyFundReminder()
        // Ramadan zakat reminder
        scheduleRamadanZakatReminder()
    }

    func scheduleMonthlyFundReminder(day: Int = 1) {
        let content = UNMutableNotificationContent()
        content.title = "تذكير الصناديق الاستثمارية"
        content.body = "موعد استحقاق دفعات الصناديق الشهرية"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.day = day
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "monthly_fund_payment", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleRamadanZakatReminder() {
        let content = UNMutableNotificationContent()
        content.title = "تذكير إخراج الزكاة"
        content.body = "حان موعد احتساب وإخراج الزكاة السنوية"
        content.sound = .default
        content.badge = 1

        // Schedule for 1st Ramadan - using Hijri calendar
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: .islamicUmmAlQura)
        dateComponents.month = 9  // Ramadan
        dateComponents.day = 1
        dateComponents.hour = 8

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "ramadan_zakat", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleHaolCompletionAlert(assetSymbol: String, assetName: String, completionDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "اكتمل حول الزكاة"
        content.body = "اكتمل حول الزكاة لـ \(assetName) (\(assetSymbol))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: completionDate.timeIntervalSinceNow,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "haol_\(assetSymbol)_\(completionDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func schedulePriceAlert(symbol: String, alertType: PriceAlert.AlertType, threshold: Decimal) {
        // Will be checked when prices are updated
        // Store alert in DB and check during price updates
    }

    func scheduleLoanPaymentReminder(memberName: String, amount: Decimal, dueDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "موعد قسط قرض"
        content.body = "\(memberName) - قسط \(amount) ر.س مستحق اليوم"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: dueDate),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "loan_\(memberName)_\(dueDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func checkPriceAlerts(prices: [PriceData]) {
        let db = DatabaseManager.shared
        let alerts = db.query("SELECT * FROM alerts WHERE is_active = 1")

        for alert in alerts {
            guard let symbol = alert["symbol"] as? String,
                  let typeStr = alert["alert_type"] as? String,
                  let alertType = PriceAlert.AlertType(rawValue: typeStr),
                  let threshold = (alert["threshold"] as? Double).map({ Decimal($0) }),
                  let priceData = prices.first(where: { $0.symbol == symbol }) else { continue }

            var triggered = false
            switch alertType {
            case .priceAbove:
                triggered = priceData.price > threshold
            case .priceBelow:
                triggered = priceData.price < threshold
            case .percentageUp:
                triggered = (priceData.dailyChangePct ?? 0) >= threshold
            case .percentageDown:
                triggered = (priceData.dailyChangePct ?? 0) <= -threshold
            }

            if triggered {
                sendPriceAlert(symbol: symbol, alertType: alertType, price: priceData.price, threshold: threshold)
                db.execute("UPDATE alerts SET is_active = 0, triggered_at = '\(ISO8601DateFormatter().string(from: Date()))' WHERE symbol = '\(symbol)' AND alert_type = '\(typeStr)';")
            }
        }
    }

    private func sendPriceAlert(symbol: String, alertType: PriceAlert.AlertType, price: Decimal, threshold: Decimal) {
        let content = UNMutableNotificationContent()
        content.title = "تنبيه سعر: \(symbol)"
        content.body = "\(alertType.displayName) \(threshold) - السعر الحالي: \(price)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "price_alert_\(symbol)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

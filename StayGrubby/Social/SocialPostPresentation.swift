import Foundation

nonisolated enum SocialPostPresentation {
    /// No ticking Text(date, style: .relative): age changes only on an ordinary view refresh.
    static func timestamp(_ date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let age = max(0, now.timeIntervalSince(date))
        if age < 60 { return "Just now" }
        if age < 3_600 { return "\(Int(age / 60)) min ago" }
        if age < 86_400 { return "\(Int(age / 3_600)) hr ago" }
        if age < 604_800 { let days = Int(age / 86_400); return "\(days) \(days == 1 ? "day" : "days") ago" }
        let formatter = DateFormatter(); formatter.locale = locale; formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(calendar.component(.year, from: date) == calendar.component(.year, from: now) ? "MMMd" : "yMMMd")
        return formatter.string(from: date)
    }
    static func metadata(_ value: SharedCookingMetadata?) -> String? {
        let parts = [value?.course.flatMap { DishCategory(rawValue: $0)?.label }, value?.cuisine?.label]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

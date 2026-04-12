import Foundation

enum HistoryRetentionPolicy: String, CaseIterable {
    case never
    case oneDay
    case threeDays
    case sevenDays
    case fourteenDays
    case thirtyDays
    case ninetyDays

    static let storageKey = "historyRetentionPolicy"
    static let defaultPolicy: HistoryRetentionPolicy = .never

    var days: Int? {
        switch self {
        case .never:
            nil
        case .oneDay:
            1
        case .threeDays:
            3
        case .sevenDays:
            7
        case .fourteenDays:
            14
        case .thirtyDays:
            30
        case .ninetyDays:
            90
        }
    }

    var title: String {
        switch self {
        case .never:
            "Never"
        case .oneDay:
            "1 day"
        case .threeDays:
            "3 days"
        case .sevenDays:
            "7 days"
        case .fourteenDays:
            "14 days"
        case .thirtyDays:
            "30 days"
        case .ninetyDays:
            "90 days"
        }
    }

    static func current(userDefaults: UserDefaults = .standard) -> HistoryRetentionPolicy {
        guard let rawValue = userDefaults.string(forKey: storageKey),
              let policy = HistoryRetentionPolicy(rawValue: rawValue) else {
            return defaultPolicy
        }

        return policy
    }
}

import Foundation

enum HistoryFilter: Hashable, Identifiable {
    case kind(ClipboardItemKind)
    case pinned
    case dateRange(DateRange)
    case pinboard(String)
    case sourceApp(String)

    enum DateRange: Hashable {
        case today
        case yesterday
        case last7Days

        var displayName: String {
            switch self {
            case .today: return "Today"
            case .yesterday: return "Yesterday"
            case .last7Days: return "Last 7 days"
            }
        }
    }

    static let commonFilters: [HistoryFilter] = [
        .kind(.text),
        .kind(.image),
        .kind(.link),
        .kind(.file),
        .pinned,
        .dateRange(.today),
        .dateRange(.yesterday),
        .dateRange(.last7Days)
    ]

    var id: String {
        switch self {
        case .kind(let k): return "kind:\(k.rawValue)"
        case .pinned: return "pinned"
        case .dateRange(let r):
            switch r {
            case .today: return "date:today"
            case .yesterday: return "date:yesterday"
            case .last7Days: return "date:last7"
            }
        case .pinboard(let name): return "pinboard:\(name)"
        case .sourceApp(let name): return "sourceApp:\(name)"
        }
    }

    var displayName: String {
        switch self {
        case .kind(let k):
            switch k {
            case .text: return "Text"
            case .image: return "Images"
            case .link: return "Links"
            case .file: return "Files"
            }
        case .pinned: return "Pinned"
        case .dateRange(let r): return r.displayName
        case .pinboard(let name): return name
        case .sourceApp(let name): return "App: \(name)"
        }
    }

    var icon: String {
        switch self {
        case .kind(let k):
            switch k {
            case .text: return "doc.text"
            case .image: return "photo"
            case .link: return "link"
            case .file: return "doc"
            }
        case .pinned: return "pin.fill"
        case .dateRange: return "calendar"
        case .pinboard: return "folder.fill"
        case .sourceApp: return "app.badge"
        }
    }
}

extension Set where Element == HistoryFilter {
    var kindFilters: [ClipboardItemKind] {
        compactMap {
            if case .kind(let k) = $0 { return k }
            return nil
        }
    }

    var hasPinnedFilter: Bool {
        contains(where: {
            if case .pinned = $0 { return true }
            return false
        })
    }

    var dateRange: HistoryFilter.DateRange? {
        first(where: {
            if case .dateRange = $0 { return true }
            return false
        }).flatMap {
            if case .dateRange(let r) = $0 { return r }
            return nil
        }
    }

    var pinboardFilter: String? {
        first(where: {
            if case .pinboard = $0 { return true }
            return false
        }).flatMap {
            if case .pinboard(let name) = $0 { return name }
            return nil
        }
    }
}

import Foundation

enum ClipboardSoundName: String, CaseIterable, Sendable {
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case glass = "Glass"
    case hero = "Hero"
    case pop = "Pop"
    case submarine = "Submarine"
    case tink = "Tink"

    var title: String {
        rawValue
    }
}

enum ClipboardSoundPreference {
    static let enabledStorageKey = "clipboardSoundEnabled"
    static let nameStorageKey = "clipboardSoundName"

    static func isEnabled(userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: enabledStorageKey) != nil else { return true }
        return userDefaults.bool(forKey: enabledStorageKey)
    }

    static func selectedSound(userDefaults: UserDefaults) -> ClipboardSoundName {
        guard
            let rawValue = userDefaults.string(forKey: nameStorageKey),
            let sound = ClipboardSoundName(rawValue: rawValue)
        else {
            return .glass
        }

        return sound
    }
}

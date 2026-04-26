import Foundation
import XCTest
@testable import Clipo

final class SystemClipboardSoundPlayerTests: XCTestCase {
    func testPlayerSkipsSoundWhenDisabled() async {
        let recorder = SoundPlaybackRecorder()
        let player = SystemClipboardSoundPlayer(
            currentBundleIdentifier: "com.bat.clipo",
            isSoundEnabled: { false },
            selectedSound: { .glass },
            playNamedSound: { name in
                await recorder.recordPlayedSound(name)
                return true
            },
            beep: {
                await recorder.recordBeep()
            }
        )

        await player.playIfNeeded(for: .stub(title: "External", sourceAppBundleId: "com.apple.TextEdit"))

        let state = await recorder.snapshot()
        XCTAssertEqual(state.playedSoundNames, [])
        XCTAssertEqual(state.beepCount, 0)
    }

    func testPlayerUsesSelectedSoundWhenEnabled() async {
        let recorder = SoundPlaybackRecorder()
        let player = SystemClipboardSoundPlayer(
            currentBundleIdentifier: "com.bat.clipo",
            isSoundEnabled: { true },
            selectedSound: { .submarine },
            playNamedSound: { name in
                await recorder.recordPlayedSound(name)
                return true
            },
            beep: {
                await recorder.recordBeep()
            }
        )

        await player.playIfNeeded(for: .stub(title: "External", sourceAppBundleId: "com.apple.TextEdit"))

        let state = await recorder.snapshot()
        XCTAssertEqual(state.playedSoundNames, ["Submarine"])
        XCTAssertEqual(state.beepCount, 0)
    }

    func testPlayerFallsBackToBeepWhenSelectedSoundCannotPlay() async {
        let recorder = SoundPlaybackRecorder()
        let player = SystemClipboardSoundPlayer(
            currentBundleIdentifier: "com.bat.clipo",
            isSoundEnabled: { true },
            selectedSound: { .pop },
            playNamedSound: { name in
                await recorder.recordPlayedSound(name)
                return false
            },
            beep: {
                await recorder.recordBeep()
            }
        )

        await player.playIfNeeded(for: .stub(title: "External", sourceAppBundleId: "com.apple.TextEdit"))

        let state = await recorder.snapshot()
        XCTAssertEqual(state.playedSoundNames, ["Pop"])
        XCTAssertEqual(state.beepCount, 1)
    }

    func testPlayerSkipsItemsCopiedByClipoItself() async {
        let recorder = SoundPlaybackRecorder()
        let player = SystemClipboardSoundPlayer(
            currentBundleIdentifier: "com.bat.clipo",
            isSoundEnabled: { true },
            selectedSound: { .glass },
            playNamedSound: { name in
                await recorder.recordPlayedSound(name)
                return true
            },
            beep: {
                await recorder.recordBeep()
            }
        )

        await player.playIfNeeded(for: .stub(title: "Internal", sourceAppBundleId: "com.bat.clipo"))

        let state = await recorder.snapshot()
        XCTAssertEqual(state.playedSoundNames, [])
        XCTAssertEqual(state.beepCount, 0)
    }
}

actor SoundPlaybackRecorder {
    private(set) var playedSoundNames: [String] = []
    private(set) var beepCount = 0

    func recordPlayedSound(_ name: String) {
        playedSoundNames.append(name)
    }

    func recordBeep() {
        beepCount += 1
    }

    func snapshot() -> (playedSoundNames: [String], beepCount: Int) {
        (playedSoundNames, beepCount)
    }
}

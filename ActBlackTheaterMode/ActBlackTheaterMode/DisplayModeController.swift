import AppKit
import CoreGraphics

final class DisplayModeController {
    static let shared = DisplayModeController()

    private var activeDisplayID: CGDirectDisplayID?
    private var activeOriginalMode: CGDisplayMode?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func handleAppWillTerminate() {
        restoreActiveDisplayMode()
    }

    func activateIfNeeded(for screen: NSScreen) {
        guard TheaterPrefs.loadBool(PrefKey.displayModeEnabled, default: false) else { return }
        guard let displayID = screen.displayID else { return }
        guard let currentMode = CGDisplayCopyDisplayMode(displayID) else { return }

        // If we were already controlling a display mode, restore before switching again.
        if activeDisplayID != nil && activeDisplayID != displayID {
            restoreActiveDisplayMode()
        }

        let targetWidth = TheaterPrefs.loadInt(PrefKey.displayModeWidth, default: 1920)
        let targetHeight = TheaterPrefs.loadInt(PrefKey.displayModeHeight, default: 1080)
        let targetRefresh = TheaterPrefs.loadDouble(PrefKey.displayModeRefresh, default: 60.0)
        guard targetWidth > 0, targetHeight > 0 else { return }

        let currentWidth = currentMode.pixelWidth
        let currentHeight = currentMode.pixelHeight
        if currentWidth == targetWidth && currentHeight == targetHeight {
            activeDisplayID = displayID
            activeOriginalMode = currentMode
            savePendingRestore(displayID: displayID, mode: currentMode)
            return
        }

        guard let targetMode = bestMode(
            displayID: displayID,
            width: targetWidth,
            height: targetHeight,
            preferredRefresh: targetRefresh
        ) else {
            return
        }

        let result = CGDisplaySetDisplayMode(displayID, targetMode, nil)
        guard result == .success else { return }

        activeDisplayID = displayID
        activeOriginalMode = currentMode
        savePendingRestore(displayID: displayID, mode: currentMode)
    }

    func restoreActiveDisplayMode() {
        guard let displayID = activeDisplayID, let originalMode = activeOriginalMode else {
            restorePendingModeIfNeeded()
            return
        }

        let result = CGDisplaySetDisplayMode(displayID, originalMode, nil)
        if result == .success {
            clearPendingRestore()
        }

        activeDisplayID = nil
        activeOriginalMode = nil
    }

    func restorePendingModeIfNeeded() {
        guard TheaterPrefs.loadBool(PrefKey.displayModeRestorePending, default: false) else { return }

        let displayIDInt = TheaterPrefs.loadInt(PrefKey.displayModeOriginalDisplayID, default: 0)
        let width = TheaterPrefs.loadInt(PrefKey.displayModeOriginalWidth, default: 0)
        let height = TheaterPrefs.loadInt(PrefKey.displayModeOriginalHeight, default: 0)
        let refresh = TheaterPrefs.loadDouble(PrefKey.displayModeOriginalRefresh, default: 0.0)
        guard displayIDInt > 0, width > 0, height > 0 else { return }

        let displayID = CGDirectDisplayID(displayIDInt)
        guard let mode = findMode(
            displayID: displayID,
            width: width,
            height: height,
            refresh: refresh
        ) else { return }

        let result = CGDisplaySetDisplayMode(displayID, mode, nil)
        if result == .success {
            clearPendingRestore()
        }
    }

    private func savePendingRestore(displayID: CGDirectDisplayID, mode: CGDisplayMode) {
        TheaterPrefs.saveBool(PrefKey.displayModeRestorePending, true)
        TheaterPrefs.saveInt(PrefKey.displayModeOriginalDisplayID, Int(displayID))
        TheaterPrefs.saveInt(PrefKey.displayModeOriginalWidth, mode.pixelWidth)
        TheaterPrefs.saveInt(PrefKey.displayModeOriginalHeight, mode.pixelHeight)
        TheaterPrefs.saveDouble(PrefKey.displayModeOriginalRefresh, mode.refreshRate)
    }

    private func clearPendingRestore() {
        TheaterPrefs.saveBool(PrefKey.displayModeRestorePending, false)
    }

    private func bestMode(
        displayID: CGDirectDisplayID,
        width: Int,
        height: Int,
        preferredRefresh: Double
    ) -> CGDisplayMode? {
        let allModes = (CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode]) ?? []
        let exact = allModes.filter { $0.pixelWidth == width && $0.pixelHeight == height }
        if exact.isEmpty { return nil }

        if preferredRefresh > 0 {
            return exact.min { lhs, rhs in
                abs(lhs.refreshRate - preferredRefresh) < abs(rhs.refreshRate - preferredRefresh)
            }
        }

        return exact.max { lhs, rhs in
            lhs.refreshRate < rhs.refreshRate
        }
    }

    private func findMode(displayID: CGDirectDisplayID, width: Int, height: Int, refresh: Double) -> CGDisplayMode? {
        let allModes = (CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode]) ?? []
        let matchingSize = allModes.filter { $0.pixelWidth == width && $0.pixelHeight == height }
        guard !matchingSize.isEmpty else { return nil }

        if refresh <= 0 {
            return matchingSize.first
        }

        return matchingSize.min { lhs, rhs in
            abs(lhs.refreshRate - refresh) < abs(rhs.refreshRate - refresh)
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }
}

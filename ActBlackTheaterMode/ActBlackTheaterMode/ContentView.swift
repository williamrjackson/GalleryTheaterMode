import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Persistent Settings

private enum PrefKey {
    static let targetWidth = "theater.targetWidth"
    static let offsetY = "theater.offsetY"
}

private struct TheaterPrefs {
    static func loadInt(_ key: String, default def: Int) -> Int {
        let v = UserDefaults.standard.object(forKey: key) as? Int
        return v ?? def
    }
    static func loadBool(_ key: String, default def: Bool) -> Bool {
        let v = UserDefaults.standard.object(forKey: key) as? Bool
        return v ?? def
    }
    static func saveInt(_ key: String, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }
    static func saveBool(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

// MARK: - UI

struct ContentView: View {
    @State private var widthText: String = "\(TheaterPrefs.loadInt(PrefKey.targetWidth, default: 1600))"
    @State private var yText: String = "\(TheaterPrefs.loadInt(PrefKey.offsetY, default: 0))"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Theater Mode Player").font(.title2).bold()

            HStack(spacing: 12) {
                LabeledTextField(label: "Target Width", text: $widthText, width: 160)
                LabeledTextField(label: "Offset Y", text: $yText, width: 140)
                Spacer()
            }

            Button("Choose Video and Play") {
                chooseAndPlay()
            }
            .keyboardShortcut(.defaultAction)

            Text("""
            Playback Controls:
            
            Space = Play/Pause
            ← / → = Seek (Shift = 10s)
            ↑ / ↓ = Move Y (Shift = 50)
            Esc = Exit
            """)
                .foregroundStyle(.secondary)
                .font(.subheadline) // slightly larger than footnote
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 260)
    }

    private func chooseAndPlay() {
        let targetW = Int(widthText) ?? 1600
        let oy = Int(yText) ?? 0

        // Persist base settings
        TheaterPrefs.saveInt(PrefKey.targetWidth, targetW)
        TheaterPrefs.saveInt(PrefKey.offsetY, oy)

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            DispatchQueue.main.async {
                TheaterWindowController.present(
                    url: url,
                    targetWidth: CGFloat(targetW),
                    offsetY: CGFloat(oy)
                )
            }
        }
    }
}

private struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
        }
    }
}

// MARK: - Player Window

final class TheaterWindowController: NSWindowController {
    private var eventMonitor: Any?

    static func present(url: URL,
                        targetWidth: CGFloat,
                        offsetY: CGFloat) {
        // Prefer external display if present (projector is often last)
        let targetScreen = NSScreen.screens.last ?? NSScreen.main!
        let frame = targetScreen.frame

        let vc = TheaterPlayerViewController(
            url: url,
            screenFrame: frame,
            targetWidth: targetWidth,
            offsetY: offsetY
        )

        let win = KeyableBorderlessWindow(contentRect: frame,
                                         styleMask: [.borderless],
                                         backing: .buffered,
                                         defer: false,
                                         screen: targetScreen)

        win.level = .mainMenu + 2
        win.backgroundColor = .black
        win.isOpaque = true
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.contentViewController = vc
        win.makeKeyAndOrderFront(nil)
        win.makeMain()
        NSApp.activate(ignoringOtherApps: true)

        // Optional: defocus any text field in the config window
        NSApp.mainWindow?.makeFirstResponder(nil)

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let controller = TheaterWindowController(window: win)
        controller.showWindow(nil)

        controller.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // ESC closes
            if event.keyCode == 53 {
                win.close()
                return nil
            }

            // Space toggles play/pause
            if event.keyCode == 49 { // Space
                vc.togglePlayPause()
                return nil
            }

            // Arrow keys
            switch event.keyCode {
            case 126, 125: // Up / Down = adjust Y
                let bigStep: CGFloat = 50
                let smallStep: CGFloat = 10
                let step = event.modifierFlags.contains(.shift) ? bigStep : smallStep
                let delta: CGFloat = (event.keyCode == 126) ? step : -step
                vc.adjustOffsetY(by: delta)
                return nil

            case 124, 123: // Right / Left = seek
                let bigSeek: Double = 10.0
                let smallSeek: Double = 2.0
                let seek = event.modifierFlags.contains(.shift) ? bigSeek : smallSeek
                let delta: Double = (event.keyCode == 124) ? seek : -seek
                vc.seekBy(seconds: delta)
                return nil

            default:
                vc.pingOverlay()
                return nil
            }
        }


        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: win, queue: .main) { _ in
            if let mon = controller.eventMonitor {
                NSEvent.removeMonitor(mon)
                controller.eventMonitor = nil
            }
        }
    }
}

// MARK: - Player View Controller

final class TheaterPlayerViewController: NSViewController {
    private let url: URL
    private let screenFrame: CGRect
    private let targetWidth: CGFloat
    private var offsetY: CGFloat

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var endObserver: Any?
    private var overlayLayer: CATextLayer?
    private var overlayHideWorkItem: DispatchWorkItem?

    // Cached for repositioning
    private var targetHeight: CGFloat = 0

    init(url: URL,
         screenFrame: CGRect,
         targetWidth: CGFloat,
         offsetY: CGFloat) {
        self.url = url
        self.screenFrame = screenFrame
        self.targetWidth = targetWidth
        self.offsetY = offsetY
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func loadView() {
        self.view = NSView(frame: screenFrame)
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.black.cgColor
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        startPlayback()
    }

    func adjustOffsetY(by delta: CGFloat) {
        offsetY += delta
        TheaterPrefs.saveInt(PrefKey.offsetY, Int(offsetY.rounded()))
        repositionLayer()
    }

    private func startPlayback() {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        let p = AVPlayer(playerItem: item)
        self.player = p

        let layer = AVPlayerLayer(player: p)
        layer.videoGravity = .resizeAspect
        self.playerLayer = layer
        
        // Determine natural size safely
        var videoSize = CGSize(width: 1920, height: 1080)
        if let track = asset.tracks(withMediaType: .video).first {
            let transformed = track.naturalSize.applying(track.preferredTransform)
            videoSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        }

        let aspect = videoSize.height / max(videoSize.width, 1)
        targetHeight = targetWidth * aspect

        layer.frame = computeLayerFrame()
        self.view.layer?.addSublayer(layer)
        
        setupOverlayIfNeeded()
        pingOverlay() // show once at start

        p.play()
    }
    
    private func setupOverlayIfNeeded() {
        guard overlayLayer == nil else { return }
        guard let root = self.view.layer else { return }

        let text = """
        Controls:
        Space  = Play/Pause
        ← / →  = Seek 2s   (Shift = 10s)
        ↑ / ↓  = Move Y 10 (Shift = 50)
        Esc    = Exit
        """

        let tl = CATextLayer()
        tl.string = text
        tl.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        tl.fontSize = 16
        tl.alignmentMode = .left
        tl.isWrapped = true
        tl.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

        // Styling
        tl.foregroundColor = NSColor(white: 1.0, alpha: 0.92).cgColor
        tl.backgroundColor = NSColor(white: 0.0, alpha: 0.55).cgColor
        tl.cornerRadius = 12
        tl.masksToBounds = true

        // Layout: bottom-left with padding
        // (CATextLayer doesn't auto-size nicely; give it a sane box)
        let padding: CGFloat = 24
        let boxW: CGFloat = 520
        let boxH: CGFloat = 150
        tl.frame = CGRect(x: padding, y: padding, width: boxW, height: boxH)

        // Start hidden
        tl.opacity = 0.0

        root.addSublayer(tl)
        overlayLayer = tl
    }

    func pingOverlay() {
        guard let tl = overlayLayer else { return }

        // Cancel pending hide
        overlayHideWorkItem?.cancel()
        overlayHideWorkItem = nil

        // Show immediately (no implicit animations)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tl.opacity = 1.0
        CATransaction.commit()

        // Schedule fade-out
        let work = DispatchWorkItem { [weak self] in
            self?.fadeOverlay()
        }
        overlayHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    private func fadeOverlay() {
        guard let tl = overlayLayer else { return }

        // Animate opacity down
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = tl.presentation()?.opacity ?? tl.opacity
        anim.toValue = 0.0
        anim.duration = 0.5
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        tl.add(anim, forKey: "fadeOpacity")

        // Set final state (disable implicit animations)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tl.opacity = 0.0
        CATransaction.commit()
    }

    private func repositionLayer() {
        guard let layer = playerLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true) // no implicit animation
        layer.frame = computeLayerFrame()
        CATransaction.commit()
    }

    private func computeLayerFrame() -> CGRect {
        // Center on screen; no X offset (always centered)
        let center = CGPoint(x: screenFrame.midX, y: screenFrame.midY)

        let originOnScreen = CGPoint(
            x: center.x - targetWidth / 2,
            y: center.y - targetHeight / 2 + offsetY
        )

        // Convert to window-local coordinates
        let originInWindow = CGPoint(
            x: originOnScreen.x - screenFrame.origin.x,
            y: originOnScreen.y - screenFrame.origin.y
        )

        return CGRect(origin: originInWindow, size: CGSize(width: targetWidth, height: targetHeight))
    }
    func togglePlayPause() {
        guard let p = player else { return }
        if p.timeControlStatus == .playing {
            p.pause()
        } else {
            p.play()
        }
    }

    func seekBy(seconds delta: Double) {
        guard let p = player, let item = p.currentItem else { return }

        let current = p.currentTime()
        let currentSeconds = CMTimeGetSeconds(current)
        if !currentSeconds.isFinite { return }

        let durationSeconds = CMTimeGetSeconds(item.duration)
        let hasDuration = durationSeconds.isFinite && durationSeconds > 0

        var newSeconds = currentSeconds + delta
        if hasDuration {
            newSeconds = max(0, min(durationSeconds, newSeconds))
        } else {
            newSeconds = max(0, newSeconds)
        }

        let newTime = CMTime(seconds: newSeconds, preferredTimescale: 600)
        p.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        player?.pause()
    }
}
final class KeyableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

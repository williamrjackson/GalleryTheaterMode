import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

// MARK: - UI
struct ContentView: View {
    @State private var widthText: String = "\(TheaterPrefs.loadInt(PrefKey.targetWidth))"
    @State private var yText: String = "\(TheaterPrefs.loadInt(PrefKey.offsetY))"
    @State private var bgColor: NSColor = TheaterPrefs.loadColor(
        r: PrefKey.bgColorR, g: PrefKey.bgColorG, b: PrefKey.bgColorB, a: PrefKey.bgColorA)
    @State private var rectColor: NSColor = TheaterPrefs.loadColor(
        r: PrefKey.rectColorR, g: PrefKey.rectColorG, b: PrefKey.rectColorB, a: PrefKey.rectColorA)

    // Session-only placeholder image (no persistence)
    @State private var placeholderImageURL: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Theater Mode Player").font(.title2).bold()

            HStack(spacing: 12) {
                LabeledTextField(label: "Target Width", text: $widthText, width: 160)
                LabeledTextField(label: "Offset Y", text: $yText, width: 140)
                Spacer()
            }
            .onReceive(NotificationCenter.default.publisher(for: .theaterOffsetYDidChange)) { _ in
                yText = "\(TheaterPrefs.loadInt(PrefKey.offsetY, default: 0))"
            }
            .onReceive(NotificationCenter.default.publisher(for: .theaterTargetWidthDidChange)) { _ in
                widthText = "\(TheaterPrefs.loadInt(PrefKey.targetWidth, default: 1600))"
            }

            HStack(spacing: 18) {
                Text("Ready State:").font(.headline)
                ColorPicker("Background", selection: Binding(
                    get: { Color(nsColor: bgColor) },
                    set: { newVal in bgColor = NSColor(newVal) }
                ))
                .frame(width: 220)

                ColorPicker("Screen", selection: Binding(
                    get: { Color(nsColor: rectColor) },
                    set: { newVal in rectColor = NSColor(newVal) }
                ))
                .frame(width: 220)

                Spacer()
            }

            // Placeholder image: session-only, always Fit, no checkbox
            HStack(spacing: 10) {
                Button("Choose Placeholder Image…") {
                    choosePlaceholderImage()
                }

                Text("Placeholder Image:")
                    .foregroundStyle(.secondary)

                Text(placeholderImageURL?.lastPathComponent ?? "None")
                    .font(.callout)
                    .foregroundStyle(placeholderImageURL == nil ? .secondary : .primary)

                Spacer()
            }
            Spacer()
            Spacer()
            Button("Load Video File") {
                chooseAndPlay()
            }.frame(maxWidth: .infinity, alignment: .center)
            .keyboardShortcut(.defaultAction)
            Spacer()
            HStack(spacing: 20) {
                VStack() {
                    Text("Ready State Controls:")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("""
                Space = Start Presentation
                ← / → = Width
                ↑ / ↓ = Position
                Arrow Key Modifiers: Shift: more; Option: less
                """)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                }

                VStack() {
                    Text("Playback Controls:")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("""
                Space = Play/Pause
                ← / → = Seek 3 sec (Shift: 10 sec) (Option: 1 frame)
                ↑ / ↓ = Seek 1 min (Shift:  5 min) (Option:  30 sec)
                Esc   = Exit
                """)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                }
            }
        }
        .padding(16)
        .fixedSize()
    }

    private func choosePlaceholderImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                placeholderImageURL = url
            }
        }
    }

    private func chooseAndPlay() {
        let targetW = Int(widthText) ?? 1600
        let oy = Int(yText) ?? 0
        
        // Persist base settings
        TheaterPrefs.saveInt(PrefKey.targetWidth, targetW)
        TheaterPrefs.saveInt(PrefKey.offsetY, oy)
        TheaterPrefs.saveColor(
            bgColor, r: PrefKey.bgColorR, g: PrefKey.bgColorG, b: PrefKey.bgColorB, a: PrefKey.bgColorA)
        TheaterPrefs.saveColor(
            rectColor, r: PrefKey.rectColorR, g: PrefKey.rectColorG, b: PrefKey.rectColorB, a: PrefKey.rectColorA)
        
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
                    offsetY: CGFloat(oy),
                    backgroundColor: bgColor,
                    rectColor: rectColor,
                    placeholderImagePath: placeholderImageURL?.path,
                    placeholderImageMode: "fit"
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
                        offsetY: CGFloat,
                        backgroundColor: NSColor,
                        rectColor: NSColor,
                        placeholderImagePath: String?,
                        placeholderImageMode: String) {
        // Prefer external display if present (projector is often last)
        let targetScreen = NSScreen.screens.last ?? NSScreen.main!
        let frame = targetScreen.frame

        let vc = TheaterPlayerViewController(
            url: url,
            screenFrame: frame,
            targetWidth: targetWidth,
            offsetY: offsetY,
            backgroundColor: backgroundColor,
            rectColor: rectColor,
            placeholderImagePath: placeholderImagePath,
            placeholderImageMode: placeholderImageMode
        )

        let win = KeyableBorderlessWindow(contentRect: frame,
                                         styleMask: [.borderless],
                                         backing: .buffered,
                                         defer: false,
                                         screen: targetScreen)

        win.level = .mainMenu + 2
        win.backgroundColor = backgroundColor
        win.isOpaque = true
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.contentViewController = vc

        win.makeKeyAndOrderFront(nil)
        win.makeMain()
        NSApp.activate(ignoringOtherApps: true)

        // Defocus any text field in the config window (prevents typing behind)
        NSApp.mainWindow?.makeFirstResponder(nil)

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let controller = TheaterWindowController(window: win)
        controller.showWindow(nil)

        // Hide cursor in theater mode
        NSCursor.hide()

        controller.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // ESC closes
            if event.keyCode == 53 {
                win.close()
                return nil
            }

            // Space toggles play/pause (first press triggers intro transition)
            if event.keyCode == 49 {
                vc.togglePlayPause()
                return nil
            }

            // Arrow keys
            switch event.keyCode {
            case 126, 125: // Up / Down = adjust Y; Big seek during playback
                if vc.isInReadyMode {
                    let bigStep: CGFloat = 50
                    let smallStep: CGFloat = 10
                    let tinyStep: CGFloat = 1
                    var step = smallStep
                    if (event.modifierFlags.contains(.option)) {
                        step = tinyStep
                    } else if (event.modifierFlags.contains(.shift)) {
                        step = bigStep
                    }
                    let delta: CGFloat = (event.keyCode == 126) ? step : -step
                    vc.adjustOffsetY(by: delta)
                }
                else {
                    let bigSeek: Double = 300.0
                    let smallSeek: Double = 60.0
                    let tinySeek: Double = 30.0
                    var seek = smallSeek
                    if (event.modifierFlags.contains(.option)) {
                        seek = tinySeek
                    } else if (event.modifierFlags.contains(.shift)) {
                        seek = bigSeek
                    }
                    let delta: Double = (event.keyCode == 124) ? seek : -seek
                    vc.seekBy(seconds: delta)
                }
                return nil


            case 124, 123: // Right / Left
                if vc.isInReadyMode {
                    let bigStep: CGFloat = 100
                    let smallStep: CGFloat = 20
                    let tinyStep: CGFloat = 1
                    var step = smallStep
                    if (event.modifierFlags.contains(.option)) {
                        step = tinyStep
                    } else if (event.modifierFlags.contains(.shift)) {
                        step = bigStep
                    }
                    let delta: CGFloat = (event.keyCode == 124) ? step : -step
                    vc.adjustTargetWidth(by: delta)
                } else {
                    if event.modifierFlags.contains(.option) {
                        let direction = (event.keyCode == 124) ? 1 : -1
                        vc.pause()
                        vc.seekByFrames(direction)
                    } else {
                        let bigSeek: Double = 10.0
                        let smallSeek: Double = 3.0
                        let seek = event.modifierFlags.contains(.shift) ? bigSeek : smallSeek
                        let delta: Double = (event.keyCode == 124) ? seek : -seek
                        vc.seekBy(seconds: delta)
                    }
                }
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

            // Always restore cursor, even if window closed not via ESC
            NSCursor.unhide()

            // Ensure config UI reflects latest value when theater closes
            NotificationCenter.default.post(name: .theaterOffsetYDidChange, object: nil)
        }
    }
}

// MARK: - Player View Controller

final class TheaterPlayerViewController: NSViewController {
    private let url: URL
    private let screenFrame: CGRect
    private var targetWidth: CGFloat
    private var targetHeight: CGFloat = 0
    private var videoAspect: CGFloat = 9.0 / 16.0 // height/width fallback
    private let backgroundColor: NSColor
    private let rectColor: NSColor

    private let placeholderImagePath: String?
    private let placeholderImageMode: String

    private var placeholderLayer: CALayer?
    private var placeholderImageLayer: CALayer?

    private var hasStartedPlayback = false
    private var offsetY: CGFloat

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?

    private var overlayLayer: CATextLayer?
    private var overlayHideWorkItem: DispatchWorkItem?

    init(url: URL,
         screenFrame: CGRect,
         targetWidth: CGFloat,
         offsetY: CGFloat,
         backgroundColor: NSColor,
         rectColor: NSColor,
         placeholderImagePath: String?,
         placeholderImageMode: String) {

        self.url = url
        self.screenFrame = screenFrame
        self.targetWidth = targetWidth
        self.offsetY = offsetY
        self.backgroundColor = backgroundColor
        self.rectColor = rectColor
        self.placeholderImagePath = placeholderImagePath
        self.placeholderImageMode = placeholderImageMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    var isInReadyMode: Bool { !hasStartedPlayback }

    override func loadView() {
        self.view = NSView(frame: screenFrame)
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = backgroundColor.cgColor
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        startPlayback()
    }

    func adjustOffsetY(by delta: CGFloat) {
        offsetY += delta
        TheaterPrefs.saveInt(PrefKey.offsetY, Int(offsetY.rounded()))
        repositionLayers()
        NotificationCenter.default.post(name: .theaterOffsetYDidChange, object: nil)
    }
    
    func adjustTargetWidth(by delta: CGFloat) {
        // Only allow width changes before playback starts
        guard !hasStartedPlayback else { return }

        targetWidth = max(100, targetWidth + delta)  // clamp to something sane
        targetHeight = max(1, targetWidth * videoAspect)

        TheaterPrefs.saveInt(PrefKey.targetWidth, Int(targetWidth.rounded()))
        repositionLayers()

        NotificationCenter.default.post(name: .theaterTargetWidthDidChange, object: nil)
    }

    private func repositionLayers() {
        let newFrame = computeLayerFrame()
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        playerLayer?.frame = newFrame
        placeholderLayer?.frame = newFrame
        placeholderImageLayer?.frame = placeholderLayer?.bounds ?? .zero
        
        CATransaction.commit()
    }
    
    // MARK: - Intro Transition (series)
    // Fade background + placeholder for d1, then fade player in for d2, then play.
    private func runInitialTransition() {
        let d1: CFTimeInterval = 2.0
        let d2: CFTimeInterval = 2.0

        fadeBackgroundToBlack(duration: d1)
        fadeFromPlaceholder(duration: d1)

        fadePlayerIn(after: d1, duration: d2)

        DispatchQueue.main.asyncAfter(deadline: .now() + d1 + d2) { [weak self] in
            self?.player?.play()
        }
    }

    private func fadePlayerIn(after delay: CFTimeInterval, duration: CFTimeInterval) {
        guard let pl = playerLayer else { return }

        pl.removeAnimation(forKey: "playerIn")

        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = pl.presentation()?.opacity ?? pl.opacity
        anim.toValue = 1.0
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.beginTime = CACurrentMediaTime() + delay
        anim.fillMode = .both
        anim.isRemovedOnCompletion = true

        pl.add(anim, forKey: "playerIn")

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pl.opacity = 1.0
        CATransaction.commit()
    }

    private func fadeBackgroundToBlack(duration: CFTimeInterval = 3.0) {
        guard let root = self.view.layer else { return }

        // Kill any previous background animation so they don't fight.
        root.removeAnimation(forKey: "bgToBlack")

        let from = root.presentation()?.backgroundColor ?? root.backgroundColor ?? NSColor.black.cgColor
        let to = NSColor.black.cgColor

        let anim = CABasicAnimation(keyPath: "backgroundColor")
        anim.fromValue = from
        anim.toValue = to
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.beginTime = CACurrentMediaTime()
        anim.isRemovedOnCompletion = true

        root.add(anim, forKey: "bgToBlack")

        // Set final model value without implicit animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.backgroundColor = to
        CATransaction.commit()
    }

    private func fadeFromPlaceholder(duration: CFTimeInterval = 3.0) {
        guard let layer = placeholderLayer else { return }

        layer.removeAnimation(forKey: "placeholderFade")

        let from = layer.presentation()?.opacity ?? layer.opacity
        
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = from
        anim.toValue = 0.0
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.beginTime = CACurrentMediaTime()
        anim.isRemovedOnCompletion = true

        layer.add(anim, forKey: "placeholderFade")

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = 0.0
        CATransaction.commit()
    }

    private func startPlayback() {
        guard let root = self.view.layer else { return }

        // 1) Set background immediately so you can at least see *something*
        root.backgroundColor = backgroundColor.cgColor

        // 2) Build asset + determine video size (with a sane fallback)
        let asset = AVURLAsset(url: url)

        var videoSize = CGSize(width: 1920, height: 1080) // fallback
        if let track = asset.tracks(withMediaType: .video).first {
            let transformed = track.naturalSize.applying(track.preferredTransform)
            videoSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        }

        let aspect = videoSize.height / max(videoSize.width, 1)
        videoAspect = aspect
        targetHeight = max(1, targetWidth * aspect)

        // 3) Create player + layer (but keep hidden for preview)
        let item = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: item)
        self.player = p

        let pl = AVPlayerLayer(player: p)
        pl.videoGravity = .resizeAspect
        pl.opacity = 0.0
        self.playerLayer = pl

        // 4) Create placeholder rectangle
        let rect = CALayer()
        rect.backgroundColor = rectColor.cgColor
        rect.cornerRadius = 0
        rect.opacity = 1.0
        rect.masksToBounds = true
        self.placeholderLayer = rect

        // 5) Compute frame now that targetHeight is valid
        let f = computeLayerFrame()
        pl.frame = f
        rect.frame = f

        // Ensure placeholder is on top
        pl.zPosition = 0
        rect.zPosition = 1

        // 6) Add sublayers (order matters visually)
        root.addSublayer(pl)
        root.addSublayer(rect)

        // 7) Pause at start (don’t show first frame yet)
        // Optional placeholder image inside rect
        if let path = placeholderImagePath, !path.isEmpty,
           let nsImage = NSImage(contentsOfFile: path),
           let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {

            let imgLayer = CALayer()
            imgLayer.frame = rect.bounds
            imgLayer.contents = cg
            imgLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            imgLayer.contentsGravity = (placeholderImageMode == "fill") ? .resizeAspectFill : .resizeAspect
            imgLayer.masksToBounds = true

            rect.addSublayer(imgLayer)
            self.placeholderImageLayer = imgLayer
        }

        // Start paused at t=0 (no first frame shown since player layer is hidden)
        p.seek(to: .zero)
        p.pause()

        setupOverlayIfNeeded()
        pingOverlay()
    }

    private func setupOverlayIfNeeded() {
        guard overlayLayer == nil else { return }
        guard let root = self.view.layer else { return }

        let text = """
        Ready Mode Controls:                                                    Playback Controls:
        Space  = Start Presentation                                             Space  = Play/Pause
        ← / →  = Width                                                          ← / →  = Seek 3 sec   (Shift = 10 sec)   (Option = 1 frame)
        ↑ / ↓  = Position                                                       ↑ / ↓  = Seek 1 min   (Shift = 5 min)    (Option = 30 sec)
        Arrow Key Modifiers: Shift = more; Option = less                        Esc    = Exit
        """

        let tl = CATextLayer()
        tl.string = text
        tl.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        tl.fontSize = 16
        tl.alignmentMode = .left
        tl.isWrapped = false
        tl.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

        // Styling
        tl.foregroundColor = NSColor(white: 1.0, alpha: 0.92).cgColor
        tl.backgroundColor = NSColor(white: 0.0, alpha: 0.55).cgColor
        tl.cornerRadius = 12
        tl.masksToBounds = true

        // Layout: bottom full width with padding
        let padding: CGFloat = 24
        let boxH: CGFloat = 150
        let viewWidth = self.view.bounds.width
        let boxW = max(200, viewWidth - (padding * 2))
        
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

        if !hasStartedPlayback {
            hasStartedPlayback = true

            // Fade background to black over 1 second (linear)
            runInitialTransition()
            return
        }

        if p.timeControlStatus == .playing {
            p.pause()
        } else {
            p.play()
        }
    }
    func pause() {
        guard let p = player else { return }
        
        if p.timeControlStatus == .playing {
            p.pause()
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
    
    func seekByFrames(_ frameCount: Int) {
        guard let player = player,
              let item = player.currentItem,
              let track = item.asset.tracks(withMediaType: .video).first
        else { return }

        let fps = track.nominalFrameRate
        guard fps > 0 else { return }

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        let current = player.currentTime()
        let delta = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
        let newTime = CMTimeAdd(current, delta)

        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        player?.pause()
        overlayHideWorkItem?.cancel()
        overlayHideWorkItem = nil
    }
}

final class KeyableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

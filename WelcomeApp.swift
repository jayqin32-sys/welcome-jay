import AppKit
import QuartzCore
import ServiceManagement

private let chatGPTID = "com.openai.codex"
private func frameForWindow(_ pid: pid_t) -> CGRect? {
    guard let screens = NSScreen.screens.first,
          let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                   kCGNullWindowID) as? [[String: Any]] else { return nil }
    for window in windows {
        guard window[kCGWindowOwnerPID as String] as? Int == Int(pid),
              window[kCGWindowLayer as String] as? Int == 0,
              let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: dictionary),
              frame.width >= 300, frame.height >= 240 else { continue }
        return CGRect(x: frame.minX, y: screens.frame.maxY - frame.maxY,
                      width: frame.width, height: frame.height)
    }
    return nil
}

private final class SceneView: NSView {
    var elapsed: Double = 0
    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: bounds, cornerWidth: 11, cornerHeight: 11, transform: nil))
        ctx.clip()
        drawScene(ctx, size: bounds.size, time: elapsed, live: true)
        ctx.restoreGState()
    }
}

private final class WelcomeController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var panel: NSPanel?
    private var view: SceneView?
    private var tickTimer: Timer?
    private var statusItem: NSStatusItem?
    private var observers: [NSObjectProtocol] = []
    private var playbackID = 0
    private var knownProcesses: Set<pid_t> = []
    private let workspace = NSWorkspace.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        knownProcesses = Set(workspace.runningApplications
            .filter { $0.bundleIdentifier == chatGPTID }.map(\.processIdentifier))
        let center = workspace.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == chatGPTID,
                  self.knownProcesses.insert(app.processIdentifier).inserted else { return }
            self.cancel()
            self.findWindow(for: app, id: self.playbackID, deadline: CACurrentMediaTime() + 14)
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == chatGPTID else { return }
            self?.knownProcesses.remove(app.processIdentifier)
        })
    }

    private func buildMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Welcome Jay")
            button.toolTip = "Welcome Jay"
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(NSMenuItem(title: "仅在 ChatGPT 完全退出后重开时播放", action: nil, keyEquivalent: ""))
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if service.status == .requiresApproval {
                addItem("打开登录项设置", #selector(openLoginSettings), to: menu)
            } else {
                addItem("登录后自动运行", #selector(toggleLogin), to: menu)
                menu.items.last?.state = service.status == .enabled ? .on : .off
            }
        }
        menu.addItem(.separator())
        addItem("退出 Welcome Jay", #selector(quit), to: menu)
    }

    private func addItem(_ title: String, _ action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func openLoginSettings() {
        if #available(macOS 13.0, *) { SMAppService.openSystemSettingsLoginItems() }
    }

    @objc private func toggleLogin() {
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.mainApp
                if service.status == .enabled { try service.unregister() }
                else { try service.register() }
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }

    private func findWindow(for app: NSRunningApplication, id: Int, deadline: Double) {
        guard id == playbackID, !app.isTerminated, CACurrentMediaTime() < deadline else { return }
        let pid = app.processIdentifier
        if workspace.frontmostApplication?.processIdentifier == pid,
           let frame = frameForWindow(pid) {
            show(at: frame, pid: pid)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.067) { [weak self] in
            self?.findWindow(for: app, id: id, deadline: deadline)
        }
    }

    private func cancel() {
        playbackID += 1
        tickTimer?.invalidate()
        tickTimer = nil
        panel?.orderOut(nil)
        panel = nil
        view = nil
    }

    private func show(at frame: CGRect, pid: pid_t) {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false

        let canvas = SceneView(frame: CGRect(origin: .zero, size: frame.size))
        canvas.autoresizingMask = [.width, .height]
        panel.contentView = canvas
        self.panel = panel
        view = canvas
        panel.orderFrontRegardless()

        let start = CACurrentMediaTime()
        var lastGeometry = start
        let timer = Timer(timeInterval: 1 / 60.0, repeats: true) { [weak self, weak panel, weak canvas] _ in
            guard let self, let panel, let canvas else { return }
            let now = CACurrentMediaTime()
            if now - start >= filmDuration { self.cancel(); return }
            if now - lastGeometry > 0.045 {
                lastGeometry = now
                guard self.workspace.frontmostApplication?.processIdentifier == pid,
                      let frame = frameForWindow(pid) else { self.cancel(); return }
                if frame != panel.frame { panel.setFrame(frame, display: false) }
            }
            canvas.elapsed = now - start
            canvas.needsDisplay = true
        }
        tickTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

@main
private struct Entry {
    static func main() {
        let app = NSApplication.shared
        _ = app.setActivationPolicy(.accessory)
        let controller = WelcomeController()
        app.delegate = controller
        withExtendedLifetime(controller) { app.run() }
    }
}

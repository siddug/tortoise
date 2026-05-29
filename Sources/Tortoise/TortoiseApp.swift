import AppKit
import SwiftUI

@main
struct TortoiseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = TortoiseModel()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = AppIconProvider.appIconImage

        statusItemController = StatusItemController(model: model)
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}

enum AppIconProvider {
    static var appIconImage: NSImage {
        let side: CGFloat = 256
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: image.size)
        let background = NSBezierPath(roundedRect: rect, xRadius: 56, yRadius: 56)
        NSColor(calibratedRed: 0.92, green: 0.94, blue: 0.87, alpha: 1).setFill()
        background.fill()

        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 6, dy: 6), xRadius: 52, yRadius: 52)
        border.lineWidth = 6
        NSColor(calibratedRed: 0.34, green: 0.37, blue: 0.28, alpha: 1).setStroke()
        border.stroke()

        TortoiseArtwork.drawIcon(in: NSRect(x: 34, y: 58, width: 188, height: 140))

        image.unlockFocus()
        return image
    }
}

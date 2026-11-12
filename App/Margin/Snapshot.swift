import AppKit
import SwiftUI

/// `Margin --snapshot <out.png> [--after <seconds>]` renders the main window offscreen to a PNG and quits.
/// Used for docs/README images and for verifying UI without screen-recording permission.
enum Snapshot {
    static var request: (url: URL, delay: Double)? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return nil }
        var delay = 1.5
        if let j = args.firstIndex(of: "--after"), j + 1 < args.count, let d = Double(args[j + 1]) { delay = d }
        return (URL(fileURLWithPath: args[i + 1]), delay)
    }

    @MainActor
    static func run(library: LibraryModel, to url: URL, after delay: Double) {
        let size = NSSize(width: 1100, height: 680)
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -10_000, y: -10_000), size: size),
            styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false
        )
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView: LibraryView().environment(library))
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            exit(0)
        }
    }
}

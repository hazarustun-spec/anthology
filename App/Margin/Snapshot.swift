import AppKit
import SwiftUI

/// `Margin --snapshot <out.png> [--after <seconds>]` renders the main window offscreen to a PNG and quits.
/// Used for docs/README images and for verifying UI without screen-recording permission.
enum Snapshot {
    static var request: (url: URL, delay: Double)? {
        #if !DEBUG
        return nil
        #endif
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
        let args = ProcessInfo.processInfo.arguments
        window.appearance = NSAppearance(named: args.contains("--light") ? .aqua : .darkAqua)
        if let i = args.firstIndex(of: "--note"), i + 1 < args.count { library.open(noteID: args[i + 1]) }
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        let lock = AppLock()
        if let tab = value("--settings") {
            UserDefaults.standard.set(Int(tab) ?? 0, forKey: "settingsTab")
            window.setContentSize(NSSize(width: 560, height: 600))
            window.contentView = NSHostingView(rootView: SettingsView().environment(library).environment(lock))
        } else if let step = value("--onboarding") {
            window.setContentSize(NSSize(width: 720, height: 520))
            window.contentView = NSHostingView(rootView: OnboardingView(startStep: Int(step) ?? 0).environment(lock))
        } else if let q = value("--search") {
            window.setContentSize(NSSize(width: 700, height: 520))
            window.contentView = NSHostingView(rootView:
                SearchPalette(isPresented: .constant(true), query: q).environment(library).padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color(palette: Palette.canvas)))
        } else if args.contains("--capture") {
            window.setContentSize(NSSize(width: 600, height: 230))
            window.contentView = NSHostingView(rootView: QuickCaptureView(library: library, dismiss: {}).padding(20).background(Color(palette: Palette.canvas)))
        } else {
            window.contentView = NSHostingView(rootView: LibraryView(snapshotLayout: true).environment(library).environment(lock))
        }
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            exit(0)
        }
    }
}

import Foundation
import MarginCore

/// Picks the notes folder: Anthology's iCloud Drive container when available, else a local folder.
/// On the Mac, notes saved before iCloud was enabled are moved into iCloud once.
enum RootResolver {
    enum Location: Equatable { case iCloud, local }

    static func resolve() -> (URL, Location) {
        if let env = ProcessInfo.processInfo.environment["MARGIN_ROOT"], !env.isEmpty {
            return (URL(fileURLWithPath: env, isDirectory: true), .local)
        }
        guard let cloud = MarginPaths.iCloudRoot() else { return (MarginPaths.localRoot, .local) }
        try? FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        #if os(macOS)
        migrateIfNeeded(from: MarginPaths.localRoot, to: cloud)
        MarginPaths.recordRoot(cloud)
        #endif
        return (cloud, .iCloud)
    }

    /// Copies topics into iCloud only when iCloud has none yet; the old folder is kept, renamed.
    static func migrateIfNeeded(from local: URL, to cloud: URL) {
        let fm = FileManager.default
        func topics(_ url: URL) -> [String] {
            ((try? fm.contentsOfDirectory(atPath: url.path)) ?? []).filter {
                fm.fileExists(atPath: url.appendingPathComponent("\($0)/_topic.json").path)
            }
        }
        let localTopics = topics(local)
        guard !localTopics.isEmpty, topics(cloud).isEmpty else { return }
        do {
            for name in (try fm.contentsOfDirectory(atPath: local.path)) where name != ".margin.lock" {
                let dest = cloud.appendingPathComponent(name)
                if !fm.fileExists(atPath: dest.path) { try fm.copyItem(at: local.appendingPathComponent(name), to: dest) }
            }
            guard Set(topics(cloud)).isSuperset(of: localTopics) else { return }
            let stamp = Date().formatted(.iso8601.year().month().day())
            try fm.moveItem(at: local, to: local.deletingLastPathComponent().appendingPathComponent("Notes (moved to iCloud \(stamp))"))
        } catch {
            NSLog("Anthology: iCloud migration skipped: \(error)")
        }
    }
}

/// Keeps iCloud placeholders downloaded so every note is readable offline.
@MainActor
final class ICloudDownloader: NSObject {
    static let shared = ICloudDownloader()
    private let query = NSMetadataQuery()
    var onChange: (() -> Void)?

    func start() {
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: .NSMetadataQueryDidUpdate, object: query)
        query.start()
    }

    @objc private func update() {
        query.disableUpdates()
        for case let item as NSMetadataItem in query.results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            if status != NSMetadataUbiquitousItemDownloadingStatusCurrent {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
        }
        query.enableUpdates()
        onChange?()
    }
}

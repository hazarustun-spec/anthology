import Foundation

public enum MarginPaths {
    /// The app's iCloud container id comes from its Info.plist (`MarginICloudContainer`), set per build.
    public static var iCloudContainerID: String? {
        Bundle.main.object(forInfoDictionaryKey: "MarginICloudContainer") as? String
    }

    /// The app's iCloud Documents folder via the entitlement (apps only; nil without iCloud).
    public static func iCloudRoot() -> URL? {
        guard let id = iCloudContainerID else { return nil }
        return FileManager.default.url(forUbiquityContainerIdentifier: id)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    /// Where the Mac app records the notes folder it uses, so margin-mcp (no entitlements) finds it.
    public static var rootPointer: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/Margin/notes-root")
    }

    public static func recordRoot(_ url: URL) {
        try? FileManager.default.createDirectory(at: rootPointer.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? url.path.write(to: rootPointer, atomically: true, encoding: .utf8)
    }

    /// Notes folder used before iCloud was enabled.
    public static var localRoot: URL {
        #if os(macOS)
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/Margin/Notes", isDirectory: true)
        #else
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Notes", isDirectory: true)
        #endif
    }

    /// Where notes live. `MARGIN_ROOT` wins; then the app's iCloud container if it exists;
    /// otherwise a local Application Support folder (pre-iCloud builds).
    public static func defaultRoot(env: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let custom = env["MARGIN_ROOT"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        if let recorded = try? String(contentsOf: rootPointer, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !recorded.isEmpty, FileManager.default.fileExists(atPath: recorded) {
            return URL(fileURLWithPath: recorded, isDirectory: true)
        }
        return localRoot
    }
}

import Foundation

public enum MarginPaths {
    public static let bundleID = "com.marginnotes.Margin"
    public static let iCloudContainerID = "iCloud.com.marginnotes.Margin"
    public static let iCloudContainerFolder = "iCloud~com~marginnotes~Margin"

    /// The app's iCloud Documents folder via the entitlement (apps only; returns nil without iCloud).
    /// Call off the main thread: the first call may take a while.
    public static func iCloudRoot() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID)?
            .appendingPathComponent("Documents", isDirectory: true)
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
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let iCloud = home.appendingPathComponent("Library/Mobile Documents/\(iCloudContainerFolder)/Documents", isDirectory: true)
        if FileManager.default.fileExists(atPath: iCloud.path) { return iCloud }
        return home.appendingPathComponent("Library/Application Support/Margin/Notes", isDirectory: true)
    }
}

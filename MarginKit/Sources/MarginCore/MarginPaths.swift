import Foundation

public enum MarginPaths {
    public static let bundleID = "com.marginnotes.Margin"
    public static let iCloudContainerFolder = "iCloud~com~marginnotes~Margin"

    /// Where notes live. `MARGIN_ROOT` wins; then the app's iCloud container if it exists;
    /// otherwise a local Application Support folder (pre-iCloud builds).
    public static func defaultRoot(env: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let custom = env["MARGIN_ROOT"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let iCloud = home.appendingPathComponent("Library/Mobile Documents/\(iCloudContainerFolder)/Documents", isDirectory: true)
        if FileManager.default.fileExists(atPath: iCloud.path) { return iCloud }
        return home.appendingPathComponent("Library/Application Support/Margin/Notes", isDirectory: true)
    }
}

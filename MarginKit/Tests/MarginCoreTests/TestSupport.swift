import Foundation
@testable import MarginCore

func tempRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("margin-tests-\(UUID().uuidString)", isDirectory: true)
}

func makeStore() throws -> MarginStore {
    try MarginStore(root: tempRoot())
}

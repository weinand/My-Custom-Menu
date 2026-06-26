// Loads, validates, and saves menu configuration from Application Support.
import Foundation

final class MenuStore: ObservableObject {
    @Published var configuration: MenuConfiguration = .default
    @Published private(set) var lastLoadErrorMessage: String?

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private func describeCodingPath(_ path: [CodingKey]) -> String {
        if path.isEmpty {
            return "<root>"
        }

        return path.map { key in
            if let intValue = key.intValue {
                return "[\(intValue)]"
            }

            return key.stringValue
        }.joined(separator: ".")
    }

    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case let .typeMismatch(type, context):
            return "Type mismatch for \(type) at \(describeCodingPath(context.codingPath)): \(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "Value not found for \(type) at \(describeCodingPath(context.codingPath)): \(context.debugDescription)"
        case let .keyNotFound(key, context):
            return "Key '\(key.stringValue)' not found at \(describeCodingPath(context.codingPath)): \(context.debugDescription)"
        case let .dataCorrupted(context):
            return "Data corrupted at \(describeCodingPath(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error: \(error.localizedDescription)"
        }
    }

    var configURL: URL {
        let fm = FileManager.default
        let baseURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return baseURL
            .appendingPathComponent("My Custom Menu", isDirectory: true)
            .appendingPathComponent("menu.json", isDirectory: false)
    }

    var backupURL: URL {
        let baseName = configURL.deletingPathExtension().lastPathComponent
        let backupFileName = "\(baseName).backup.json"
        return configURL.deletingLastPathComponent().appendingPathComponent(backupFileName, isDirectory: false)
    }

    func load() {
        do {
            lastLoadErrorMessage = nil
            let url = configURL
            let fm = FileManager.default
            NSLog("Loading menu config from %@", url.path)

            if !fm.fileExists(atPath: url.path) {
                try createConfigDirectoryIfNeeded()
                try save()
                return
            }

            if let fileAttributes = try? fm.attributesOfItem(atPath: url.path),
               let fileSize = fileAttributes[.size] as? NSNumber {
                NSLog("Menu config size: %@ bytes", fileSize)
            }

            let data = try Data(contentsOf: url)
            configuration = try decoder.decode(MenuConfiguration.self, from: data)
            NSLog("Menu config loaded successfully")
        } catch let decodingError as DecodingError {
            configuration = .default
            let detail = describeDecodingError(decodingError)
            lastLoadErrorMessage = "Failed to decode menu config at \(configURL.path): \(detail)"
            NSLog("%@", lastLoadErrorMessage ?? "Failed to decode menu config")
        } catch {
            configuration = .default
            lastLoadErrorMessage = "Failed to load menu config at \(configURL.path): \(error.localizedDescription)"
            NSLog("%@", lastLoadErrorMessage ?? "Failed to load menu config")
        }
    }

    func consumeLastLoadErrorMessage() -> String? {
        let message = lastLoadErrorMessage
        lastLoadErrorMessage = nil
        return message
    }

    func save() throws {
        try createConfigDirectoryIfNeeded()
        try createBackupIfNeeded()
        let data = try encoder.encode(configuration)
        try data.write(to: configURL, options: .atomic)
    }

    private func createConfigDirectoryIfNeeded() throws {
        let folderURL = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    private func createBackupIfNeeded() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: configURL.path) else {
            return
        }

        if fm.fileExists(atPath: backupURL.path) {
            try fm.removeItem(at: backupURL)
        }

        try fm.copyItem(at: configURL, to: backupURL)
    }
}

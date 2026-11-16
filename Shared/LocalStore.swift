import Foundation

/// 轻量本地存储：数据放在 Application Support/HealthDuo 下的 JSON 文件里。
/// 不依赖 iCloud，也不需要开发者账号的 CloudKit 能力。
final class LocalStore {
    static let shared = LocalStore()

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("HealthDuo", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = directory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        let url = directory.appendingPathComponent("\(key).json")
        try? data.write(to: url, options: .atomic)
    }

    func remove(key: String) {
        let url = directory.appendingPathComponent("\(key).json")
        try? FileManager.default.removeItem(at: url)
    }
}

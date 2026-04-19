import Foundation

enum AppConfig {
    static let baseURL: URL = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "ServerBaseURL") as? String ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return URL(string: "http://localhost:8080")!
        }
        return url
    }()
}

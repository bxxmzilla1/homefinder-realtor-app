import Foundation

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: Keys.serverURL) }
    }

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Keys.apiKey) }
    }

    private enum Keys {
        static let serverURL = "serverURL"
        static let apiKey = "apiKey"
    }

    private init() {
        let defaults = UserDefaults.standard
        serverURL = defaults.string(forKey: Keys.serverURL) ?? BuildConfig.defaultServerURL
        apiKey = defaults.string(forKey: Keys.apiKey) ?? BuildConfig.defaultAPIKey
    }

    var isConfigured: Bool {
        !serverURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func resetToBuildDefaults() {
        serverURL = BuildConfig.defaultServerURL
        apiKey = BuildConfig.defaultAPIKey
    }
}

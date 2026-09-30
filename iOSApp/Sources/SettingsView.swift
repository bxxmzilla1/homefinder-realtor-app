import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var testResult: String?
    @State private var testSucceeded = false
    @State private var isTesting = false
    let onSaved: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("http://192.168.1.72:3000", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                } header: {
                    Text("Listings server")
                } footer: {
                    Text("Run the server on your PC with npm start. Your iPhone must be on the same Wi-Fi network as the PC.")
                }

                Section {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Text("Test connection")
                            Spacer()
                            if isTesting { ProgressView() }
                        }
                    }
                    .disabled(isTesting)

                    if let testResult {
                        Label(testResult, systemImage: testSucceeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundColor(testSucceeded ? .green : .red)
                            .font(.footnote)
                    }
                }

                if !BuildConfig.defaultServerURL.isEmpty {
                    Section {
                        Button("Restore built-in defaults") {
                            serverURL = BuildConfig.defaultServerURL
                            apiKey = BuildConfig.defaultAPIKey
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        apply()
                        onSaved()
                        dismiss()
                    }
                    .font(.body.bold())
                }
            }
            .onAppear {
                serverURL = settings.serverURL
                apiKey = settings.apiKey
            }
        }
        .navigationViewStyle(.stack)
    }

    private func apply() {
        settings.serverURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func testConnection() async {
        let previousURL = settings.serverURL
        let previousKey = settings.apiKey
        apply()
        isTesting = true
        defer { isTesting = false }
        do {
            let response = try await APIClient.shared.search(["resultsPerPage": "1", "status": "A"])
            testSucceeded = true
            testResult = "Connected. \(Format.count(response.paging.totalRecords ?? 0)) active listings available."
        } catch {
            testSucceeded = false
            testResult = error.localizedDescription
            settings.serverURL = previousURL
            settings.apiKey = previousKey
        }
    }
}

import Foundation
import AppKit

struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
    }
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var isChecking = false
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var updateURL: URL?
    
    private let githubAPIURL = URL(string: "https://api.github.com/repos/bloodstalk1/Clipo/releases/latest")!
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
    }
    
    func checkForUpdates(silent: Bool = false) async -> Bool {
        guard !isChecking else { return false }
        isChecking = true
        defer { isChecking = false }
        
        var request = URLRequest(url: githubAPIURL)
        request.setValue("Clipo Update Checker", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            
            let decoder = JSONDecoder()
            let release = try decoder.decode(GitHubRelease.self, from: data)
            
            let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let current = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            
            if isVersionNewer(latest: latest, current: current) {
                self.latestVersion = release.tagName
                self.updateURL = URL(string: release.htmlUrl)
                self.updateAvailable = true
                return true
            }
        } catch {
            // Handle error silently
        }
        
        self.updateAvailable = false
        return false
    }
    
    func isVersionNewer(latest: String, current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        let count = max(latestComponents.count, currentComponents.count)
        for i in 0..<count {
            let latestVal = i < latestComponents.count ? latestComponents[i] : 0
            let currentVal = i < currentComponents.count ? currentComponents[i] : 0
            
            if latestVal > currentVal {
                return true
            } else if latestVal < currentVal {
                return false
            }
        }
        return false
    }
}

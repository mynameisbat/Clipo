import CryptoKit
import Foundation

struct PasteboardSnapshot: Sendable {
    let strings: [String]
    let fileURLs: [URL]
    let imageData: Data?
    let imageFileExtension: String?
    let htmlData: Data?
    let rtfData: Data?
    let webArchiveData: Data?
    let sourceAppBundleId: String?

    init(
        strings: [String],
        fileURLs: [URL],
        imageData: Data?,
        imageFileExtension: String?,
        htmlData: Data? = nil,
        rtfData: Data? = nil,
        webArchiveData: Data? = nil,
        sourceAppBundleId: String?
    ) {
        self.strings = strings
        self.fileURLs = fileURLs
        self.imageData = imageData
        self.imageFileExtension = imageFileExtension
        self.htmlData = htmlData
        self.rtfData = rtfData
        self.webArchiveData = webArchiveData
        self.sourceAppBundleId = sourceAppBundleId
    }

    var fingerprint: String {
        if let imageData {
            let digest = SHA256.hash(data: imageData)
            let hash = digest.map { String(format: "%02x", $0) }.joined()
            return "image::\(hash)"
        }

        if let htmlData {
            let digest = SHA256.hash(data: htmlData)
            let hash = digest.map { String(format: "%02x", $0) }.joined()
            return "html::\(hash)"
        }

        if let rtfData {
            let digest = SHA256.hash(data: rtfData)
            let hash = digest.map { String(format: "%02x", $0) }.joined()
            return "rtf::\(hash)"
        }

        if let webArchiveData {
            let digest = SHA256.hash(data: webArchiveData)
            let hash = digest.map { String(format: "%02x", $0) }.joined()
            return "webarchive::\(hash)"
        }

        if let fileURL = fileURLs.first {
            return "file::\(fileURL.path)"
        }

        if let text = strings.first, !text.isEmpty {
            return "text::\(text)"
        }

        return "empty"
    }
}

import Foundation

// MARK: - FirebaseConfig
//
// Reads `GoogleService-Info.plist` once and exposes the values needed to call
// Firebase's REST APIs directly. We do NOT link the Firebase SDKs — all auth
// and Firestore work is done with URLSession against the public REST endpoints.

enum FirebaseConfig {
    static let apiKey:    String = plistValue("API_KEY")
    static let projectId: String = plistValue("PROJECT_ID")
    static let bundleId:  String = plistValue("BUNDLE_ID")

    // MARK: - REST base URLs

    static var identityToolkitURL: String {
        "https://identitytoolkit.googleapis.com/v1"
    }
    static var secureTokenURL: String {
        "https://securetoken.googleapis.com/v1"
    }
    static var firestoreBase: String {
        "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents"
    }

    // MARK: - Private

    private static let plist: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else {
            print("[FirebaseConfig] GoogleService-Info.plist not found — auth/firestore will fail")
            return [:]
        }
        return dict
    }()

    private static func plistValue(_ key: String) -> String {
        guard let v = plist[key] as? String, !v.isEmpty else {
            print("[FirebaseConfig] Missing or empty '\(key)' in GoogleService-Info.plist")
            return ""
        }
        return v
    }
}

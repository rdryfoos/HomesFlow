import Foundation

// @covers FR-AUTH-01, NFR-SEC-01

enum SupabaseConfig {
    static var url: URL {
        guard
            let string = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: string)
        else {
            fatalError("SUPABASE_URL missing from Info.plist — copy Secrets.xcconfig.example")
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("SUPABASE_ANON_KEY missing from Info.plist")
        }
        return key
    }
}

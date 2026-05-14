import Foundation

enum SupabaseConfig {
    static var url: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    static var anonKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static var isConfigured: Bool {
        url != nil && anonKey != nil
    }
}


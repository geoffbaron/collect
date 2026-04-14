import Foundation
import Supabase

// MARK: - Supabase Client Singleton
// Replace the placeholder values below with your actual project credentials.
// Dashboard → Project Settings → API

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    // The base URL of your Supabase project — also used to build Edge Function URLs.
    static let projectURL = Secrets.supabaseURL

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey
        )
    }
}

// MARK: - Secrets
// TODO: Replace these with your actual values from the Supabase dashboard.
// Do NOT commit real credentials — move these to a .xcconfig or environment
// variable before shipping.
private enum Secrets {
    static let supabaseURL     = "https://nrvlkoakvjlqvkqvncel.supabase.co"
    static let supabaseAnonKey = "sb_publishable_ehxGkAGni7zVzhesCt4LDw_MVBGkpZD"
}

import Foundation
import Supabase

enum SupabaseConfig {
    // MARK: - Configuration
    
    /// Supabase Project URL
    static let url = URL(string: "https://lesulvngqpvgepijazin.supabase.co")!
    
    /// Supabase Anon/Public Key
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxlc3Vsdm5ncXB2Z2VwaWphemluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxMDg5ODIsImV4cCI6MjA3ODY4NDk4Mn0.AbRfmyB4PR-CrHfiiNUmr_Oia708S-DA0wbtgAzMP5I"
    
    // MARK: - Client
    
    static let client: SupabaseClient = {
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }()
    
    // MARK: - Storage
    
    /// Имя bucket для видео
    static let bucketName = "signs"
}


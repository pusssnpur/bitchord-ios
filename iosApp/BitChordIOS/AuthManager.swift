import Foundation
import Combine
import AuthenticationServices

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var sessions: [AccountSession] = []
    
    private let keychain = KeychainManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSessions()
    }
    
    // MARK: - Public Methods
    func signInWithGoogle() {
        // Implement Google Sign-In
        // Would use GoogleSignIn SDK
        print("Google Sign-In not yet implemented")
    }
    
    func signInWithYouTubeMusic() {
        // Implement YouTube Music OAuth
        // Uses OAuth2 with YouTube Music scopes
        print("YouTube Music Sign-In not yet implemented")
    }
    
    func signInWithDiscord() {
        // Implement Discord OAuth2
        print("Discord Sign-In not yet implemented")
    }
    
    func signInWithLastFm() {
        // Implement Last.fm auth
        print("Last.fm Sign-In not yet implemented")
    }
    
    func signInWithListenBrainz() {
        // Implement ListenBrainz auth
        print("ListenBrainz Sign-In not yet implemented")
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        keychain.deleteAll()
    }
    
    func signOut(sessionId: String) {
        sessions.removeAll { $0.id == sessionId }
        saveSessions()
    }
    
    func revokeSession(sessionId: String) {
        // Call backend to revoke
        signOut(sessionId: sessionId)
    }
    
    func refreshTokens(for session: AccountSession) async throws -> AuthTokens {
        // Refresh OAuth tokens
        throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
    
    // MARK: - Private Methods
    private func loadSessions() {
        if let data = keychain.getData(for: "auth.sessions"),
           let sessions = try? JSONDecoder().decode([AccountSession].self, from: data) {
            self.sessions = sessions
            if let current = sessions.first(where: { $0.isCurrent }) {
                self.currentUser = current.userProfile
                self.isAuthenticated = true
            }
        }
    }
    
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            keychain.setData(data, for: "auth.sessions")
        }
    }
}

// MARK: - Models
struct UserProfile: Codable, Equatable {
    let id: String
    let name: String
    let email: String?
    let avatarURL: URL?
    let isPremium: Bool
    let country: String?
    
    var initials: String {
        name.components(separatedBy: " ").compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

struct AccountSession: Codable, Equatable, Identifiable {
    let id: String
    let provider: AuthProvider
    let email: String
    let name: String
    let avatarURL: URL?
    let tokens: AuthTokens
    let createdAt: Date
    let lastUsedAt: Date
    var isCurrent: Bool = false
    var userProfile: UserProfile?
}

enum AuthProvider: String, Codable, CaseIterable {
    case google = "google"
    case youtubeMusic = "youtube_music"
    case discord = "discord"
    case lastfm = "lastfm"
    case listenBrainz = "listenbrainz"
    
    var displayName: String {
        switch self {
        case .google: return "Google"
        case .youtubeMusic: return "YouTube Music"
        case .discord: return "Discord"
        case .lastfm: return "Last.fm"
        case .listenBrainz: return "ListenBrainz"
        }
    }
    
    var iconName: String {
        switch self {
        case .google: return "globe"
        case .youtubeMusic: return "music.note"
        case .discord: return "message"
        case .lastfm: return "waveform"
        case .listenBrainz: return "brain"
        }
    }
}

struct AuthTokens: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let tokenType: String
    let scope: String?
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
}
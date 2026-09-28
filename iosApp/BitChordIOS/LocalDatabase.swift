import Foundation
import GRDB

final class LocalDatabase {
    static let shared = LocalDatabase()
    
    private let dbQueue: DatabaseQueue
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbPath = documentsPath.appendingPathComponent("bitchord.db").path
        
        dbQueue = try! DatabaseQueue(path: dbPath)
        try! migrate()
    }
    
    private func migrate() throws {
        try dbQueue.write { db in
            try db.create(table: "tracks", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("video_id", .text).notNull().unique(onConflict: .replace)
                t.column("title", .text).notNull()
                t.column("artist_name", .text).notNull()
                t.column("artist_id", .text)
                t.column("album_name", .text)
                t.column("album_id", .text)
                t.column("duration", .double).notNull()
                t.column("artwork_url", .text)
                t.column("is_explicit", .boolean).notNull().defaults(to: false)
                t.column("audio_quality", .text).notNull()
                t.column("source", .text).notNull()
                t.column("added_at", .datetime)
                t.column("play_count", .integer).notNull().defaults(to: 0)
                t.column("last_played", .datetime)
                t.column("is_liked", .boolean).notNull().defaults(to: false)
                t.column("lyrics_data", .blob)
            }
            
            try db.create(table: "playlists", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("artwork_url", .text)
                t.column("owner_name", .text)
                t.column("owner_id", .text)
                t.column("track_count", .integer).notNull().defaults(to: 0)
                t.column("duration", .double)
                t.column("is_public", .boolean).notNull().defaults(to: true)
                t.column("is_collaborative", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime)
                t.column("browse_id", .text)
            }
            
            try db.create(table: "playlist_tracks", ifNotExists: true) { t in
                t.column("playlist_id", .text).notNull()
                t.column("track_id", .text).notNull()
                t.column("position", .integer).notNull()
                t.column("added_at", .datetime).notNull()
                t.primaryKey(["playlist_id", "track_id"], onConflict: .replace)
                t.foreignKey(["playlist_id"], references: "playlists", columns: ["id"], onDelete: .cascade)
                t.foreignKey(["track_id"], references: "tracks", columns: ["id"], onDelete: .cascade)
            }
            
            try db.create(table: "albums", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("artist_name", .text).notNull()
                t.column("artist_id", .text)
                t.column("year", .integer)
                t.column("track_count", .integer).notNull().defaults(to: 0)
                t.column("duration", .double)
                t.column("artwork_url", .text)
                t.column("type", .text).notNull()
                t.column("release_date", .date)
                t.column("browse_id", .text)
            }
            
            try db.create(table: "artists", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("thumbnail_url", .text)
                t.column("subscriber_count", .integer)
                t.column("is_verified", .boolean).notNull().defaults(to: false)
                t.column("browse_id", .text)
            }
            
            try db.create(table: "downloads", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("track_id", .text).notNull()
                t.column("quality", .text).notNull()
                t.column("local_path", .text).notNull()
                t.column("file_size", .integer).notNull()
                t.column("downloaded_at", .datetime).notNull()
                t.column("metadata", .blob)
                t.foreignKey(["track_id"], references: "tracks", columns: ["id"], onDelete: .cascade)
            }
            
            try db.create(table: "history", ifNotExists: true) { t in
                t.column("id", .integer).primaryKey(autoincrement: true)
                t.column("track_id", .text).notNull()
                t.column("played_at", .datetime).notNull()
                t.column("position", .double).notNull().defaults(to: 0)
                t.column("completed", .boolean).notNull().defaults(to: false)
                t.foreignKey(["track_id"], references: "tracks", columns: ["id"], onDelete: .cascade)
            }
            
            try db.create(table: "settings", ifNotExists: true) { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
            
            try db.create(table: "auth_sessions", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("provider", .text).notNull()
                t.column("email", .text).notNull()
                t.column("name", .text).notNull()
                t.column("avatar_url", .text)
                t.column("access_token", .text).notNull()
                t.column("refresh_token", .text)
                t.column("expires_at", .datetime)
                t.column("created_at", .datetime).notNull()
                t.column("last_used_at", .datetime).notNull()
                t.column("is_current", .boolean).notNull().defaults(to: false)
            }
            
            // Indexes
            try db.create(index: "idx_tracks_artist", on: "tracks", columns: ["artist_name"], ifNotExists: true)
            try db.create(index: "idx_tracks_album", on: "tracks", columns: ["album_name"], ifNotExists: true)
            try db.create(index: "idx_tracks_liked", on: "tracks", columns: ["is_liked"], ifNotExists: true)
            try db.create(index: "idx_history_track", on: "history", columns: ["track_id"], ifNotExists: true)
            try db.create(index: "idx_history_played_at", on: "history", columns: ["played_at"], ifNotExists: true)
        }
    }
    
    // MARK: - Tracks
    func saveTracks(_ tracks: [Track]) throws {
        try dbQueue.write { db in
            for track in tracks {
                try track.insert(db)
            }
        }
    }
    
    func getTrack(id: String) throws -> Track? {
        try dbQueue.read { db in
            try Track.fetchOne(db, key: id)
        }
    }
    
    func getTracks(ids: [String]) throws -> [Track] {
        try dbQueue.read { db in
            try Track.filter(ids.contains(Column("id"))).fetchAll(db)
        }
    }
    
    func getLikedTracks(limit: Int = 50, offset: Int = 0) throws -> [Track] {
        try dbQueue.read { db in
            try Track.filter(Column("is_liked") == true)
                .order(Column("added_at").desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    func setTrackLiked(_ trackId: String, liked: Bool) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE tracks SET is_liked = ? WHERE id = ?", arguments: [liked, trackId])
        }
    }
    
    func incrementPlayCount(_ trackId: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                UPDATE tracks SET play_count = play_count + 1, last_played = ? WHERE id = ?
                """, arguments: [Date(), trackId])
        }
    }
    
    func searchTracks(query: String, limit: Int = 50) throws -> [Track] {
        try dbQueue.read { db in
            let pattern = "%\(query.lowercased())%"
            return try Track.filter(
                (Column("title").lower.like(pattern)) |
                (Column("artist_name").lower.like(pattern)) |
                (Column("album_name").lower.like(pattern))
            )
            .order(Column("play_count").desc)
            .limit(limit)
            .fetchAll(db)
        }
    }
    
    // MARK: - Playlists
    func savePlaylists(_ playlists: [Playlist]) throws {
        try dbQueue.write { db in
            for playlist in playlists {
                try playlist.insert(db)
                // Save tracks
                for (index, track) in playlist.tracks.enumerated() {
                    try db.execute(sql: """
                        INSERT OR REPLACE INTO playlist_tracks (playlist_id, track_id, position, added_at)
                        VALUES (?, ?, ?, ?)
                        """, arguments: [playlist.id, track.id, index, Date()])
                }
            }
        }
    }
    
    func getPlaylist(id: String) throws -> Playlist? {
        try dbQueue.read { db in
            guard var playlist = try Playlist.fetchOne(db, key: id) else { return nil }
            playlist.tracks = try Track
                .joining(required: PlaylistTrack.filter(Column("playlist_id") == id))
                .order(Column("position"))
                .fetchAll(db)
            return playlist
        }
    }
    
    func getPlaylists(limit: Int = 50, offset: Int = 0) throws -> [Playlist] {
        try dbQueue.read { db in
            try Playlist
                .order(Column("updated_at").desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    func deletePlaylist(id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM playlists WHERE id = ?", arguments: [id])
        }
    }
    
    // MARK: - Albums
    func saveAlbums(_ albums: [Album]) throws {
        try dbQueue.write { db in
            for album in albums {
                try album.insert(db)
            }
        }
    }
    
    func getAlbum(id: String) throws -> Album? {
        try dbQueue.read { db in
            try Album.fetchOne(db, key: id)
        }
    }
    
    // MARK: - Artists
    func saveArtists(_ artists: [Artist]) throws {
        try dbQueue.write { db in
            for artist in artists {
                try artist.insert(db)
            }
        }
    }
    
    func getArtist(id: String) throws -> Artist? {
        try dbQueue.read { db in
            try Artist.fetchOne(db, key: id)
        }
    }
    
    // MARK: - Downloads
    func saveDownload(_ download: DownloadRecord) throws {
        try dbQueue.write { db in
            try download.insert(db)
        }
    }
    
    func getDownload(trackId: String) throws -> DownloadRecord? {
        try dbQueue.read { db in
            try DownloadRecord.filter(Column("track_id") == trackId).fetchOne(db)
        }
    }
    
    func getAllDownloads() throws -> [DownloadRecord] {
        try dbQueue.read { db in
            try DownloadRecord.order(Column("downloaded_at").desc).fetchAll(db)
        }
    }
    
    func deleteDownload(trackId: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM downloads WHERE track_id = ?", arguments: [trackId])
        }
    }
    
    // MARK: - History
    func addToHistory(_ entry: HistoryEntry) throws {
        try dbQueue.write { db in
            try entry.insert(db)
        }
    }
    
    func getHistory(limit: Int = 100) throws -> [HistoryEntry] {
        try dbQueue.read { db in
            try HistoryEntry.order(Column("played_at").desc).limit(limit).fetchAll(db)
        }
    }
    
    func clearHistory() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM history")
        }
    }
    
    // MARK: - Settings
    func setString(_ key: String, _ value: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", arguments: [key, value])
        }
    }
    
    func getString(_ key: String) -> String? {
        try? dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?", arguments: [key])
        } ?? nil
    }
    
    func setBool(_ key: String, _ value: Bool) throws {
        try setString(key, value ? "true" : "false")
    }
    
    func getBool(_ key: String, default: Bool = false) -> Bool {
        (try? getString(key))?.lowercased() == "true" ?? `default`
    }
    
    func setInt(_ key: String, _ value: Int) throws {
        try setString(key, String(value))
    }
    
    func getInt(_ key: String, default: Int = 0) -> Int {
        Int(try? getString(key) ?? "") ?? `default`
    }
    
    func setDouble(_ key: String, _ value: Double) throws {
        try setString(key, String(value))
    }
    
    func getDouble(_ key: String, default: Double = 0) -> Double {
        Double(try? getString(key) ?? "") ?? `default`
    }
    
    // MARK: - Auth Sessions
    func saveAuthSession(_ session: AuthSession) throws {
        try dbQueue.write { db in
            try session.insert(db)
        }
    }
    
    func getAuthSession(id: String) throws -> AuthSession? {
        try dbQueue.read { db in
            try AuthSession.fetchOne(db, key: id)
        }
    }
    
    func getCurrentAuthSession() throws -> AuthSession? {
        try dbQueue.read { db in
            try AuthSession.filter(Column("is_current") == true).fetchOne(db)
        }
    }
    
    func setCurrentAuthSession(_ sessionId: String?) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE auth_sessions SET is_current = 0")
            if let id = sessionId {
                try db.execute(sql: "UPDATE auth_sessions SET is_current = 1 WHERE id = ?", arguments: [id])
            }
        }
    }
}

// MARK: - Record Types
struct Track: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var videoId: String
    var title: String
    var artistName: String
    var artistId: String?
    var albumName: String?
    var albumId: String?
    var duration: TimeInterval
    var artworkURL: String?
    var isExplicit: Bool
    var audioQuality: String
    var source: String
    var addedAt: Date?
    var playCount: Int
    var lastPlayed: Date?
    var isLiked: Bool
    var lyricsData: Data?
}

struct Playlist: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var title: String
    var description: String?
    var artworkURL: String?
    var ownerName: String?
    var ownerId: String?
    var trackCount: Int
    var duration: TimeInterval?
    var isPublic: Bool
    var isCollaborative: Bool
    var createdAt: Date
    var updatedAt: Date?
    var browseId: String?
    var tracks: [Track] = []
}

struct Album: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var title: String
    var artistName: String
    var artistId: String?
    var year: Int?
    var trackCount: Int
    var duration: TimeInterval?
    var artworkURL: String?
    var type: String
    var releaseDate: Date?
    var browseId: String?
}

struct Artist: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var thumbnailURL: String?
    var subscriberCount: Int?
    var isVerified: Bool
    var browseId: String?
}

struct DownloadRecord: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var trackId: String
    var quality: String
    var localPath: String
    var fileSize: Int64
    var downloadedAt: Date
    var metadata: Data?
}

struct HistoryEntry: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var trackId: String
    var playedAt: Date
    var position: TimeInterval
    var completed: Bool
}

struct AuthSession: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var provider: String
    var email: String
    var name: String
    var avatarURL: String?
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    var createdAt: Date
    var lastUsedAt: Date
    var isCurrent: Bool
}
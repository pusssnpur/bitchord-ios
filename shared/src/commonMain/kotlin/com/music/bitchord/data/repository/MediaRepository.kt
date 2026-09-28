package com.music.bitchord.data.repository

import com.music.bitchord.data.model.*
import kotlinx.coroutines.flow.Flow

interface MediaRepository {
    // Search
    suspend fun search(query: String, filter: SearchFilter = SearchFilter.ALL): Result<SearchResults>
    suspend fun getSearchSuggestions(query: String): Result<List<String>>

    // Home
    suspend fun getHomeSections(): Result<HomeSections>

    // Library
    suspend fun getLikedTracks(limit: Int = 50, offset: Int = 0): Result<List<Track>>
    suspend fun likeTrack(trackId: String): Result<Unit>
    suspend fun unlikeTrack(trackId: String): Result<Unit>

    suspend fun getPlaylists(limit: Int = 50, offset: Int = 0): Result<List<Playlist>>
    suspend fun getPlaylist(playlistId: String): Result<Playlist>
    suspend fun createPlaylist(title: String, description: String? = null, isPublic: Boolean = true): Result<Playlist>
    suspend fun addTracksToPlaylist(playlistId: String, trackIds: List<String>): Result<Unit>
    suspend fun removeTracksFromPlaylist(playlistId: String, trackIds: List<String>): Result<Unit>

    suspend fun getAlbums(limit: Int = 50, offset: Int = 0): Result<List<Album>>
    suspend fun getAlbum(albumId: String): Result<Album>

    suspend fun getArtists(limit: Int = 50, offset: Int = 0): Result<List<Artist>>
    suspend fun getArtist(artistId: String): Result<Artist>
    suspend fun getArtistTopTracks(artistId: String, limit: Int = 10): Result<List<Track>>
    suspend fun getArtistAlbums(artistId: String, limit: Int = 20): Result<List<Album>>

    // Browse
    suspend fun getMoodCategories(): Result<List<MoodCategory>>
    suspend fun getGenreCategories(): Result<List<GenreCategory>>
    suspend fun getMoodPlaylist(moodId: String): Result<Playlist>
    suspend fun getGenrePlaylist(genreId: String): Result<Playlist>
    suspend fun getCharts(): Result<List<Playlist>>

    // Radio / Mix
    suspend fun getRadio(trackId: String): Result<List<Track>>
    suspend fun getMix(playlistId: String): Result<List<Track>>

    // Lyrics
    suspend fun getLyrics(trackId: String): Result<Lyrics?>
    suspend fun searchLyrics(query: String): Result<List<Lyrics>>

    // Stream URL resolution
    suspend fun getStreamUrl(trackId: String, quality: AudioQuality = AudioQuality.HIGH): Result<String>
    suspend fun getStreamManifest(trackId: String): Result<StreamManifest>

    // Offline / Downloads
    suspend fun getDownloadInfo(trackId: String): Result<DownloadInfo?>
    suspend fun queueDownload(trackId: String, quality: AudioQuality): Result<DownloadTask>
    suspend fun cancelDownload(taskId: String): Result<Unit>
    suspend fun getActiveDownloads(): Result<List<DownloadTask>>
    suspend fun getCompletedDownloads(): Result<List<DownloadTask>>

    // History / Recently played
    suspend fun getRecentlyPlayed(limit: Int = 50): Result<List<RecentItem>>
    suspend fun addToHistory(item: RecentItem): Result<Unit>
    suspend fun clearHistory(): Result<Unit>

    // User profile
    suspend fun getCurrentUser(): Result<UserProfile?>
    suspend fun updateUserProfile(profile: UserProfile): Result<Unit>
}

@Serializable
enum class SearchFilter {
    ALL, TRACKS, ALBUMS, ARTISTS, PLAYLISTS, VIDEOS, COMMUNITY_PLAYLISTS
}

@Serializable
data class StreamManifest(
    val urls: Map<AudioQuality, String>,
    val format: StreamFormat,
    val drm: DrmInfo? = null,
    val expiresAt: Instant? = null
)

@Serializable
enum class StreamFormat {
    MP4, WEBM, M4A, FLAC, HLS, DASH
}

@Serializable
data class DrmInfo(
    val scheme: String,
    val licenseUrl: String,
    val keyId: String
)

@Serializable
data class DownloadInfo(
    val trackId: String,
    val localPath: String,
    val quality: AudioQuality,
    val fileSize: Long,
    val downloadedAt: Instant,
    val metadata: TrackMetadata
)

@Serializable
data class DownloadTask(
    val id: String,
    val trackId: String,
    val quality: AudioQuality,
    val status: DownloadStatus,
    val progress: Float,
    val totalBytes: Long,
    val downloadedBytes: Long,
    val error: String? = null
)

@Serializable
enum class DownloadStatus {
    QUEUED, DOWNLOADING, PAUSED, COMPLETED, FAILED, CANCELLED
}

@Serializable
data class TrackMetadata(
    val title: String,
    val artists: List<String>,
    val album: String?,
    val albumArtist: String?,
    val year: Int?,
    val trackNumber: Int?,
    val discNumber: Int?,
    val genre: String?,
    val artwork: ByteArray?,
    val lyrics: String?
)

@Serializable
data class UserProfile(
    val id: String,
    val name: String,
    val email: String?,
    val thumbnailUrl: String?,
    val isPremium: Boolean,
    val country: String?
)

sealed class Result<out T> {
    data class Success<out T>(val value: T) : Result<T>()
    data class Failure(val error: Throwable) : Result<Nothing>()
    
    companion object {
        fun <T> success(value: T): Result<T> = Success(value)
        fun <T> failure(error: Throwable): Result<T> = Failure(error)
    }
    
    fun isSuccess(): Boolean = this is Success<*>
    fun isFailure(): Boolean = this is Failure
    
    fun getOrNull(): T? = when (this) {
        is Success -> value
        is Failure -> null
    }
    
    fun getOrThrow(): T = when (this) {
        is Success -> value
        is Failure -> throw error
    }
    
    fun onSuccess(action: (T) -> Unit): Result<T> {
        if (this is Success) action(value)
        return this
    }
    
    fun onFailure(action: (Throwable) -> Unit): Result<T> {
        if (this is Failure) action(error)
        return this
    }
    
    fun <R> map(transform: (T) -> R): Result<R> = when (this) {
        is Success -> Success(transform(value))
        is Failure -> Failure(error)
    }
    
    fun <R> flatMap(transform: (T) -> Result<R>): Result<R> = when (this) {
        is Success -> transform(value)
        is Failure -> Failure(error)
    }
}
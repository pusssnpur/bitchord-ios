package com.music.bitchord.data.model

import kotlinx.serialization.Serializable

@Serializable
sealed interface BrowseResult {
    @Serializable data class Tracks(
        val tracks: List<Track>,
        val nextPageToken: String? = null
    ) : BrowseResult

    @Serializable data class Albums(
        val albums: List<Album>,
        val nextPageToken: String? = null
    ) : BrowseResult

    @Serializable data class Artists(
        val artists: List<Artist>,
        val nextPageToken: String? = null
    ) : BrowseResult

    @Serializable data class Playlists(
        val playlists: List<Playlist>,
        val nextPageToken: String? = null
    ) : BrowseResult
}

@Serializable
data class SearchResults(
    val tracks: BrowseResult.Tracks? = null,
    val albums: BrowseResult.Albums? = null,
    val artists: BrowseResult.Artists? = null,
    val playlists: BrowseResult.Playlists? = null,
    val videos: List<Track> = emptyList(),
    val communityPlaylists: List<Playlist> = emptyList(),
    val featuredPlaylists: List<Playlist> = emptyList(),
    val query: String
)

@Serializable
data class HomeSections(
    val newReleases: List<Album> = emptyList(),
    val charts: List<Playlist> = emptyList(),
    val moods: List<MoodCategory> = emptyList(),
    val genres: List<GenreCategory> = emptyList(),
    val recommendedPlaylists: List<Playlist> = emptyList(),
    val recommendedAlbums: List<Album> = emptyList(),
    val recommendedArtists: List<Artist> = emptyList(),
    val yourLikes: List<Track> = emptyList(),
    val recentlyPlayed: List<RecentItem> = emptyList()
)

@Serializable
data class MoodCategory(
    val id: String,
    val title: String,
    val thumbnailUrl: String?,
    val browseId: String?
)

@Serializable
data class GenreCategory(
    val id: String,
    val title: String,
    val thumbnailUrl: String?,
    val browseId: String?
)

@Serializable
sealed class RecentItem {
    @Serializable data class Track(val track: Track, val playedAt: Instant) : RecentItem()
    @Serializable data class Album(val album: Album, val playedAt: Instant) : RecentItem()
    @Serializable data class Playlist(val playlist: Playlist, val playedAt: Instant) : RecentItem()
    @Serializable data class Artist(val artist: Artist, val playedAt: Instant) : RecentItem()
}
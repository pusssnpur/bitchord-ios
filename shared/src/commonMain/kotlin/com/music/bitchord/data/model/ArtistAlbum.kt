package com.music.bitchord.data.model

import kotlinx.serialization.Serializable

@Serializable
data class Artist(
    val id: String,
    val name: String,
    val thumbnailUrl: String? = null,
    val subscriberCount: Long? = null,
    val isVerified: Boolean = false,
    val browseId: String? = null
)

@Serializable
data class Album(
    val id: String,
    val title: String,
    val artists: List<Artist>,
    val year: Int? = null,
    val trackCount: Int = 0,
    val duration: Duration? = null,
    val thumbnailUrl: String? = null,
    val description: String? = null,
    val type: AlbumType = AlbumType.ALBUM,
    val releaseDate: LocalDate? = null,
    val browseId: String? = null
) {
    val displayArtist: String get() = artists.joinToString(", ") { it.name }
}

@Serializable
enum class AlbumType {
    ALBUM, SINGLE, EP, COMPILATION, SOUNDTRACK
}
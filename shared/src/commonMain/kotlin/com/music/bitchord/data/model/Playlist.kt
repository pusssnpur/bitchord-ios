package com.music.bitchord.data.model

import kotlinx.serialization.Serializable
import kotlinx.datetime.Instant

@Serializable
data class Playlist(
    val id: String,
    val title: String,
    val description: String? = null,
    val thumbnailUrl: String? = null,
    val owner: PlaylistOwner?,
    val trackCount: Int = 0,
    val duration: Duration? = null,
    val isPublic: Boolean = true,
    val isCollaborative: Boolean = false,
    val tracks: List<Track> = emptyList(),
    val createdAt: Instant? = null,
    val updatedAt: Instant? = null,
    val browseId: String? = null
)

@Serializable
data class PlaylistOwner(
    val name: String,
    val id: String? = null,
    val thumbnailUrl: String? = null
)
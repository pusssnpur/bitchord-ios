package com.music.bitchord.data.model

import kotlinx.serialization.Serializable
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

@Serializable
data class Track(
    val id: String,
    val videoId: String,
    val title: String,
    val artists: List<Artist>,
    val album: Album?,
    val duration: Duration,
    val thumbnailUrl: String?,
    val isExplicit: Boolean = false,
    val isAvailable: Boolean = true,
    val streamUrl: String? = null,
    val audioQuality: AudioQuality = AudioQuality.STANDARD,
    val lyrics: Lyrics? = null,
    val addedAt: Instant? = null,
    val playCount: Long = 0,
    val source: TrackSource = TrackSource.YOUTUBE_MUSIC
) {
    val displayArtist: String get() = artists.joinToString(", ") { it.name }
    val displayTitle: String get() = title
}

@Serializable
enum class AudioQuality {
    LOW, STANDARD, HIGH, LOSSLESS, HI_RES
}

@Serializable
data class Duration(val milliseconds: Long) {
    companion object {
        fun fromMillis(millis: Long) = Duration(millis)
        fun fromSeconds(seconds: Long) = Duration(seconds * 1000)
    }

    val seconds: Long get() = milliseconds / 1000
    val minutes: Long get() = seconds / 60
    val hours: Long get() = minutes / 60

    override fun toString(): String {
        return when {
            hours > 0 -> "%d:%02d:%02d".format(hours, minutes % 60, seconds % 60)
            else -> "%d:%02d".format(minutes, seconds % 60)
        }
    }
}

@Serializable
enum class TrackSource {
    YOUTUBE_MUSIC, LOCAL, UPLOAD, OTHER
}
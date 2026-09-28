package com.music.bitchord.data.model

import kotlinx.serialization.Serializable

@Serializable
data class Lyrics(
    val source: LyricsSource,
    val syncType: SyncType,
    val lines: List<LyricLine>,
    val language: String? = null,
    val isTranslation: Boolean = false,
    val translationOf: String? = null
) {
    val hasWordSync: Boolean get() = syncType == SyncType.WORD || syncType == SyncType.CHARACTER
    val hasLineSync: Boolean get() = syncType != SyncType.UNSYNCED
}

@Serializable
enum class LyricsSource {
    YOUTUBE_MUSIC, LRC_LIB, MUSIXMATCH, GENIUS, NETEASE, LOCAL, USER
}

@Serializable
enum class SyncType {
    UNSYNCED, LINE, WORD, CHARACTER
}

@Serializable
data class LyricLine(
    val startTime: Long,
    val endTime: Long,
    val text: String,
    val words: List<LyricWord> = emptyList(),
    val translation: String? = null
) {
    val duration: Long get() = endTime - startTime
    val isEmpty: Boolean get() = text.trim().isEmpty()
}

@Serializable
data class LyricWord(
    val startTime: Long,
    val endTime: Long,
    val text: String,
    val confidence: Float = 1.0f
) {
    val duration: Long get() = endTime - startTime
}
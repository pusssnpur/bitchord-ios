package com.music.bitchord.playback

import com.music.bitchord.data.model.Track
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.datetime.Instant

interface PlayerController {
    val playbackState: StateFlow<PlaybackState>
    val currentTrack: StateFlow<Track?>
    val position: StateFlow<Long>
    val duration: StateFlow<Long>
    val bufferedPosition: StateFlow<Long>
    val volume: MutableStateFlow<Float>
    val speed: MutableStateFlow<Float>
    val repeatMode: MutableStateFlow<RepeatMode>
    val shuffleMode: MutableStateFlow<ShuffleMode>
    val audioQuality: MutableStateFlow<AudioQuality>
    val crossfadeDuration: MutableStateFlow<Int>

    suspend fun play(track: Track, queue: List<Track>, startIndex: Int = 0)
    suspend fun playPause()
    suspend fun pause()
    suspend fun stop()
    suspend fun seekTo(position: Long)
    suspend fun next()
    suspend fun previous()
    suspend fun setQueue(queue: List<Track>, startIndex: Int = 0)
    suspend fun addToQueue(track: Track, atIndex: Int? = null)
    suspend fun removeFromQueue(index: Int)
    suspend fun clearQueue()
    suspend fun setVolume(volume: Float)
    suspend fun setSpeed(speed: Float)
    suspend fun setRepeatMode(mode: RepeatMode)
    suspend fun setShuffleMode(mode: ShuffleMode)
    suspend fun setAudioQuality(quality: AudioQuality)
    suspend fun setCrossfadeDuration(ms: Int)

    // Sleep timer
    suspend fun setSleepTimer(duration: Long?)
    val sleepTimerRemaining: StateFlow<Long?>
    
    // Equalizer
    suspend fun setEqualizerEnabled(enabled: Boolean)
    suspend fun setEqualizerPreset(preset: EqualizerPreset)
    suspend fun setEqualizerBands(bands: List<Float>)
    
    // Spatial audio
    suspend fun setSpatialAudioEnabled(enabled: Boolean)
    suspend fun setHeadTrackingEnabled(enabled: Boolean)
}

data class PlaybackState(
    val status: PlaybackStatus = PlaybackStatus.IDLE,
    val error: String? = null,
    val isLoading: Boolean = false,
    val isBuffering: Boolean = false
)

enum class PlaybackStatus {
    IDLE, CONNECTING, BUFFERING, PLAYING, PAUSED, STOPPED, COMPLETED, ERROR
}

enum class RepeatMode {
    OFF, ALL, ONE
}

enum class ShuffleMode {
    OFF, ON, SMART
}

@Serializable
data class EqualizerPreset(
    val name: String,
    val bands: List<Float>,
    val isCustom: Boolean = false
) {
    companion object {
        val FLAT = EqualizerPreset("Flat", List(10) { 0f })
        val BASS_BOOST = EqualizerPreset("Bass Boost", listOf(6f, 4f, 2f, 1f, 0f, -1f, -2f, -3f, -4f, -5f))
        val TREBLE_BOOST = EqualizerPreset("Treble Boost", listOf(-5f, -4f, -3f, -2f, -1f, 0f, 1f, 2f, 3f, 4f))
        val VOCAL_BOOST = EqualizerPreset("Vocal Boost", listOf(-2f, 0f, 2f, 4f, 6f, 4f, 2f, 0f, -2f, -4f))
        val CLASSICAL = EqualizerPreset("Classical", listOf(3f, 2f, 1f, 0f, -1f, -1f, 0f, 1f, 2f, 3f))
        val ROCK = EqualizerPreset("Rock", listOf(4f, 3f, 1f, -2f, -3f, -2f, 0f, 2f, 4f, 5f))
        val POP = EqualizerPreset("Pop", listOf(1f, 2f, 3f, 2f, 1f, 0f, -1f, -1f, 0f, 1f))
        val JAZZ = EqualizerPreset("Jazz", listOf(3f, 2f, 1f, 0f, 1f, 2f, 2f, 1f, 0f, -1f))
        val ELECTRONIC = EqualizerPreset("Electronic", listOf(4f, 3f, 2f, 0f, -1f, -1f, 0f, 2f, 3f, 4f))
        val HIP_HOP = EqualizerPreset("Hip Hop", listOf(5f, 4f, 2f, 0f, -2f, -3f, -2f, 0f, 2f, 3f))
    }
}

data class QueueState(
    val tracks: List<Track> = emptyList(),
    val currentIndex: Int = -1,
    val history: List<Track> = emptyList(),
    val shuffleOrder: List<Int> = emptyList()
)
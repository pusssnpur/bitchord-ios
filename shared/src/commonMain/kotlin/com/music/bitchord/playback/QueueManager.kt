package com.music.bitchord.playback

import com.music.bitchord.data.model.Track
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

interface QueueManager {
    val queueState: StateFlow<QueueState>
    
    fun getQueue(): List<Track>
    fun getCurrentTrack(): Track?
    fun getCurrentIndex(): Int
    fun getHistory(): List<Track>
    fun getUpNext(limit: Int = 10): List<Track>
    
    fun playAt(index: Int)
    fun moveToIndex(fromIndex: Int, toIndex: Int)
    fun removeAt(index: Int)
    fun clear()
    fun shuffle()
    fun unshuffle()
    fun setRepeatMode(mode: RepeatMode)
    fun setShuffleMode(mode: ShuffleMode)
    
    // Automix
    fun enableAutomix(enabled: Boolean)
    fun setCrossfadeDuration(ms: Int)
    fun setTransitionPolicy(policy: TransitionPolicy)
    
    // Smart queue
    fun addRecommendations(basedOn: Track, count: Int = 10)
    fun addSimilarTracks(to: Track, count: Int = 5)
}

enum class TransitionPolicy {
    NONE, CROSSFADE, BEAT_MATCH, HARMONIC, SMART
}

data class AutomixConfig(
    val enabled: Boolean = false,
    val crossfadeDuration: Int = 8000, // ms
    val transitionPolicy: TransitionPolicy = TransitionPolicy.SMART,
    val beatMatchTolerance: Float = 0.05f, // 5% BPM tolerance
    val harmonicMixingEnabled: Boolean = true,
    val vocalDetectionEnabled: Boolean = true,
    val minimumOverlap: Int = 4000, // ms
    val maximumOverlap: Int = 16000 // ms
)
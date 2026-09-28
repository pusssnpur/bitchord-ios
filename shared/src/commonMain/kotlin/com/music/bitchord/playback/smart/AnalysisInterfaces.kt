package com.music.bitchord.playback.smart

import com.music.bitchord.data.model.Track
import kotlinx.coroutines.flow.Flow

interface AnalysisStore {
    suspend fun getAnalysis(trackId: String): TrackAnalysis?
    suspend fun putAnalysis(analysis: TrackAnalysis)
    suspend fun removeAnalysis(trackId: String)
    suspend fun clear()
    fun getAllAnalyses(): Flow<List<TrackAnalysis>>
    fun getAnalysisSize(): Long
}

interface TrackAnalyzer {
    suspend fun analyze(track: Track, audioSource: AudioSource): TrackAnalysis
    suspend fun analyzeIncremental(trackId: String, audioSource: AudioSource, existingAnalysis: TrackAnalysis): TrackAnalysis
    fun supportsFormat(format: String): Boolean
}

interface AudioSource {
    val sampleRate: Int
    val channels: Int
    val duration: Double
    suspend fun readSamples(buffer: FloatArray, offset: Long, length: Int): Int
    suspend fun seek(time: Double)
    fun close()
}

interface BeatTracker {
    suspend fun track(audioSource: AudioSource): List<Beat>
    suspend fun trackDownbeats(audioSource: AudioSource, beats: List<Beat>): List<Downbeat>
}

interface VocalTracker {
    suspend fun detectVocals(audioSource: AudioSource): List<VocalSegment>
    suspend fun separateVocals(audioSource: AudioSource): VocalSeparationResult
}

@Serializable
data class VocalSeparationResult(
    val vocalPath: String,
    val instrumentalPath: String,
    val quality: Float
)

interface TransitionPlanner {
    suspend fun planTransition(
        from: TrackAnalysis,
        to: TrackAnalysis,
        config: AutomixConfig
    ): TransitionPlan
}
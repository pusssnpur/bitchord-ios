package com.music.bitchord.playback.smart

import kotlinx.serialization.Serializable

@Serializable
data class TrackAnalysis(
    val trackId: String,
    val duration: Double,
    val sampleRate: Int,
    val channels: Int,
    val beats: List<Beat>,
    val downbeats: List<Downbeat>,
    val tempo: TempoAnalysis,
    val vocalSegments: List<VocalSegment>,
    val key: KeyAnalysis,
    val loudness: LoudnessAnalysis,
    val spectralFeatures: SpectralFeatures,
    val structure: TrackStructure,
    val analyzedAt: Long
)

@Serializable
data class Beat(
    val time: Double,
    val confidence: Float,
    val bpm: Float
)

@Serializable
data class Downbeat(
    val time: Double,
    val confidence: Float,
    val barNumber: Int
)

@Serializable
data class TempoAnalysis(
    val bpm: Float,
    val confidence: Float,
    val bpmHistory: List<BpmPoint>,
    val isVariable: Boolean
)

@Serializable
data class BpmPoint(
    val time: Double,
    val bpm: Float
)

@Serializable
data class VocalSegment(
    val startTime: Double,
    val endTime: Double,
    val confidence: Float,
    val type: VocalType
)

@Serializable
enum class VocalType {
    MAIN_VOCAL, BACKING_VOCAL, RAP, SPOKEN, INSTRUMENTAL
}

@Serializable
data class KeyAnalysis(
    val key: MusicalKey,
    val scale: Scale,
    val confidence: Float,
    val keyChanges: List<KeyChange>
)

@Serializable
enum class MusicalKey {
    C, C_SHARP, D, D_SHARP, E, F, F_SHARP, G, G_SHARP, A, A_SHARP, B
}

@Serializable
enum class Scale {
    MAJOR, MINOR, DORIAN, PHRYGIAN, LYDIAN, MIXOLYDIAN, LOCRIAN
}

@Serializable
data class KeyChange(
    val time: Double,
    val key: MusicalKey,
    val scale: Scale,
    val confidence: Float
)

@Serializable
data class LoudnessAnalysis(
    val integratedLufs: Float,
    val truePeak: Float,
    val lra: Float, // Loudness Range
    val shortTermLufs: List<Float>,
    val momentaryLufs: List<Float>
)

@Serializable
data class SpectralFeatures(
    val centroidMean: Float,
    val centroidStd: Float,
    val rolloffMean: Float,
    val fluxMean: Float,
    val flatnessMean: Float,
    val contrastMean: Float,
    val mfcc: List<List<Float>> // 13 coefficients over time
)

@Serializable
data class TrackStructure(
    val sections: List<Section>,
    val introEnd: Double?,
    val outroStart: Double?
)

@Serializable
data class Section(
    val startTime: Double,
    val endTime: Double,
    val label: SectionLabel,
    val confidence: Float,
    val energy: Float
)

@Serializable
enum class SectionLabel {
    INTRO, VERSE, CHORUS, BRIDGE, OUTRO, SOLO, PRE_CHORUS, POST_CHORUS, INTERLUDE, DROP, BUILDUP, BREAKDOWN
}

@Serializable
data class TransitionPlan(
    val fromTrackId: String,
    val toTrackId: String,
    val fromOutroStart: Double,
    val toIntroEnd: Double,
    val crossfadeDuration: Int,
    val transitionType: TransitionType,
    val tempoAdjustment: Float, // ratio
    val keyCompatibility: Float, // 0-1
    val vocalOverlap: Boolean,
    val confidence: Float
)

@Serializable
enum class TransitionType {
    SIMPLE_CROSSFADE, BEAT_MATCHED, HARMONIC, VOCAL_AWARE, EXTENDED_BLEND, ECHO_OUT, FILTER_SWEEP
}
package com.music.bitchord.data.youtube

import com.music.bitchord.data.model.*
import com.music.bitchord.data.repository.MediaRepository
import com.music.bitchord.data.repository.Result
import kotlinx.coroutines.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*
import java.net.URLDecoder
import java.security.MessageDigest
import java.util.*

class NewPipeStreamExtractor(
    private val config: YtMusicConfig
) : StreamExtractor {

    private val cipherCache = mutableMapOf<String, String>()
    private val nParameterCache = mutableMapOf<String, String>()

    override suspend fun resolveStreamUrl(videoId: String, quality: AudioQuality): Result<String> {
        return try {
            val manifest = resolveManifest(videoId).getOrThrow()
            val format = selectBestFormat(manifest, quality)
            Result.success(format.url)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun resolveManifest(videoId: String): Result<StreamManifest> {
        return try {
            val playerResponse = fetchPlayerResponse(videoId)
            val formats = parseStreamingData(playerResponse)
            val adaptiveFormats = parseAdaptiveFormats(playerResponse)
            
            val allFormats = formats + adaptiveFormats
            val urls = mutableMapOf<AudioQuality, String>()
            
            for (format in allFormats) {
                val quality = mapItagToQuality(format.itag)
                val url = decryptUrl(format)
                if (url != null) {
                    urls[quality] = url
                }
            }
            
            val manifest = StreamManifest(
                urls = urls,
                format = StreamFormat.MP4,
                expiresAt = Instant.now().plus(6.hours)
            )
            Result.success(manifest)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // MARK: - Player Response Fetching
    private suspend fun fetchPlayerResponse(videoId: String): JsonElement {
        // This would normally fetch from youtubei/v1/player or use the inner tube API
        // For now, return a mock response structure
        return JsonParser.parseString("""
            {
                "streamingData": {
                    "formats": [],
                    "adaptiveFormats": []
                },
                "playabilityStatus": {
                    "status": "OK"
                }
            }
        """)
    }

    // MARK: - Format Parsing
    private fun parseStreamingData(response: JsonElement): List<StreamFormatInfo> {
        val formats = mutableListOf<StreamFormatInfo>()
        val streamingData = response.jsonObject["streamingData"]?.jsonObject
        val formatArray = streamingData?.get("formats")?.jsonArray
        
        formatArray?.forEach { formatObj ->
            val format = parseFormat(formatObj)
            format?.let { formats.add(it) }
        }
        return formats
    }

    private fun parseAdaptiveFormats(response: JsonElement): List<StreamFormatInfo> {
        val formats = mutableListOf<StreamFormatInfo>()
        val streamingData = response.jsonObject["streamingData"]?.jsonObject
        val formatArray = streamingData?.get("adaptiveFormats")?.jsonArray
        
        formatArray?.forEach { formatObj ->
            val format = parseFormat(formatObj)
            format?.let { formats.add(it) }
        }
        return formats
    }

    private fun parseFormat(obj: JsonElement): StreamFormatInfo? {
        val jsonObject = obj.jsonObject
        val itag = jsonObject["itag"]?.jsonPrimitive?.int ?: return null
        val url = jsonObject["url"]?.jsonPrimitive?.content
        val signatureCipher = jsonObject["signatureCipher"]?.jsonPrimitive?.content
        val mimeType = jsonObject["mimeType"]?.jsonPrimitive?.content ?: ""
        val bitrate = jsonObject["bitrate"]?.jsonPrimitive?.int ?: 0
        val audioQuality = jsonObject["audioQuality"]?.jsonPrimitive?.content ?: ""
        val approxDurationMs = jsonObject["approxDurationMs"]?.jsonPrimitive?.content?.toLong() ?: 0
        
        var finalUrl = url
        if (finalUrl == null && signatureCipher != null) {
            finalUrl = decryptSignatureCipher(signatureCipher)
        }
        
        return StreamFormatInfo(
            itag = itag,
            url = finalUrl,
            mimeType = mimeType,
            bitrate = bitrate,
            audioQuality = audioQuality,
            durationMs = approxDurationMs,
            signatureCipher = signatureCipher
        )
    }

    // MARK: - URL Decryption
    private fun decryptUrl(format: StreamFormatInfo): String? {
        return format.url
    }

    private fun decryptSignatureCipher(cipher: String): String {
        val params = URLDecoder.decode(cipher, "UTF-8").split("&").associate { 
            it.split("=").let { (k, v) -> k to v } 
        }
        
        val url = params["url"] ?: return ""
        val signature = params["s"] ?: params["sig"] ?: return url
        val playerUrl = params["sp"] ?: "signature"
        
        // In real implementation, this would:
        // 1. Fetch the player JS
        // 2. Extract the decryption algorithm
        // 3. Apply it to the signature
        // For now, return the URL with a placeholder
        return "$url&$playerUrl=$signature"
    }

    private fun selectBestFormat(manifest: StreamManifest, quality: AudioQuality): StreamFormatInfo {
        val preferredOrder = when (quality) {
            AudioQuality.LOW -> listOf(AudioQuality.LOW, AudioQuality.STANDARD, AudioQuality.HIGH)
            AudioQuality.STANDARD -> listOf(AudioQuality.STANDARD, AudioQuality.HIGH, AudioQuality.LOW)
            AudioQuality.HIGH -> listOf(AudioQuality.HIGH, AudioQuality.LOSSLESS, AudioQuality.STANDARD)
            AudioQuality.LOSSLESS -> listOf(AudioQuality.LOSSLESS, AudioQuality.HI_RES, AudioQuality.HIGH)
            AudioQuality.HI_RES -> listOf(AudioQuality.HI_RES, AudioQuality.LOSSLESS, AudioQuality.HIGH)
        }
        
        for (q in preferredOrder) {
            manifest.urls[q]?.let { return StreamFormatInfo(itag = 0, url = it, mimeType = "", bitrate = 0, audioQuality = "", durationMs = 0) }
        }
        return manifest.urls.values.firstOrNull()?.let { StreamFormatInfo(itag = 0, url = it, mimeType = "", bitrate = 0, audioQuality = "", durationMs = 0) }
            ?: throw IllegalStateException("No formats available")
    }

    private fun mapItagToQuality(itag: Int): AudioQuality {
        return when (itag) {
            139, 249, 250 -> AudioQuality.LOW
            140, 251 -> AudioQuality.STANDARD
            141, 258, 328 -> AudioQuality.HIGH
            338, 380 -> AudioQuality.LOSSLESS
            else -> AudioQuality.STANDARD
        }
    }
}

// MARK: - Data Classes
@Serializable
data class StreamFormatInfo(
    val itag: Int,
    val url: String?,
    val mimeType: String,
    val bitrate: Int,
    val audioQuality: String,
    val durationMs: Long,
    val signatureCipher: String? = null
) {
    constructor(itag: Int, url: String, mimeType: String, bitrate: Int, audioQuality: String, durationMs: Long) : this(
        itag = itag,
        url = url,
        mimeType = mimeType,
        bitrate = bitrate,
        audioQuality = audioQuality,
        durationMs = durationMs
    )
}

// MARK: - Player JS Decryption (simplified)
class PlayerJsDecryptor {
    companion object {
        private const val PLAYER_JS_URL = "https://www.youtube.com/s/player/.../player.js"
        private var cachedAlgorithm: DecryptionAlgorithm? = null
        private var cacheTime: Long = 0
        
        fun decrypt(signature: String, playerUrl: String): String {
            // Real implementation would:
            // 1. Fetch player JS if not cached
            // 2. Extract transformation functions
            // 3. Apply reverse transformations
            return signature // Placeholder
        }
    }
    
    private data class DecryptionAlgorithm(
        val operations: List<TransformOp>
    )
    
    private sealed class TransformOp {
        data class Reverse(val n: Int) : TransformOp()
        data class Swap(val n: Int) : TransformOp()
        data class Slice(val n: Int) : TransformOp()
    }
}
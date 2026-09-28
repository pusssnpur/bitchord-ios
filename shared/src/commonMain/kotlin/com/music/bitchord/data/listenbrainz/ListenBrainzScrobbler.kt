package com.music.bitchord.data.listenbrainz

import com.music.bitchord.data.model.Track
import com.music.bitchord.data.repository.Result
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.http.*
import kotlinx.coroutines.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*

class ListenBrainzScrobbler(
    private val client: HttpClient,
    private val config: ListenBrainzConfig,
    private val tokenProvider: ListenBrainzTokenProvider
) {

    private val baseUrl = "https://api.listenbrainz.org/1"
    private val submitCache = mutableListOf<ListenBrainzSubmit>()
    private val cacheLock = Mutex()
    private var isSubmitting = false

    suspend fun submitListens(track: Track, listenedAt: Long = System.currentTimeMillis() / 1000): Result<Unit> {
        return try {
            val token = tokenProvider.getToken() ?: return Result.failure(IllegalStateException("Not authenticated"))
            
            val submit = ListenBrainzSubmit(
                listenedAt = listenedAt,
                trackMetadata = ListenBrainzTrackMetadata(
                    trackName = track.title,
                    artistName = track.artistName,
                    releaseName = track.albumName,
                    additionalInfo = ListenBrainzAdditionalInfo(
                        releaseMbid = null,
                        recordingMbid = null,
                        trackNumber = null,
                        duration = track.duration.toLong(),
                        musicbrainzId = null,
                        isrc = null
                    )
                )
            )
            
            cacheLock.withLock {
                submitCache.add(submit)
                if (submitCache.size >= 50) {
                    flushCache()
                }
            }
            
            sendSubmits(listOf(submit), token)
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun submitPlayingNow(track: Track): Result<Unit> {
        return try {
            val token = tokenProvider.getToken() ?: return Result.failure(IllegalStateException("Not authenticated"))
            
            val payload = json {
                obj("listens" to jsonArray(
                    json {
                        obj("track_metadata" to json {
                            obj("track_name" to track.title)
                            obj("artist_name" to track.artistName)
                            obj("release_name" to track.albumName ?: "")
                            obj("additional_info" to json {
                                obj("duration" to track.duration.toLong())
                            })
                        })
                    }
                ))
            }
            
            client.post("$baseUrl/submit-playing-now") {
                headers["Authorization"] = "Token $token"
                contentType(ContentType.Application.Json)
                setBody(payload)
            }
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun authenticate(username: String, password: String): Result<String> {
        return try {
            val payload = json {
                obj("user_name" to username)
                obj("password" to password)
            }
            val response = client.post("$baseUrl/auth") {
                contentType(ContentType.Application.Json)
                setBody(payload)
            }
            val json = Json.parseToJsonElement(response.body())
            val token = json.jsonObject["token"]?.jsonPrimitive?.content ?: throw IllegalStateException("No token")
            tokenProvider.saveToken(token)
            Result.success(token)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private suspend fun sendSubmits(submits: List<ListenBrainzSubmit>, token: String) {
        val payload = json {
            obj("listens" to jsonArray(
                submits.map { submit ->
                    json {
                        obj("listened_at" to submit.listenedAt)
                        obj("track_metadata" to json {
                            obj("track_name" to submit.trackMetadata.trackName)
                            obj("artist_name" to submit.trackMetadata.artistName)
                            obj("release_name" to submit.trackMetadata.releaseName ?: "")
                            obj("additional_info" to json {
                                obj("duration" to submit.trackMetadata.additionalInfo.duration)
                            })
                        })
                    }
                })
            })
            
            client.post("$baseUrl/submit-listens") {
                headers["Authorization"] = "Token $token"
                contentType(ContentType.Application.Json)
                setBody(payload)
            }
    }

    private suspend fun flushCache() {
        cacheLock.withLock {
            if (submitCache.isEmpty() || isSubmitting) return
            isSubmitting = true
            val token = tokenProvider.getToken()
            val entries = submitCache.toList()
            submitCache.clear()
            isSubmitting = false
            
            token?.let { token ->
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        sendSubmits(entries, token)
                    } catch (e: Exception) {
                        cacheLock.withLock { submitCache.addAll(0, entries) }
                    }
                }
            }
        }
    }
}

// MARK: - Data Classes
@Serializable
data class ListenBrainzConfig(
    val userAgent: String = "BitChord/1.6"
)

@Serializable
data class ListenBrainzSubmit(
    val listenedAt: Long,
    val trackMetadata: ListenBrainzTrackMetadata
)

@Serializable
data class ListenBrainzTrackMetadata(
    val trackName: String,
    val artistName: String,
    val releaseName: String?,
    val additionalInfo: ListenBrainzAdditionalInfo
)

@Serializable
data class ListenBrainzAdditionalInfo(
    val releaseMbid: String?,
    val recordingMbid: String?,
    val trackNumber: Int?,
    val duration: Long,
    val musicbrainzId: String?,
    val isrc: String?
)

interface ListenBrainzTokenProvider {
    fun getToken(): String?
    suspend fun saveToken(token: String)
    suspend fun clearToken()
}
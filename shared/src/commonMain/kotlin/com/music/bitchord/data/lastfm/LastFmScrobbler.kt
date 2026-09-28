package com.music.bitchord.data.lastfm

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
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

class LastFmScrobbler(
    private val client: HttpClient,
    private val config: LastFmConfig,
    private val sessionProvider: LastFmSessionProvider
) {

    private val apiUrl = "https://ws.audioscrobbler.com/2.0/"
    private val scrobbleCache = mutableListOf<ScrobbleEntry>()
    private val cacheLock = Mutex()
    private var isScrobbling = false

    suspend fun scrobble(track: Track, timestamp: Long = System.currentTimeMillis() / 1000): Result<Unit> {
        return try {
            val session = sessionProvider.getSession() ?: return Result.failure(IllegalStateException("Not authenticated"))
            
            val entry = ScrobbleEntry(
                artist = track.artistName,
                track = track.title,
                album = track.albumName,
                albumArtist = track.artists.firstOrNull()?.name,
                timestamp = timestamp,
                duration = track.duration.toLong(),
                trackNumber = null,
                mbid = null
            )
            
            cacheLock.withLock {
                scrobbleCache.add(entry)
                if (scrobbleCache.size >= 50) {
                    flushCache()
                }
            }
            
            // Also send immediately for real-time feel
            sendScrobble(entry, session.key)
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun updateNowPlaying(track: Track): Result<Unit> {
        return try {
            val session = sessionProvider.getSession() ?: return Result.failure(IllegalStateException("Not authenticated"))
            
            val params = buildParams("track.updateNowPlaying", mapOf(
                "artist" to track.artistName,
                "track" to track.title,
                "album" to track.albumName ?: "",
                "duration" to track.duration.toLong().toString(),
                "sk" to session.key
            ))
            
            val response = client.post(apiUrl) {
                contentType(ContentType.Application.FormUrlEncoded)
                setBody(params)
            }
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun authenticate(username: String, password: String): Result<LastFmSession> {
        return try {
            val authToken = getAuthToken()
            // User would need to authorize at: https://www.last.fm/api/auth/?api_key=${config.apiKey}&token=$authToken
            // Then we exchange token for session
            val session = getSession(authToken)
            Result.success(session)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getAuthToken(): String {
        val params = buildParams("auth.getToken", emptyMap())
        val response = client.post(apiUrl) {
            contentType(ContentType.Application.FormUrlEncoded)
            setBody(params)
        }
        val json = Json.parseToJsonElement(response.body())
        return json.jsonObject["token"]?.jsonPrimitive?.content ?: throw IllegalStateException("No token")
    }

    suspend fun getSession(token: String): LastFmSession {
        val params = buildParams("auth.getSession", mapOf("token" to token))
        val response = client.post(apiUrl) {
            contentType(ContentType.Application.FormUrlEncoded)
            setBody(params)
        }
        val json = Json.parseToJsonElement(response.body())
        val sessionObj = json.jsonObject["session"]?.jsonObject
        return LastFmSession(
            name = sessionObj?.get("name")?.jsonPrimitive?.content ?: "",
            key = sessionObj?.get("key")?.jsonPrimitive?.content ?: "",
            subscriber = sessionObj?.get("subscriber")?.jsonPrimitive?.boolean ?: false
        )
    }

    private suspend fun sendScrobble(entry: ScrobbleEntry, sessionKey: String) {
        val params = buildParams("track.scrobble", mapOf(
            "artist[0]" to entry.artist,
            "track[0]" to entry.track,
            "album[0]" to entry.album ?: "",
            "timestamp[0]" to entry.timestamp.toString(),
            "duration[0]" to entry.duration.toString(),
            "sk" to sessionKey
        ))
        
        client.post(apiUrl) {
            contentType(ContentType.Application.FormUrlEncoded)
            setBody(params)
        }
    }

    private suspend fun flushCache() {
        cacheLock.withLock {
            if (scrobbleCache.isEmpty() || isScrobbling) return
            isScrobbling = true
            val session = sessionProvider.getSession()
            val entries = scrobbleCache.toList()
            scrobbleCache.clear()
            isScrobbling = false
            
            session?.let { session ->
                CoroutineScope(Dispatchers.IO).launch {
                    for (entry in entries) {
                        try {
                            sendScrobble(entry, session.key)
                        } catch (e: Exception) {
                            cacheLock.withLock { scrobbleCache.add(0, entry) }
                        }
                    }
                }
            }
        }
    }

    private fun buildParams(method: String, extraParams: Map<String, String>): List<Pair<String, String>> {
        val timestamp = (System.currentTimeMillis() / 1000).toString()
        val params = mutableMapOf<String, String>(
            "method" to method,
            "api_key" to config.apiKey,
            "format" to "json",
            "timestamp" to timestamp
        )
        params.putAll(extraParams)
        
        // Add signature
        val sig = generateSignature(params, config.apiSecret)
        params["api_sig"] = sig
        
        return params.toList()
    }

    private fun generateSignature(params: Map<String, String>, secret: String): String {
        val sorted = params.toList().sortedBy { it.first }
        val stringBuilder = StringBuilder()
        for ((k, v) in sorted) {
            stringBuilder.append(k).append(v)
        }
        stringBuilder.append(secret)
        
        val md = MessageDigest.getInstance("MD5")
        val digest = md.digest(stringBuilder.toString().toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}

// MARK: - Data Classes
@Serializable
data class LastFmConfig(
    val apiKey: String,
    val apiSecret: String
)

@Serializable
data class LastFmSession(
    val name: String,
    val key: String,
    val subscriber: Boolean
)

@Serializable
data class ScrobbleEntry(
    val artist: String,
    val track: String,
    val album: String?,
    val albumArtist: String?,
    val timestamp: Long,
    val duration: Long,
    val trackNumber: Int?,
    val mbid: String?
)

interface LastFmSessionProvider {
    fun getSession(): LastFmSession?
    suspend fun saveSession(session: LastFmSession)
    suspend fun clearSession()
}
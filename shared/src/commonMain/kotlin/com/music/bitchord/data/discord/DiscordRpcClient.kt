package com.music.bitchord.data.discord

import com.music.bitchord.data.model.Track
import io.ktor.client.*
import io.ktor.client.plugins.websockets.*
import io.ktor.client.request.*
import io.ktor.http.*
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*
import java.net.URI

class DiscordRpcClient(
    private val client: HttpClient,
    private val config: DiscordRpcConfig
) : DiscordRpcController {

    private var webSocket: DefaultClientWebSocketSession? = null
    private val sendChannel = Channel<JsonElement>(Channel.UNLIMITED)
    private val heartbeatJob: Job? = null
    private var sequence: Int = -1
    private var sessionId: String? = null
    private var userId: String? = null
    private val reconnectAttempts = 0
    private val maxReconnectAttempts = 5

    override val isConnected = MutableStateFlow(false)

    override suspend fun connect() {
        if (isConnected.value) return
        
        try {
            client.webSocket(config.gatewayUrl) { session ->
                webSocket = session
                session.incoming.consumeEach { frame ->
                    when (frame) {
                        is Frame.Text -> handleMessage(frame.readText())
                        is Frame.Binary -> handleMessage(frame.readBytes().decodeToString())
                        is Frame.Close -> handleClose(frame.closeCode, frame.closeReason)
                    }
                }
            }
        } catch (e: Exception) {
            scheduleReconnect()
        }
    }

    override suspend fun disconnect() {
        heartbeatJob?.cancel()
        webSocket?.close(CloseReason(1000, "Client disconnect"))
        webSocket = null
        isConnected.value = false
        sendChannel.close()
    }

    override suspend fun updatePresence(
        track: Track,
        position: Long,
        duration: Long,
        isPlaying: Boolean
    ) {
        val payload = buildPresencePayload(track, position, duration, isPlaying)
        send(payload)
    }

    override suspend fun clearPresence() {
        val payload = json {
            obj("op" to OpCode.SET_ACTIVITY.ordinal)
            obj("d" to json {
                obj("activity" to JsonNull)
            })
        }
        send(payload)
    }

    // MARK: - Message Handling
    private fun handleMessage(message: String) {
        val json = Json.parseToJsonElement(message)
        val opCode = json.jsonObject["op"]?.jsonPrimitive?.int ?: return
        val opcode = OpCode.values().firstOrNull { it.ordinal == opCode } ?: return
        
        when (opcode) {
            OpCode.HELLO -> {
                val interval = json.jsonObject["d"]?.jsonObject?.get("heartbeat_interval")?.jsonPrimitive?.int ?: 41250
                startHeartbeat(interval.toLong())
                sendIdentify()
            }
            OpCode.READY -> {
                val d = json.jsonObject["d"]?.jsonObject
                sessionId = d?.get("session_id")?.jsonPrimitive?.content
                userId = d?.get("user")?.jsonObject?.get("id")?.jsonPrimitive?.content
                sequence = d?.get("s")?.jsonPrimitive?.int ?: -1
                isConnected.value = true
                reconnectAttempts = 0
            }
            OpCode.HEARTBEAT_ACK -> {
                // Heartbeat acknowledged
            }
            OpCode.DISPATCH -> {
                val event = json.jsonObject["t"]?.jsonPrimitive?.content ?: ""
                sequence = json.jsonObject["s"]?.jsonPrimitive?.int ?: sequence
                when (event) {
                    "READY" -> { /* Already handled */ }
                    "RESUMED" -> { isConnected.value = true }
                    else -> { /* Ignore other events */ }
                }
            }
            OpCode.INVALID_SESSION -> {
                val resumable = json.jsonObject["d"]?.jsonPrimitive?.boolean ?: false
                if (!resumable) {
                    sessionId = null
                    sequence = -1
                }
                scheduleReconnect()
            }
            else -> { /* Ignore */ }
        }
    }

    private fun handleClose(code: Int, reason: String) {
        isConnected.value = false
        scheduleReconnect()
    }

    // MARK: - Heartbeat
    private fun startHeartbeat(intervalMs: Long) {
        CoroutineScope(Dispatchers.IO).launch {
            while (isConnected.value) {
                delay(intervalMs)
                sendHeartbeat()
            }
        }
    }

    private suspend fun sendHeartbeat() {
        val payload = json {
            obj("op" to OpCode.HEARTBEAT.ordinal)
            obj("d" to sequence)
        }
        send(payload)
    }

    // MARK: - Identify
    private suspend fun sendIdentify() {
        val payload = json {
            obj("op" to OpCode.IDENTIFY.ordinal)
            obj("d" to json {
                obj("token" to config.botToken)
                obj("properties" to json {
                    obj("$os" to "linux")
                    obj("$browser" to "BitChord")
                    obj("$device" to "BitChord")
                })
                obj("presence" to json {
                    obj("status" to "online")
                    obj("afk" to false)
                })
                obj("intents" to 0)
            })
        }
        send(payload)
    }

    // MARK: - Presence Building
    private fun buildPresencePayload(
        track: Track,
        position: Long,
        duration: Long,
        isPlaying: Boolean
    ): JsonElement {
        val startTime = System.currentTimeMillis() - position
        val endTime = startTime + duration - position
        
        return json {
            obj("op" to OpCode.SET_ACTIVITY.ordinal)
            obj("d" to json {
                obj("activity" to json {
                    obj("name" to track.title)
                    obj("type" to 2) // LISTENING
                    obj("details" to track.artistName)
                    obj("state" to track.albumName ?: "")
                    obj("timestamps" to json {
                        obj("start" to startTime)
                        obj("end" to endTime)
                    })
                    obj("assets" to json {
                        obj("large_image" to track.thumbnailUrl ?: "")
                        obj("large_text" to track.title)
                        obj("small_image" to "bitchord")
                        obj("small_text" to "BitChord")
                    })
                    obj("buttons" to jsonArray(
                        json { obj("label" to "Play on YouTube Music") obj("url" to "https://music.youtube.com/watch?v=${track.videoId}") }
                    ))
                })
            })
        }
    }

    private suspend fun send(payload: JsonElement) {
        if (!isConnected.value) return
        webSocket?.send(Frame.Text(payload.toString()))
    }

    private fun scheduleReconnect() {
        if (reconnectAttempts >= maxReconnectAttempts) return
        CoroutineScope(Dispatchers.IO).launch {
            delay(5000 * (reconnectAttempts + 1))
            connect()
        }
    }
}

// MARK: - Config
data class DiscordRpcConfig(
    val gatewayUrl: String = "wss://gateway.discord.gg/?v=10&encoding=json",
    val botToken: String = "",
    val clientId: String = "1234567890"
)

enum class OpCode {
    DISPATCH, HEARTBEAT, IDENTIFY, PRESENCE_UPDATE, VOICE_STATE_UPDATE, RESUME, RECONNECT,
    REQUEST_GUILD_MEMBERS, INVALID_SESSION, HELLO, HEARTBEAT_ACK, SET_ACTIVITY
}
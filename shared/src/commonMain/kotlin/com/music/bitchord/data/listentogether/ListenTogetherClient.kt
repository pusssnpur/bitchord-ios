package com.music.bitchord.data.listentogether

import com.music.bitchord.data.model.Track
import com.music.bitchord.data.repository.Result
import io.ktor.client.*
import io.ktor.client.plugins.websockets.*
import io.ktor.client.request.*
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*

class ListenTogetherClient(
    private val client: HttpClient,
    private val config: ListenTogetherConfig,
    private val clock: PartyClock
) : ListenTogetherController {

    private var webSocket: DefaultClientWebSocketSession? = null
    private val sendChannel = Channel<JsonElement>(Channel.UNLIMITED)
    private val incomingMessages = MutableSharedFlow<PartyMessage>(extraBufferCapacity = 100)
    private var currentParty: PartyState? = null
    private var reconnectJob: Job? = null

    override val messages = incomingMessages
    override val partyState = MutableStateFlow<PartyState?>(null)
    override val isConnected = MutableStateFlow(false)

    override suspend fun connect(serverUrl: String, partyCode: String, username: String): Result<PartyState> {
        return try {
            val url = "$serverUrl/ws/party/$partyCode?username=$username"
            client.webSocket(url) { session ->
                webSocket = session
                session.incoming.consumeEach { frame ->
                    when (frame) {
                        is Frame.Text -> handleMessage(frame.readText())
                        is Frame.Close -> handleClose()
                    }
                }
            }
            // Wait for initial state
            val state = waitForInitialState()
            currentParty = state
            partyState.value = state
            isConnected.value = true
            startHeartbeat()
            Result.success(state)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun disconnect() {
        reconnectJob?.cancel()
        webSocket?.close(CloseReason(1000, "Disconnect"))
        webSocket = null
        isConnected.value = false
        currentParty = null
        partyState.value = null
    }

    override suspend fun createParty(serverUrl: String, username: String, settings: PartySettings): Result<PartyState> {
        return try {
            val payload = json {
                obj("username" to username)
                obj("settings" to json {
                    obj("isPublic" to settings.isPublic)
                    obj("maxUsers" to settings.maxUsers)
                    obj("requirePassword" to settings.requirePassword)
                    obj("password" to settings.password ?: "")
                })
            }
            val response = client.post("$serverUrl/api/party/create") {
                contentType(ContentType.Application.Json)
                setBody(payload)
            }
            val json = Json.parseToJsonElement(response.body())
            val partyCode = json.jsonObject["party_code"]?.jsonPrimitive?.content ?: throw IllegalStateException("No party code")
            
            connect(serverUrl, partyCode, username)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun play(track: Track, position: Long): Result<Unit> {
        sendMessage(PartyMessage.Play(track, position, clock.now()))
    }

    override suspend fun pause(): Result<Unit> {
        sendMessage(PartyMessage.Pause(clock.now()))
    }

    override suspend fun seek(position: Long): Result<Unit> {
        sendMessage(PartyMessage.Seek(position, clock.now()))
    }

    override suspend fun next(): Result<Unit> {
        sendMessage(PartyMessage.Next(clock.now()))
    }

    override suspend fun previous(): Result<Unit> {
        sendMessage(PartyMessage.Previous(clock.now()))
    }

    override suspend fun setVolume(volume: Float): Result<Unit> {
        sendMessage(PartyMessage.VolumeChange(volume, clock.now()))
    }

    override suspend fun sendChatMessage(text: String): Result<Unit> {
        sendMessage(PartyMessage.Chat(text, clock.now()))
    }

    override suspend fun voteSkip(): Result<Unit> {
        sendMessage(PartyMessage.VoteSkip(clock.now()))
    }

    override suspend fun addToQueue(track: Track): Result<Unit> {
        sendMessage(PartyMessage.QueueAdd(track, clock.now()))
    }

    override suspend fun removeFromQueue(index: Int): Result<Unit> {
        sendMessage(PartyMessage.QueueRemove(index, clock.now()))
    }

    override suspend fun reorderQueue(fromIndex: Int, toIndex: Int): Result<Unit> {
        sendMessage(PartyMessage.QueueReorder(fromIndex, toIndex, clock.now()))
    }

    // MARK: - Private
    private suspend fun handleMessage(text: String) {
        val message = Json.decodeFromString<PartyMessage>(text)
        incomingMessages.tryEmit(message)
        
        when (message) {
            is PartyMessage.StateSync -> {
                currentParty = message.state
                partyState.value = message.state
            }
            is PartyMessage.UserJoined -> {
                currentParty?.let { party ->
                    partyState.value = party.copy(users = party.users + message.user)
                }
            }
            is PartyMessage.UserLeft -> {
                currentParty?.let { party ->
                    partyState.value = party.copy(users = party.users.filter { it.id != message.userId })
                }
            }
            is PartyMessage.QueueUpdate -> {
                currentParty?.let { party ->
                    partyState.value = party.copy(queue = message.queue)
                }
            }
            else -> { /* Other messages handled via flow */ }
        }
    }

    private fun handleClose() {
        isConnected.value = false
        scheduleReconnect()
    }

    private suspend fun sendMessage(message: PartyMessage) {
        webSocket?.send(Frame.Text(Json.encodeToString(message)))
    }

    private suspend fun waitForInitialState(): PartyState {
        return incomingMessages.first { it is PartyMessage.StateSync } as PartyMessage.StateSync).state
    }

    private fun startHeartbeat() {
        reconnectJob = CoroutineScope(Dispatchers.IO).launch {
            while (isConnected.value) {
                delay(30000)
                sendMessage(PartyMessage.Ping(clock.now()))
            }
        }
    }

    private fun scheduleReconnect() {
        reconnectJob = CoroutineScope(Dispatchers.IO).launch {
            delay(5000)
            currentParty?.let { party ->
                connect(config.serverUrl, party.code, party.currentUser?.name ?: "Unknown")
            }
        }
    }
}

// MARK: - Models
@Serializable
data class ListenTogetherConfig(
    val serverUrl: String = "https://party.bitchord.app"
)

@Serializable
data class PartySettings(
    val isPublic: Boolean = true,
    val maxUsers: Int = 50,
    val requirePassword: Boolean = false,
    val password: String? = null
)

@Serializable
data class PartyState(
    val code: String,
    val hostId: String,
    val currentUser: PartyUser?,
    val users: List<PartyUser> = emptyList(),
    val queue: List<QueuedTrack> = emptyList(),
    val currentTrack: QueuedTrack? = null,
    val playbackState: PlaybackState = PlaybackState.PAUSED,
    val position: Long = 0,
    val volume: Float = 1.0f,
    val settings: PartySettings = PartySettings()
)

@Serializable
data class PartyUser(
    val id: String,
    val name: String,
    val avatarUrl: String? = null,
    val isHost: Boolean = false,
    val isConnected: Boolean = true,
    val joinedAt: Long = System.currentTimeMillis()
)

@Serializable
data class QueuedTrack(
    val id: String,
    val track: Track,
    val addedBy: String,
    val addedAt: Long,
    val votes: Int = 0
)

enum class PlaybackState {
    PLAYING, PAUSED, BUFFERING, ENDED
}

@Serializable
sealed class PartyMessage {
    @Serializable data class StateSync(val state: PartyState) : PartyMessage()
    @Serializable data class Play(val track: Track, val position: Long, val serverTime: Long) : PartyMessage()
    @Serializable data class Pause(val serverTime: Long) : PartyMessage()
    @Serializable data class Seek(val position: Long, val serverTime: Long) : PartyMessage()
    @Serializable data class Next(val serverTime: Long) : PartyMessage()
    @Serializable data class Previous(val serverTime: Long) : PartyMessage()
    @Serializable data class VolumeChange(val volume: Float, val serverTime: Long) : PartyMessage()
    @Serializable data class Chat(val text: String, val serverTime: Long) : PartyMessage()
    @Serializable data class VoteSkip(val serverTime: Long) : PartyMessage()
    @Serializable data class QueueAdd(val track: Track, val serverTime: Long) : PartyMessage()
    @Serializable data class QueueRemove(val index: Int, val serverTime: Long) : PartyMessage()
    @Serializable data class QueueReorder(val fromIndex: Int, val toIndex: Int, val serverTime: Long) : PartyMessage()
    @Serializable data class QueueUpdate(val queue: List<QueuedTrack>) : PartyMessage()
    @Serializable data class UserJoined(val user: PartyUser) : PartyMessage()
    @Serializable data class UserLeft(val userId: String) : PartyMessage()
    @Serializable data class Ping(val serverTime: Long) : PartyMessage()
    @Serializable data class Pong(val serverTime: Long) : PartyMessage()
    @Serializable data class Error(val message: String) : PartyMessage()
}

interface PartyClock {
    val now: Long
    fun sync(serverTime: Long)
}

class SystemPartyClock : PartyClock {
    private var offset: Long = 0
    
    override val now: Long
        get() = System.currentTimeMillis() + offset
    
    override fun sync(serverTime: Long) {
        offset = serverTime - System.currentTimeMillis()
    }
}

interface ListenTogetherController {
    val messages: MutableSharedFlow<PartyMessage>
    val partyState: MutableStateFlow<PartyState?>
    val isConnected: MutableStateFlow<Boolean>
    
    suspend fun connect(serverUrl: String, partyCode: String, username: String): Result<PartyState>
    suspend fun disconnect()
    suspend fun createParty(serverUrl: String, username: String, settings: PartySettings): Result<PartyState>
    suspend fun play(track: Track, position: Long): Result<Unit>
    suspend fun pause(): Result<Unit>
    suspend fun seek(position: Long): Result<Unit>
    suspend fun next(): Result<Unit>
    suspend fun previous(): Result<Unit>
    suspend fun setVolume(volume: Float): Result<Unit>
    suspend fun sendChatMessage(text: String): Result<Unit>
    suspend fun voteSkip(): Result<Unit>
    suspend fun addToQueue(track: Track): Result<Unit>
    suspend fun removeFromQueue(index: Int): Result<Unit>
    suspend fun reorderQueue(fromIndex: Int, toIndex: Int): Result<Unit>
}
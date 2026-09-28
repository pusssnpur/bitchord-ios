package com.music.bitchord.auth

import com.music.bitchord.data.model.UserProfile
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable

@Serializable
data class AuthTokens(
    val accessToken: String,
    val refreshToken: String?,
    val expiresAt: Long?,
    val tokenType: String = "Bearer",
    val scope: String? = null
)

@Serializable
data class AccountSession(
    val id: String,
    val provider: AuthProvider,
    val email: String,
    val name: String,
    val avatarUrl: String?,
    val tokens: AuthTokens,
    val createdAt: Long,
    val lastUsedAt: Long
)

enum class AuthProvider {
    GOOGLE, YOUTUBE_MUSIC, DISCORD, LASTFM, LISTENBRAINZ
}

interface AuthRepository {
    val currentSession: StateFlow<AccountSession?>
    val isAuthenticated: StateFlow<Boolean>
    val userProfile: MutableStateFlow<UserProfile?>

    suspend fun signInWithGoogle(): Result<AccountSession>
    suspend fun signInWithYouTubeMusic(): Result<AccountSession>
    suspend fun signInWithDiscord(): Result<AccountSession>
    suspend fun signInWithLastFm(): Result<AccountSession>
    suspend fun signInWithListenBrainz(): Result<AccountSession>
    
    suspend fun refreshTokens(session: AccountSession): Result<AuthTokens>
    suspend fun signOut(sessionId: String): Result<Unit>
    suspend fun signOutAll(): Result<Unit>
    suspend fun getSessions(): Result<List<AccountSession>>
    suspend fun revokeSession(sessionId: String): Result<Unit>
}

interface DiscordRpcController {
    val isConnected: StateFlow<Boolean>
    suspend fun connect()
    suspend fun disconnect()
    suspend fun updatePresence(track: com.music.bitchord.data.model.Track, position: Long, duration: Long, isPlaying: Boolean)
    suspend fun clearPresence()
}
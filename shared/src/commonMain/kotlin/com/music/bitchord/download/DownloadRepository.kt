package com.music.bitchord.download

import com.music.bitchord.data.model.*
import kotlinx.coroutines.flow.Flow

interface DownloadRepository {
    val activeDownloads: Flow<List<DownloadTask>>
    val completedDownloads: Flow<List<DownloadTask>>
    val downloadProgress: Flow<Map<String, Float>>

    suspend fun queueDownload(trackId: String, quality: AudioQuality): Result<DownloadTask>
    suspend fun pauseDownload(taskId: String): Result<Unit>
    suspend fun resumeDownload(taskId: String): Result<Unit>
    suspend fun cancelDownload(taskId: String): Result<Unit>
    suspend fun retryDownload(taskId: String): Result<Unit>
    suspend fun removeDownload(taskId: String): Result<Unit>
    suspend fun clearCompleted(): Result<Unit>

    suspend fun getDownloadInfo(trackId: String): Result<DownloadInfo?>
    suspend fun getLocalPath(trackId: String): Result<String?>
    
    // Metadata tagging
    suspend fun tagDownloadedFile(task: DownloadTask, metadata: TrackMetadata): Result<Unit>
    suspend fun embedArtwork(task: DownloadTask, artwork: ByteArray): Result<Unit>
    suspend fun embedLyrics(task: DownloadTask, lyrics: Lyrics): Result<Unit>
    
    // Storage management
    suspend fun getStorageUsage(): Result<StorageUsage>
    suspend fun setMaxStorageSize(bytes: Long): Result<Unit>
    suspend fun cleanupOrphanedFiles(): Result<Int>
}

@Serializable
data class StorageUsage(
    val totalBytes: Long,
    val usedBytes: Long,
    val availableBytes: Long,
    val downloadCount: Int
)
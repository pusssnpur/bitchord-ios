package com.music.bitchord.data.webdav

import com.music.bitchord.data.repository.Result
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.plugins.auth.*
import io.ktor.client.plugins.auth.providers.*
import io.ktor.client.request.*
import io.ktor.http.*
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*
import java.io.InputStream
import java.net.URLEncoder

class WebDavClient(
    private val client: HttpClient,
    private val config: WebDavConfig
) {

    private val baseUrl = config.url.trimEnd('/')

    suspend fun testConnection(): Result<Unit> {
        return try {
            client.request(HttpMethod.PropFind, baseUrl) {
                headers["Depth"] = "0"
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun listFiles(path: String): Result<List<WebDavFile>> {
        return try {
            val encodedPath = encodePath(path)
            val response = client.request(HttpMethod.PropFind, "$baseUrl$encodedPath") {
                headers["Depth"] = "1"
                headers["Content-Type"] = "application/xml"
            }
            val xml = response.bodyAsText()
            val files = parseDirectoryListing(xml, path)
            Result.success(files)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun downloadFile(path: String, destination: java.io.File): Result<Unit> {
        return try {
            val encodedPath = encodePath(path)
            client.get("$baseUrl$encodedPath") {
                headers["Accept"] = "*/*"
            }.bodyAsStream().use { input ->
                destination.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun uploadFile(localFile: java.io.File, remotePath: String): Result<Unit> {
        return try {
            val encodedPath = encodePath(remotePath)
            // Ensure parent directories exist
            ensureParentDirectories(remotePath)
            
            client.put("$baseUrl$encodedPath") {
                headers["Content-Type"] = getMimeType(localFile.extension)
                setBody(localFile.readBytes())
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun createDirectory(path: String): Result<Unit> {
        return try {
            val encodedPath = encodePath(path)
            client.request(HttpMethod.MkCol, "$baseUrl$encodedPath")
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun deleteFile(path: String): Result<Unit> {
        return try {
            val encodedPath = encodePath(path)
            client.delete("$baseUrl$encodedPath")
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun moveFile(fromPath: String, toPath: String): Result<Unit> {
        return try {
            val encodedFrom = encodePath(fromPath)
            val encodedTo = encodePath(toPath)
            client.request(HttpMethod.Move, "$baseUrl$encodedFrom") {
                headers["Destination"] = "$baseUrl$encodedTo"
                headers["Overwrite"] = "T"
            }
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getFileInfo(path: String): Result<WebDavFile> {
        return try {
            val encodedPath = encodePath(path)
            val response = client.request(HttpMethod.PropFind, "$baseUrl$encodedPath") {
                headers["Depth"] = "0"
            }
            val xml = response.bodyAsText()
            val file = parseFileInfo(xml, path)
            Result.success(file)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // MARK: - Sync Operations
    suspend fun syncDirectory(localDir: java.io.File, remotePath: String, progress: (Float) -> Unit): Result<SyncResult> {
        return try {
            val remoteFiles = listFiles(remotePath).getOrThrow().associateBy { it.path }
            val localFiles = localDir.walkTopDown().filter { it.isFile }.map { it.toWebDavFile(remotePath) }
            
            var uploaded = 0
            var downloaded = 0
            var deleted = 0
            var errors = 0
            
            val total = localFiles.size + remoteFiles.size
            var processed = 0
            
            // Upload new/changed local files
            for (localFile in localFiles) {
                val remoteFile = remoteFiles[localFile.path]
                val shouldUpload = remoteFile == null || 
                    localFile.lastModified > remoteFile.lastModified || 
                    localFile.size != remoteFile.size
                
                if (shouldUpload) {
                    uploadFile(localFile.file, localFile.path).onFailure { errors++ }
                        .onSuccess { uploaded++ }
                }
                processed++
                progress(processed.toFloat() / total)
            }
            
            // Download new remote files
            for (remoteFile in remoteFiles.values) {
                val localFile = localFiles.find { it.path == remoteFile.path }
                val shouldDownload = localFile == null || 
                    remoteFile.lastModified > localFile.lastModified ||
                    remoteFile.size != localFile.size
                
                if (shouldDownload) {
                    val destFile = java.io.File(localDir, remoteFile.path.substringAfter(remotePath))
                    destFile.parentFile?.mkdirs()
                    downloadFile(remoteFile.path, destFile).onFailure { errors++ }
                        .onSuccess { downloaded++ }
                }
                processed++
                progress(processed.toFloat() / total)
            }
            
            // Optionally delete remote files not in local (with confirmation)
            
            Result.success(SyncResult(uploaded, downloaded, deleted, errors))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // MARK: - Private Helpers
    private fun encodePath(path: String): String {
        return path.split('/').map { URLEncoder.encode(it, "UTF-8") }.joinToString("/") { "/" + it }
    }

    private fun ensureParentDirectories(path: String) {
        val parts = path.split('/').dropLast(1)
        var currentPath = ""
        for (part in parts) {
            if (part.isBlank()) continue
            currentPath += "/$part"
            try {
                createDirectory(currentPath).getOrNull()
            } catch (e: Exception) {
                // Directory might already exist
            }
        }
    }

    private fun getMimeType(extension: String?): String {
        return when (extension?.lowercase()) {
            "mp3" -> "audio/mpeg"
            "flac" -> "audio/flac"
            "m4a", "aac" -> "audio/mp4"
            "ogg" -> "audio/ogg"
            "wav" -> "audio/wav"
            "opus" -> "audio/opus"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "lrc" -> "text/plain"
            else -> "application/octet-stream"
        }
    }

    private fun parseDirectoryListing(xml: String, basePath: String): List<WebDavFile> {
        // Simplified XML parsing - real implementation would use a proper XML parser
        return emptyList()
    }

    private fun parseFileInfo(xml: String, path: String): WebDavFile {
        // Simplified XML parsing
        return WebDavFile(path = path, name = path.substringAfterLast('/'), size = 0, lastModified = 0, isDirectory = false)
    }
}

// MARK: - Data Classes
@Serializable
data class WebDavConfig(
    val url: String,
    val username: String,
    val password: String
)

@Serializable
data class WebDavFile(
    val path: String,
    val name: String,
    val size: Long,
    val lastModified: Long,
    val isDirectory: Boolean,
    val contentType: String? = null,
    val etag: String? = null
) {
    val file: java.io.File
        get() = java.io.File(path)
}

@Serializable
data class SyncResult(
    val uploaded: Int,
    val downloaded: Int,
    val deleted: Int,
    val errors: Int
)

// Extension for File
private fun java.io.File.toWebDavFile(remoteBase: String): WebDavFile {
    val relativePath = this.absolutePath.substringAfter(remoteBase).replace('\\', '/')
    return WebDavFile(
        path = "$remoteBase$relativePath",
        name = this.name,
        size = this.length(),
        lastModified = this.lastModified(),
        isDirectory = this.isDirectory
    )
}
package lol.alphaliu01.gastube

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.ByteBuffer

/**
 * Handles video and audio muxing using Android's native MediaMuxer API.
 * This replaces FFmpegKit for merging separate video and audio streams.
 */
class MediaMuxerHandler : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "MediaMuxerHandler"
        private const val BUFFER_SIZE = 1024 * 1024 // 1MB buffer
    }

    private val scope = CoroutineScope(Dispatchers.IO)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "muxVideoAudio" -> {
                val videoPath = call.argument<String>("videoPath")
                val audioPath = call.argument<String>("audioPath")
                val outputPath = call.argument<String>("outputPath")

                if (videoPath == null || audioPath == null || outputPath == null) {
                    result.error("INVALID_ARGS", "videoPath, audioPath, and outputPath are required", null)
                    return
                }

                scope.launch {
                    try {
                        val success = muxVideoAndAudio(videoPath, audioPath, outputPath)
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Muxing failed", e)
                        withContext(Dispatchers.Main) {
                            result.error("MUXING_FAILED", e.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Mux video and audio streams into a single MP4 file using MediaMuxer.
     * This is a native Android approach that doesn't require FFmpeg.
     */
    private fun muxVideoAndAudio(videoPath: String, audioPath: String, outputPath: String): Boolean {
        var muxer: MediaMuxer? = null
        var videoExtractor: MediaExtractor? = null
        var audioExtractor: MediaExtractor? = null
        var muxerStarted = false

        try {
            // Verify input files exist
            if (!File(videoPath).exists()) {
                Log.e(TAG, "Video file not found: $videoPath")
                return false
            }
            if (!File(audioPath).exists()) {
                Log.e(TAG, "Audio file not found: $audioPath")
                return false
            }

            // Delete output file if it exists
            File(outputPath).delete()

            // Create extractors
            videoExtractor = MediaExtractor()
            audioExtractor = MediaExtractor()

            videoExtractor.setDataSource(videoPath)
            audioExtractor.setDataSource(audioPath)

            // Find video track
            var videoTrackIndex = -1
            var videoFormat: MediaFormat? = null
            for (i in 0 until videoExtractor.trackCount) {
                val format = videoExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/")) {
                    videoTrackIndex = i
                    videoFormat = format
                    break
                }
            }

            // Find audio track
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null
            for (i in 0 until audioExtractor.trackCount) {
                val format = audioExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }

            if (videoTrackIndex < 0 || videoFormat == null) {
                Log.e(TAG, "No video track found in file: $videoPath (trackCount: ${videoExtractor.trackCount})")
                return false
            }

            if (audioTrackIndex < 0 || audioFormat == null) {
                Log.e(TAG, "No audio track found in file: $audioPath (trackCount: ${audioExtractor.trackCount})")
                return false
            }

            // Log track information for debugging
            val videoMime = videoFormat.getString(MediaFormat.KEY_MIME)
            val audioMime = audioFormat.getString(MediaFormat.KEY_MIME)
            Log.d(TAG, "Video format: $videoMime, Audio format: $audioMime")

            // Select tracks
            videoExtractor.selectTrack(videoTrackIndex)
            audioExtractor.selectTrack(audioTrackIndex)

            // Create muxer
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            // Add tracks to muxer
            val muxerVideoTrack = muxer.addTrack(videoFormat)
            val muxerAudioTrack = muxer.addTrack(audioFormat)

            muxer.start()
            muxerStarted = true

            // Copy video track
            val videoBuffer = ByteBuffer.allocate(BUFFER_SIZE)
            val videoBufferInfo = MediaCodec.BufferInfo()

            while (true) {
                videoBuffer.clear()
                val sampleSize = videoExtractor.readSampleData(videoBuffer, 0)
                if (sampleSize < 0) break

                videoBufferInfo.offset = 0
                videoBufferInfo.size = sampleSize
                videoBufferInfo.presentationTimeUs = videoExtractor.sampleTime
                videoBufferInfo.flags = videoExtractor.sampleFlags

                muxer.writeSampleData(muxerVideoTrack, videoBuffer, videoBufferInfo)
                videoExtractor.advance()
            }

            // Copy audio track
            val audioBuffer = ByteBuffer.allocate(BUFFER_SIZE)
            val audioBufferInfo = MediaCodec.BufferInfo()

            while (true) {
                audioBuffer.clear()
                val sampleSize = audioExtractor.readSampleData(audioBuffer, 0)
                if (sampleSize < 0) break

                audioBufferInfo.offset = 0
                audioBufferInfo.size = sampleSize
                audioBufferInfo.presentationTimeUs = audioExtractor.sampleTime
                audioBufferInfo.flags = audioExtractor.sampleFlags

                muxer.writeSampleData(muxerAudioTrack, audioBuffer, audioBufferInfo)
                audioExtractor.advance()
            }

            Log.i(TAG, "Muxing completed successfully")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Muxing error", e)
            // Clean up partial output
            File(outputPath).delete()
            return false
        } finally {
            try {
                // Only call stop() if muxer was successfully started
                // Calling stop() on an unstarted muxer causes crashes
                if (muxerStarted) {
                    muxer?.stop()
                }
                muxer?.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping/releasing muxer", e)
            }
            try {
                videoExtractor?.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing video extractor", e)
            }
            try {
                audioExtractor?.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing audio extractor", e)
            }
        }
    }
}

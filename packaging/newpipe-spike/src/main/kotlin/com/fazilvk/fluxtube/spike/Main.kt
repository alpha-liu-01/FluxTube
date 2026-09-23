package com.fazilvk.fluxtube.spike

import com.fazilvk.fluxtube.newpipe.FluxTubeDownloader
import com.google.gson.GsonBuilder
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.stream.AudioStream
import org.schabi.newpipe.extractor.stream.StreamInfo
import org.schabi.newpipe.extractor.stream.VideoStream

/**
 * No arguments: stay up and answer NewPipeChannel calls on stdin.
 * A video id: print that video's streams as JSON and exit (used by play.sh).
 */
fun main(args: Array<String>) {
    NewPipe.init(FluxTubeDownloader.getInstance())
    val videoId = args.firstOrNull()?.takeIf { it.isNotBlank() }
    if (videoId == null) {
        ExtractorServer.serve()
        return
    }

    val url = "https://www.youtube.com/watch?v=$videoId"
    val info = StreamInfo.getInfo(ServiceList.YouTube, url)
    val payload = mapOf(
        "id" to info.id,
        "title" to info.name,
        "userAgent" to FluxTubeDownloader.USER_AGENT,
        "hlsUrl" to info.hlsUrl,
        "videoStreams" to info.videoStreams.map { mapVideo(it) },
        "videoOnlyStreams" to info.videoOnlyStreams.map { mapVideo(it) },
        "audioStreams" to info.audioStreams.map { mapAudio(it) },
    )
    println(GsonBuilder().create().toJson(payload))
}

private fun mapVideo(stream: VideoStream): Map<String, Any?> = mapOf(
    "url" to stream.content,
    "resolution" to stream.resolution,
    "mimeType" to stream.format?.mimeType,
    "isVideoOnly" to stream.isVideoOnly,
)

private fun mapAudio(stream: AudioStream): Map<String, Any?> = mapOf(
    "url" to stream.content,
    "mimeType" to stream.format?.mimeType,
)

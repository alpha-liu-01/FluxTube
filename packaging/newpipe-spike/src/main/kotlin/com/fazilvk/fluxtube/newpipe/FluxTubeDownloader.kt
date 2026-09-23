package com.fazilvk.fluxtube.newpipe

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request as ExtractorRequest
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import java.util.concurrent.TimeUnit

/**
 * OkHttp downloader for NewPipe Extractor. Copied from the Android app so this
 * spike does not depend on the Android build. Keep the User-Agent in sync.
 */
class FluxTubeDownloader private constructor(
    private val client: OkHttpClient
) : Downloader() {

    companion object {
        const val USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        @Volatile
        private var instance: FluxTubeDownloader? = null

        fun getInstance(): FluxTubeDownloader {
            return instance ?: synchronized(this) {
                instance ?: createInstance().also { instance = it }
            }
        }

        private fun createInstance(): FluxTubeDownloader {
            val client = OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .followRedirects(true)
                .followSslRedirects(true)
                .build()

            return FluxTubeDownloader(client)
        }
    }

    override fun execute(request: ExtractorRequest): Response {
        val url = request.url()
        val httpMethod = request.httpMethod()
        val dataToSend = request.dataToSend()
        val headers = request.headers()

        val requestBuilder = Request.Builder()
            .url(url)
            .header("User-Agent", USER_AGENT)

        for ((headerName, headerValueList) in headers) {
            if (headerValueList.isNotEmpty()) {
                requestBuilder.header(headerName, headerValueList[0])
            }
        }

        when (httpMethod) {
            "GET" -> requestBuilder.get()
            "HEAD" -> requestBuilder.head()
            "POST" -> {
                val body = dataToSend?.toRequestBody() ?: "".toRequestBody()
                requestBuilder.post(body)
            }
            else -> {
                val body = dataToSend?.toRequestBody()
                requestBuilder.method(httpMethod, body)
            }
        }

        val response = client.newCall(requestBuilder.build()).execute()
        val responseCode = response.code

        if (responseCode == 429) {
            response.close()
            throw ReCaptchaException("Rate limited by YouTube", url)
        }

        val responseBody = response.body?.string() ?: ""
        val responseHeaders: MutableMap<String, MutableList<String>> = response.headers.toMultimap()
            .mapValues { (_, values) -> values.toMutableList() }
            .toMutableMap()

        val latestUrl = response.request.url.toString()
        val responseMessage = response.message

        response.close()

        return Response(
            responseCode,
            responseMessage,
            responseHeaders,
            responseBody,
            latestUrl
        )
    }
}

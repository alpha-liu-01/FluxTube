package lol.alphaliu01.gastube.player

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.ContextThemeWrapper
import androidx.mediarouter.app.MediaRouteChooserDialog
import androidx.mediarouter.media.MediaRouteSelector
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.CastState
import com.google.android.gms.cast.framework.CastStateListener
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.images.WebImage
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Google Cast bridge.
 *
 * Casting a YouTube stream means handing the receiver a single self-contained
 * URL, so the Dart side picks a progressive (muxed) stream or the HLS manifest
 * rather than the adaptive video-only track ExoPlayer uses locally.
 *
 * Every entry point tolerates Cast being unavailable: plenty of devices this app
 * runs on have no Google Play Services, in which case availability reports false
 * and the UI hides the button instead of failing at the call site.
 */
class CastMethodHandler : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "CastMethodHandler"

        private const val STATE_UNAVAILABLE = "unavailable"
        private const val STATE_NO_DEVICES = "noDevices"
        private const val STATE_AVAILABLE = "available"
        private const val STATE_CONNECTING = "connecting"
        private const val STATE_CONNECTED = "connected"
    }

    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Null until the framework is confirmed usable; never assume it exists. */
    private var castContext: CastContext? = null
    private var castStateListener: CastStateListener? = null

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarted(session: CastSession, sessionId: String) = emitState()
        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) = emitState()
        override fun onSessionEnded(session: CastSession, error: Int) = emitState()
        override fun onSessionSuspended(session: CastSession, reason: Int) = emitState()
        override fun onSessionStarting(session: CastSession) = emitState()
        override fun onSessionResuming(session: CastSession, sessionId: String) = emitState()
        override fun onSessionStartFailed(session: CastSession, error: Int) = emitState()
        override fun onSessionEnding(session: CastSession) = emitState()
        override fun onSessionResumeFailed(session: CastSession, error: Int) = emitState()
    }

    fun setActivity(activity: Activity) {
        this.activity = activity
    }

    /** Releases listeners so the handler does not outlive the activity. */
    fun detach() {
        val context = castContext
        if (context != null) {
            try {
                context.sessionManager.removeSessionManagerListener(
                    sessionListener, CastSession::class.java
                )
                castStateListener?.let { context.removeCastStateListener(it) }
            } catch (e: Exception) {
                Log.w(TAG, "detach failed: ${e.message}")
            }
        }
        castStateListener = null
        castContext = null
        activity = null
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(ensureCastContext() != null)
            "getState" -> result.success(currentStateMap())
            "showPicker" -> showPicker(result)
            "loadMedia" -> loadMedia(call, result)
            "stop" -> stopCasting(result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        eventSink = sink
        // Registered lazily: attaching the listener is also what starts route
        // discovery, so it should not happen until Dart is watching.
        val context = ensureCastContext()
        if (context != null && castStateListener == null) {
            val listener = CastStateListener { emitState() }
            castStateListener = listener
            try {
                context.addCastStateListener(listener)
                context.sessionManager.addSessionManagerListener(
                    sessionListener, CastSession::class.java
                )
            } catch (e: Exception) {
                Log.w(TAG, "listener registration failed: ${e.message}")
            }
        }
        emitState()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /**
     * Resolves the Cast framework, or null when it cannot be used.
     *
     * Play Services is checked first because [CastContext.getSharedInstance]
     * throws rather than returning null on devices without it.
     */
    private fun ensureCastContext(): CastContext? {
        castContext?.let { return it }
        val ctx: Context = activity ?: return null
        return try {
            val availability = GoogleApiAvailability.getInstance()
                .isGooglePlayServicesAvailable(ctx)
            if (availability != ConnectionResult.SUCCESS) {
                Log.i(TAG, "Play Services unavailable ($availability); Cast disabled")
                return null
            }
            CastContext.getSharedInstance(ctx).also { castContext = it }
        } catch (e: Exception) {
            Log.i(TAG, "Cast unavailable: ${e.message}")
            null
        }
    }

    private fun currentStateMap(): Map<String, Any?> {
        val context = ensureCastContext()
            ?: return mapOf("state" to STATE_UNAVAILABLE, "deviceName" to null)

        val state = try {
            when (context.castState) {
                CastState.NO_DEVICES_AVAILABLE -> STATE_NO_DEVICES
                CastState.NOT_CONNECTED -> STATE_AVAILABLE
                CastState.CONNECTING -> STATE_CONNECTING
                CastState.CONNECTED -> STATE_CONNECTED
                else -> STATE_AVAILABLE
            }
        } catch (e: Exception) {
            STATE_UNAVAILABLE
        }
        val deviceName = try {
            context.sessionManager.currentCastSession?.castDevice?.friendlyName
        } catch (e: Exception) {
            null
        }
        return mapOf("state" to state, "deviceName" to deviceName)
    }

    private fun emitState() {
        val sink = eventSink ?: return
        val payload = currentStateMap()
        mainHandler.post {
            try {
                sink.success(payload)
            } catch (e: Exception) {
                Log.w(TAG, "event dispatch failed: ${e.message}")
            }
        }
    }

    private fun showPicker(result: MethodChannel.Result) {
        val currentActivity = activity
        val context = ensureCastContext()
        if (currentActivity == null || context == null) {
            result.error("CAST_UNAVAILABLE", "Cast is not available on this device", null)
            return
        }
        mainHandler.post {
            try {
                // MainActivity's own theme is Flutter's plain android:Theme, not an
                // AppCompat one, and MediaRouteChooserDialog extends AppCompatDialog —
                // it needs AppCompat theme attributes resolvable regardless of the
                // host activity's theme, so it gets an explicit AppCompat wrapper.
                val themedContext = ContextThemeWrapper(
                    currentActivity, androidx.appcompat.R.style.Theme_AppCompat_DayNight
                )
                val dialog = MediaRouteChooserDialog(themedContext)
                dialog.routeSelector = context.mergedSelector ?: MediaRouteSelector.EMPTY
                dialog.show()
                result.success(true)
            } catch (e: Exception) {
                Log.w(TAG, "picker failed: ${e.message}")
                result.error("CAST_ERROR", e.message, null)
            }
        }
    }

    /**
     * Sends a stream to the connected receiver.
     *
     * `url` must be playable on its own; `contentType` distinguishes a
     * progressive file from an HLS manifest so the receiver picks the right
     * pipeline.
     */
    private fun loadMedia(call: MethodCall, result: MethodChannel.Result) {
        val context = ensureCastContext()
        if (context == null) {
            result.error("CAST_UNAVAILABLE", "Cast is not available on this device", null)
            return
        }
        val remoteClient = try {
            context.sessionManager.currentCastSession?.remoteMediaClient
        } catch (e: Exception) {
            null
        }
        if (remoteClient == null) {
            result.error("NO_SESSION", "No Cast device is connected", null)
            return
        }

        val url = call.argument<String>("url")
        if (url.isNullOrEmpty()) {
            result.error("BAD_ARGS", "url is required", null)
            return
        }
        val title = call.argument<String>("title")
        val subtitle = call.argument<String>("subtitle")
        val imageUrl = call.argument<String>("imageUrl")
        val contentType = call.argument<String>("contentType") ?: "video/mp4"
        val isLive = call.argument<Boolean>("isLive") ?: false
        val positionMs = (call.argument<Number>("positionMs") ?: 0).toLong()

        mainHandler.post {
            try {
                val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
                    if (!title.isNullOrEmpty()) putString(MediaMetadata.KEY_TITLE, title)
                    if (!subtitle.isNullOrEmpty()) {
                        putString(MediaMetadata.KEY_SUBTITLE, subtitle)
                    }
                    if (!imageUrl.isNullOrEmpty()) {
                        addImage(WebImage(android.net.Uri.parse(imageUrl)))
                    }
                }
                val mediaInfo = MediaInfo.Builder(url)
                    .setStreamType(
                        if (isLive) MediaInfo.STREAM_TYPE_LIVE
                        else MediaInfo.STREAM_TYPE_BUFFERED
                    )
                    .setContentType(contentType)
                    .setMetadata(metadata)
                    .build()

                val request = MediaLoadRequestData.Builder()
                    .setMediaInfo(mediaInfo)
                    .setAutoplay(true)
                    .setCurrentTime(if (isLive) 0L else positionMs)
                    .build()

                remoteClient.load(request)
                result.success(true)
            } catch (e: Exception) {
                Log.w(TAG, "load failed: ${e.message}")
                result.error("CAST_ERROR", e.message, null)
            }
        }
    }

    private fun stopCasting(result: MethodChannel.Result) {
        val context = ensureCastContext()
        if (context == null) {
            result.success(false)
            return
        }
        mainHandler.post {
            try {
                context.sessionManager.endCurrentSession(true)
                result.success(true)
            } catch (e: Exception) {
                Log.w(TAG, "stop failed: ${e.message}")
                result.error("CAST_ERROR", e.message, null)
            }
        }
    }
}

package com.opencomputer.client

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.File
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

private const val REQUEST_PICK_VIDEO = 1001
private const val REQUEST_STORAGE_PERMISSION = 1002
private const val DEFAULT_SAMPLE_PATH = "/sdcard/Download/opencomputer-host-v0.mp4"
private const val TAG = "OpenComputerClient"

class MainActivity : Activity(), SurfaceHolder.Callback {
    private lateinit var surfaceView: SurfaceView
    private lateinit var statusText: TextView
    private lateinit var sourceInput: EditText
    private lateinit var playPathButton: Button
    private lateinit var pickButton: Button
    private lateinit var stopButton: Button

    private var surfaceReady = false
    private var pendingSource: VideoSource? = null
    private var player: H264SurfacePlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        buildUi()
        requestVideoPermissionIfNeeded()
    }

    override fun onPause() {
        super.onPause()
        stopPlayback("Paused")
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        surfaceReady = true
        pendingSource?.let {
            pendingSource = null
            startPlayback(it)
        }
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) = Unit

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        surfaceReady = false
        stopPlayback("Surface destroyed")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_VIDEO && resultCode == RESULT_OK) {
            val uri = data?.data ?: return
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: SecurityException) {
                // Some providers grant transient read access only. Playback can still continue now.
            }
            sourceInput.setText(uri.toString())
            startOrQueue(VideoSource.UriSource(uri))
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_STORAGE_PERMISSION && grantResults.any { it != PackageManager.PERMISSION_GRANTED }) {
            setStatus("Storage permission not granted. Use Pick video to select a sample through the system picker.")
        }
    }

    private fun buildUi() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.rgb(245, 247, 251))
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        }

        surfaceView = SurfaceView(this).apply {
            holder.addCallback(this@MainActivity)
            setBackgroundColor(Color.BLACK)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }
        root.addView(surfaceView)

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(12), dp(16), dp(14))
            setBackgroundColor(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        sourceInput = EditText(this).apply {
            setSingleLine(true)
            setText(DEFAULT_SAMPLE_PATH)
            hint = "MP4 path or content URI"
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        controls.addView(sourceInput)

        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = dp(10) }
        }

        playPathButton = actionButton("Play path").apply {
            setOnClickListener {
                startOrQueue(VideoSource.PathSource(sourceInput.text.toString().trim()))
            }
        }
        pickButton = actionButton("Pick video").apply {
            setOnClickListener { pickVideo() }
        }
        stopButton = actionButton("Stop").apply {
            setOnClickListener { stopPlayback("Stopped") }
        }

        buttonRow.addView(playPathButton)
        buttonRow.addView(pickButton)
        buttonRow.addView(stopButton)
        controls.addView(buttonRow)

        statusText = TextView(this).apply {
            text = "Ready. Push Host V0 sample to $DEFAULT_SAMPLE_PATH or pick a video."
            textSize = 13f
            setTextColor(Color.rgb(31, 41, 55))
            setLineSpacing(0f, 1.12f)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = dp(10) }
        }

        val statusScroll = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(116)
            ).also { it.topMargin = dp(8) }
            addView(statusText)
        }
        controls.addView(statusScroll)

        root.addView(controls)
        setContentView(root)
    }

    private fun actionButton(label: String): Button {
        return Button(this).apply {
            text = label
            minHeight = dp(44)
            isAllCaps = false
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).also {
                it.marginEnd = dp(8)
            }
        }
    }

    private fun pickVideo() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, REQUEST_PICK_VIDEO)
    }

    private fun startOrQueue(source: VideoSource) {
        if (!surfaceReady) {
            pendingSource = source
            setStatus("Waiting for video surface...")
            return
        }
        startPlayback(source)
    }

    private fun startPlayback(source: VideoSource) {
        if (source is VideoSource.PathSource && source.path.isBlank()) {
            setStatus("Enter a video path first.")
            return
        }
        stopPlayback("Restarting")
        val surface = surfaceView.holder.surface
        player = H264SurfacePlayer(
            context = this,
            surface = surface,
            listener = object : H264SurfacePlayer.Listener {
                override fun onState(message: String) {
                    runOnUiThread { setStatus(message) }
                }

                override fun onStats(stats: PlaybackStats) {
                    runOnUiThread { setStatus(stats.toDisplayText()) }
                }

                override fun onError(error: Throwable) {
                    runOnUiThread { setStatus("Error: ${error.message ?: error.javaClass.simpleName}") }
                }
            }
        ).also { it.start(source) }
    }

    private fun stopPlayback(message: String) {
        player?.stop()
        player = null
        if (this::statusText.isInitialized) {
            setStatus(message)
        }
    }

    private fun requestVideoPermissionIfNeeded() {
        val permission = when {
            Build.VERSION.SDK_INT >= 33 -> Manifest.permission.READ_MEDIA_VIDEO
            Build.VERSION.SDK_INT >= 23 -> Manifest.permission.READ_EXTERNAL_STORAGE
            else -> null
        }
        if (permission != null && checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(permission), REQUEST_STORAGE_PERMISSION)
        }
    }

    private fun setStatus(message: String) {
        Log.d(TAG, message)
        statusText.text = message
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}

sealed class VideoSource {
    data class PathSource(val path: String) : VideoSource()
    data class UriSource(val uri: Uri) : VideoSource()
}

data class PlaybackStats(
    val sourceLabel: String,
    val codecName: String,
    val width: Int,
    val height: Int,
    val durationUs: Long,
    val decodedFrames: Long,
    val elapsedMs: Long,
    val observedFps: Double
) {
    fun toDisplayText(): String {
        val duration = if (durationUs > 0) "%.2fs".format(Locale.US, durationUs / 1_000_000.0) else "unknown"
        return """
            Playing
            Source: $sourceLabel
            Codec: $codecName
            Video: ${width}x${height}, duration $duration
            Decoded frames: $decodedFrames
            Elapsed: ${elapsedMs}ms
            Observed FPS: ${"%.1f".format(Locale.US, observedFps)}
        """.trimIndent()
    }
}

class H264SurfacePlayer(
    private val context: Context,
    private val surface: Surface,
    private val listener: Listener
) {
    interface Listener {
        fun onState(message: String)
        fun onStats(stats: PlaybackStats)
        fun onError(error: Throwable)
    }

    private val stopped = AtomicBoolean(false)
    private var worker: Thread? = null

    fun start(source: VideoSource) {
        stopped.set(false)
        worker = Thread({ decode(source) }, "OpenComputerDecoder").apply { start() }
    }

    fun stop() {
        stopped.set(true)
        worker?.interrupt()
        worker = null
    }

    private fun decode(source: VideoSource) {
        var extractor: MediaExtractor? = null
        var codec: MediaCodec? = null
        var closeableFd: android.os.ParcelFileDescriptor? = null
        try {
            listener.onState("Opening ${source.label()}")
            Log.d(TAG, "Opening source ${source.label()}")
            extractor = MediaExtractor()
            closeableFd = when (source) {
                is VideoSource.PathSource -> {
                    val file = File(source.path)
                    if (!file.exists()) {
                        throw IllegalArgumentException("File does not exist: ${source.path}")
                    }
                    extractor.setDataSource(source.path)
                    null
                }
                is VideoSource.UriSource -> {
                    val fd = context.contentResolver.openFileDescriptor(source.uri, "r")
                        ?: throw IllegalArgumentException("Could not open URI: ${source.uri}")
                    extractor.setDataSource(fd.fileDescriptor)
                    fd
                }
            }

            val trackIndex = findVideoTrack(extractor)
            if (trackIndex < 0) {
                throw IllegalArgumentException("No video track found.")
            }
            extractor.selectTrack(trackIndex)
            val format = extractor.getTrackFormat(trackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalArgumentException("Video track has no MIME type.")
            if (!mime.startsWith("video/")) {
                throw IllegalArgumentException("Unsupported MIME type: $mime")
            }

            val width = format.getIntegerOrDefault(MediaFormat.KEY_WIDTH)
            val height = format.getIntegerOrDefault(MediaFormat.KEY_HEIGHT)
            val durationUs = format.getLongOrDefault(MediaFormat.KEY_DURATION)
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, surface, null, 0)
            codec.start()

            listener.onState("Decoding $mime ${width}x${height}")
            Log.d(TAG, "Decoder configured mime=$mime width=$width height=$height durationUs=$durationUs")
            runDecodeLoop(source, extractor, codec, mime, width, height, durationUs)
        } catch (error: Throwable) {
            if (!stopped.get()) {
                Log.e(TAG, "Playback error", error)
                listener.onError(error)
            }
        } finally {
            try {
                codec?.stop()
            } catch (_: Throwable) {
            }
            codec?.release()
            extractor?.release()
            closeableFd?.close()
        }
    }

    private fun runDecodeLoop(
        source: VideoSource,
        extractor: MediaExtractor,
        codec: MediaCodec,
        codecName: String,
        width: Int,
        height: Int,
        durationUs: Long
    ) {
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        var firstPresentationUs = -1L
        var firstFrameWallMs = 0L
        var decodedFrames = 0L
        var lastStatsMs = 0L

        while (!outputDone && !stopped.get()) {
            if (!inputDone) {
                val inputIndex = codec.dequeueInputBuffer(10_000)
                if (inputIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inputIndex)
                        ?: throw IllegalStateException("Missing input buffer $inputIndex")
                    val sampleSize = extractor.readSampleData(inputBuffer, 0)
                    if (sampleSize < 0) {
                        codec.queueInputBuffer(inputIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(inputIndex, 0, sampleSize, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }

            when (val outputIndex = codec.dequeueOutputBuffer(info, 10_000)) {
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                else -> {
                    if (outputIndex >= 0) {
                        if (firstPresentationUs < 0 && info.presentationTimeUs >= 0) {
                            firstPresentationUs = info.presentationTimeUs
                            firstFrameWallMs = SystemClock.elapsedRealtime()
                        }
                        paceFrame(firstPresentationUs, firstFrameWallMs, info.presentationTimeUs)
                        val render = info.size > 0
                        codec.releaseOutputBuffer(outputIndex, render)
                        if (render) {
                            decodedFrames += 1
                        }
                        if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            outputDone = true
                        }

                        val now = SystemClock.elapsedRealtime()
                        if (now - lastStatsMs >= 500 || outputDone) {
                            lastStatsMs = now
                            val elapsedMs = if (firstFrameWallMs > 0) now - firstFrameWallMs else 0L
                            val fps = if (elapsedMs > 0) decodedFrames * 1000.0 / elapsedMs else 0.0
                            Log.d(TAG, "Playback stats frames=$decodedFrames elapsedMs=$elapsedMs fps=$fps")
                            listener.onStats(
                                PlaybackStats(
                                    sourceLabel = source.label(),
                                    codecName = codecName,
                                    width = width,
                                    height = height,
                                    durationUs = durationUs,
                                    decodedFrames = decodedFrames,
                                    elapsedMs = elapsedMs,
                                    observedFps = fps
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private fun paceFrame(firstPresentationUs: Long, firstFrameWallMs: Long, presentationUs: Long) {
        if (firstPresentationUs < 0 || firstFrameWallMs <= 0 || presentationUs <= firstPresentationUs) {
            return
        }
        val targetMs = firstFrameWallMs + ((presentationUs - firstPresentationUs) / 1000L)
        val delayMs = targetMs - SystemClock.elapsedRealtime()
        if (delayMs > 2) {
            Thread.sleep(delayMs.coerceAtMost(50L))
        }
    }

    private fun findVideoTrack(extractor: MediaExtractor): Int {
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("video/") == true) {
                return index
            }
        }
        return -1
    }
}

private fun VideoSource.label(): String = when (this) {
    is VideoSource.PathSource -> path
    is VideoSource.UriSource -> uri.toString()
}

private fun MediaFormat.getIntegerOrDefault(key: String): Int {
    return if (containsKey(key)) getInteger(key) else 0
}

private fun MediaFormat.getLongOrDefault(key: String): Long {
    return if (containsKey(key)) getLong(key) else 0L
}

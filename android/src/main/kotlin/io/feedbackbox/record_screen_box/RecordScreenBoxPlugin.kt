package io.feedbackbox.record_screen_box

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.os.Environment
import java.io.File
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import java.io.IOException

/** RecordScreenBoxPlugin */
class RecordScreenBoxPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  /// Method channel
  private lateinit var channel : MethodChannel

  /// Properties
  private var _result : Result? = null
  private var _pathToSaveRecording: String = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM).absolutePath + File.separator

  private var _videoName : String = ""
  private var _displayWidth : Double = 1280.0
  private var _displayHeight : Double = 720.0

  private var _mediaRecorder: MediaRecorder? = null
  private var _projectionManager: MediaProjectionManager? = null
  private var _mediaProjectionCallback: MediaProjectionCallback? = null
  private var _mediaProjection: MediaProjection? = null

  private var _virtualDisplay: VirtualDisplay? = null
  private var _windowManager: WindowManager? = null
  private var _screenDensity: Int = 0
  private var _activity : Activity? = null

  private var _isRecording: Boolean = false
  private var _hasBeenStarted: Boolean = false

  private val screenRecorderStartRequestCode = 333

  @RequiresApi(Build.VERSION_CODES.N)
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode == screenRecorderStartRequestCode) {
      if (resultCode == Activity.RESULT_OK) {
        _mediaProjectionCallback = MediaProjectionCallback()
        _mediaProjection = _projectionManager?.getMediaProjection(resultCode, data!!)
        _mediaProjection?.registerCallback(_mediaProjectionCallback, null)
        _virtualDisplay = createVirtualDisplay()
        _result?.success(true)
        return true
      }
      _result?.success(false)
    }

    _isRecording = false
    _hasBeenStarted = false

    return false
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "screen_recorder_box")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  @RequiresApi(Build.VERSION_CODES.N)
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    // Start recording
    when (call.method) {
      "startScreenRecording" -> {
        initializeProperties(call, result)
        initializeMediaRecorder()
        startRecordScreen()
      }
      // Stop recording
      "stopScreenRecording" -> {
        stopRecordingScreen()
        result.success("${_pathToSaveRecording}${_videoName}.mp4")
      }
      // Pause recording (if started)
      "pauseScreenRecording" -> {
        val didPause = pauseRecordingScreen()
        result.success(didPause)
      }
      "resumeScreenRecording" -> {
        val didResume = resumeRecordingScreen()
        result.success(didResume)
      }
      "isRecording" -> {
        result.success(_isRecording)
      }
      "hasBeenStarted" -> {
        result.success(_hasBeenStarted)
      }
      // Calling not implemented method
      else -> {
        result.notImplemented()
      }
    }
  }
  
  /** Handles the startScreenRecording method call */
  @RequiresApi(Build.VERSION_CODES.N)
  private fun initializeProperties(@NonNull call: MethodCall, @NonNull result: Result) {
    // Set result here so we can use it later
    _result = result

    // Set mediaRecorder and projectionManager
    _mediaRecorder = MediaRecorder()
    
    // Set the videoName from the arguments passed on to this method
    _videoName = call.argument("name")!!
    _displayHeight = call.argument("height")!!
    _displayWidth = call.argument("width")!!
    _pathToSaveRecording = call.argument("path")!!

    println("Video name: $_videoName")
    println("Device height: $_displayHeight")
    println("Device width: $_displayWidth")
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun initializeMediaRecorder() {
    _mediaRecorder?.setVideoSource(MediaRecorder.VideoSource.SURFACE)
    _mediaRecorder?.setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
    _mediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
    _mediaRecorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
    _mediaRecorder?.setAudioEncodingBitRate(16 * 44100)
    _mediaRecorder?.setAudioSamplingRate(44100)
    _mediaRecorder?.setVideoEncoder(MediaRecorder.VideoEncoder.H264)

    _mediaRecorder?.setVideoSize(_displayWidth.toInt(), _displayHeight.toInt())
    _mediaRecorder?.setVideoFrameRate(30)

    _mediaRecorder?.setOutputFile("${_pathToSaveRecording}${_videoName}.mp4")

    _mediaRecorder?.setVideoEncodingBitRate(5 * _displayWidth.toInt() * _displayHeight.toInt())
    _mediaRecorder?.prepare()
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun startRecordScreen() {
    if (!_hasBeenStarted) {
      try {
        _mediaRecorder?.start()
        _isRecording = true
        _hasBeenStarted = true
      } catch (e: IOException) {
        println("Error: startRecordScreen")
        println(e.message)
      }
  
      val permissionIntent = _projectionManager?.createScreenCaptureIntent()
      _activity?.startActivityForResult(permissionIntent!!, screenRecorderStartRequestCode)
    }
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun stopRecordingScreen() {
    if (_hasBeenStarted) {
      try {
        _mediaRecorder?.stop()
        _mediaRecorder?.reset()
      } catch (e: Exception) {
        println("Error: stopRecordingScreen")
        println(e.message)
      } finally {
        stopScreenSharing()
        _isRecording = false
        _hasBeenStarted = false
      }
    }
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun pauseRecordingScreen() : Boolean {
    if (_isRecording && _hasBeenStarted) {
      return try {
          _mediaRecorder?.pause()
        _isRecording = false
        true
      } catch (e: Exception) {
          println("Error: pauseRecordingScreen")
          println(e.message)
        false
      }
    }
    println("There is nothing to pause, recorder not recording... Are you stupid?")
    return false
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun resumeRecordingScreen() : Boolean {
    if (!_isRecording && _hasBeenStarted) {
      return try {
        _mediaRecorder?.resume()
        _isRecording = true
        true
      } catch (e: Exception) {
        println("Error: resumeRecordingScreen")
        println(e.message)
        false
      }
    }

    if (_isRecording && _hasBeenStarted) {
      println("There is nothing to resume, recorder still recording... Are you stupid?")
    } else {
      println("There is nothing to resume, recorder not even started... Are you stupid?")
    }

    return false
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun stopScreenSharing() {
    if (_virtualDisplay != null) {
      _virtualDisplay?.release()
      if (_mediaProjection != null) {
        _mediaProjection?.unregisterCallback(_mediaProjectionCallback)
        _mediaProjection?.stop()
        _mediaProjection = null
      }
    }
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun createVirtualDisplay(): VirtualDisplay? {
    val metrics = DisplayMetrics()
    _windowManager?.defaultDisplay?.getMetrics(metrics)
    _screenDensity = metrics.densityDpi

    return _mediaProjection?.createVirtualDisplay(
      "MainActivity",
      _displayWidth.toInt(),
      _displayHeight.toInt(),
      _screenDensity,
      DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
      _mediaRecorder?.surface,
      null,
      null
    )
  }

  @RequiresApi(Build.VERSION_CODES.N)
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    _projectionManager = binding.activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager?
    _windowManager = binding.activity.getSystemService(Context.WINDOW_SERVICE) as WindowManager?
    _activity = binding.activity

    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    TODO("Not yet implemented")
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    TODO("Not yet implemented")
  }

  override fun onDetachedFromActivity() {
    TODO("Not yet implemented")
  }

  @RequiresApi(Build.VERSION_CODES.N)
  inner class MediaProjectionCallback : MediaProjection.Callback() {
    override fun onStop() {
      _mediaRecorder?.stop()
      _mediaRecorder?.reset()

      _mediaProjection = null
      stopScreenSharing()
    }
  }
}

package com.example.ogg_to_aac_converter

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/** OggToAacConverterPlugin */
class OggToAacConverterPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private val executor = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())
  private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding

  // Temporarily disabled native part
  // companion object {
  //   init {
  //     System.loadLibrary("native_audio_converter") // JNI library name
  //   }
  // }

  // private external fun decodeOggToPcm(oggPath: String, pcmPath: String): Boolean
  // private external fun getOggAudioInfo(oggPath: String): IntArray // [sampleRate, channels]

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ogg_to_aac_converter")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else if (call.method == "convertOggToAac") {
      val inputPath = call.argument<String>("inputPath")
      val outputPath = call.argument<String>("outputPath")

      if (inputPath == null || outputPath == null) {
        result.error("INVALID_ARGUMENTS", "Input or output path is null", null)
        return
      }

      executor.execute {
        try {
          val inputFile = File(inputPath)
          val outputFile = File(outputPath)

          if (!inputFile.exists()) {
            mainHandler.post { result.error("FILE_NOT_FOUND", "Input file does not exist: $inputPath", null) }
            return@execute
          }

          // Create output directory if it doesn't exist
          outputFile.parentFile?.mkdirs()

          // Create temporary PCM file
          val tempPcmFile = File.createTempFile("temp_audio", ".pcm", flutterPluginBinding.applicationContext.cacheDir)
          val pcmPath = tempPcmFile.absolutePath

          // In this simplified version, we just copy the file for demo
          inputFile.inputStream().use { input ->
            File(pcmPath).outputStream().use { output ->
              input.copyTo(output)
            }
          }

          // Variables to store audio information
          val sampleRate = 44100 // Default value
          val channels = 2      // Default value

          // Encode PCM to AAC
          val encodeSuccess = encodePcmToAac(pcmPath, outputPath, sampleRate, channels)
          tempPcmFile.delete()

          if (encodeSuccess) {
            mainHandler.post { result.success(outputPath) }
          } else {
            mainHandler.post { result.error("ENCODE_FAILED", "Failed to encode PCM to AAC", null) }
          }
        } catch (e: Exception) {
          mainHandler.post { result.error("CONVERSION_ERROR", e.message, e.stackTraceToString()) }
        }
      }
    } else {
      result.notImplemented()
    }
  }

  private fun encodePcmToAac(pcmPath: String, aacPath: String, sampleRate: Int, channelCount: Int): Boolean {
    val pcmFile = File(pcmPath)
    if (!pcmFile.exists()) return false

    val outputFile = File(aacPath)

    try {
      // In this simplified version, we just copy the file for demo
      pcmFile.inputStream().use { input ->
        outputFile.outputStream().use { output ->
          input.copyTo(output)
        }
      }
      return true
    } catch (e: Exception) {
      e.printStackTrace()
      return false
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    executor.shutdown()
  }
}

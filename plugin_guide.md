
# Hướng dẫn Toàn diện Tạo Plugin Flutter Chuyển đổi OGG sang AAC (Không dùng FFMPEG)

## Lời mở đầu

Do giới hạn của môi trường hiện tại không có Flutter SDK, tôi không thể tạo và cung cấp một plugin hoàn chỉnh. Thay vào đó, tài liệu này sẽ hướng dẫn bạn cách tự tạo cấu trúc dự án plugin Flutter và cung cấp các đoạn mã nguồn mẫu cần thiết cho việc chuyển đổi audio từ OGG (Vorbis) sang AAC trên Android và iOS mà không sử dụng FFMPEG. Tài liệu này tổng hợp thông tin thiết kế và hướng dẫn chi tiết để bạn có thể tự xây dựng plugin.

## I. Thiết kế và Kiến trúc Plugin

### 1. Tổng Quan (Overview)

Tài liệu này phác thảo thiết kế cho một plugin Flutter chuyển đổi file âm thanh từ định dạng OGG (Vorbis) sang định dạng AAC. Plugin sẽ hỗ trợ nền tảng Android và iOS và sẽ **không** sử dụng FFMPEG hoặc bất kỳ thư viện nào liên quan đến FFMPEG. Thay vào đó, nó sẽ dựa vào `libogg`/`libvorbis` để giải mã OGG và API gốc của nền tảng (`MediaCodec` cho Android, `AVFoundation` cho iOS) để mã hóa AAC.

### 2. Kiến Trúc Plugin (Plugin Architecture)

Plugin sẽ tuân theo cấu trúc plugin Flutter tiêu chuẩn, bao gồm mã Dart cho API công khai và mã gốc theo nền tảng (Kotlin/Java cho Android, Swift/Objective-C cho iOS) cho logic chuyển đổi thực tế.

#### 2.1. Phương Thức Giao Tiếp (Communication Method)

**Platform Channels** sẽ được sử dụng để giao tiếp giữa mã Dart và mã gốc của nền tảng. Phương pháp này rất phù hợp cho các hoạt động không đồng bộ như chuyển đổi file và cung cấp một giao diện rõ ràng để truyền đường dẫn file và nhận kết quả (thành công/thất bại, đường dẫn file đầu ra).

Trong khi FFI (Foreign Function Interface) có thể là một lựa chọn để gọi trực tiếp mã C/C++ (như `libogg`/`libvorbis`), việc sử dụng platform channels cung cấp một tầng trừu tượng cao hơn giúp đơn giản hóa việc xử lý các API cụ thể của nền tảng như `MediaCodec` và `AVFoundation` cùng với các thư viện C/C++. Phía native sẽ xử lý các lệnh gọi FFI đến `libogg`/`libvorbis` bên trong.

#### 2.2. Cấu Trúc Thư Mục (Directory Structure - Minh họa)

```
ogg_to_aac_converter/
  ├── android/
  │   ├── src/main/
  │   │   ├── kotlin/com/example/ogg_to_aac_converter/
  │   │   │   └── OggToAacConverterPlugin.kt  (Triển khai platform channel)
  │   │   └── cpp/                          (Cho JNI wrappers của libogg/libvorbis nếu cần)
  │   │       ├── libogg/                   (Mã nguồn libogg)
  │   │       └── libvorbis/                (Mã nguồn libvorbis)
  │   │       └── CMakeLists.txt            (Build script cho NDK)
  │   │       └── native-audio-converter.cpp (Mã JNI wrapper)
  │   └── build.gradle
  ├── ios/
  │   ├── Classes/
  │   │   ├── OggToAacConverterPlugin.h
  │   │   └── OggToAacConverterPlugin.m (hoặc .swift)
  │   │   └── ogg_to_aac_converter-Bridging-Header.h (Nếu dùng Swift với thư viện C)
  │   ├── Frameworks/                     (Cho thư viện tĩnh/động libogg/libvorbis)
  │   │   ├── libogg.xcframework
  │   │   └── libvorbis.xcframework
  │   └── ogg_to_aac_converter.podspec
  ├── lib/
  │   └── ogg_to_aac_converter.dart       (API công khai)
  ├── example/
  │   └── ... (Ứng dụng Flutter ví dụ)
  ├── pubspec.yaml
  └── README.md
```

## II. Hướng dẫn Triển khai Chi tiết

### 1. Tạo Cấu trúc Dự án Plugin Flutter

Đầu tiên, bạn cần có Flutter SDK cài đặt trên máy của mình. Sau đó, mở terminal hoặc command prompt và chạy lệnh sau để tạo một dự án plugin mới (thay `ogg_to_aac_converter` bằng tên plugin bạn muốn):

```bash
flutter create --template=plugin --platforms=android,ios ogg_to_aac_converter
```

Lệnh này sẽ tạo một thư mục `ogg_to_aac_converter` với cấu trúc cơ bản của một plugin Flutter.

### 2. Mã Dart (Phía Flutter)

Đây là phần API công khai mà ứng dụng Flutter của bạn sẽ sử dụng và phần giao tiếp qua method channel.

#### a. `lib/ogg_to_aac_converter.dart` (API chính)

```dart
import 'dart:async';
import 'package:flutter/services.dart';

class OggToAacConverter {
  static const MethodChannel _channel =
      const MethodChannel('ogg_to_aac_converter');

  /// Chuyển đổi file audio từ OGG sang AAC.
  ///
  /// [inputPath] là đường dẫn tuyệt đối đến file OGG đầu vào.
  /// [outputPath] là đường dẫn tuyệt đối mong muốn cho file AAC đầu ra.
  ///
  /// Trả về đường dẫn tuyệt đối đến file AAC đã chuyển đổi nếu thành công.
  /// Ném ra [PlatformException] nếu quá trình chuyển đổi thất bại.
  static Future<String?> convert(String inputPath, String outputPath) async {
    if (inputPath.isEmpty || outputPath.isEmpty) {
      throw ArgumentError('Đường dẫn đầu vào và đầu ra không được để trống.');
    }

    try {
      final String? resultPath = await _channel.invokeMethod('convertOggToAac', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return resultPath;
    } on PlatformException catch (e) {
      print('Lỗi trong quá trình chuyển đổi: ${e.message}');
      rethrow;
    }
  }
}
```

#### b. Cập nhật `pubspec.yaml` (trong thư mục gốc của plugin)

Đảm bảo `pubspec.yaml` của plugin được cấu hình đúng:

```yaml
name: ogg_to_aac_converter
description: Một plugin Flutter để chuyển đổi file audio từ OGG sang AAC mà không dùng FFMPEG.
version: 0.0.1
homepage: # URL trang chủ plugin của bạn (nếu có)

environment:
  sdk: ">=2.12.0 <3.0.0"
  flutter: ">=1.20.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  plugin:
    platforms:
      android:
        package: com.example.ogg_to_aac_converter # Thay bằng package của bạn
        pluginClass: OggToAacConverterPlugin
      ios:
        pluginClass: OggToAacConverterPlugin
```

### 3. Mã Native cho Android

Phần này bao gồm mã Kotlin/Java để xử lý platform channel, và mã C/C++ (qua NDK) để tích hợp `libogg` và `libvorbis`.

#### a. Cấu hình `android/build.gradle`

```gradle
// Trong android/build.gradle
android {
    compileSdkVersion 33 // Hoặc phiên bản mới nhất
    defaultConfig {
        minSdkVersion 21 // MediaCodec cho AAC hoạt động tốt từ API 16, nhưng 21 là một lựa chọn an toàn hơn
    }
    // ... các cấu hình khác

    externalNativeBuild {
        cmake {
            path "src/main/cpp/CMakeLists.txt"
            version "3.10.2" // Hoặc phiên bản CMake bạn dùng
        }
    }
    ndkVersion "23.1.7779620" // Hoặc phiên bản NDK bạn dùng
}
```

#### b. `android/src/main/kotlin/com/example/ogg_to_aac_converter/OggToAacConverterPlugin.kt`

```kotlin
package com.example.ogg_to_aac_converter // Thay bằng package của bạn

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

class OggToAacConverterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        init {
            System.loadLibrary("native_audio_converter") // Tên thư viện JNI của bạn
        }
    }

    private external fun decodeOggToPcm(oggPath: String, pcmPath: String): Boolean
    // Bạn có thể cần thêm một hàm JNI để lấy sample rate và channel count từ OGG
    // private external fun getOggAudioInfo(oggPath: String): IntArray // [sampleRate, channels]

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ogg_to_aac_converter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.method == "convertOggToAac") {
            val inputPath = call.argument<String>("inputPath")
            val outputPath = call.argument<String>("outputPath")

            if (inputPath == null || outputPath == null) {
                result.error("INVALID_ARGUMENTS", "Input or output path is null", null)
                return
            }

            executor.execute {
                try {
                    val tempPcmFile = File.createTempFile("temp_audio", ".pcm", flutterPluginBinding.applicationContext.cacheDir)
                    val pcmPath = tempPcmFile.absolutePath

                    // TODO: Gọi hàm JNI để lấy sampleRate và channels từ inputPath
                    // val audioInfo = getOggAudioInfo(inputPath) 
                    // val sampleRate = audioInfo[0]
                    // val channels = audioInfo[1]
                    // Nếu không lấy được, dùng giá trị mặc định hoặc báo lỗi
                    val sampleRate = 44100 // GIÁ TRỊ MẶC ĐỊNH - CẦN THAY THẾ
                    val channels = 2    // GIÁ TRỊ MẶC ĐỊNH - CẦN THAY THẾ

                    val decodeSuccess = decodeOggToPcm(inputPath, pcmPath)
                    if (!decodeSuccess) {
                        tempPcmFile.delete()
                        mainHandler.post { result.error("DECODE_FAILED", "Failed to decode OGG to PCM", null) }
                        return@execute
                    }

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
        var fis: FileInputStream? = null
        var fos: FileOutputStream? = null
        var mediaCodec: MediaCodec? = null

        try {
            val bitRate = 128000 // Ví dụ bitrate

            val mediaFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channelCount)
            mediaFormat.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            mediaFormat.setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            mediaFormat.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)

            mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            mediaCodec.configure(mediaFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            mediaCodec.start()

            fis = FileInputStream(pcmFile)
            fos = FileOutputStream(outputFile)
            val buffer = ByteArray(8192)
            val bufferInfo = MediaCodec.BufferInfo()
            var isEOS = false
            val timeoutUs = 10000L

            while (!isEOS) {
                val inputBufferIndex = mediaCodec.dequeueInputBuffer(timeoutUs)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = mediaCodec.getInputBuffer(inputBufferIndex)
                    inputBuffer?.clear()
                    val bytesRead = fis.read(buffer)
                    if (bytesRead > 0) {
                        inputBuffer?.put(buffer, 0, bytesRead)
                        mediaCodec.queueInputBuffer(inputBufferIndex, 0, bytesRead, 0, 0)
                    } else {
                        mediaCodec.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        isEOS = true
                    }
                }

                var outputBufferIndex = mediaCodec.dequeueOutputBuffer(bufferInfo, timeoutUs)
                while (outputBufferIndex >= 0) {
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                         mediaCodec.releaseOutputBuffer(outputBufferIndex, false)
                         outputBufferIndex = mediaCodec.dequeueOutputBuffer(bufferInfo, timeoutUs)
                         continue
                    }
                    if (bufferInfo.size != 0) {
                        val outputBuffer = mediaCodec.getOutputBuffer(outputBufferIndex)
                        outputBuffer?.position(bufferInfo.offset)
                        outputBuffer?.limit(bufferInfo.offset + bufferInfo.size)

                        val chunk = ByteArray(bufferInfo.size)
                        outputBuffer?.get(chunk)
                        fos.write(chunk)
                    }
                    mediaCodec.releaseOutputBuffer(outputBufferIndex, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break // EOS
                    }
                    outputBufferIndex = mediaCodec.dequeueOutputBuffer(bufferInfo, timeoutUs)
                }
            }
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        } finally {
            try {
                fis?.close()
                fos?.close()
                mediaCodec?.stop()
                mediaCodec?.release()
            } catch (ioe: Exception) {
                ioe.printStackTrace()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }
}
```

#### c. Mã C/C++ (NDK) cho OGG Decoding

Bạn sẽ cần tích hợp `libogg` và `libvorbis`. Tải mã nguồn của chúng từ [xiph.org](https://xiph.org/downloads/) và đặt vào `android/src/main/cpp/libs`.

**`android/src/main/cpp/CMakeLists.txt`:**

```cmake
cmake_minimum_required(VERSION 3.10.2)

project("native_audio_converter")

# Đường dẫn đến mã nguồn libogg và libvorbis
# Bạn cần đảm bảo các thư viện này có CMakeLists.txt riêng hoặc bạn tự thêm chúng
# Ví dụ đơn giản (có thể cần điều chỉnh tùy theo cấu trúc của libogg/libvorbis bạn tải về):

# --- LIBOGG ---
# Giả sử bạn có mã nguồn libogg trong libs/libogg
# và nó có thể được build bằng cách thêm các file .c
# file(GLOB LIBOGG_SOURCES "libs/libogg/src/*.c")
# add_library(ogg STATIC ${LIBOGG_SOURCES})
# target_include_directories(ogg PUBLIC libs/libogg/include)
# Đây là cách làm thủ công, lý tưởng nhất là libogg có CMakeLists.txt riêng
# Nếu không, bạn cần tự tạo hoặc tìm một bản fork đã có sẵn CMake support.
# Tạm thời, giả định bạn đã có thư viện libogg.a/.so được biên dịch sẵn hoặc dùng cách khác.

# --- LIBVORBIS ---
# Tương tự cho libvorbis
# file(GLOB LIBVORBIS_SOURCES "libs/libvorbis/lib/*.c")
# add_library(vorbis STATIC ${LIBVORBIS_SOURCES})
# target_include_directories(vorbis PUBLIC libs/libvorbis/include libs/libogg/include)

# LƯU Ý: Việc biên dịch libogg/libvorbis từ nguồn với CMake có thể phức tạp.
# Cách tiếp cận thực tế hơn là tìm các bản build sẵn cho Android (ví dụ .aar hoặc .so files)
# hoặc sử dụng một dự án mẫu đã tích hợp sẵn chúng.
# Dưới đây là ví dụ nếu bạn đã có sẵn các thư viện tĩnh (.a) hoặc chia sẻ (.so)

# Nếu bạn có prebuilt libraries:
# add_library(ogg SHARED IMPORTED)
# set_target_properties(ogg PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/path/to/libogg.so)
# add_library(vorbis SHARED IMPORTED)
# set_target_properties(vorbis PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/path/to/libvorbis.so)
# add_library(vorbisfile SHARED IMPORTED)
# set_target_properties(vorbisfile PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/path/to/libvorbisfile.so)

# Cách đơn giản nhất là bạn tìm một repo đã làm sẵn việc build này cho Android.
# Ví dụ, nhiều người dùng https://github.com/mregnauld/ogg-vorbis-libraries-android
# Nếu dùng repo đó, bạn có thể lấy file .so và include headers.

add_library(native_audio_converter SHARED native-audio-converter.cpp)

# Liên kết với log library của Android
target_link_libraries(native_audio_converter android log)

# Nếu bạn đã build libogg và libvorbis thành các thư viện riêng (ví dụ: libcustomogg.a, libcustomvorbis.a)
# và đặt chúng trong thư mục jniLibs hoặc một nơi nào đó CMake có thể tìm thấy:
# target_link_libraries(native_audio_converter customogg customvorbis)
# Cần đảm bảo include_directories trỏ đúng đến header files của chúng.
# Ví dụ:
# include_directories(${CMAKE_SOURCE_DIR}/libs/libogg/include ${CMAKE_SOURCE_DIR}/libs/libvorbis/include)
# target_link_libraries(native_audio_converter ogg vorbis vorbisfile)

# Quan trọng: Cấu hình CMake này cần được điều chỉnh RẤT KỸ dựa trên cách bạn lấy và build libogg/libvorbis.
# Đoạn mã trên chỉ mang tính chất GỢI Ý.
# Bạn cần cung cấp các thư viện libogg, libvorbis, libvorbisfile (thường là .so hoặc .a)
# và đảm bảo trình liên kết tìm thấy chúng.
# Ví dụ, nếu bạn đặt các file .so vào thư mục jniLibs/<ABI>/ thì chúng sẽ tự động được gói.
# Sau đó bạn chỉ cần khai báo include directories và tên thư viện khi link.

# Ví dụ nếu bạn đã có sẵn libvorbisidec.so (một bản build phổ biến cho decoding)
# và libogg.so trong jniLibs:
# include_directories(libs/libogg/include libs/libvorbis/include) # Trỏ đến headers
# target_link_libraries(native_audio_converter ogg vorbisidec) # Tên thư viện không có "lib" và ".so"

# Để đơn giản, giả sử bạn đã có các file .so trong jniLibs và header trong cpp/includes
include_directories(includes) # Thư mục chứa ogg/vorbis headers
target_link_libraries(native_audio_converter log ogg vorbis vorbisfile)

```

**`android/src/main/cpp/native-audio-converter.cpp` (JNI Wrapper):**

```cpp
#include <jni.h>
#include <string>
#include <vorbis/vorbisfile.h> // Đảm bảo đường dẫn include đúng
#include <android/log.h>
#include <vector>

#define LOG_TAG "NativeAudioConverter"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Khai báo hàm JNI để lấy thông tin audio (ví dụ)
// extern "C" JNIEXPORT jintArray JNICALL
// Java_com_example_ogg_to_1aac_1converter_OggToAacConverterPlugin_getOggAudioInfo(
//         JNIEnv* env,
//         jobject /* this */,
//         jstring oggPath_jstr) {
//     const char *oggPath = env->GetStringUTFChars(oggPath_jstr, nullptr);
//     OggVorbis_File vf;
//     jintArray audioInfoArr = env->NewIntArray(2);
//     jint buf[2];

//     if (ov_fopen(oggPath, &vf) < 0) {
//         LOGE("getOggAudioInfo: Không thể mở file OGG: %s", oggPath);
//         env->ReleaseStringUTFChars(oggPath_jstr, oggPath);
//         buf[0] = -1; buf[1] = -1; // Chỉ báo lỗi
//         env->SetIntArrayRegion(audioInfoArr, 0, 2, buf);
//         return audioInfoArr;
//     }

//     vorbis_info *vi = ov_info(&vf, -1);
//     buf[0] = vi->rate;    // Sample rate
//     buf[1] = vi->channels; // Channels
//     env->SetIntArrayRegion(audioInfoArr, 0, 2, buf);

//     ov_clear(&vf);
//     env->ReleaseStringUTFChars(oggPath_jstr, oggPath);
//     return audioInfoArr;
// }

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_ogg_to_1aac_1converter_OggToAacConverterPlugin_decodeOggToPcm(
        JNIEnv* env,
        jobject /* this */,
        jstring oggPath_jstr,
        jstring pcmPath_jstr) {

    const char *oggPath = env->GetStringUTFChars(oggPath_jstr, nullptr);
    const char *pcmPath = env->GetStringUTFChars(pcmPath_jstr, nullptr);

    OggVorbis_File vf;
    FILE* pcmFile = nullptr;
    bool success = false;

    LOGI("Bắt đầu giải mã OGG: %s sang PCM: %s", oggPath, pcmPath);

    if (ov_fopen(oggPath, &vf) < 0) {
        LOGE("Không thể mở file OGG: %s", oggPath);
        goto cleanup;
    }

    pcmFile = fopen(pcmPath, "wb");
    if (!pcmFile) {
        LOGE("Không thể tạo file PCM: %s", pcmPath);
        goto cleanup;
    }

    // vorbis_info *vi = ov_info(&vf, -1); // Bạn đã có thông tin này từ getOggAudioInfo
    // LOGI("Thông tin Vorbis: channels=%d, rate=%ld", vi->channels, vi->rate);

    char pcm_buffer[16384]; // Tăng buffer size
    int current_section;
    long bytes_read;

    do {
        bytes_read = ov_read(&vf, pcm_buffer, sizeof(pcm_buffer), 0, 2, 1, &current_section);
        if (bytes_read < 0) {
            LOGE("Lỗi khi đọc từ stream OGG: %ld", bytes_read);
            goto cleanup;
        } else if (bytes_read > 0) {
            size_t written = fwrite(pcm_buffer, 1, bytes_read, pcmFile);
            if (written < bytes_read) {
                LOGE("Lỗi khi ghi vào file PCM");
                goto cleanup;
            }
        }
    } while (bytes_read > 0);

    LOGI("Giải mã OGG sang PCM thành công.");
    success = true;

cleanup:
    if (vf.datasource) { // Kiểm tra trước khi gọi ov_clear để tránh crash nếu ov_fopen thất bại
        ov_clear(&vf);
    }
    if (pcmFile) {
        fclose(pcmFile);
    }
    env->ReleaseStringUTFChars(oggPath_jstr, oggPath);
    env->ReleaseStringUTFChars(pcmPath_jstr, pcmPath);

    return success;
}
```

**Lưu ý quan trọng cho Android NDK:**
*   **Biên dịch `libogg`/`libvorbis`:** Đây là phần thử thách nhất. Bạn cần đảm bảo `CMakeLists.txt` của chúng (hoặc của bạn) được cấu hình đúng cho cross-compilation. Tìm các dự án đã port sẵn (ví dụ: trên GitHub) hoặc các file `.so` đã biên dịch sẵn cho các ABI của Android (armeabi-v7a, arm64-v8a, x86, x86_64) và đặt chúng vào `android/src/main/jniLibs/<ABI>/`. Đặt các file header vào `android/src/main/cpp/includes/ogg` và `android/src/main/cpp/includes/vorbis`.
*   **Lấy thông tin audio:** Cực kỳ quan trọng là phải lấy được sample rate và channel count từ file OGG để cấu hình `MediaCodec` chính xác. Bạn cần triển khai một hàm JNI (như `getOggAudioInfo` được comment ở trên) để đọc thông tin này từ `vorbis_info` và truyền lên tầng Kotlin/Java.

### 4. Mã Native cho iOS

Phần này bao gồm mã Swift/Objective-C để xử lý platform channel và tích hợp `libogg`/`libvorbis`.

#### a. Cấu hình `ios/ogg_to_aac_converter.podspec`

```ruby
# Trong ios/ogg_to_aac_converter.podspec
Pod::Spec.new do |s|
  s.name             = 'ogg_to_aac_converter'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin to convert OGG to AAC without FFMPEG.'
  s.description      = <<-DESC
A Flutter plugin to convert OGG audio files to AAC format using libogg/libvorbis and native platform APIs.
                       DESC
  s.homepage         = 'http://example.com' # Thay bằng URL của bạn
  s.license          = { :file => '../LICENSE' } # Giả sử bạn có file LICENSE ở thư mục gốc
  s.author           = { 'Your Name' => 'your.email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Thêm libogg và libvorbis làm vendored_frameworks hoặc vendored_libraries
  # Đây là cách nếu bạn có XCFrameworks đã biên dịch sẵn
  # s.vendored_frameworks = 'Frameworks/libogg.xcframework', 'Frameworks/libvorbis.xcframework'
  # Đảm bảo các XCFrameworks này nằm trong thư mục ios/Frameworks của plugin
  # Hoặc nếu bạn có thư viện tĩnh .a và headers:
  # s.vendored_libraries = 'Libraries/libogg.a', 'Libraries/libvorbis.a', 'Libraries/libvorbisfile.a'
  # s.xcconfig = { 'HEADER_SEARCH_PATHS' => '"$(PODS_ROOT)/ogg_to_aac_converter/Libraries/includes"' }
  # s.preserve_paths = 'Libraries/includes/**/*'

  # Quan trọng: Bạn cần cung cấp các thư viện này. Ví dụ:
  # Tải Xiph Ogg/Vorbis và biên dịch chúng cho iOS (arm64, simulator)
  # Hoặc tìm các bản build sẵn.
  # Ví dụ, nếu bạn đặt headers trong Classes/includes và libs trong Classes/libs:
  s.pod_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/Classes/includes"' }
  s.libraries = 'ogg', 'vorbis', 'vorbisfile'
  # Bạn cần thêm các file .a vào project hoặc cấu hình linker flags để tìm chúng.
  # Cách dễ hơn là dùng XCFrameworks nếu có.

  s.frameworks = 'AVFoundation', 'AudioToolbox'
  s.swift_version = '5.0'
end
```

#### b. `ios/Classes/OggToAacConverterPlugin.swift`

```swift
import Flutter
import UIKit
import AVFoundation
// Bạn cần import các module C nếu chúng được đóng gói đúng cách, hoặc dùng bridging header
// Ví dụ, nếu bạn có bridging header:
// #import "ogg/ogg.h"
// #import "vorbis/codec.h"
// #import "vorbis/vorbisfile.h"

// Cấu trúc để trả về thông tin audio từ OGG
struct OggAudioInfo {
    let sampleRate: Int32
    let channels: Int32
    let error: String?
}

public class OggToAacConverterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ogg_to_aac_converter", binaryMessenger: registrar.messenger())
        let instance = OggToAacConverterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "convertOggToAac" {
            guard let args = call.arguments as? [String: Any],
                  let inputPath = args["inputPath"] as? String,
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Input or output path is null or invalid", details: nil))
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let tempPcmUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".pcm")
                
                let audioInfo = self.getOggInfo(oggPath: inputPath)
                if let error = audioInfo.error {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "OGG_INFO_FAILED", message: "Failed to get OGG info: \(error)", details: nil))
                    }
                    return
                }

                let decodeSuccess = self.decodeOggToPcmFile(oggPath: inputPath, pcmPath: tempPcmUrl.path)
                
                if !decodeSuccess {
                    try? FileManager.default.removeItem(at: tempPcmUrl)
                    DispatchQueue.main.async {
                        result(FlutterError(code: "DECODE_FAILED", message: "Failed to decode OGG to PCM", details: nil))
                    }
                    return
                }

                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: audioInfo.sampleRate, // Lấy từ OGG
                    AVNumberOfChannelsKey: audioInfo.channels, // Lấy từ OGG
                    AVEncoderBitRateKey: 128000 // Ví dụ
                ]

                let encodeSuccess = self.encodePcmToAac(pcmUrl: tempPcmUrl, aacPath: outputPath, settings: audioSettings)
                try? FileManager.default.removeItem(at: tempPcmUrl)

                DispatchQueue.main.async {
                    if encodeSuccess {
                        result(outputPath)
                    } else {
                        result(FlutterError(code: "ENCODE_FAILED", message: "Failed to encode PCM to AAC", details: nil))
                    }
                }
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getOggInfo(oggPath: String) -> OggAudioInfo {
        var vf = OggVorbis_File()
        guard let oggPath_c = oggPath.cString(using: .utf8) else {
            return OggAudioInfo(sampleRate: 0, channels: 0, error: "Cannot convert oggPath to C string")
        }

        if ov_fopen(UnsafeMutablePointer(mutating: oggPath_c), &vf) < 0 {
            return OggAudioInfo(sampleRate: 0, channels: 0, error: "Cannot open OGG file: \(oggPath)")
        }
        defer { ov_clear(&vf) }

        guard let vi = ov_info(&vf, -1) else {
            return OggAudioInfo(sampleRate: 0, channels: 0, error: "Cannot get OGG info")
        }
        return OggAudioInfo(sampleRate: vi.pointee.rate, channels: vi.pointee.channels, error: nil)
    }

    private func decodeOggToPcmFile(oggPath: String, pcmPath: String) -> Bool {
        var vf = OggVorbis_File()
        guard let oggPath_c = oggPath.cString(using: .utf8),
              let pcmPath_c = pcmPath.cString(using: .utf8) else {
            print("decodeOggToPcmFile: Không thể chuyển đổi đường dẫn sang C string")
            return false
        }

        if ov_fopen(UnsafeMutablePointer(mutating: oggPath_c), &vf) < 0 {
            print("decodeOggToPcmFile: Không thể mở file OGG: \(oggPath)")
            return false
        }
        defer { ov_clear(&vf) }

        guard let pcmFile = fopen(pcmPath_c, "wb") else {
            print("decodeOggToPcmFile: Không thể tạo file PCM: \(pcmPath)")
            return false
        }
        defer { fclose(pcmFile) }

        var current_section: Int32 = 0
        let bufferSize = 16384
        var buffer = [CChar](repeating: 0, count: bufferSize)
        var bytesRead: Int

        repeat {
            bytesRead = Int(ov_read(&vf, &buffer, Int32(bufferSize), 0, 2, 1, &current_section))
            if bytesRead < 0 {
                print("decodeOggToPcmFile: Lỗi khi đọc từ stream OGG: \(bytesRead)")
                return false
            } else if bytesRead > 0 {
                let written = fwrite(buffer, 1, bytesRead, pcmFile)
                if written < bytesRead {
                    print("decodeOggToPcmFile: Lỗi khi ghi vào file PCM")
                    return false
                }
            }
        } while bytesRead > 0
        
        print("Giải mã OGG sang PCM thành công cho iOS.")
        return true
    }

    private func encodePcmToAac(pcmUrl: URL, aacPath: String, settings: [String: Any]) -> Bool {
        let outputUrl = URL(fileURLWithPath: aacPath)
        var assetWriter: AVAssetWriter?
        var assetWriterInput: AVAssetWriterInput?
        // Để đọc file PCM, chúng ta cần biết định dạng của nó (sample rate, channels, bit depth)
        // Giả sử file PCM là float 32-bit, little-endian, non-interleaved (cần điều chỉnh nếu khác)
        // AVAssetReader là một cách, hoặc đọc thủ công và đưa vào AVAudioConverter

        do {
            // Xóa file output nếu đã tồn tại
            if FileManager.default.fileExists(atPath: outputUrl.path) {
                try FileManager.default.removeItem(at: outputUrl)
            }

            let audioFile = try AVAudioFile(forReading: pcmUrl)
            // Cài đặt output format
            let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, 
                                             sampleRate: audioFile.processingFormat.sampleRate, 
                                             channels: audioFile.processingFormat.channelCount, 
                                             interleaved: false) // Non-interleaved for AAC usually
            
            guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: AVAudioFormat(settings: settings)!) else {
                print("Không thể tạo AVAudioConverter")
                return false
            }

            // Tạo output file để ghi
            let outputFile = try AVAudioFile(forWriting: outputUrl, settings: settings)

            let bufferCapacity: AVAudioFrameCount = 4096
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: bufferCapacity) else {
                 print("Không thể tạo AVAudioPCMBuffer")
                 return false
            }
            let outputBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: bufferCapacity)!

            while true {
                var error: NSError? = nil
                try audioFile.read(into: pcmBuffer, frameCount: bufferCapacity)
                if pcmBuffer.frameLength == 0 {
                    break // End of file
                }

                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return pcmBuffer
                }
                
                let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
                if status == .error || error != nil {
                    print("Lỗi khi convert: \(error?.localizedDescription ?? "Unknown error")")
                    return false
                }
                if status == .endOfStream {
                    break
                }
                if outputBuffer.frameLength > 0 {
                    try outputFile.write(from: outputBuffer)
                }
                pcmBuffer.frameLength = 0 // Reset for next read
                outputBuffer.frameLength = 0 // Reset for next conversion
            }
            // Xử lý phần còn lại trong converter (nếu có)
            let finalOutputBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: bufferCapacity)!
            var finalError: NSError? = nil
            let finalStatus = converter.convert(to: finalOutputBuffer, error: &finalError, withInputFrom: { numPackets, outStatus in
                outStatus.pointee = .endOfStream
                return nil
            })
            if finalStatus == .error || finalError != nil {
                 print("Lỗi khi finalizing conversion: \(finalError?.localizedDescription ?? "Unknown error")")
            }
            if finalOutputBuffer.frameLength > 0 {
                try outputFile.write(from: finalOutputBuffer)
            }

            return true
        } catch {
            print("Lỗi khi mã hóa AAC (AVAudioFile/AVAudioConverter): \(error.localizedDescription)")
            return false
        }
    }
}

// Cần tạo bridging header (ví dụ: ogg_to_aac_converter-Bridging-Header.h) và import:
/*
 #ifndef ogg_to_aac_converter_Bridging_Header_h
 #define ogg_to_aac_converter_Bridging_Header_h

 #import "ogg/ogg.h"
 #import "vorbis/codec.h"
 #import "vorbis/vorbisfile.h"

 #endif
 */
// Và cấu hình trong Build Settings -> Swift Compiler - General -> Objective-C Bridging Header
// trỏ đến file này (ví dụ: $(SRCROOT)/Classes/ogg_to_aac_converter-Bridging-Header.h)
```

**Lưu ý quan trọng cho iOS:**
*   **Bridging Header:** Nếu dùng Swift, bạn cần tạo bridging header để sử dụng thư viện C `libogg`/`libvorbis`.
*   **Thư viện `libogg`/`libvorbis`:** Tích hợp thư viện C vào iOS có thể phức tạp. Sử dụng XCFrameworks đã biên dịch sẵn là tốt nhất. Bạn cần biên dịch chúng cho các kiến trúc iOS (arm64, simulator) và macOS (cho simulator). Đặt chúng vào `ios/Frameworks` và cấu hình `.podspec`.
*   **Lấy thông tin audio:** Cần lấy sample rate và channels từ OGG để cấu hình `AVAudioConverter` hoặc `AVAssetWriter` chính xác.

### 5. Giấy phép (Licensing)

*   **Mã Plugin:** Sẽ được cấp phép theo một giấy phép mã nguồn mở dễ dãi (ví dụ: MIT hoặc Apache 2.0), theo yêu cầu.
*   **libogg & libvorbis:** Cả hai thường có sẵn theo giấy phép kiểu BSD, là giấy phép dễ dãi và tương thích với tính chất mã nguồn mở của plugin.
*   **MediaCodec (Android) & AVFoundation (iOS):** Đây là một phần của các hệ điều hành tương ứng và việc sử dụng chúng được điều chỉnh bởi giấy phép SDK của nền tảng.

Thiết kế này đảm bảo tất cả các thành phần tuân thủ yêu cầu mã nguồn mở và miễn phí sử dụng.

### 6. Sử dụng Plugin trong Ứng dụng Flutter

Sau khi bạn đã tạo plugin và thêm mã nguồn trên, hãy build lại ứng dụng Flutter của bạn. Trong mã Dart của ứng dụng, bạn có thể gọi hàm chuyển đổi:

```dart
import 'package:ogg_to_aac_converter/ogg_to_aac_converter.dart';
import 'package:path_provider/path_provider.dart'; // Để lấy thư mục lưu file
import 'dart:io';

// ... trong một hàm async nào đó
try {
  // Ví dụ: Lấy đường dẫn file OGG từ assets hoặc bộ nhớ
  // String inputOggPath = ...; (Bạn cần đảm bảo file này tồn tại)
  
  // Tạo đường dẫn cho file AAC output
  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  String outputAacPath = "${appDocumentsDir.path}/converted_audio.aac";

  // Giả sử bạn có một file OGG tên là 'sample.ogg' trong thư mục documents
  // Để test, bạn có thể copy file từ assets vào thư mục documents trước
  String inputOggPath = "${appDocumentsDir.path}/sample.ogg"; 

  print("Đang chuyển đổi: $inputOggPath sang $outputAacPath");
  String? resultPath = await OggToAacConverter.convert(inputOggPath, outputAacPath);

  if (resultPath != null) {
    print('Chuyển đổi thành công! File AAC được lưu tại: $resultPath');
  } else {
    print('Chuyển đổi thất bại.');
  }
} catch (e) {
  print('Lỗi khi gọi plugin: $e');
}
```

### 7. Biên dịch và Thử nghiệm

1.  **Biên dịch `libogg` và `libvorbis`:** Đây là bước phức tạp nhất. Bạn cần thiết lập môi trường NDK cho Android và một chuỗi công cụ phù hợp cho iOS để biên dịch các thư viện C này.
2.  **Tích hợp thư viện đã biên dịch:** Đặt các file thư viện đã biên dịch vào đúng vị trí và cấu hình `build.gradle`/`podspec`.
3.  **Viết mã JNI/Swift bridging:** Đảm bảo các hàm C được gọi đúng cách.
4.  **Kiểm thử kỹ lưỡng:** Thử nghiệm trên nhiều thiết bị và phiên bản OS.

Đây là một nhiệm vụ nâng cao. Chúc bạn thành công!

## Lời kết

Tài liệu này cung cấp một bộ khung và hướng dẫn chi tiết để bạn có thể tự phát triển plugin Flutter chuyển đổi OGG sang AAC. Do sự phức tạp của việc tích hợp thư viện C/C++ native, bạn có thể cần tham khảo thêm các tài liệu và ví dụ cụ thể cho việc biên dịch và liên kết `libogg`/`libvorbis` trên Android và iOS.


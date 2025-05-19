#include <jni.h>
#include <string>
#include <android/log.h>
#include <vector>

// Include necessary header files
#include "ogg/ogg.h"
#include "vorbis/codec.h"
#include "vorbis/vorbisenc.h"
#include "vorbis/vorbisfile.h"

#define LOG_TAG "NativeAudioConverter"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// JNI function to get audio information from OGG file
extern "C" JNIEXPORT jintArray JNICALL
Java_com_nmtuong_flutter_1ogg_1to_1aac_FlutterOggToAacPlugin_getOggAudioInfo(
        JNIEnv* env,
        jobject /* this */,
        jstring oggPath_jstr) {
    const char *oggPath = env->GetStringUTFChars(oggPath_jstr, nullptr);
    OggVorbis_File vf;
    jintArray audioInfoArr = env->NewIntArray(2);
    jint buf[2];

    if (ov_fopen(oggPath, &vf) < 0) {
        LOGE("getOggAudioInfo: Cannot open OGG file: %s", oggPath);
        env->ReleaseStringUTFChars(oggPath_jstr, oggPath);
        buf[0] = -1; buf[1] = -1; // Error indicator
        env->SetIntArrayRegion(audioInfoArr, 0, 2, buf);
        return audioInfoArr;
    }

    vorbis_info *vi = ov_info(&vf, -1);
    buf[0] = vi->rate;    // Sample rate
    buf[1] = vi->channels; // Channels
    env->SetIntArrayRegion(audioInfoArr, 0, 2, buf);

    LOGI("OGG info: sample rate=%d, channels=%d", buf[0], buf[1]);

    ov_clear(&vf);
    env->ReleaseStringUTFChars(oggPath_jstr, oggPath);
    return audioInfoArr;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_nmtuong_flutter_1ogg_1to_1aac_FlutterOggToAacPlugin_decodeOggToPcm(
        JNIEnv* env,
        jobject /* this */,
        jstring oggPath_jstr,
        jstring pcmPath_jstr) {

    const char *oggPath = env->GetStringUTFChars(oggPath_jstr, nullptr);
    const char *pcmPath = env->GetStringUTFChars(pcmPath_jstr, nullptr);

    OggVorbis_File vf;
    FILE* pcmFile = nullptr;
    bool success = false;
    vorbis_info *vi = nullptr;
    char pcm_buffer[65536]; // 64KB buffer for better performance
    int current_section;
    long bytes_read;

    LOGI("Starting OGG decoding: %s to PCM: %s", oggPath, pcmPath);

    if (ov_fopen(oggPath, &vf) < 0) {
        LOGE("Cannot open OGG file: %s", oggPath);
        goto cleanup;
    }

    // Use a larger buffer for file I/O
    pcmFile = fopen(pcmPath, "wb");
    if (pcmFile) {
        // Set a 64KB buffer for file I/O
        setvbuf(pcmFile, nullptr, _IOFBF, 65536);
    }
    if (!pcmFile) {
        LOGE("Cannot create PCM file: %s", pcmPath);
        goto cleanup;
    }

    vi = ov_info(&vf, -1);
    LOGI("Vorbis info: channels=%d, rate=%ld", vi->channels, vi->rate);

    do {
        bytes_read = ov_read(&vf, pcm_buffer, sizeof(pcm_buffer), 0, 2, 1, &current_section);
        if (bytes_read < 0) {
            LOGE("Error reading from OGG stream: %ld", bytes_read);
            goto cleanup;
        } else if (bytes_read > 0) {
            size_t written = fwrite(pcm_buffer, 1, bytes_read, pcmFile);
            if (written < bytes_read) {
                LOGE("Error writing to PCM file");
                goto cleanup;
            }
        }
    } while (bytes_read > 0);

    LOGI("OGG to PCM decoding successful.");
    success = true;

cleanup:
    if (vf.datasource) { // Check before calling ov_clear to avoid crash if ov_fopen failed
        ov_clear(&vf);
    }
    if (pcmFile) {
        fclose(pcmFile);
    }
    env->ReleaseStringUTFChars(oggPath_jstr, oggPath);
    env->ReleaseStringUTFChars(pcmPath_jstr, pcmPath);

    return success;
}

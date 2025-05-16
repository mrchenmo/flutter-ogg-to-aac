#include "OggConverter.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vorbis/vorbisfile.h>

// Get audio information from OGG file
int* getOggAudioInfo(const char* oggPath) {
    OggVorbis_File vf;
    int* audioInfo = (int*)malloc(2 * sizeof(int));
    
    // Initialize with zeros (error case)
    audioInfo[0] = 0;
    audioInfo[1] = 0;
    
    if (ov_fopen(oggPath, &vf) < 0) {
        printf("getOggAudioInfo: Cannot open OGG file: %s\n", oggPath);
        return audioInfo;
    }
    
    vorbis_info *vi = ov_info(&vf, -1);
    audioInfo[0] = vi->rate;    // Sample rate
    audioInfo[1] = vi->channels; // Channels
    
    printf("OGG info: sample rate=%d, channels=%d\n", audioInfo[0], audioInfo[1]);
    
    ov_clear(&vf);
    return audioInfo;
}

// Decode OGG to PCM
int decodeOggToPcm(const char* oggPath, const char* pcmPath) {
    OggVorbis_File vf;
    FILE* pcmFile = NULL;
    int success = 0;
    
    printf("Starting OGG decoding: %s to PCM: %s\n", oggPath, pcmPath);
    
    if (ov_fopen(oggPath, &vf) < 0) {
        printf("Cannot open OGG file: %s\n", oggPath);
        goto cleanup;
    }
    
    pcmFile = fopen(pcmPath, "wb");
    if (!pcmFile) {
        printf("Cannot create PCM file: %s\n", pcmPath);
        goto cleanup;
    }
    
    vorbis_info *vi = ov_info(&vf, -1);
    printf("Vorbis info: channels=%d, rate=%ld\n", vi->channels, vi->rate);
    
    char pcm_buffer[16384]; // Increased buffer size
    int current_section;
    long bytes_read;
    
    do {
        bytes_read = ov_read(&vf, pcm_buffer, sizeof(pcm_buffer), 0, 2, 1, &current_section);
        if (bytes_read < 0) {
            printf("Error reading from OGG stream: %ld\n", bytes_read);
            goto cleanup;
        } else if (bytes_read > 0) {
            size_t written = fwrite(pcm_buffer, 1, bytes_read, pcmFile);
            if (written < bytes_read) {
                printf("Error writing to PCM file\n");
                goto cleanup;
            }
        }
    } while (bytes_read > 0);
    
    printf("OGG to PCM decoding successful.\n");
    success = 1;
    
cleanup:
    if (vf.datasource) { // Check before calling ov_clear to avoid crash if ov_fopen failed
        ov_clear(&vf);
    }
    if (pcmFile) {
        fclose(pcmFile);
    }
    
    return success;
}

#ifndef OggConverter_h
#define OggConverter_h

#ifdef __cplusplus
extern "C" {
#endif

// Get audio information from OGG file
// Returns an array with [sampleRate, channels]
// If error occurs, returns [0, 0]
int* getOggAudioInfo(const char* oggPath);

// Decode OGG to PCM
// Returns 1 if successful, 0 if failed
int decodeOggToPcm(const char* oggPath, const char* pcmPath);

#ifdef __cplusplus
}
#endif

#endif /* OggConverter_h */

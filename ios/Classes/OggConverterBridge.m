#import "OggConverterBridge.h"
#import "OggConverter.h"

@implementation OggConverterBridge

// Get audio information from OGG file
+ (NSArray<NSNumber *> *)getOggAudioInfoFromPath:(NSString *)oggPath {
    const char *path = [oggPath UTF8String];
    int *audioInfo = getOggAudioInfo(path);
    
    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:2];
    [result addObject:@(audioInfo[0])]; // Sample rate
    [result addObject:@(audioInfo[1])]; // Channels
    
    free(audioInfo); // Free the memory allocated in C
    
    return result;
}

// Decode OGG to PCM
+ (BOOL)decodeOggToPcmFromPath:(NSString *)oggPath toPcmPath:(NSString *)pcmPath {
    const char *oggPathCStr = [oggPath UTF8String];
    const char *pcmPathCStr = [pcmPath UTF8String];
    
    int result = decodeOggToPcm(oggPathCStr, pcmPathCStr);
    
    return result == 1;
}

@end

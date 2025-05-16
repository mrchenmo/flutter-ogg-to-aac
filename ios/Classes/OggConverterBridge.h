#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OggConverterBridge : NSObject

// Get audio information from OGG file
// Returns an array with [sampleRate, channels]
+ (NSArray<NSNumber *> *)getOggAudioInfoFromPath:(NSString *)oggPath;

// Decode OGG to PCM
// Returns YES if successful, NO if failed
+ (BOOL)decodeOggToPcmFromPath:(NSString *)oggPath toPcmPath:(NSString *)pcmPath;

@end

NS_ASSUME_NONNULL_END

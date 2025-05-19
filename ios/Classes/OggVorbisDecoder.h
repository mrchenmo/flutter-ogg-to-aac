#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OggVorbisDecoder : NSObject

/**
 * Decode an OGG file to PCM data
 * @param inputPath Path to the input OGG file
 * @param error Error pointer
 * @return Path to the output PCM file, or nil if an error occurred
 */
+ (nullable NSString *)decodeOggToPCM:(NSString *)inputPath
                            sampleRate:(NSUInteger *)sampleRate
                              channels:(NSUInteger *)channels
                                 error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

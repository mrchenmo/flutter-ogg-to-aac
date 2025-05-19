#import "OggVorbisDecoder.h"
#include <ogg/ogg.h>
#include <vorbis/codec.h>
#include <vorbis/vorbisenc.h>
#include <vorbis/vorbisfile.h>

@implementation OggVorbisDecoder

+ (nullable NSString *)decodeOggToPCM:(NSString *)inputPath
                            sampleRate:(NSUInteger *)sampleRate
                              channels:(NSUInteger *)channels
                                 error:(NSError **)error {
    // Check if input file exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:inputPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.flutter_ogg_to_aac"
                                         code:404
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"OGG file not found at path: %@", inputPath]}];
        }
        return nil;
    }
    
    // Create temporary path for PCM file
    NSString *tempDir = NSTemporaryDirectory();
    NSString *pcmPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.pcm", [[NSUUID UUID] UUIDString]]];
    
    // Open OGG file
    OggVorbis_File vf;
    if (ov_fopen([inputPath UTF8String], &vf) != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.flutter_ogg_to_aac"
                                         code:500
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to open OGG file"}];
        }
        return nil;
    }
    
    // Get OGG file info
    vorbis_info *info = ov_info(&vf, 0);
    if (!info) {
        ov_clear(&vf);
        if (error) {
            *error = [NSError errorWithDomain:@"com.flutter_ogg_to_aac"
                                         code:500
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to get OGG file info"}];
        }
        return nil;
    }
    
    // Set output parameters
    *channels = info->channels;
    *sampleRate = info->rate;
    
    // Create PCM file
    if (![[NSFileManager defaultManager] createFileAtPath:pcmPath contents:nil attributes:nil]) {
        ov_clear(&vf);
        if (error) {
            *error = [NSError errorWithDomain:@"com.flutter_ogg_to_aac"
                                         code:500
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create PCM file"}];
        }
        return nil;
    }
    
    // Open file handle for writing
    NSFileHandle *outputFile = [NSFileHandle fileHandleForWritingAtPath:pcmPath];
    if (!outputFile) {
        ov_clear(&vf);
        if (error) {
            *error = [NSError errorWithDomain:@"com.flutter_ogg_to_aac"
                                         code:500
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to open PCM file for writing"}];
        }
        return nil;
    }
    
    // Buffer for reading OGG data
    const int bufferSize = 4096;
    char buffer[bufferSize];
    
    // Read and decode OGG data
    int bitstream = 0;
    long bytesRead = 0;
    
    do {
        bytesRead = ov_read(&vf, buffer, bufferSize, 0, 2, 1, &bitstream);
        
        if (bytesRead > 0) {
            NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
            [outputFile writeData:data];
        }
    } while (bytesRead > 0);
    
    // Close files
    [outputFile closeFile];
    ov_clear(&vf);
    
    return pcmPath;
}

@end

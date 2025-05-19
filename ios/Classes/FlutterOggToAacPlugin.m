#import "FlutterOggToAacPlugin.h"
#import "OggVorbisDecoder.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface FlutterOggToAacPlugin ()
@end

@implementation FlutterOggToAacPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_ogg_to_aac"
            binaryMessenger:[registrar messenger]];
  FlutterOggToAacPlugin* instance = [[FlutterOggToAacPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"convertOggToAac" isEqualToString:call.method]) {
    NSDictionary *arguments = call.arguments;
    NSString *inputPath = arguments[@"inputPath"];
    NSString *outputPath = arguments[@"outputPath"];

    NSLog(@"Received convert request - Input: %@, Output: %@", inputPath, outputPath);

    if (inputPath == nil || outputPath == nil) {
      NSLog(@"Invalid arguments - Input or output path missing");
      result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                 message:@"Input or output path missing"
                                 details:nil]);
      return;
    }

    // Use Documents directory instead of the provided path
    NSString *fileName = [outputPath lastPathComponent];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *safeOutputPath = [documentsDirectory stringByAppendingPathComponent:fileName];

    NSLog(@"Using safe output path: %@", safeOutputPath);

    [self convertOggToAac:inputPath outputPath:safeOutputPath completion:^(NSString *convertedPath, NSError *error) {
      if (error) {
        NSLog(@"Conversion error: %@", error.localizedDescription);
        result([FlutterError errorWithCode:@"CONVERSION_ERROR"
                                   message:[error localizedDescription]
                                   details:nil]);
      } else {
        NSLog(@"Conversion successful: %@", convertedPath);
        result(convertedPath);
      }
    }];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)convertOggToAac:(NSString *)inputPath outputPath:(NSString *)outputPath completion:(void(^)(NSString *convertedPath, NSError *error))completion {
  // Print path information for debugging
  NSLog(@"OGG to AAC conversion - Input path: %@", inputPath);
  NSLog(@"OGG to AAC conversion - Output path: %@", outputPath);

  // Check input path
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:inputPath]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(nil, [NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Input OGG file not found"}]);
    });
    return;
  }

  // Check output directory
  NSString *outputDirectory = [outputPath stringByDeletingLastPathComponent];
  BOOL isDirectory = NO;

  if (![fileManager fileExistsAtPath:outputDirectory isDirectory:&isDirectory] || !isDirectory) {
    NSError *dirError = nil;
    if (![fileManager createDirectoryAtPath:outputDirectory withIntermediateDirectories:YES attributes:nil error:&dirError]) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil, [NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                      userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot create output directory: %@", dirError.localizedDescription]}]);
      });
      return;
    }
  }

  // Run conversion on background thread to avoid blocking UI
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *error = nil;

    // Step 1: Decode OGG to PCM
    NSUInteger sampleRate = 0;
    NSUInteger channels = 0;
    NSString *pcmPath = [OggVorbisDecoder decodeOggToPCM:inputPath sampleRate:&sampleRate channels:&channels error:&error];

    if (error || pcmPath == nil) {
      NSLog(@"OGG to AAC conversion - Failed to decode OGG: %@", error ? error.localizedDescription : @"Unknown error");
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil, error ?: [NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500 userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode OGG file"}]);
      });
      return;
    }

    NSLog(@"OGG to AAC conversion - PCM file created at: %@", pcmPath);
    NSLog(@"OGG to AAC conversion - Sample rate: %lu, Channels: %lu", (unsigned long)sampleRate, (unsigned long)channels);

    // Step 2: Encode PCM to AAC
    [self encodePCMToAAC:pcmPath outputPath:outputPath sampleRate:(int)sampleRate channels:(int)channels completion:^(NSError *encodeError) {
      // Step 3: Delete temporary PCM file
      [[NSFileManager defaultManager] removeItemAtPath:pcmPath error:nil];

      dispatch_async(dispatch_get_main_queue(), ^{
        if (encodeError) {
          NSLog(@"OGG to AAC conversion - Failed to encode PCM to AAC: %@", encodeError.localizedDescription);
          completion(nil, encodeError);
        } else {
          NSLog(@"OGG to AAC conversion - Successfully converted to: %@", outputPath);
          completion(outputPath, nil);
        }
      });
    }];
  });
}

- (void)encodePCMToAAC:(NSString *)pcmPath outputPath:(NSString *)outputPath sampleRate:(int)sampleRate channels:(int)channels completion:(void(^)(NSError *error))completion {
    // Check input and output paths
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Check input file
    if (![fileManager fileExistsAtPath:pcmPath]) {
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:404
                                 userInfo:@{NSLocalizedDescriptionKey: @"Input PCM file not found"}]);
        return;
    }

    // Check output directory
    NSString *outputDirectory = [outputPath stringByDeletingLastPathComponent];
    BOOL isDirectory = NO;

    if (![fileManager fileExistsAtPath:outputDirectory isDirectory:&isDirectory] || !isDirectory) {
        NSError *dirError = nil;
        if (![fileManager createDirectoryAtPath:outputDirectory withIntermediateDirectories:YES attributes:nil error:&dirError]) {
            completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot create output directory: %@", dirError.localizedDescription]}]);
            return;
        }
    }

    // Check write permissions for output directory
    if (![fileManager isWritableFileAtPath:outputDirectory]) {
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: @"Output directory is not writable"}]);
        return;
    }

    // Delete output file if it already exists
    NSError *removeError = nil;
    if ([fileManager fileExistsAtPath:outputPath]) {
        if (![fileManager removeItemAtPath:outputPath error:&removeError]) {
            completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot remove existing output file: %@", removeError.localizedDescription]}]);
            return;
        }
    }

    // Create URLs for input and output files
    NSURL *inputURL = [NSURL fileURLWithPath:pcmPath];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

    // Read PCM data
    NSError *error = nil;
    NSData *pcmData = [NSData dataWithContentsOfFile:pcmPath options:0 error:&error];
    if (error) {
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to read PCM data: %@", error.localizedDescription]}]);
        return;
    }

    // Create a temporary WAV file from raw PCM
    NSString *tempDir = NSTemporaryDirectory();
    NSString *tempWavPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.wav", [[NSUUID UUID] UUIDString]]];
    NSURL *tempWavURL = [NSURL fileURLWithPath:tempWavPath];

    // Set up audio format for WAV file
    AudioStreamBasicDescription inputFormat;
    memset(&inputFormat, 0, sizeof(inputFormat));
    inputFormat.mSampleRate = sampleRate;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    inputFormat.mBitsPerChannel = 16;
    inputFormat.mChannelsPerFrame = channels;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame = channels * (inputFormat.mBitsPerChannel / 8);

    // Create temporary WAV file
    AudioFileID audioFile;
    OSStatus status = AudioFileCreateWithURL((__bridge CFURLRef)tempWavURL,
                                           kAudioFileWAVEType,
                                           &inputFormat,
                                           kAudioFileFlags_EraseFile,
                                           &audioFile);

    if (status != noErr) {
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to create WAV file: %d", (int)status]}]);
        return;
    }

    // Write PCM data to WAV file
    UInt32 bytesToWrite = (UInt32)pcmData.length;
    status = AudioFileWriteBytes(audioFile, false, 0, &bytesToWrite, pcmData.bytes);
    AudioFileClose(audioFile);

    if (status != noErr) {
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to write WAV file: %d", (int)status]}]);
        return;
    }

    // Create temporary AAC file
    NSString *tempAacPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.aac", [[NSUUID UUID] UUIDString]]];
    NSURL *tempAacURL = [NSURL fileURLWithPath:tempAacPath];

    // Set up audio format for AAC file
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = sampleRate;
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;
    outputFormat.mFormatFlags = 0;
    outputFormat.mBytesPerPacket = 0;
    outputFormat.mFramesPerPacket = 1024;
    outputFormat.mBytesPerFrame = 0;
    outputFormat.mChannelsPerFrame = channels;
    outputFormat.mBitsPerChannel = 0;

    // No need to set codec parameters for AAC

    // Create ExtAudioFile for input WAV file
    ExtAudioFileRef inputFile;
    status = ExtAudioFileOpenURL((__bridge CFURLRef)tempWavURL, &inputFile);
    if (status != noErr) {
        [fileManager removeItemAtPath:tempWavPath error:nil];
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to open WAV file: %d", (int)status]}]);
        return;
    }

    // Create ExtAudioFile for output AAC file
    ExtAudioFileRef outputFile;
    status = ExtAudioFileCreateWithURL((__bridge CFURLRef)tempAacURL,
                                     kAudioFileAAC_ADTSType,
                                     &outputFormat,
                                     NULL,
                                     kAudioFileFlags_EraseFile,
                                     &outputFile);

    if (status != noErr) {
        ExtAudioFileDispose(inputFile);
        [fileManager removeItemAtPath:tempWavPath error:nil];
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to create AAC file: %d", (int)status]}]);
        return;
    }

    // Set client data format for output file
    status = ExtAudioFileSetProperty(outputFile,
                                   kExtAudioFileProperty_ClientDataFormat,
                                   sizeof(inputFormat),
                                   &inputFormat);

    if (status != noErr) {
        ExtAudioFileDispose(inputFile);
        ExtAudioFileDispose(outputFile);
        [fileManager removeItemAtPath:tempWavPath error:nil];
        [fileManager removeItemAtPath:tempAacPath error:nil];
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to set client data format: %d", (int)status]}]);
        return;
    }

    // Set codec parameters for output file
    UInt32 codecQuality = 127; // Highest quality
    status = ExtAudioFileSetProperty(outputFile,
                                   kExtAudioFileProperty_CodecManufacturer,
                                   sizeof(codecQuality),
                                   &codecQuality);

    // Set bit rate for output file (196 kbps - same as Android)
    // Use a different way to set bit rate
    // Note: cannot set bit rate directly for ExtAudioFile
    // Bit rate will be set automatically based on codec quality

    // Read data from WAV file and write to AAC file
    const UInt32 bufferSize = 32768;
    void *buffer = malloc(bufferSize);
    if (!buffer) {
        ExtAudioFileDispose(inputFile);
        ExtAudioFileDispose(outputFile);
        [fileManager removeItemAtPath:tempWavPath error:nil];
        [fileManager removeItemAtPath:tempAacPath error:nil];
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: @"Failed to allocate memory"}]);
        return;
    }

    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = channels;
    bufferList.mBuffers[0].mDataByteSize = bufferSize;
    bufferList.mBuffers[0].mData = buffer;

    UInt32 frames = bufferSize / (channels * sizeof(SInt16));

    while (true) {
        bufferList.mBuffers[0].mDataByteSize = bufferSize;
        status = ExtAudioFileRead(inputFile, &frames, &bufferList);

        if (status != noErr) {
            break;
        }

        if (frames == 0) {
            break;
        }

        status = ExtAudioFileWrite(outputFile, frames, &bufferList);

        if (status != noErr) {
            break;
        }
    }

    // Free resources
    free(buffer);
    ExtAudioFileDispose(inputFile);
    ExtAudioFileDispose(outputFile);

    // Delete temporary WAV file
    [fileManager removeItemAtPath:tempWavPath error:nil];

    if (status != noErr) {
        [fileManager removeItemAtPath:tempAacPath error:nil];
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to convert WAV to AAC: %d", (int)status]}]);
        return;
    }

    // Copy file from temporary directory to destination path
    NSError *copyError = nil;
    if ([fileManager copyItemAtPath:tempAacPath toPath:outputPath error:&copyError]) {
        // Delete temporary file
        [fileManager removeItemAtPath:tempAacPath error:nil];
        completion(nil);
    } else {
        [fileManager removeItemAtPath:tempAacPath error:nil];
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot write output file: %@", copyError.localizedDescription]}]);
    }
}

@end

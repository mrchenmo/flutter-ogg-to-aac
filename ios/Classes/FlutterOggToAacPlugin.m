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

    // Sử dụng thư mục Documents thay vì đường dẫn được cung cấp
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
  // In thông tin đường dẫn để debug
  NSLog(@"OGG to AAC conversion - Input path: %@", inputPath);
  NSLog(@"OGG to AAC conversion - Output path: %@", outputPath);

  // Kiểm tra đường dẫn đầu vào
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:inputPath]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(nil, [NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Input OGG file not found"}]);
    });
    return;
  }

  // Kiểm tra thư mục đầu ra
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
    // Kiểm tra đường dẫn đầu vào và đầu ra
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Kiểm tra file đầu vào
    if (![fileManager fileExistsAtPath:pcmPath]) {
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:404
                                 userInfo:@{NSLocalizedDescriptionKey: @"Input PCM file not found"}]);
        return;
    }

    // Kiểm tra thư mục đầu ra
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

    // Kiểm tra quyền ghi vào thư mục đầu ra
    if (![fileManager isWritableFileAtPath:outputDirectory]) {
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: @"Output directory is not writable"}]);
        return;
    }

    // Xóa file đầu ra nếu đã tồn tại
    NSError *removeError = nil;
    if ([fileManager fileExistsAtPath:outputPath]) {
        if (![fileManager removeItemAtPath:outputPath error:&removeError]) {
            completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot remove existing output file: %@", removeError.localizedDescription]}]);
            return;
        }
    }

    // Tạo URL cho file đầu vào và đầu ra
    NSURL *inputURL = [NSURL fileURLWithPath:pcmPath];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

    // Đọc dữ liệu PCM
    NSError *error = nil;
    NSData *pcmData = [NSData dataWithContentsOfFile:pcmPath options:0 error:&error];
    if (error) {
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to read PCM data: %@", error.localizedDescription]}]);
        return;
    }

    // Tạo một file WAV tạm thời từ PCM raw
    NSString *tempDir = NSTemporaryDirectory();
    NSString *tempWavPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.wav", [[NSUUID UUID] UUIDString]]];
    NSURL *tempWavURL = [NSURL fileURLWithPath:tempWavPath];

    // Thiết lập định dạng âm thanh cho file WAV
    AudioStreamBasicDescription inputFormat;
    memset(&inputFormat, 0, sizeof(inputFormat));
    inputFormat.mSampleRate = sampleRate;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    inputFormat.mBitsPerChannel = 16;
    inputFormat.mChannelsPerFrame = channels;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame = channels * (inputFormat.mBitsPerChannel / 8);

    // Tạo file WAV tạm thời
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

    // Ghi dữ liệu PCM vào file WAV
    UInt32 bytesToWrite = (UInt32)pcmData.length;
    status = AudioFileWriteBytes(audioFile, false, 0, &bytesToWrite, pcmData.bytes);
    AudioFileClose(audioFile);

    if (status != noErr) {
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to write WAV file: %d", (int)status]}]);
        return;
    }

    // Tạo file AAC tạm thời
    NSString *tempAacPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.aac", [[NSUUID UUID] UUIDString]]];
    NSURL *tempAacURL = [NSURL fileURLWithPath:tempAacPath];

    // Thiết lập định dạng âm thanh cho file AAC
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

    // Không cần thiết lập các tham số codec cho AAC

    // Tạo ExtAudioFile cho file WAV đầu vào
    ExtAudioFileRef inputFile;
    status = ExtAudioFileOpenURL((__bridge CFURLRef)tempWavURL, &inputFile);
    if (status != noErr) {
        [fileManager removeItemAtPath:tempWavPath error:nil];
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to open WAV file: %d", (int)status]}]);
        return;
    }

    // Tạo ExtAudioFile cho file AAC đầu ra
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

    // Thiết lập client data format cho file đầu ra
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

    // Thiết lập codec parameters cho file đầu ra
    UInt32 codecQuality = 127; // Highest quality
    status = ExtAudioFileSetProperty(outputFile,
                                   kExtAudioFileProperty_CodecManufacturer,
                                   sizeof(codecQuality),
                                   &codecQuality);

    // Thiết lập bit rate cho file đầu ra (196 kbps - giống Android)
    // Sử dụng cách khác để thiết lập bit rate
    // Lưu ý: không thể thiết lập bit rate trực tiếp cho ExtAudioFile
    // Bit rate sẽ được thiết lập tự động dựa trên chất lượng codec

    // Đọc dữ liệu từ file WAV và ghi vào file AAC
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

    // Giải phóng tài nguyên
    free(buffer);
    ExtAudioFileDispose(inputFile);
    ExtAudioFileDispose(outputFile);

    // Xóa file WAV tạm thời
    [fileManager removeItemAtPath:tempWavPath error:nil];

    if (status != noErr) {
        [fileManager removeItemAtPath:tempAacPath error:nil];
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to convert WAV to AAC: %d", (int)status]}]);
        return;
    }

    // Copy file từ thư mục tạm sang đường dẫn đích
    NSError *copyError = nil;
    if ([fileManager copyItemAtPath:tempAacPath toPath:outputPath error:&copyError]) {
        // Xóa file tạm thời
        [fileManager removeItemAtPath:tempAacPath error:nil];
        completion(nil);
    } else {
        [fileManager removeItemAtPath:tempAacPath error:nil];
        completion([NSError errorWithDomain:@"com.flutter_ogg_to_aac" code:500
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot write output file: %@", copyError.localizedDescription]}]);
    }
}

@end

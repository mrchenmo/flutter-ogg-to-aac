import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ogg_to_aac_converter_platform_interface.dart';

/// An implementation of [OggToAacConverterPlatform] that uses method channels.
class MethodChannelOggToAacConverter extends OggToAacConverterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ogg_to_aac_converter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String?> convert(String inputPath, String outputPath) async {
    if (inputPath.isEmpty || outputPath.isEmpty) {
      throw ArgumentError('Input and output paths cannot be empty.');
    }

    try {
      final String? resultPath = await methodChannel.invokeMethod('convertOggToAac', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return resultPath;
    } catch (e) {
      print('Error during conversion process: $e');
      rethrow;
    }
  }
}

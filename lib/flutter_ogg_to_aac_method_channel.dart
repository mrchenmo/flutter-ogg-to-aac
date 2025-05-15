import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ogg_to_aac_platform_interface.dart';

/// An implementation of [FlutterOggToAacPlatform] that uses method channels.
class MethodChannelFlutterOggToAac extends FlutterOggToAacPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_ogg_to_aac');

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

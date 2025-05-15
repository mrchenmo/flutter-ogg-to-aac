import 'flutter_ogg_to_aac_platform_interface.dart';

class FlutterOggToAac {
  /// Get platform version
  Future<String?> getPlatformVersion() {
    return FlutterOggToAacPlatform.instance.getPlatformVersion();
  }

  /// Convert audio file from OGG to AAC.
  ///
  /// [inputPath] is the absolute path to the input OGG file.
  /// [outputPath] is the desired absolute path for the output AAC file.
  ///
  /// Returns the absolute path to the converted AAC file if successful.
  /// Throws [PlatformException] if the conversion process fails.
  static Future<String?> convert(String inputPath, String outputPath) {
    return FlutterOggToAacPlatform.instance.convert(inputPath, outputPath);
  }
}

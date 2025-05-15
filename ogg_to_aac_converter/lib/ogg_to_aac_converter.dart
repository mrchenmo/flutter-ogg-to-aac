import 'ogg_to_aac_converter_platform_interface.dart';

class OggToAacConverter {
  /// Get platform version
  Future<String?> getPlatformVersion() {
    return OggToAacConverterPlatform.instance.getPlatformVersion();
  }

  /// Convert audio file from OGG to AAC.
  ///
  /// [inputPath] is the absolute path to the input OGG file.
  /// [outputPath] is the desired absolute path for the output AAC file.
  ///
  /// Returns the absolute path to the converted AAC file if successful.
  /// Throws [PlatformException] if the conversion process fails.
  static Future<String?> convert(String inputPath, String outputPath) {
    return OggToAacConverterPlatform.instance.convert(inputPath, outputPath);
  }
}

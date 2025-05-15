import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ogg_to_aac_converter_method_channel.dart';

abstract class OggToAacConverterPlatform extends PlatformInterface {
  /// Constructs a OggToAacConverterPlatform.
  OggToAacConverterPlatform() : super(token: _token);

  static final Object _token = Object();

  static OggToAacConverterPlatform _instance = MethodChannelOggToAacConverter();

  /// The default instance of [OggToAacConverterPlatform] to use.
  ///
  /// Defaults to [MethodChannelOggToAacConverter].
  static OggToAacConverterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OggToAacConverterPlatform] when
  /// they register themselves.
  static set instance(OggToAacConverterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Convert audio file from OGG to AAC.
  ///
  /// [inputPath] is the absolute path to the input OGG file.
  /// [outputPath] is the desired absolute path for the output AAC file.
  ///
  /// Returns the absolute path to the converted AAC file if successful.
  /// Throws [PlatformException] if the conversion process fails.
  Future<String?> convert(String inputPath, String outputPath) {
    throw UnimplementedError('convert() has not been implemented.');
  }
}

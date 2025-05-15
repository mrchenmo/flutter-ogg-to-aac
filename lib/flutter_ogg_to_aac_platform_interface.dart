import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ogg_to_aac_method_channel.dart';

abstract class FlutterOggToAacPlatform extends PlatformInterface {
  /// Constructs a FlutterOggToAacPlatform.
  FlutterOggToAacPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterOggToAacPlatform _instance = MethodChannelFlutterOggToAac();

  /// The default instance of [FlutterOggToAacPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterOggToAac].
  static FlutterOggToAacPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterOggToAacPlatform] when
  /// they register themselves.
  static set instance(FlutterOggToAacPlatform instance) {
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

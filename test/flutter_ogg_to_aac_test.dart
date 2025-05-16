import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac_platform_interface.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterOggToAacPlatform
    with MockPlatformInterfaceMixin
    implements FlutterOggToAacPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String?> convert(String inputPath, String outputPath) {
    if (inputPath.isEmpty) {
      throw ArgumentError('Input path cannot be empty.');
    }
    if (outputPath.isEmpty) {
      throw ArgumentError('Output path cannot be empty.');
    }
    return Future.value('/path/to/output.aac');
  }
}

void main() {
  final FlutterOggToAacPlatform initialPlatform = FlutterOggToAacPlatform.instance;

  test('$MethodChannelFlutterOggToAac is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterOggToAac>());
  });

  test('getPlatformVersion', () async {
    FlutterOggToAac flutterOggToAacPlugin = FlutterOggToAac();
    MockFlutterOggToAacPlatform fakePlatform = MockFlutterOggToAacPlatform();
    FlutterOggToAacPlatform.instance = fakePlatform;

    expect(await flutterOggToAacPlugin.getPlatformVersion(), '42');
  });

  group('convert', () {
    late MockFlutterOggToAacPlatform fakePlatform;

    setUp(() {
      fakePlatform = MockFlutterOggToAacPlatform();
      FlutterOggToAacPlatform.instance = fakePlatform;
    });

    test('returns correct output path on success', () async {
      final result = await FlutterOggToAac.convert('/path/to/input.ogg', '/path/to/output.aac');
      expect(result, '/path/to/output.aac');
    });

    test('throws ArgumentError when input path is empty', () {
      expect(
        () => FlutterOggToAac.convert('', '/path/to/output.aac'),
        throwsA(isA<ArgumentError>())
      );
    });

    test('throws ArgumentError when output path is empty', () {
      expect(
        () => FlutterOggToAac.convert('/path/to/input.ogg', ''),
        throwsA(isA<ArgumentError>())
      );
    });
  });
}

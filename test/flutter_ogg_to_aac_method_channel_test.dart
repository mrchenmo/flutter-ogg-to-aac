import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterOggToAac platform = MethodChannelFlutterOggToAac();
  const MethodChannel channel = MethodChannel('flutter_ogg_to_aac');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getPlatformVersion') {
          return '42';
        } else if (methodCall.method == 'convertOggToAac') {
          final Map<dynamic, dynamic> args = methodCall.arguments as Map<dynamic, dynamic>;
          final String inputPath = args['inputPath'] as String;
          final String outputPath = args['outputPath'] as String;

          // Check input path
          if (inputPath.contains('non_existent')) {
            throw PlatformException(
              code: 'CONVERSION_ERROR',
              message: 'File not found',
              details: 'Input file does not exist: $inputPath'
            );
          }

          // Return output path if successful
          return outputPath;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  group('convert', () {
    test('returns output path on success', () async {
      final result = await platform.convert('/path/to/input.ogg', '/path/to/output.aac');
      expect(result, '/path/to/output.aac');
    });

    test('throws PlatformException when file does not exist', () async {
      expect(
        () => platform.convert('/path/to/non_existent.ogg', '/path/to/output.aac'),
        throwsA(isA<PlatformException>())
      );
    });

    test('throws ArgumentError when input path is empty', () async {
      expect(
        () => platform.convert('', '/path/to/output.aac'),
        throwsA(isA<ArgumentError>())
      );
    });

    test('throws ArgumentError when output path is empty', () async {
      expect(
        () => platform.convert('/path/to/input.ogg', ''),
        throwsA(isA<ArgumentError>())
      );
    });
  });
}

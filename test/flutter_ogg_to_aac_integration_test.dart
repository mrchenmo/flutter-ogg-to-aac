import 'package:flutter/services.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:flutter_test/flutter_test.dart';

// Lưu ý: Đây là test giả lập, không cần file thật
// Để chạy test thật trên thiết bị, cần chuẩn bị file test_audio.ogg

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterOggToAac Mock Integration Tests', () {
    const String testOggPath = '/path/to/test_audio.ogg';
    const String outputAacPath = '/path/to/output_audio.aac';
    const String nonExistentPath = '/path/to/non_existent.ogg';

    // Thiết lập mock cho MethodChannel
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_ogg_to_aac'), (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'convertOggToAac') {
              final Map<dynamic, dynamic> args =
                  methodCall.arguments as Map<dynamic, dynamic>;
              final String inputPath = args['inputPath'] as String;
              final String outputPath = args['outputPath'] as String;

              // Giả lập lỗi khi file không tồn tại
              if (inputPath.contains('non_existent')) {
                throw PlatformException(
                  code: 'CONVERSION_ERROR',
                  message: 'File not found',
                  details: 'Input file does not exist: $inputPath',
                );
              }

              // Trả về đường dẫn đầu ra nếu thành công
              return outputPath;
            } else if (methodCall.method == 'getPlatformVersion') {
              return 'iOS 16.0';
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_ogg_to_aac'),
            null,
          );
    });

    test('Convert valid OGG to AAC', () async {
      try {
        // Thực hiện chuyển đổi
        final result = await FlutterOggToAac.convert(
          testOggPath,
          outputAacPath,
        );

        // Kiểm tra kết quả
        print('Conversion completed: $result');
        expect(result, isNotNull);
        expect(result, outputAacPath);
      } catch (e) {
        fail('Conversion failed with error: $e');
      }
    });

    test('Throws error when input file does not exist', () async {
      // Thực hiện chuyển đổi và mong đợi lỗi
      expect(
        () => FlutterOggToAac.convert(nonExistentPath, outputAacPath),
        throwsA(isA<PlatformException>()),
      );
    });

    test('Throws ArgumentError when input path is empty', () async {
      expect(
        () => FlutterOggToAac.convert('', outputAacPath),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Throws ArgumentError when output path is empty', () async {
      expect(
        () => FlutterOggToAac.convert(testOggPath, ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

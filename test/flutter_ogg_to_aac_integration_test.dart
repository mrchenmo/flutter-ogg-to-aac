import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// Lưu ý: Test này cần chạy trên thiết bị thật hoặc máy ảo
// Sử dụng lệnh: flutter test integration_test/flutter_ogg_to_aac_integration_test.dart

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterOggToAac Integration Tests', () {
    late String tempDir;
    late String testOggPath;
    late String outputAacPath;

    setUpAll(() async {
      // Khởi tạo TestWidgetsFlutterBinding để có thể sử dụng rootBundle
      TestWidgetsFlutterBinding.ensureInitialized();

      // Lấy thư mục tạm để lưu file test
      final directory = await getTemporaryDirectory();
      tempDir = directory.path;

      // Tạo đường dẫn cho file test
      testOggPath = '$tempDir/sample-1.ogg';
      outputAacPath = '$tempDir/output_audio.aac';

      // Sao chép file sample-1.ogg vào thư mục tạm
      final File sourceFile = File('sample-1.ogg');
      final File destinationFile = File(testOggPath);

      if (await sourceFile.exists()) {
        await sourceFile.copy(testOggPath);
        print('Sample OGG file copied to: $testOggPath');
      } else {
        throw Exception('Source file sample-1.ogg not found in project root directory');
      }

      // Kiểm tra file đã được tạo
      print('Test OGG file path: $testOggPath');
      print('File exists: ${await File(testOggPath).exists()}');

      // Kiểm tra kích thước file
      final fileStats = await File(testOggPath).stat();
      print('File size: ${fileStats.size} bytes');
    });

    tearDownAll(() async {
      // Xóa các file test sau khi hoàn thành
      final testOggFile = File(testOggPath);
      final outputAacFile = File(outputAacPath);

      if (await testOggFile.exists()) {
        await testOggFile.delete();
      }

      if (await outputAacFile.exists()) {
        await outputAacFile.delete();
      }
    });

    testWidgets('Convert valid OGG to AAC', (WidgetTester tester) async {
      // Kiểm tra file OGG test đã được tạo
      expect(await File(testOggPath).exists(), true);

      try {
        // Thực hiện chuyển đổi
        final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);

        // Kiểm tra kết quả
        print('Conversion completed: $result');
        expect(result, isNotNull);
        expect(await File(outputAacPath).exists(), true, reason: 'Output AAC file should exist');

        // Kiểm tra kích thước file đầu ra
        final fileStats = await File(outputAacPath).stat();
        print('Output AAC file size: ${fileStats.size} bytes');
        expect(fileStats.size, greaterThan(0), reason: 'Output AAC file should not be empty');

        // Kiểm tra header của file AAC
        final outputFile = File(outputAacPath);
        final bytes = await outputFile.openRead(0, 2).toList();
        final flattenedBytes = bytes.expand((x) => x).toList();

        // Kiểm tra ADTS header (0xFF, 0xF1)
        if (flattenedBytes.length >= 2) {
          print('First two bytes: 0x${flattenedBytes[0].toRadixString(16).padLeft(2, '0')}, 0x${flattenedBytes[1].toRadixString(16).padLeft(2, '0')}');
          expect(flattenedBytes[0], 0xFF, reason: 'First byte should be 0xFF (ADTS sync word)');
          expect(flattenedBytes[1] & 0xF0, 0xF0, reason: 'Second byte should start with 0xF');
        } else {
          fail('Could not read first two bytes of output file');
        }
      } catch (e) {
        fail('Conversion failed with error: $e');
      }
    });

    testWidgets('Throws error when input file does not exist', (WidgetTester tester) async {
      final nonExistentPath = '$tempDir/non_existent.ogg';

      // Đảm bảo file không tồn tại
      final nonExistentFile = File(nonExistentPath);
      if (await nonExistentFile.exists()) {
        await nonExistentFile.delete();
      }

      // Thực hiện chuyển đổi và mong đợi lỗi
      expect(
        () => FlutterOggToAac.convert(nonExistentPath, outputAacPath),
        throwsA(isA<PlatformException>())
      );
    });
  });
}

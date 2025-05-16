import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

// Lưu ý: Test này cần chạy trên thiết bị thật hoặc máy ảo
// Sử dụng lệnh: flutter test integration_test/flutter_ogg_to_aac_integration_test.dart

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterOggToAac Integration Tests', () {
    late String tempDir;
    late String testOggPath;
    late String outputAacPath;

    setUpAll(() async {
      // Lấy thư mục tạm để lưu file test
      final directory = await getTemporaryDirectory();
      tempDir = directory.path;
      
      // Tạo đường dẫn cho file test
      testOggPath = '$tempDir/test_audio.ogg';
      outputAacPath = '$tempDir/output_audio.aac';
      
      // Tạo file OGG test từ asset
      final ByteData data = await rootBundle.load('assets/test_audio.ogg');
      final buffer = data.buffer;
      await File(testOggPath).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)
      );
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

    testWidgets('Convert OGG to AAC successfully', (WidgetTester tester) async {
      // Kiểm tra file OGG test đã được tạo
      expect(await File(testOggPath).exists(), true);
      
      // Thực hiện chuyển đổi
      final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);
      
      // Kiểm tra kết quả
      expect(result, isNotNull);
      expect(await File(outputAacPath).exists(), true);
      
      // Kiểm tra kích thước file đầu ra
      final fileStats = await File(outputAacPath).stat();
      expect(fileStats.size, greaterThan(0));
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test OGG to AAC conversion on device', (WidgetTester tester) async {
    // Lấy thư mục tạm để lưu file test
    final directory = await getTemporaryDirectory();
    final tempDir = directory.path;
    
    // Tạo đường dẫn cho file test
    final testOggPath = '$tempDir/test_audio.ogg';
    final outputAacPath = '$tempDir/output_audio.aac';
    
    // Tạo file OGG test từ asset
    try {
      final ByteData data = await rootBundle.load('assets/sample.ogg');
      final buffer = data.buffer;
      await File(testOggPath).writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)
      );
      
      print('Đã tạo file test OGG: $testOggPath');
      print('Kích thước file: ${await File(testOggPath).length()} bytes');
      
      // Kiểm tra file OGG test đã được tạo
      expect(await File(testOggPath).exists(), true);
      
      // Thực hiện chuyển đổi
      print('Bắt đầu chuyển đổi OGG sang AAC...');
      final stopwatch = Stopwatch()..start();
      
      final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);
      
      stopwatch.stop();
      print('Thời gian chuyển đổi: ${stopwatch.elapsedMilliseconds} ms');
      
      // Kiểm tra kết quả
      print('Kết quả chuyển đổi: $result');
      expect(result, isNotNull);
      
      if (await File(outputAacPath).exists()) {
        print('File AAC đã được tạo: $outputAacPath');
        print('Kích thước file AAC: ${await File(outputAacPath).length()} bytes');
        expect(await File(outputAacPath).length(), greaterThan(0));
      } else {
        print('File AAC không tồn tại!');
        expect(await File(outputAacPath).exists(), true);
      }
      
      // Xóa các file test
      await File(testOggPath).delete();
      await File(outputAacPath).delete();
      
    } catch (e) {
      print('Lỗi trong quá trình test: $e');
      fail('Test thất bại với lỗi: $e');
    }
  });
}

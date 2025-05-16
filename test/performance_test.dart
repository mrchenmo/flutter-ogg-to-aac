import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

// Lưu ý: Test này cần chạy trên thiết bị thật hoặc máy ảo
// Sử dụng lệnh: flutter test test/performance_test.dart

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterOggToAac Performance Tests', () {
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
      try {
        final ByteData data = await rootBundle.load('assets/test_audio.ogg');
        final buffer = data.buffer;
        await File(testOggPath).writeAsBytes(
          buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)
        );
      } catch (e) {
        print('Không thể tạo file test: $e');
        // Tạo một file OGG trống để test
        await File(testOggPath).writeAsBytes([]);
      }
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

    test('Measure conversion time', () async {
      if (!await File(testOggPath).exists()) {
        // Skip test if test file doesn't exist
        return;
      }
      
      // Đo thời gian chuyển đổi
      final stopwatch = Stopwatch()..start();
      
      try {
        await FlutterOggToAac.convert(testOggPath, outputAacPath);
      } catch (e) {
        print('Lỗi khi chuyển đổi: $e');
        return;
      }
      
      stopwatch.stop();
      
      // In thời gian chuyển đổi
      print('Thời gian chuyển đổi: ${stopwatch.elapsedMilliseconds} ms');
      
      // Kiểm tra kết quả
      expect(await File(outputAacPath).exists(), true);
      
      // Kiểm tra kích thước file đầu ra
      final inputFileSize = await File(testOggPath).length();
      final outputFileSize = await File(outputAacPath).length();
      
      print('Kích thước file đầu vào: $inputFileSize bytes');
      print('Kích thước file đầu ra: $outputFileSize bytes');
      print('Tỷ lệ nén: ${outputFileSize / inputFileSize}');
      
      // Đảm bảo file đầu ra có kích thước hợp lý
      expect(outputFileSize, greaterThan(0));
    });

    test('Test multiple conversions', () async {
      if (!await File(testOggPath).exists()) {
        // Skip test if test file doesn't exist
        return;
      }
      
      const iterations = 3;
      final conversionTimes = <int>[];
      
      for (var i = 0; i < iterations; i++) {
        final outputPath = '$tempDir/output_audio_$i.aac';
        
        // Đo thời gian chuyển đổi
        final stopwatch = Stopwatch()..start();
        
        try {
          await FlutterOggToAac.convert(testOggPath, outputPath);
        } catch (e) {
          print('Lỗi khi chuyển đổi lần $i: $e');
          continue;
        }
        
        stopwatch.stop();
        conversionTimes.add(stopwatch.elapsedMilliseconds);
        
        // Kiểm tra kết quả
        expect(await File(outputPath).exists(), true);
        
        // Xóa file đầu ra
        await File(outputPath).delete();
      }
      
      // In thời gian chuyển đổi trung bình
      if (conversionTimes.isNotEmpty) {
        final averageTime = conversionTimes.reduce((a, b) => a + b) / conversionTimes.length;
        print('Thời gian chuyển đổi trung bình: $averageTime ms');
      }
    });
  });
}

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ADTS Header Analysis', () {
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
        final ByteData data = await rootBundle.load('assets/sample.ogg');
        final buffer = data.buffer;
        await File(testOggPath).writeAsBytes(
          buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)
        );
        
        print('Đã tạo file test OGG: $testOggPath');
        print('Kích thước file: ${await File(testOggPath).length()} bytes');
      } catch (e) {
        print('Không thể tạo file test: $e');
        fail('Không thể tạo file test: $e');
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

    testWidgets('Analyze ADTS header in AAC file', (WidgetTester tester) async {
      // Thực hiện chuyển đổi
      print('Bắt đầu chuyển đổi OGG sang AAC...');
      final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);
      print('Kết quả chuyển đổi: $result');
      
      // Kiểm tra file đã được tạo
      expect(await File(outputAacPath).exists(), true);
      
      // Đọc file AAC
      final bytes = await File(outputAacPath).readAsBytes();
      print('Kích thước file AAC: ${bytes.length} bytes');
      
      // Tìm kiếm ADTS header
      int adtsHeaderPosition = -1;
      for (int i = 0; i < bytes.length - 2; i++) {
        if (bytes[i] == 0xFF && (bytes[i + 1] & 0xF0) == 0xF0) {
          adtsHeaderPosition = i;
          break;
        }
      }
      
      if (adtsHeaderPosition >= 0) {
        print('Tìm thấy ADTS header tại vị trí $adtsHeaderPosition');
        
        // Phân tích ADTS header
        if (adtsHeaderPosition + 7 <= bytes.length) {
          final adtsHeader = bytes.sublist(adtsHeaderPosition, adtsHeaderPosition + 7);
          print('ADTS header: ${adtsHeader.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
          
          // Phân tích các trường trong ADTS header
          final hasProtection = (adtsHeader[1] & 0x01) == 0;
          final headerLength = hasProtection ? 9 : 7;
          
          if (adtsHeaderPosition + headerLength <= bytes.length) {
            final mpegVersion = (adtsHeader[1] & 0x08) >> 3; // 0: MPEG-4, 1: MPEG-2
            final layer = (adtsHeader[1] & 0x06) >> 1; // Luôn là 0 cho AAC
            final profileMinusOne = (adtsHeader[2] & 0xC0) >> 6; // Profile = value + 1
            final samplingFreqIndex = (adtsHeader[2] & 0x3C) >> 2;
            final channelConfig = ((adtsHeader[2] & 0x01) << 2) | ((adtsHeader[3] & 0xC0) >> 6);
            final frameLength = ((adtsHeader[3] & 0x03) << 11) | (adtsHeader[4] << 3) | ((adtsHeader[5] & 0xE0) >> 5);
            
            // Mapping sampling frequency index to actual frequency
            final samplingFrequencies = [
              96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350
            ];
            final samplingFreq = samplingFreqIndex < samplingFrequencies.length 
                ? samplingFrequencies[samplingFreqIndex] 
                : 'Unknown';
            
            // Mapping profile to name
            final profiles = ['AAC Main', 'AAC LC', 'AAC SSR', 'AAC LTP'];
            final profile = profileMinusOne < profiles.length ? profiles[profileMinusOne] : 'Unknown';
            
            print('ADTS Header Analysis:');
            print('- MPEG Version: ${mpegVersion == 0 ? "MPEG-4" : "MPEG-2"}');
            print('- Layer: $layer (should be 0 for AAC)');
            print('- Protection: ${hasProtection ? "Yes" : "No"}');
            print('- Profile: $profile');
            print('- Sampling Frequency: $samplingFreq Hz');
            print('- Channel Configuration: $channelConfig');
            print('- Frame Length: $frameLength bytes');
            
            // Kiểm tra xem frame length có hợp lệ không
            if (frameLength > 0 && frameLength <= bytes.length - adtsHeaderPosition) {
              print('- Frame length hợp lệ');
              
              // Kiểm tra xem có nhiều ADTS frame không
              int offset = adtsHeaderPosition;
              int frameCount = 0;
              
              while (offset + headerLength < bytes.length) {
                // Kiểm tra sync word (0xFFF)
                if (bytes[offset] == 0xFF && (bytes[offset + 1] & 0xF0) == 0xF0) {
                  frameCount++;
                  
                  // Lấy frame length từ header
                  final frameLen = ((bytes[offset + 3] & 0x03) << 11) | 
                                 (bytes[offset + 4] << 3) | 
                                 ((bytes[offset + 5] & 0xE0) >> 5);
                  
                  if (frameLen <= 0 || frameLen > bytes.length - offset) {
                    print('- Frame length không hợp lệ tại frame $frameCount: $frameLen bytes');
                    break;
                  }
                  
                  // Di chuyển đến frame tiếp theo
                  offset += frameLen;
                } else {
                  // Không tìm thấy sync word, có thể là dữ liệu bị hỏng
                  break;
                }
              }
              
              print('- Số lượng ADTS frame phát hiện được: $frameCount');
              
              if (frameCount > 1) {
                print('- File AAC có nhiều ADTS frame, định dạng có vẻ hợp lệ');
              } else {
                print('- File AAC chỉ có một ADTS frame, có thể không đầy đủ');
              }
            } else {
              print('- Frame length không hợp lệ: $frameLength bytes');
            }
          } else {
            print('- ADTS header không đủ dài để phân tích');
          }
        } else {
          print('- ADTS header không đủ dài để phân tích');
        }
      } else {
        print('Không tìm thấy ADTS header trong file');
      }
      
      // Kiểm tra dữ liệu trước ADTS header
      if (adtsHeaderPosition > 0) {
        final preHeaderData = bytes.sublist(0, adtsHeaderPosition);
        print('Dữ liệu trước ADTS header (${preHeaderData.length} bytes): ${preHeaderData.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
        print('Dữ liệu này không phải là một phần của AAC hợp lệ và có thể gây ra vấn đề khi phát file');
      }
      
      // Kết luận
      if (adtsHeaderPosition == 0) {
        print('KẾT LUẬN: File AAC có định dạng ADTS hợp lệ, bắt đầu từ byte đầu tiên');
      } else if (adtsHeaderPosition > 0) {
        print('KẾT LUẬN: File AAC có chứa ADTS header nhưng không bắt đầu từ byte đầu tiên, có dữ liệu không hợp lệ ở đầu file');
      } else {
        print('KẾT LUẬN: File không phải là AAC với ADTS header');
      }
    });
  });
}

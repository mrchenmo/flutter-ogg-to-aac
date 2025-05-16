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

  group('AAC Deep Analysis', () {
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

    testWidgets('Deep analysis of AAC file structure', (WidgetTester tester) async {
      // Thực hiện chuyển đổi
      print('Bắt đầu chuyển đổi OGG sang AAC...');
      final result = await FlutterOggToAac.convert(testOggPath, outputAacPath);
      print('Kết quả chuyển đổi: $result');
      
      // Kiểm tra file đã được tạo
      expect(await File(outputAacPath).exists(), true);
      
      // Đọc file AAC
      final bytes = await File(outputAacPath).readAsBytes();
      print('Kích thước file AAC: ${bytes.length} bytes');
      
      // Phân tích chi tiết cấu trúc file
      print('\n--- PHÂN TÍCH CHI TIẾT CẤU TRÚC FILE AAC ---');
      
      // In ra 100 byte đầu tiên để phân tích
      final headerBytes = bytes.sublist(0, bytes.length >= 100 ? 100 : bytes.length);
      print('100 byte đầu tiên (hex):');
      for (int i = 0; i < headerBytes.length; i += 16) {
        final end = i + 16 < headerBytes.length ? i + 16 : headerBytes.length;
        final line = headerBytes.sublist(i, end);
        print('${i.toString().padLeft(4, '0')}: ${line.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      }
      
      // Tìm kiếm ADTS header
      List<int> adtsPositions = [];
      for (int i = 0; i < bytes.length - 2; i++) {
        if (bytes[i] == 0xFF && (bytes[i + 1] & 0xF0) == 0xF0) {
          adtsPositions.add(i);
          
          // Chỉ lấy 10 vị trí đầu tiên để tránh quá nhiều dữ liệu
          if (adtsPositions.length >= 10) break;
        }
      }
      
      print('\nTìm thấy ${adtsPositions.length} ADTS header tại các vị trí: $adtsPositions');
      
      // Phân tích chi tiết từng ADTS header
      for (int i = 0; i < adtsPositions.length && i < 3; i++) {
        final pos = adtsPositions[i];
        if (pos + 7 <= bytes.length) {
          final adtsHeader = bytes.sublist(pos, pos + 7);
          print('\nADTS header #${i+1} tại vị trí $pos:');
          print('Bytes: ${adtsHeader.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
          
          // Phân tích các trường trong ADTS header
          final hasProtection = (adtsHeader[1] & 0x01) == 0;
          final headerLength = hasProtection ? 9 : 7;
          
          if (pos + headerLength <= bytes.length) {
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
            
            print('- MPEG Version: ${mpegVersion == 0 ? "MPEG-4" : "MPEG-2"}');
            print('- Layer: $layer (should be 0 for AAC)');
            print('- Protection: ${hasProtection ? "Yes" : "No"}');
            print('- Profile: $profile');
            print('- Sampling Frequency: $samplingFreq Hz');
            print('- Channel Configuration: $channelConfig');
            print('- Frame Length: $frameLength bytes');
            
            // Kiểm tra xem frame length có hợp lệ không
            if (frameLength > 0 && frameLength <= bytes.length - pos) {
              print('- Frame length hợp lệ');
              
              // In ra một số byte của frame data
              if (pos + headerLength + 16 <= bytes.length) {
                final frameData = bytes.sublist(pos + headerLength, pos + headerLength + 16);
                print('- Frame data (16 byte đầu tiên): ${frameData.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
              }
            } else {
              print('- Frame length không hợp lệ: $frameLength bytes');
            }
          }
        }
      }
      
      // Kiểm tra xem file có nhiều ADTS frame liên tiếp không
      if (adtsPositions.length >= 2) {
        final pos1 = adtsPositions[0];
        final pos2 = adtsPositions[1];
        
        if (pos1 + 7 <= bytes.length && pos2 + 7 <= bytes.length) {
          final frameLength1 = ((bytes[pos1 + 3] & 0x03) << 11) | (bytes[pos1 + 4] << 3) | ((bytes[pos1 + 5] & 0xE0) >> 5);
          
          print('\nKhoảng cách giữa hai ADTS header đầu tiên: ${pos2 - pos1} bytes');
          print('Frame length của ADTS header đầu tiên: $frameLength1 bytes');
          
          if (pos1 + frameLength1 == pos2) {
            print('Khoảng cách giữa hai ADTS header bằng với frame length, cấu trúc hợp lệ');
          } else {
            print('Khoảng cách giữa hai ADTS header khác với frame length, cấu trúc không hợp lệ');
          }
        }
      }
      
      // Kiểm tra dữ liệu trước ADTS header đầu tiên
      if (adtsPositions.isNotEmpty && adtsPositions[0] > 0) {
        final preHeaderData = bytes.sublist(0, adtsPositions[0]);
        print('\nDữ liệu trước ADTS header đầu tiên (${preHeaderData.length} bytes):');
        for (int i = 0; i < preHeaderData.length; i += 16) {
          final end = i + 16 < preHeaderData.length ? i + 16 : preHeaderData.length;
          final line = preHeaderData.sublist(i, end);
          print('${i.toString().padLeft(4, '0')}: ${line.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
        }
      }
      
      // Kết luận
      print('\nKẾT LUẬN:');
      if (adtsPositions.isEmpty) {
        print('File không chứa ADTS header, không phải là AAC hợp lệ');
      } else if (adtsPositions[0] > 0) {
        print('File chứa ADTS header nhưng có dữ liệu không hợp lệ ở đầu file');
        print('Cần loại bỏ ${adtsPositions[0]} byte đầu tiên để có file AAC hợp lệ');
      } else if (adtsPositions.length == 1) {
        print('File chỉ chứa một ADTS frame, có thể không đầy đủ');
      } else {
        final pos1 = adtsPositions[0];
        final pos2 = adtsPositions[1];
        final frameLength1 = ((bytes[pos1 + 3] & 0x03) << 11) | (bytes[pos1 + 4] << 3) | ((bytes[pos1 + 5] & 0xE0) >> 5);
        
        if (pos1 + frameLength1 == pos2) {
          print('File chứa nhiều ADTS frame liên tiếp với cấu trúc hợp lệ');
        } else {
          print('File chứa nhiều ADTS frame nhưng cấu trúc không hợp lệ');
        }
      }
    });
  });
}

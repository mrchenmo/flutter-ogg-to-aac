import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_ogg_to_aac/flutter_ogg_to_aac.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _oggToAacConverterPlugin = FlutterOggToAac();
  String _conversionStatus = 'Not converted yet';
  String? _inputFilePath;
  String? _outputFilePath;
  bool _isConverting = false;
  bool _isPlaying = false;
  bool _isSaving = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _selectedFileName;
  String? _savedFilePath;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _requestPermissions();

    // Listen for audio playback completion event
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    // For Android 13+, we need to request specific permissions
    if (Platform.isAndroid) {
      await Permission.photos.request();
      await Permission.videos.request();
      await Permission.audio.request();
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _oggToAacConverterPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _pickOggFile() async {
    try {
      // Use sample file from assets
      final ByteData data = await rootBundle.load('assets/sample.ogg');
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/sample.ogg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(data.buffer.asUint8List());

      setState(() {
        _inputFilePath = tempPath;
        _selectedFileName = 'sample.ogg';
        _conversionStatus = 'Sample OGG file loaded: sample.ogg';
      });
    } catch (e) {
      setState(() {
        _conversionStatus = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _convertOggToAac() async {
    if (_inputFilePath == null) {
      setState(() {
        _conversionStatus = 'Please select a file first';
      });
      return;
    }

    setState(() {
      _isConverting = true;
      _conversionStatus = 'Converting...';
    });

    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String originalFileName = _inputFilePath!.split('/').last;
      final String fileNameWithoutExt = originalFileName.substring(0, originalFileName.lastIndexOf('.'));
      final String fileName = '$fileNameWithoutExt.aac';
      _outputFilePath = '${appDocDir.path}/$fileName';

      final String? resultPath = await FlutterOggToAac.convert(_inputFilePath!, _outputFilePath!);

      setState(() {
        _isConverting = false;
        if (resultPath != null) {
          _conversionStatus = 'Conversion successful!\nAAC File: $resultPath';
          _outputFilePath = resultPath;
        } else {
          _conversionStatus = 'Conversion failed';
        }
      });
    } catch (e) {
      setState(() {
        _isConverting = false;
        _conversionStatus = 'Error: $e';
      });
    }
  }

  Future<void> _playAudio() async {
    if (_outputFilePath == null) {
      setState(() {
        _conversionStatus = 'No audio file to play. Please convert first.';
      });
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer.play(DeviceFileSource(_outputFilePath!));
        setState(() {
          _isPlaying = true;
          _conversionStatus = 'Playing file: ${_outputFilePath!.split('/').last}';
        });
      }
    } catch (e) {
      setState(() {
        _isPlaying = false;
        _conversionStatus = 'Error playing audio: $e';
      });
    }
  }

  Future<void> _saveToDownloads() async {
    if (_outputFilePath == null) {
      setState(() {
        _conversionStatus = 'No audio file to save. Please convert first.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _conversionStatus = 'Saving to Downloads folder...';
    });

    try {
      // Check permissions
      if (Platform.isAndroid) {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) {
            setState(() {
              _isSaving = false;
              _conversionStatus = 'Storage permission denied';
            });
            return;
          }
        }

        // For Android 10+ (API 29+), also check for manage external storage
        final manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted) {
          final result = await Permission.manageExternalStorage.request();
          if (!result.isGranted) {
            // We can still try to save without this permission
            print('Manage external storage permission denied, but continuing anyway');
          }
        }
      }

      // Get the Downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // On Android, we use the Download directory
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          // Try alternative path
          downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir == null) {
            throw Exception('Could not access Downloads directory');
          }
        }
      } else if (Platform.isIOS) {
        // On iOS, we use the Documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        throw Exception('Unsupported platform');
      }

      // Create a unique filename
      final String originalFileName = _outputFilePath!.split('/').last;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'converted_${timestamp}_$originalFileName';
      final String filePath = path.join(downloadsDir.path, fileName);

      // Copy the file
      final File sourceFile = File(_outputFilePath!);
      final File destinationFile = await sourceFile.copy(filePath);

      setState(() {
        _isSaving = false;
        _savedFilePath = destinationFile.path;
        _conversionStatus = 'File saved to Downloads folder:\n$filePath';
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
        _conversionStatus = 'Error saving file: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Converter & Player'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Running on: $_platformVersion'),
              const SizedBox(height: 20),
              // Display selected file name
              if (_selectedFileName != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.audio_file, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'File: $_selectedFileName',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              // File selection button
              ElevatedButton.icon(
                key: const Key('selectFileButton'),
                onPressed: _pickOggFile,
                icon: const Icon(Icons.file_open),
                label: const Text('Use sample file'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              // Conversion button
              ElevatedButton.icon(
                key: const Key('convertButton'),
                onPressed: _isConverting ? null : _convertOggToAac,
                icon: const Icon(Icons.transform),
                label: const Text('Convert to AAC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              // Audio playback button
              ElevatedButton.icon(
                key: const Key('playButton'),
                onPressed: _outputFilePath == null ? null : _playAudio,
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlaying ? 'Stop playback' : 'Play audio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              // Save to Downloads button
              ElevatedButton.icon(
                key: const Key('saveButton'),
                onPressed: (_outputFilePath == null || _isSaving) ? null : _saveToDownloads,
                icon: const Icon(Icons.save_alt),
                label: Text(_isSaving ? 'Saving...' : 'Save to Downloads'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.grey.shade50,
                ),
                child: _isConverting || _isSaving
                    ? Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 10),
                            Text(_isConverting ? 'Converting...' : 'Saving to Downloads...'),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_conversionStatus),
                          if (_savedFilePath != null) ...[
                            const SizedBox(height: 10),
                            const Text('Saved file:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_savedFilePath!),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

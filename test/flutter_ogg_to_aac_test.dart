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
}

import Flutter
import UIKit
import AVFoundation

public class OggToAacConverterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ogg_to_aac_converter", binaryMessenger: registrar.messenger())
    let instance = OggToAacConverterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getPlatformVersion" {
      result("iOS " + UIDevice.current.systemVersion)
    } else if call.method == "convertOggToAac" {
      guard let args = call.arguments as? [String: Any],
            let inputPath = args["inputPath"] as? String,
            let outputPath = args["outputPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Input or output path is null or invalid", details: nil))
          return
      }

      DispatchQueue.global(qos: .userInitiated).async {
          let inputUrl = URL(fileURLWithPath: inputPath)
          let outputUrl = URL(fileURLWithPath: outputPath)

          do {
              // Check if input file exists
              guard FileManager.default.fileExists(atPath: inputPath) else {
                  DispatchQueue.main.async {
                      result(FlutterError(code: "FILE_NOT_FOUND", message: "Input file does not exist: \(inputPath)", details: nil))
                  }
                  return
              }

              // Create output directory if it doesn't exist
              try FileManager.default.createDirectory(at: outputUrl.deletingLastPathComponent(), withIntermediateDirectories: true)

              // Remove output file if it already exists
              if FileManager.default.fileExists(atPath: outputPath) {
                  try FileManager.default.removeItem(at: outputUrl)
              }

              // In this simplified version, we just copy the file for demo
              try FileManager.default.copyItem(at: inputUrl, to: outputUrl)

              DispatchQueue.main.async {
                  result(outputPath)
              }
          } catch {
              DispatchQueue.main.async {
                  result(FlutterError(code: "CONVERSION_ERROR", message: error.localizedDescription, details: nil))
              }
          }
      }
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}

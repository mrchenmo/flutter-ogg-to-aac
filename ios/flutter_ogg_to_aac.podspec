#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_ogg_to_aac.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_ogg_to_aac'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin to convert OGG to AAC without FFMPEG.'
  s.description      = <<-DESC
A Flutter plugin to convert OGG audio files to AAC format using libogg/libvorbis and native platform APIs.
                       DESC
  s.homepage         = 'https://github.com/yourusername/flutter_ogg_to_aac'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # No Swift code used

  # Add required frameworks
  s.frameworks = 'AVFoundation', 'AudioToolbox'

  # Add libogg and libvorbis dependencies
  s.dependency 'libogg', '~> 1.3.5'
  s.dependency 'libvorbis', '~> 1.3.7'

  # Specify that we use C++
  s.library = 'c++'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_ogg_to_aac_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end

pubspec_path = File.join(__dir__, '..', 'pubspec.yaml')
pubspec = File.read(pubspec_path)
version = pubspec.match(/^version:\s*([\d.]+)/)[1]

Pod::Spec.new do |s|
  s.name             = 'paygate'
  s.version          = version
  s.summary          = 'Paygate SDK for Flutter - iOS implementation'
  s.description      = 'Present paywalls, onboarding flows, and more in your Flutter app.'
  s.homepage         = 'https://github.com/build-context/paygate-flutter'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Paygate' => 'support@paygate.dev' }
  s.source           = { :git => 'https://github.com/build-context/paygate-flutter.git', :tag => "v#{s.version}" }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'Paygate', '0.1.7'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
end

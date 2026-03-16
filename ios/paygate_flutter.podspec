Pod::Spec.new do |s|
  s.name             = 'paygate_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Paygate SDK for Flutter - iOS implementation'
  s.description      = 'Present paywalls, onboarding flows, and more in your Flutter app.'
  s.homepage         = 'https://github.com/paygate/paygate-flutter'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Paygate' => 'support@paygate.dev' }
  s.source           = { :http => 'https://github.com/paygate/paygate-flutter' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'
  s.swift_version    = '5.0'
end

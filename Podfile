source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/ello/cocoapod-specs.git'

# Uncomment this line to define a global platform for your project
platform :ios, '8.0'

# Yep.
inhibit_all_warnings!

project 'Ello'


# Opt into framework support (required for Swift support in CocoaPods RC1)
use_frameworks!

def ello_app_pods
  pod '1PasswordExtension', git: 'https://github.com/ello/onepassword-app-extension'
  pod 'CRToast', git: 'https://github.com/ello/CRToast'
  pod 'Fabric', '~> 1.6'
  pod 'Analytics/Segmentio'
  pod 'JTSImageViewController', git: 'https://github.com/ello/JTSImageViewController'
  pod 'KINWebBrowser', git: 'https://github.com/ello/KINWebBrowser'
  pod 'PINRemoteImage', git: 'https://github.com/pinterest/PINRemoteImage.git', commit: 'af312667f0ce830264198366f481f1b222675a31'
  pod 'SSPullToRefresh', '~> 1.2'
  pod 'ImagePickerSheetController'
  pod 'iRate', '~> 1.11'
  # swift pods
  pod 'TimeAgoInWords', git: 'https://github.com/ello/TimeAgoInWords'
  pod 'WebLinking', '~> 1.0'
  pod 'SnapKit'
end

def common_pods
  if ENV['ELLO_STAFF']
    pod 'ElloUIFonts', '~> 1.1.0'
    pod 'ElloCerts', '~> 1.0.0'
  else
    pod 'ElloOSSUIFonts', '~> 1.0.0'
    pod 'ElloCerts', '~> 1.0.0'
  end
  pod 'MBProgressHUD', '~> 0.9.0'
  pod 'SVGKit', git: 'https://github.com/SVGKit/SVGKit'
  pod 'FLAnimatedImage', '~> 1.0'
  pod 'YapDatabase', '2.8.1'
  pod 'Alamofire', '~> 3.0'
  pod 'Moya', '~> 6.0.0'
  pod 'KeychainAccess', '~> 2.3'
  pod 'SwiftyUserDefaults', '~> 1.3.0'
  pod 'SwiftyJSON', git: 'https://github.com/ello/SwiftyJSON', branch: 'Swift-2.0'
  pod 'Crashlytics', '~> 3.4'
end

def spec_pods
  pod 'FBSnapshotTestCase'
  pod 'Quick', '~> 0.9'
  pod 'Nimble', '~> 4.0'
  pod 'Nimble-Snapshots', git: 'https://github.com/ashfurrow/Nimble-Snapshots'
  pod 'OHHTTPStubs', '~> 4.3'
end

post_install do |installer_representation|
    installer_representation.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['WARNING_CFLAGS'] = '$(inherited) -Wno-error=private-header' if target.name == 'FBSnapshotTestCase'
        end
    end
end

target 'Ello' do
  common_pods
  ello_app_pods
end

target 'ShareExtension' do
  common_pods
end

target 'Specs' do
  common_pods
  ello_app_pods
  spec_pods
end

plugin 'cocoapods-keys', {
  project: 'Ello',
  keys: [
    'ClientKey',
    'ClientSecret',
    'CrashlyticsKey',
    'Domain',
    'HttpProtocol',
    'Salt',
    'SegmentKey',
  ]
}

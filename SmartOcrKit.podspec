#
# Be sure to run `pod lib lint SmartOcrKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
    s.name             = 'SmartOcrKit'
    s.version          = '1.0.0'
    s.summary          = 'A short description of SmartOcrKit.'
    
    # This description is used to generate tags and improve search results.
    #   * Think: What does it do? Why did you write it? What is the focus?
    #   * Try to keep it short, snappy and to the point.
    #   * Write the description between the DESC delimiters below.
    #   * Finally, don't worry about the indent, CocoaPods strips it!
    
    s.description      = <<-DESC
    TODO: Add long description of the pod here.
    DESC
    
    s.homepage         = 'https://github.com/MjzDK/SmartOcrKit'
    # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'MjzDK' => '15929996560@163.com' }
    s.source           = { :git => 'https://github.com/MjzDK/SmartOcrKit.git', :tag => s.version.to_s }
    # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
    
    s.ios.deployment_target = '8.0'
    s.vendored_libraries = 'SmartOcrKit/Classes/libSmartOCR.a'
    s.source_files = 'SmartOcrKit/Classes/**/*.{h,m}'
    
    s.resource_bundles = {
        'SmartOcrKit' => ['SmartOcrKit/Assets/*.{xml,lib,dat}']
    }
    s.frameworks = 'AVFoundation','AudioToolbox','CoreMedia'
    s.libraries = 'iconv.2.4.0','xml2'
    s.static_framework = true
    s.public_header_files = 'Pod/Classes/**/*.h'
    s.prefix_header_contents = '#import "NSBundle+OCR.h"','#import "SmartOCR.h"'
    # s.frameworks = 'UIKit', 'MapKit'
    # s.dependency 'AFNetworking', '~> 2.3'
end

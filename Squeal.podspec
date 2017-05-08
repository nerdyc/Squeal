#
#  Be sure to run `pod spec lint Squeal.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "Squeal"
  s.version      = "1.2.0"
  s.summary      = "A Swift wrapper for SQLite databases"

  s.description  = <<-DESC
    Squeal provides access to SQLite databases in Swift. Its goal is to be
    simple and straight-forward, without much magic.
    
    Squeal provides some helpers to generate and execute the most common SQL 
    statements, and take the drudgery out of generating these yourself. 
    However, it's not a goal of this project to hide SQL from the developer, or 
    to provide a generic object-mapping on top of SQLite.
  DESC

  s.homepage     = "https://github.com/nerdyc/Squeal"
  s.license      = { :type => "MIT", :file => "LICENSE.txt" }

  s.author             = { "Christian Niles" => "christian@nerdyc.com" }
  s.social_media_url   = "http://twitter.com/nerdyc"

  s.ios.deployment_target = "9.0"
  s.tvos.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "3.0"

  s.source       = { :git => "https://github.com/nerdyc/Squeal.git", :tag => "v#{s.version}" }

  s.source_files  = "Sources/**/*.swift"
  s.module_name = "Squeal"
  s.library = "sqlite3"

  s.preserve_paths = 'Clibsqlite3/**/*'
  s.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS[sdk=macosx*]'             => '$(PODS_TARGET_SRCROOT)/Clibsqlite3/macOS/**',
    'SWIFT_INCLUDE_PATHS[sdk=iphoneos*]'           => '$(PODS_TARGET_SRCROOT)/Clibsqlite3/iOS/**',
    'SWIFT_INCLUDE_PATHS[sdk=iphonesimulator*]'    => '$(PODS_TARGET_SRCROOT)/Clibsqlite3/iOS-Simulator/**',
    'SWIFT_INCLUDE_PATHS[sdk=appletvos*]'          => '$(PODS_TARGET_SRCROOT)/Clibsqlite3/tvOS/**',
    'SWIFT_INCLUDE_PATHS[sdk=appletvsimulator*]'   => '$(PODS_TARGET_SRCROOT)/Clibsqlite3/tvOS-Simulator/**',
    'SWIFT_INCLUDE_PATHS[sdk=watchos*]'            => '$(PODS_TARGET_SRCROOT)/Clibsqlite3/watchOS/**',
    'SWIFT_INCLUDE_PATHS[sdk=watchsimulator*]'     => '$(PODS_TARGET_SRCROOT)/Clibsqlite3/watchOS-Simulator/**'
  }

end

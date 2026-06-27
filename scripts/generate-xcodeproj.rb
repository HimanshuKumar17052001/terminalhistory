#!/usr/bin/env ruby
# Generates App/TerminalHistory.xcodeproj using the xcodeproj Ruby gem.
# Idempotent: removes any existing project before regenerating.

gem 'xcodeproj', '1.25.0'
require 'xcodeproj'
require 'fileutils'

APP_NAME = 'TerminalHistory'
BUNDLE_ID = 'com.himanshukumar17052001.TerminalHistory'
DEPLOYMENT_TARGET = '13.0'
APP_DIR = File.expand_path(File.join(__dir__, '..', 'App'))
# Sources live in App/TerminalHistory/ (sibling of the .xcodeproj, matching Xcode's default layout).
SRC_DIR = File.join(APP_DIR, APP_NAME)
PROJECT_PATH = File.join(APP_DIR, "#{APP_NAME}.xcodeproj")

FileUtils.rm_rf(PROJECT_PATH)
FileUtils.mkdir_p(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.development_region = 'en'
project.root_object.known_regions = ['en', 'Base']

# Build a native target manually to avoid new_target's add_system_framework path
# (which crashes when no SDKROOT is set in this sandbox).
target = project.new(Xcodeproj::Project::Object::PBXNativeTarget)
project.targets << target
target.name = APP_NAME
target.product_name = APP_NAME
target.product_type = 'com.apple.product-type.application'

config_list = project.new(Xcodeproj::Project::Object::XCConfigurationList)
target.build_configuration_list = config_list
config_list.default_configuration_name = 'Release'
config_list.default_configuration_is_visible = '0'

# Two configurations: Debug and Release.
['Debug', 'Release'].each do |name|
  cfg = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  cfg.name = name
  config_list.build_configurations << cfg
  s = cfg.build_settings
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  s['MACOSX_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  s['SDKROOT'] = 'macosx'
  s['SWIFT_VERSION'] = '5.0'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['CODE_SIGN_IDENTITY'] = '-'
  s['DEVELOPMENT_TEAM'] = ''
  s['ENABLE_HARDENED_RUNTIME'] = 'NO'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['CODE_SIGN_ENTITLEMENTS'] = "#{APP_NAME}/#{APP_NAME}.entitlements"
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['INFOPLIST_FILE'] = "#{APP_NAME}/Info.plist"
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
  s['COMBINE_HIDPI_IMAGES'] = 'YES'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  s['ALWAYS_SEARCH_USER_PATHS'] = 'NO'
  s['CLANG_ENABLE_MODULES'] = 'YES'
  s['ENABLE_STRICT_OBJC_MSGSEND'] = 'YES'
  s['GCC_NO_COMMON_BLOCKS'] = 'YES'
  s['GCC_OPTIMIZATION_LEVEL'] = (name == 'Release' ? 's' : '0')
  s['GCC_PREPROCESSOR_DEFINITIONS'] = ['DEBUG=1', '$(inherited)'] if name == 'Debug'
  s['ONLY_ACTIVE_ARCH'] = 'YES' if name == 'Debug'
  s['SWIFT_OPTIMIZATION_LEVEL'] = (name == 'Release' ? '-O' : '-Onone')
  s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG' if name == 'Debug'
end

# Project-level build settings.
project.build_configurations.each do |cfg|
  s = cfg.build_settings
  s['SDKROOT'] = 'macosx'
  s['MACOSX_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  s['ALWAYS_SEARCH_USER_PATHS'] = 'NO'
  s['CLANG_ENABLE_OBJC_ARC'] = 'YES'
  s['CLANG_ENABLE_MODULES'] = 'YES'
  s['ENABLE_STRICT_OBJC_MSGSEND'] = 'YES'
  s['GCC_NO_COMMON_BLOCKS'] = 'YES'
  s['SWIFT_VERSION'] = '5.0'
  s['ONLY_ACTIVE_ARCH'] = 'YES' if cfg.name == 'Debug'
end

# Build phases.
sources_phase = project.new(Xcodeproj::Project::Object::PBXSourcesBuildPhase)
target.build_phases << sources_phase

frameworks_phase = project.new(Xcodeproj::Project::Object::PBXFrameworksBuildPhase)
target.build_phases << frameworks_phase

resources_phase = project.new(Xcodeproj::Project::Object::PBXResourcesBuildPhase)
target.build_phases << resources_phase

# Product reference (the built .app).
product_ref = project.products_group.new_reference("#{APP_NAME}.app")
product_ref.last_known_file_type = 'wrapper.application'
target.product_reference = product_ref

# Source groups: project root group contains the TerminalHistory group
# (which itself contains all source files), matching Xcode's default layout.
main_group = project.main_group
app_group = main_group.new_group(APP_NAME, APP_NAME)
target_group = app_group

# Info.plist (write a minimal one if missing)
info_plist_path = File.join(SRC_DIR, 'Info.plist')
unless File.exist?(info_plist_path)
  File.write(info_plist_path, <<~PLIST)
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>$(EXECUTABLE_NAME)</string>
        <key>CFBundleIdentifier</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>$(PRODUCT_NAME)</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>0.1.0</string>
        <key>CFBundleVersion</key>
        <string>1</string>
        <key>LSMinimumSystemVersion</key>
        <string>#{DEPLOYMENT_TARGET}</string>
        <key>LSUIElement</key>
        <true/>
        <key>NSHumanReadableCopyright</key>
        <string>MIT</string>
        <key>NSPrincipalClass</key>
        <string>NSApplication</string>
    </dict>
    </plist>
  PLIST
end
info_plist_ref = target_group.new_reference('Info.plist')
info_plist_ref.last_known_file_type = 'text.plist.xml'

# Entitlements file reference.
entitlements_ref = target_group.new_reference('TerminalHistory.entitlements')
entitlements_ref.last_known_file_type = 'text.plist.entitlements'

# Asset catalog.
assets_ref = target_group.new_reference('Assets.xcassets')
assets_ref.last_known_file_type = 'folder.assetcatalog'
build_file = resources_phase.add_file_reference(assets_ref)

# Swift sources.
swift_files = Dir.glob(File.join(SRC_DIR, '*.swift')).sort
puts "Found #{swift_files.length} Swift files in #{SRC_DIR}"
swift_files.each do |path|
  ref = target_group.new_reference(File.basename(path))
  ref.last_known_file_type = 'sourcecode.swift'
  sources_phase.add_file_reference(ref)
end

# Local SwiftPM package: THCore (one level up from App/).
package_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package_ref.relative_path = '..'

product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product_dep.product_name = 'THCore'
product_dep.package = package_ref

target.package_product_dependencies << product_dep

# Add a build file referencing the product dependency to the frameworks phase.
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product_dep
build_file.settings = { 'ATTRIBUTES' => ['Weak'] }
frameworks_phase.files << build_file

# Register the package reference with the project.
project.root_object.package_references << package_ref

project.save
puts "Generated #{PROJECT_PATH}"
puts "Swift sources: #{Dir.glob(File.join(SRC_DIR, '*.swift')).count}"

#!/usr/local/opt/ruby/bin/ruby
# Script to add the UpcomingClassWidget extension target to the Xcode project.
# Run with: /usr/local/opt/ruby/bin/ruby add_widget_target.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('Runner.xcodeproj', __dir__)

project = Xcodeproj::Project.open(PROJECT_PATH)

# --- Find existing groups and targets ---
runner_target = project.targets.find { |t| t.name == 'Runner' }
raise "Runner target not found" unless runner_target

products_group = project.main_group.find_subpath('Products', true)

# --- Create widget source files group ---
widget_group = project.main_group.new_group('UpcomingClassWidget', 'UpcomingClassWidget')

widget_dir = File.expand_path('UpcomingClassWidget', __dir__)
source_files = %w[
  UpcomingClassWidget.swift
  UpcomingClassWidgetProvider.swift
  UpcomingClassWidgetView.swift
]

widget_files = {}
source_files.each do |filename|
  file_path = File.join(widget_dir, filename)
  raise "Missing file: #{file_path}" unless File.exist?(file_path)
  file_ref = widget_group.new_file(filename)
  file_ref.path = filename
  widget_files[filename] = file_ref
end

# Info.plist
info_path = File.join(widget_dir, 'Info.plist')
raise "Missing file: #{info_path}" unless File.exist?(info_path)
info_ref = widget_group.new_file('Info.plist')
info_ref.path = 'Info.plist'

# --- Create the widget extension target ---
widget_target = project.new_target(
  :app_extension,
  'UpcomingClassWidget',
  :ios
)

widget_target.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['INFOPLIST_FILE'] = 'UpcomingClassWidget/Info.plist'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.lyme.beikenext.UpcomingClassWidget'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  config.build_settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../../Frameworks',
  ]
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'UpcomingClassWidget/UpcomingClassWidget.entitlements'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['ENABLE_BITCODE'] = 'NO'
  config.build_settings['DEVELOPMENT_TEAM'] = '$(DEVELOPMENT_TEAM)'

  case config.name
  when 'Debug'
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
  when 'Release'
    config.build_settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
  end
end

# --- Add source files to widget target ---
source_files.each do |filename|
  widget_target.source_build_phase.add_file_reference(widget_files[filename])
end

# --- Add Info.plist to resources ---
widget_target.resources_build_phase.add_file_reference(info_ref)

# --- Add WidgetKit and SwiftUI frameworks ---
widget_target.add_system_frameworks(%w[WidgetKit SwiftUI])

# --- Embed widget extension in Runner target ---
embed_phase = runner_target.copy_files_build_phases.find { |ph| ph.dst_subfolder_spec == '13' }
unless embed_phase
  embed_phase = runner_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13'
end

widget_product = project.products.find { |p| p.path&.include?('UpcomingClassWidget') }
if widget_product
  bf = embed_phase.add_file_reference(widget_product)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# --- Add target dependency from Runner to widget ---
runner_target.add_dependency(widget_target)

# --- Set Runner entitlements ---
runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# --- Sort and save ---
project.main_group.sort_by_type
project.main_group.sort
project.save

puts "✅ Widget extension target 'UpcomingClassWidget' added successfully!"
puts "   Next: Run 'pod install', then open Runner.xcworkspace in Xcode to build and test."

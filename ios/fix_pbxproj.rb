require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

widget_target = project.targets.find { |t| t.name == 'OrderTrackerWidgetExtension' }
if widget_target
  assets_path = 'OrderTrackerWidget/Assets.xcassets'
  # Find or create file reference
  assets_ref = project.files.find { |f| f.path == assets_path } || project.new_file(assets_path)
  
  unless widget_target.resources_build_phase.files_references.include?(assets_ref)
    widget_target.resources_build_phase.add_file_reference(assets_ref, true)
    puts "Added Assets.xcassets"
  end

  entitlements_path = 'OrderTrackerWidget/OrderTrackerWidgetExtension.entitlements'
  entitlements_ref = project.files.find { |f| f.path == entitlements_path } || project.new_file(entitlements_path)
  
  widget_target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
  end
  
  project.save
  puts "Success"
else
  puts "Target not found"
end

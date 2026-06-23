import re

file_path = '/Users/apple/Documents/mytogether/mytogetherapp/ios/OrderTrackerWidget/OrderTrackerWidgetLiveActivity.swift'
with open(file_path, 'r') as f:
    content = f.read()

# Add sharedDefault and helper function right after the struct definition or before it
helper_funcs = """
let sharedDefault = UserDefaults(suiteName: "group.com.mytogetherorg.mytogether")!

func getString(context: ActivityViewContext<LiveActivitiesAppAttributes>, key: String) -> String? {
    return sharedDefault.string(forKey: context.attributes.prefixedKey(key))
}
"""

content = content.replace("struct OrderTrackerWidgetLiveActivity: Widget {", helper_funcs + "\nstruct OrderTrackerWidgetLiveActivity: Widget {")

# Replace context.state.XXX with getString(context: context, key: "XXX")
content = re.sub(r'context\.state\.([a-zA-Z0-9_]+)', r'getString(context: context, key: "\1")', content)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")

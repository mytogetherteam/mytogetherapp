#!/bin/bash

# Ensure we are in the flutter project directory
if [ ! -f "pubspec.yaml" ]; then
    echo "Error: Please run this script from the root of your Flutter project."
    exit 1
fi

echo "Starting secure iOS build with code obfuscation..."

# Run flutter build ipa with obfuscation flags
flutter build ipa --obfuscate --split-debug-info=./build/app/outputs/symbols

echo ""
echo "Build complete! If successful, your .xcarchive or .ipa file is ready."
echo "You can now open Xcode > Window > Organizer to upload to App Store Connect."
echo "Note: Keep the symbols folder safe. You will need it to read crash reports."

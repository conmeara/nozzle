#!/bin/bash

echo "🔄 Resetting nozzle onboarding for testing..."

# Reset the onboarding completion flag
defaults write org.conmeara.nozzle hasCompletedOnboarding -bool false
defaults write org.conmeara.nozzle onboardingVersion -int 0

echo "✅ Onboarding flags reset!"
echo "📱 Now build and run nozzle - the onboarding should appear automatically"
echo ""
echo "🛠️  Build command:"
echo "xcodebuild -project nozzle.xcodeproj -scheme nozzle"
echo ""
echo "🎯 Or open nozzle.xcodeproj in Xcode and press Cmd+R"
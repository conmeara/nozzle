#!/usr/bin/env swift

// This file can be used to preview individual onboarding screens
// Copy any screen code and modify for testing

import SwiftUI
import PlaygroundSupport

// Example: Test WelcomeScreen independently
struct OnboardingPreview: View {
    var body: some View {
        VStack {
            Text("🎉 Onboarding Screens Created!")
                .font(.largeTitle)
                .padding()
            
            Text("Files created:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("✅ OnboardingState.swift - State management")
                Text("✅ OnboardingWindow.swift - Window controller")
                Text("✅ OnboardingView.swift - Main container")
                Text("✅ WelcomeScreen.swift - Welcome & features")
                Text("✅ PermissionsScreen.swift - Live permissions")
                Text("✅ ShortcutsScreen.swift - Keyboard shortcuts")
                Text("✅ ResourcesScreen.swift - Learning resources")
                Text("✅ FinishScreen.swift - Menu bar tip")
            }
            .font(.system(.body, design: .monospaced))
            .padding()
            
            Text("🚀 Ready to integrate into Xcode project!")
                .font(.title2)
                .foregroundColor(.green)
                .padding()
        }
        .padding(40)
        .frame(width: 600, height: 400)
    }
}

// This would show the preview in a playground environment
PlaygroundPage.current.setLiveView(OnboardingPreview())
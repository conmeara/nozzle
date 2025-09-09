#!/usr/bin/env swift

import Foundation

// Simple test to verify onboarding flag logic
let bundleId = "org.conmeara.nozzle"

// Check current state
let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
print("Current onboarding status: \(hasCompleted ? "Completed" : "Not completed")")

// Reset for testing
UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
print("Reset onboarding flag to: false")

// Verify reset
let newStatus = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
print("New onboarding status: \(newStatus ? "Completed" : "Not completed")")

print("\nTo test onboarding:")
print("1. Build and run nozzle")
print("2. The onboarding should appear automatically")
print("3. Or use the 'Show Welcome Screen' button in Settings")
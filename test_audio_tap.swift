#!/usr/bin/env swift

import AVFoundation
import Foundation

print("Testing basic audio tap...")

let engine = AVAudioEngine()
let input = engine.inputNode
var bufferCount = 0

// Remove any existing tap
input.removeTap(onBus: 0)

// Install tap
input.installTap(onBus: 0, bufferSize: 4096, format: input.outputFormat(forBus: 0)) { buffer, time in
    bufferCount += 1
    print("✅ TAP CALLBACK #\(bufferCount): \(buffer.frameLength) frames")
    
    if bufferCount >= 10 {
        engine.stop()
        print("Test completed successfully!")
        exit(0)
    }
}

print("Tap installed, preparing engine...")
engine.prepare()

print("Starting engine...")
do {
    try engine.start()
    print("Engine started successfully")
} catch {
    print("❌ Failed to start engine: \(error)")
    exit(1)
}

// Keep the script running
print("Waiting for audio buffers...")
RunLoop.main.run()
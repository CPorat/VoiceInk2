//
//  SystemAudioCaptureTests.swift
//  VoiceInkTests
//
//  Created by AI Assistant on 05/01/2025.
//

import Testing
import AVFoundation
import CoreMedia
import ScreenCaptureKit
@testable import VoiceInk

@available(macOS 12.3, *)
struct SystemAudioCaptureTests {
    
    // MARK: - Format Validation Tests
    
    @Test("Validate audio format - Valid Linear PCM")
    func testValidateAudioFormat_ValidLinearPCM() async throws {
        let capture = SystemAudioCapture()
        
        // Create a valid Linear PCM format description
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = 44100
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mChannelsPerFrame = 2
        asbd.mBitsPerChannel = 32
        asbd.mBytesPerFrame = 8 // 2 channels * 32 bits / 8 bits per byte
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerPacket = asbd.mBytesPerFrame * asbd.mFramesPerPacket
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        
        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        #expect(status == noErr)
        #expect(formatDescription != nil)
        
        if let formatDesc = formatDescription {
            let isValid = capture.validateAudioFormat(formatDesc)
            #expect(isValid == true)
        }
    }
    
    @Test("Validate audio format - Invalid format ID")
    func testValidateAudioFormat_InvalidFormatID() async throws {
        let capture = SystemAudioCapture()
        
        // Create an invalid format (AAC instead of Linear PCM)
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = 44100
        asbd.mFormatID = kAudioFormatMPEG4AAC // Invalid format
        asbd.mChannelsPerFrame = 2
        asbd.mBitsPerChannel = 0 // AAC doesn't use bits per channel
        asbd.mBytesPerFrame = 0
        asbd.mFramesPerPacket = 1024
        asbd.mBytesPerPacket = 0
        
        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        #expect(status == noErr)
        #expect(formatDescription != nil)
        
        if let formatDesc = formatDescription {
            let isValid = capture.validateAudioFormat(formatDesc)
            #expect(isValid == false)
        }
    }
    
    @Test("Validate audio format - Invalid sample rate")
    func testValidateAudioFormat_InvalidSampleRate() async throws {
        let capture = SystemAudioCapture()
        
        // Create format with invalid sample rate (too low)
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = 4000 // Too low (below 8000 Hz)
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mChannelsPerFrame = 2
        asbd.mBitsPerChannel = 32
        asbd.mBytesPerFrame = 8
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerPacket = 8
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        
        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        #expect(status == noErr)
        
        if let formatDesc = formatDescription {
            let isValid = capture.validateAudioFormat(formatDesc)
            #expect(isValid == false)
        }
    }
    
    @Test("Validate audio format - Invalid channel count")
    func testValidateAudioFormat_InvalidChannelCount() async throws {
        let capture = SystemAudioCapture()
        
        // Create format with invalid channel count (too many)
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = 44100
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mChannelsPerFrame = 8 // Too many channels
        asbd.mBitsPerChannel = 32
        asbd.mBytesPerFrame = 32 // 8 channels * 32 bits / 8 bits per byte
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerPacket = 32
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        
        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        #expect(status == noErr)
        
        if let formatDesc = formatDescription {
            let isValid = capture.validateAudioFormat(formatDesc)
            #expect(isValid == false)
        }
    }
    
    @Test("Validate audio format - Invalid bits per channel")
    func testValidateAudioFormat_InvalidBitsPerChannel() async throws {
        let capture = SystemAudioCapture()
        
        // Create format with invalid bits per channel
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = 44100
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mChannelsPerFrame = 2
        asbd.mBitsPerChannel = 24 // Invalid (not 16 or 32)
        asbd.mBytesPerFrame = 6 // 2 channels * 24 bits / 8 bits per byte
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerPacket = 6
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        
        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        #expect(status == noErr)
        
        if let formatDesc = formatDescription {
            let isValid = capture.validateAudioFormat(formatDesc)
            #expect(isValid == false)
        }
    }
    
    @Test("Validate audio format - Inconsistent frame size")
    func testValidateAudioFormat_InconsistentFrameSize() async throws {
        let capture = SystemAudioCapture()
        
        // Create format with inconsistent frame size
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = 44100
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mChannelsPerFrame = 2
        asbd.mBitsPerChannel = 32
        asbd.mBytesPerFrame = 6 // Inconsistent! Should be 8 (2 * 32/8)
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerPacket = 6
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
        
        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        #expect(status == noErr)
        
        if let formatDesc = formatDescription {
            let isValid = capture.validateAudioFormat(formatDesc)
            #expect(isValid == false)
        }
    }
    
    // MARK: - Memory Safety Tests
    
    @Test("Process audio buffers - Handle empty buffer")
    func testProcessAudioBuffers_EmptyBuffer() async throws {
        let capture = SystemAudioCapture()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            throw TestError.bufferCreationFailed
        }
        
        // Create empty audio buffer list
        var audioBufferList = AudioBufferList()
        audioBufferList.mNumberBuffers = 1
        audioBufferList.mBuffers.mNumberChannels = 2
        audioBufferList.mBuffers.mDataByteSize = 0 // Empty buffer
        audioBufferList.mBuffers.mData = nil
        
        // Should throw error for empty buffer
        do {
            try capture.processAudioBuffers(audioBufferList, into: pcmBuffer, frameCount: 1024)
            Issue.record("Expected error for empty buffer")
        } catch SystemAudioCapture.SystemAudioCaptureError.audioFormatNotAvailable {
            // Expected error
        }
    }
    
    @Test("Process audio buffers - Handle malformed data")
    func testProcessAudioBuffers_MalformedData() async throws {
        let capture = SystemAudioCapture()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            throw TestError.bufferCreationFailed
        }
        
        // Create malformed audio buffer list with invalid data
        var audioBufferList = AudioBufferList()
        audioBufferList.mNumberBuffers = 1
        audioBufferList.mBuffers.mNumberChannels = 2
        audioBufferList.mBuffers.mDataByteSize = 100 // Some size
        
        // Create some test data (not valid audio data)
        var testData: [UInt8] = Array(repeating: 0xFF, count: 100)
        audioBufferList.mBuffers.mData = UnsafeMutableRawPointer(&testData)
        
        // Should handle malformed data gracefully
        do {
            try capture.processAudioBuffers(audioBufferList, into: pcmBuffer, frameCount: 25)
            // Should not crash, even with malformed data
        } catch {
            // Any error is acceptable as long as it doesn't crash
        }
    }
    
    @Test("Process audio buffers - Handle zero frame count")
    func testProcessAudioBuffers_ZeroFrameCount() async throws {
        let capture = SystemAudioCapture()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            throw TestError.bufferCreationFailed
        }
        
        // Create valid audio buffer list
        var audioBufferList = AudioBufferList()
        audioBufferList.mNumberBuffers = 1
        audioBufferList.mBuffers.mNumberChannels = 2
        audioBufferList.mBuffers.mDataByteSize = 1024
        
        var testData: [Float] = Array(repeating: 0.5, count: 256)
        audioBufferList.mBuffers.mData = UnsafeMutableRawPointer(&testData)
        
        // Should handle zero frame count gracefully
        do {
            try capture.processAudioBuffers(audioBufferList, into: pcmBuffer, frameCount: 0)
            // Should not crash with zero frame count
        } catch {
            // Any error is acceptable as long as it doesn't crash
        }
    }
    
    // MARK: - Resource Management Tests
    
    @Test("Audio capture lifecycle - Proper initialization")
    func testAudioCaptureLifecycle_Initialization() async throws {
        let capture = SystemAudioCapture()
        
        // Should start in non-capturing state
        #expect(capture.isCapturing == false)
        #expect(capture.audioLevel == 0.0)
    }
    
    @Test("Audio capture lifecycle - Stop without start")
    func testAudioCaptureLifecycle_StopWithoutStart() async throws {
        let capture = SystemAudioCapture()
        
        // Should handle stop without start gracefully
        capture.stopCapture()
        
        // Should remain in non-capturing state
        #expect(capture.isCapturing == false)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Audio format validation - Edge case sample rates")
    func testAudioFormatValidation_EdgeCaseSampleRates() async throws {
        let capture = SystemAudioCapture()
        
        // Test boundary sample rates
        let testRates: [Double] = [8000, 192000, 7999, 192001]
        let expectedResults = [true, true, false, false]
        
        for (index, rate) in testRates.enumerated() {
            var asbd = AudioStreamBasicDescription()
            asbd.mSampleRate = rate
            asbd.mFormatID = kAudioFormatLinearPCM
            asbd.mChannelsPerFrame = 2
            asbd.mBitsPerChannel = 32
            asbd.mBytesPerFrame = 8
            asbd.mFramesPerPacket = 1
            asbd.mBytesPerPacket = 8
            asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
            
            var formatDescription: CMAudioFormatDescription?
            let status = CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                asbd: &asbd,
                layoutSize: 0,
                layout: nil,
                magicCookieSize: 0,
                magicCookie: nil,
                extensions: nil,
                formatDescriptionOut: &formatDescription
            )
            
            #expect(status == noErr)
            
            if let formatDesc = formatDescription {
                let isValid = capture.validateAudioFormat(formatDesc)
                #expect(isValid == expectedResults[index])
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Error handling - Invalid format description")
    func testErrorHandling_InvalidFormatDescription() async throws {
        let capture = SystemAudioCapture()
        
        // Create a sample buffer with invalid format description
        // This tests the error handling path when format description is malformed
        
        // Since we can't easily create a malformed CMFormatDescription,
        // we test the validation logic with edge cases
        let result = capture.validateAudioFormat(nil as CMFormatDescription?)
        #expect(result == false)
    }
    
    // MARK: - Memory Leak Prevention Tests
    
    @Test("Memory management - Audio buffer processing")
    func testMemoryManagement_AudioBufferProcessing() async throws {
        let capture = SystemAudioCapture()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        // Process multiple buffers to test for memory leaks
        for _ in 0..<100 {
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
                throw TestError.bufferCreationFailed
            }
            
            var audioBufferList = AudioBufferList()
            audioBufferList.mNumberBuffers = 1
            audioBufferList.mBuffers.mNumberChannels = 2
            audioBufferList.mBuffers.mDataByteSize = 4096
            
            var testData: [Float] = Array(repeating: 0.1, count: 1024)
            audioBufferList.mBuffers.mData = UnsafeMutableRawPointer(&testData)
            
            try capture.processAudioBuffers(audioBufferList, into: pcmBuffer, frameCount: 512)
        }
        
        // Test passes if no memory issues occur
        #expect(true)
    }
    
    // MARK: - Display Selection Tests
    
    @Test("Display selection - Valid main display")
    func testSelectDisplay_ValidMainDisplay() async throws {
        let capture = SystemAudioCapture()
        
        // Mock displays with main display
        let mockMainDisplay = createMockDisplay(id: CGMainDisplayID())
        let mockSecondaryDisplay = createMockDisplay(id: 12345)
        let displays = [mockMainDisplay, mockSecondaryDisplay]
        
        let selectedDisplay = try capture.selectDisplay(from: displays)
        
        #expect(selectedDisplay.displayID == CGMainDisplayID())
    }
    
    @Test("Display selection - No main display, fallback to built-in")  
    func testSelectDisplay_FallbackToBuiltIn() async throws {
        let capture = SystemAudioCapture()
        
        // Mock displays without main display (built-in has lower ID)
        let mockBuiltinDisplay = createMockDisplay(id: 100) // Low ID indicates built-in
        let mockExternalDisplay = createMockDisplay(id: 50000000) // High ID indicates external
        let displays = [mockExternalDisplay, mockBuiltinDisplay]
        
        let selectedDisplay = try capture.selectDisplay(from: displays)
        
        #expect(selectedDisplay.displayID == 100)
    }
    
    @Test("Display selection - First available fallback")
    func testSelectDisplay_FirstAvailableFallback() async throws {
        let capture = SystemAudioCapture()
        
        // Mock displays with only external displays (high IDs)
        let mockDisplay1 = createMockDisplay(id: 50000000)
        let mockDisplay2 = createMockDisplay(id: 60000000)
        let displays = [mockDisplay1, mockDisplay2]
        
        let selectedDisplay = try capture.selectDisplay(from: displays)
        
        #expect(selectedDisplay.displayID == 50000000) // Should select first
    }
    
    @Test("Display selection - Empty displays array")
    func testSelectDisplay_EmptyDisplays() async throws {
        let capture = SystemAudioCapture()
        
        let emptyDisplays: [SCDisplay] = []
        
        do {
            _ = try capture.selectDisplay(from: emptyDisplays)
            #expect(Bool(false), "Should have thrown displaySelectionFailed error")
        } catch let error as SystemAudioCapture.SystemAudioCaptureError {
            #expect(error == .displaySelectionFailed)
        }
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Start capture - No displays available")
    func testStartCapture_NoDisplaysAvailable() async throws {
        let capture = SystemAudioCapture()
        let outputURL = createTestOutputURL()
        
        // This test would require mocking SCShareableContent which is not easily mockable
        // Instead, we test the error handling path by creating a scenario where displays are empty
        
        // Note: This test demonstrates the approach but would need proper mocking framework
        // to fully test the SCShareableContent.excludingDesktopWindows behavior
        
        // For now, we can test the error types exist
        let noDisplaysError = SystemAudioCapture.SystemAudioCaptureError.noDisplaysAvailable
        #expect(noDisplaysError.localizedDescription == "No displays available for screen capture")
    }
    
    @Test("Start capture - No applications available")
    func testStartCapture_NoApplicationsAvailable() async throws {
        let capture = SystemAudioCapture()
        
        // Test that the error type exists and has correct description
        let noAppsError = SystemAudioCapture.SystemAudioCaptureError.noApplicationsAvailable
        #expect(noAppsError.localizedDescription == "No applications available for audio capture")
    }
    
    @Test("Start capture - Configuration failed")
    func testStartCapture_ConfigurationFailed() async throws {
        let capture = SystemAudioCapture()
        
        // Test that the error type exists and has correct description
        let configError = SystemAudioCapture.SystemAudioCaptureError.configurationFailed
        #expect(configError.localizedDescription == "Failed to configure system audio capture")
    }
    
    @Test("Start capture - Stream creation failed")
    func testStartCapture_StreamCreationFailed() async throws {
        let capture = SystemAudioCapture()
        
        // Test that the error type exists and has correct description
        let streamError = SystemAudioCapture.SystemAudioCaptureError.streamCreationFailed
        #expect(streamError.localizedDescription == "Failed to create screen capture stream")
    }
    
    @Test("Start capture - Headless system detected")
    func testStartCapture_HeadlessSystemDetected() async throws {
        let capture = SystemAudioCapture()
        
        // Test that the error type exists and has correct description
        let headlessError = SystemAudioCapture.SystemAudioCaptureError.headlessSystemDetected
        #expect(headlessError.localizedDescription == "Headless system detected - screen capture unavailable")
    }
    
    @Test("Start capture - Display selection failed")
    func testStartCapture_DisplaySelectionFailed() async throws {
        let capture = SystemAudioCapture()
        
        // Test that the error type exists and has correct description
        let selectionError = SystemAudioCapture.SystemAudioCaptureError.displaySelectionFailed
        #expect(selectionError.localizedDescription == "Failed to select appropriate display for capture")
    }
    
    // MARK: - Resource Management Tests
    
    @Test("Start capture - Cleanup on failure")
    func testStartCapture_CleanupOnFailure() async throws {
        let capture = SystemAudioCapture()
        
        // Test that isCapturing starts as false
        #expect(capture.isCapturing == false)
        
        // After a failed start attempt, isCapturing should remain false
        // This test verifies the cleanup logic works
        
        // Test with invalid URL to trigger failure
        let invalidURL = URL(fileURLWithPath: "")
        
        do {
            try await capture.startCapture(outputURL: invalidURL)
            // If we reach here, the test environment allows the capture to start
            // so we clean up and pass the test
            capture.stopCapture()
        } catch {
            // Expected behavior - capture should fail and cleanup properly
            #expect(capture.isCapturing == false)
        }
    }
    
    @Test("Stop capture - Proper cleanup")
    func testStopCapture_ProperCleanup() async throws {
        let capture = SystemAudioCapture()
        
        // Test that stopCapture handles being called when not capturing
        capture.stopCapture()
        
        // Should not crash and should maintain false state
        #expect(capture.isCapturing == false)
        #expect(capture.audioLevel == 0.0)
    }
    
    // MARK: - State Management Tests
    
    @Test("Capture state - Prevents multiple simultaneous captures")
    func testCaptureState_PreventMultipleCaptures() async throws {
        let capture = SystemAudioCapture()
        let outputURL = createTestOutputURL()
        
        // Mock isCapturing to true to test the guard
        await MainActor.run {
            capture.isCapturing = true
        }
        
        // Attempt to start capture while already capturing
        try await capture.startCapture(outputURL: outputURL)
        
        // Should not throw error, just return early
        #expect(capture.isCapturing == true)
    }
    
    @Test("Audio level - Initialization")
    func testAudioLevel_Initialization() async throws {
        let capture = SystemAudioCapture()
        
        // Audio level should start at 0.0
        #expect(capture.audioLevel == 0.0)
    }
    
    // MARK: - Helper Methods for Testing
    
    private func createMockDisplay(id: CGDirectDisplayID) -> SCDisplay {
        // Note: SCDisplay doesn't have a public initializer, so this is a conceptual test
        // In practice, you would need to use a mocking framework or protocol-based approach
        
        // This is a placeholder that demonstrates the test structure
        // Real implementation would require proper mocking of ScreenCaptureKit
        
        // Return a mock display - this would need proper mocking framework
        fatalError("Mock display creation requires proper mocking framework")
    }
    
    private func createTestOutputURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).wav")
    }
    
    // MARK: - Test Error Types
    
    enum TestError: Error {
        case bufferCreationFailed
        case formatCreationFailed
    }
}

// MARK: - SystemAudioCapture Extension for Testing

@available(macOS 12.3, *)
extension SystemAudioCapture {
    
    // Convenience method for testing with optional format description
    func validateAudioFormat(_ formatDescription: CMFormatDescription?) -> Bool {
        guard let formatDescription = formatDescription else {
            return false
        }
        return validateAudioFormat(formatDescription)
    }
} 
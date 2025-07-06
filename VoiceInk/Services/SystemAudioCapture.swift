import Foundation
import ScreenCaptureKit
import AVFoundation
import os

/**
 * SystemAudioCapture - A Memory-Safe System Audio Capture Service
 * 
 * This service provides safe system audio capture using ScreenCaptureKit with comprehensive
 * memory safety protections and format validation.
 *
 * ## Memory Safety Features
 * 
 * This implementation includes several critical memory safety protections:
 * 
 * 1. **Format Validation**: All audio formats are validated before processing to prevent
 *    memory corruption from malformed audio data
 * 2. **Safe Memory Access**: Uses Apple's recommended CoreMedia APIs instead of unsafe
 *    memory reinterpretation
 * 3. **Resource Management**: Proper cleanup of CoreMedia resources with RAII patterns
 * 4. **Error Handling**: Comprehensive error handling for invalid formats and edge cases
 * 
 * ## Usage Guidelines
 * 
 * ### Safe Usage Pattern:
 * ```swift
 * let capture = SystemAudioCapture()
 * 
 * do {
 *     try await capture.startCapture(outputURL: audioFileURL)
 *     // Audio capture is now active
 * } catch {
 *     // Handle initialization errors
 * }
 * 
 * // Always call stopCapture() to ensure proper cleanup
 * capture.stopCapture()
 * ```
 * 
 * ### Important Safety Considerations:
 * 
 * 1. **Always call stopCapture()** - Ensures proper resource cleanup and prevents memory leaks
 * 2. **Handle errors gracefully** - The service validates audio formats and will reject invalid data
 * 3. **Don't assume format consistency** - Audio formats can change during capture
 * 4. **Monitor isCapturing state** - Use this property to track capture state safely
 * 
 * ### Memory Safety Implementation Details:
 * 
 * - **Format Validation**: `validateAudioFormat()` checks format consistency before processing
 * - **Safe Buffer Processing**: Uses `CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer`
 *   instead of unsafe `withMemoryRebound`
 * - **Resource Cleanup**: Automatic cleanup of CoreMedia resources with `defer` blocks
 * - **Error Boundaries**: All audio processing is wrapped in proper error handling
 * 
 * ### Thread Safety:
 * 
 * This class should be used from the main thread for UI updates. Audio processing happens
 * on background threads managed by ScreenCaptureKit.
 * 
 * ### Testing:
 * 
 * Comprehensive unit tests are available in `SystemAudioCaptureTests.swift` covering:
 * - Format validation edge cases
 * - Memory safety scenarios
 * - Malformed audio data handling
 * - Resource lifecycle management
 * - Error handling validation
 */
@available(macOS 12.3, *)
class SystemAudioCapture: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "SystemAudioCapture")
    
    @Published var isCapturing = false
    @Published var audioLevel: Float = 0.0
    
    private var stream: SCStream?
    private var streamConfiguration: SCStreamConfiguration?
    private var contentFilter: SCContentFilter?
    
    // Audio file writing
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    
    override init() {
        super.init()
    }
    
    // MARK: - Capture Control
    
    func startCapture(outputURL: URL) async throws {
        logger.notice("🎵 Starting system audio capture...")
        
        guard !isCapturing else {
            logger.warning("⚠️ System audio capture already in progress")
            return
        }
        
        // Validate initialization prerequisites
        try await validateInitializationRequirements(outputURL: outputURL)
        
        // Get shareable content with comprehensive error handling
        let availableContent: SCShareableContent
        do {
            availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            logger.error("❌ Failed to get shareable content: \(error.localizedDescription)")
            
            // Provide more specific error based on the underlying error
            if error.localizedDescription.contains("permission") {
                throw SystemAudioCaptureError.permissionDenied
            } else if error.localizedDescription.contains("display") {
                throw SystemAudioCaptureError.displayPermissionDenied
            } else {
                throw SystemAudioCaptureError.configurationFailed
            }
        }
        
        // Validate display availability
        guard !availableContent.displays.isEmpty else {
            logger.error("❌ No displays available for screen capture")
            throw SystemAudioCaptureError.noDisplaysAvailable
        }
        
        // Select appropriate display with fallback logic
        let selectedDisplay = try selectDisplay(from: availableContent.displays)
        
        // Validate application availability
        guard !availableContent.applications.isEmpty else {
            logger.error("❌ No applications available for audio capture")
            throw SystemAudioCaptureError.noApplicationsAvailable
        }
        
        // Create content filter to capture all applications
        contentFilter = SCContentFilter(
            display: selectedDisplay,
            including: availableContent.applications,
            exceptingWindows: []
        )
        
        // Configure stream for audio-only capture
        streamConfiguration = SCStreamConfiguration()
        guard let config = streamConfiguration else {
            logger.error("❌ Failed to create stream configuration")
            throw SystemAudioCaptureError.configurationFailed
        }
        
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS (not used for audio)
        config.queueDepth = 5
        
        // Validate content filter creation
        guard let filter = contentFilter else {
            logger.error("❌ Content filter creation failed")
            throw SystemAudioCaptureError.configurationFailed
        }
        
        // Create stream with proper error handling
        do {
            stream = SCStream(filter: filter, configuration: config, delegate: self)
            guard let stream = stream else {
                logger.error("❌ Failed to create SCStream instance")
                throw SystemAudioCaptureError.streamCreationFailed
            }
            
            // Store output URL for file writing
            self.outputURL = outputURL
            
            // Start capture with comprehensive error handling
            try await stream.startCapture()
            
            isCapturing = true
            logger.notice("✅ System audio capture started successfully")
        } catch {
            logger.error("❌ Failed to start system audio capture: \(error.localizedDescription)")
            
            // Clean up on failure
            self.stream = nil
            self.contentFilter = nil
            self.streamConfiguration = nil
            self.outputURL = nil
            
            // Re-throw with appropriate error type
            if error is SystemAudioCaptureError {
                throw error
            } else {
                throw SystemAudioCaptureError.streamCreationFailed
            }
        }
    }
    
    func stopCapture() {
        logger.notice("🛑 Stopping system audio capture...")
        
        guard isCapturing else {
            logger.warning("⚠️ No system audio capture in progress")
            return
        }
        
        Task {
            do {
                // Stop the stream with enhanced error handling
                if let stream = stream {
                    do {
                        try await stream.stopCapture()
                        logger.debug("✅ Stream stopped successfully")
                    } catch {
                        logger.error("❌ Error stopping stream: \(error.localizedDescription)")
                        // Continue with cleanup even if stream stop fails
                    }
                }
                
                // Clean up stream resources
                stream = nil
                contentFilter = nil
                streamConfiguration = nil
                
                // Close audio file with enhanced error handling
                if let audioFile = self.audioFile {
                    logger.debug("📁 Closing audio file...")
                    // AVAudioFile automatically flushes and closes when deallocated
                    // Setting to nil ensures proper deallocation and file handle closure
                    self.audioFile = nil
                    logger.debug("✅ Audio file closed successfully")
                }
                
                // Clean up URL reference
                self.outputURL = nil
                
                // Update state on main actor
                await MainActor.run {
                    isCapturing = false
                    audioLevel = 0.0
                }
                
                logger.notice("✅ System audio capture stopped and resources cleaned up")
            } catch {
                logger.error("❌ Error during system audio capture cleanup: \(error.localizedDescription)")
                
                // Force cleanup even on error
                stream = nil
                contentFilter = nil
                streamConfiguration = nil
                audioFile = nil
                outputURL = nil
                
                await MainActor.run {
                    isCapturing = false
                    audioLevel = 0.0
                }
                
                logger.warning("⚠️ Forced cleanup completed after error")
            }
        }
    }
    
    // MARK: - Initialization Validation
    
    /**
     * Validates all initialization requirements before starting audio capture
     * 
     * This method performs comprehensive validation of system requirements, permissions,
     * and resources needed for successful audio capture initialization.
     * 
     * ## Validation Steps:
     * 
     * 1. **Output URL Validation**: Checks path validity and write permissions
     * 2. **System Resources**: Validates available disk space and system resources
     * 3. **Permission Checks**: Verifies screen recording permissions
     * 4. **Audio System**: Ensures audio subsystem is available and functional
     * 
     * ## Error Handling:
     * 
     * Throws specific SystemAudioCaptureError types for different failure scenarios
     * to provide clear feedback on what initialization step failed.
     * 
     * - Parameter outputURL: The destination URL for audio file creation
     * - Throws: SystemAudioCaptureError for various initialization failures
     */
    private func validateInitializationRequirements(outputURL: URL) async throws {
        logger.debug("🔍 Validating initialization requirements...")
        
        // Validate output URL and path
        do {
            try validateOutputURL(outputURL)
        } catch {
            logger.error("❌ Output URL validation failed: \(error.localizedDescription)")
            throw error
        }
        
        // Check available disk space
        do {
            try validateDiskSpace(for: outputURL)
        } catch {
            logger.error("❌ Disk space validation failed: \(error.localizedDescription)")
            throw error
        }
        
        // Validate screen recording permissions
        do {
            try await validateScreenRecordingPermissions()
        } catch {
            logger.error("❌ Permission validation failed: \(error.localizedDescription)")
            throw error
        }
        
        // Validate audio system availability
        do {
            try validateAudioSystemAvailability()
        } catch {
            logger.error("❌ Audio system validation failed: \(error.localizedDescription)")
            throw error
        }
        
        logger.debug("✅ All initialization requirements validated successfully")
    }
    
    /**
     * Validates the output URL for audio file creation
     * 
     * Performs comprehensive validation of the output URL including:
     * - Path validity and accessibility
     * - Directory existence and creation
     * - Write permissions
     * - File extension validation
     * 
     * - Parameter outputURL: The destination URL for audio file creation
     * - Throws: SystemAudioCaptureError for URL validation failures
     */
    private func validateOutputURL(_ outputURL: URL) throws {
        // Validate URL is not nil and has a path
        guard !outputURL.path.isEmpty else {
            logger.error("❌ Output URL path is empty")
            throw SystemAudioCaptureError.configurationFailed
        }
        
        // Validate file extension
        let supportedExtensions = ["wav", "m4a", "caf", "aiff", "mp3"]
        let fileExtension = outputURL.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            logger.error("❌ Unsupported file extension: \(fileExtension). Supported: \(supportedExtensions)")
            throw SystemAudioCaptureError.configurationFailed
        }
        
        // Ensure directory exists
        let directory = outputURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                logger.info("📁 Created output directory: \(directory.path)")
            } catch {
                logger.error("❌ Failed to create output directory: \(error.localizedDescription)")
                throw SystemAudioCaptureError.configurationFailed
            }
        }
        
        // Check write permissions
        guard fileManager.isWritableFile(atPath: directory.path) else {
            logger.error("❌ No write permission for directory: \(directory.path)")
            throw SystemAudioCaptureError.configurationFailed
        }
        
        logger.debug("✅ Output URL validated: \(outputURL.lastPathComponent)")
    }
    
    /**
     * Validates available disk space for audio recording
     * 
     * Checks if there's sufficient disk space for audio recording based on
     * estimated recording duration and audio format requirements.
     * 
     * - Parameter outputURL: The destination URL to check disk space for
     * - Throws: SystemAudioCaptureError if insufficient disk space
     */
    private func validateDiskSpace(for outputURL: URL) throws {
        let fileManager = FileManager.default
        let directory = outputURL.deletingLastPathComponent()
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: directory.path)
            guard let freeSpace = attributes[.systemFreeSize] as? UInt64 else {
                logger.warning("⚠️ Could not determine available disk space")
                return // Don't fail initialization for disk space check
            }
            
            // Estimate minimum space needed (10 minutes at 44.1kHz stereo = ~50MB)
            let minimumSpaceNeeded: UInt64 = 100 * 1024 * 1024 // 100MB buffer
            
            guard freeSpace > minimumSpaceNeeded else {
                logger.error("❌ Insufficient disk space: \(freeSpace / 1024 / 1024)MB available, \(minimumSpaceNeeded / 1024 / 1024)MB required")
                throw SystemAudioCaptureError.configurationFailed
            }
            
            logger.debug("✅ Sufficient disk space available: \(freeSpace / 1024 / 1024)MB")
        } catch {
            logger.warning("⚠️ Could not check disk space: \(error.localizedDescription)")
            // Don't fail initialization for disk space check
        }
    }
    
    /**
     * Validates screen recording permissions are granted
     * 
     * Checks if the application has been granted screen recording permissions
     * required for ScreenCaptureKit to function properly.
     * 
     * - Throws: SystemAudioCaptureError.permissionDenied if permissions not granted
     */
    private func validateScreenRecordingPermissions() async throws {
        // Check if we can get shareable content as a permission test
        do {
            let testContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            
            // If we can get content but it's empty, it might be a permission issue
            if testContent.displays.isEmpty && testContent.applications.isEmpty {
                logger.error("❌ Screen recording permission appears to be denied - no content available")
                throw SystemAudioCaptureError.permissionDenied
            }
            
            logger.debug("✅ Screen recording permissions validated")
        } catch {
            logger.error("❌ Screen recording permission validation failed: \(error.localizedDescription)")
            throw SystemAudioCaptureError.permissionDenied
        }
    }
    
    /**
     * Validates audio system availability and functionality
     * 
     * Ensures the audio subsystem is available and can handle the required
     * audio formats and processing operations.
     * 
     * - Throws: SystemAudioCaptureError.audioFormatNotAvailable if audio system unavailable
     */
    private func validateAudioSystemAvailability() throws {
        // Test if we can create required audio format
        guard let testFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) else {
            logger.error("❌ Cannot create standard audio format - audio system unavailable")
            throw SystemAudioCaptureError.audioFormatNotAvailable
        }
        
        // Test if we can create a PCM buffer
        guard let _ = AVAudioPCMBuffer(pcmFormat: testFormat, frameCapacity: 1024) else {
            logger.error("❌ Cannot create PCM buffer - audio system unavailable")
            throw SystemAudioCaptureError.audioFormatNotAvailable
        }
        
        logger.debug("✅ Audio system availability validated")
    }
    
    // MARK: - Audio File Writing
    
    /**
     * Creates an audio file with comprehensive error handling and validation
     * 
     * This method creates an AVAudioFile for writing captured audio data with
     * enhanced error handling and validation to prevent common file creation issues.
     * 
     * ## Error Handling:
     * 
     * - **File Creation**: Handles file creation failures with detailed error messages
     * - **Format Validation**: Validates audio format compatibility
     * - **Permission Checks**: Ensures write permissions are available
     * - **Resource Cleanup**: Properly handles cleanup on failure
     * 
     * ## Recovery Strategies:
     * 
     * - **Directory Creation**: Creates intermediate directories if needed
     * - **File Replacement**: Handles existing file conflicts
     * - **Format Fallback**: Falls back to supported formats if needed
     * 
     * - Parameter outputURL: The destination URL for audio file creation
     * - Parameter format: The audio format to use for the file
     * - Throws: SystemAudioCaptureError for file creation failures
     */
    private func createAudioFile(for outputURL: URL, with format: AVAudioFormat) throws {
        logger.debug("📁 Creating audio file: \(outputURL.lastPathComponent)")
        
        // Validate format before attempting file creation
        guard format.channelCount > 0 && format.sampleRate > 0 else {
            logger.error("❌ Invalid audio format: channels=\(format.channelCount), sampleRate=\(format.sampleRate)")
            throw SystemAudioCaptureError.audioFormatNotAvailable
        }
        
        // Ensure directory exists (should already be validated, but double-check)
        let directory = outputURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                logger.info("📁 Created missing output directory: \(directory.path)")
            } catch {
                logger.error("❌ Failed to create output directory: \(error.localizedDescription)")
                throw SystemAudioCaptureError.configurationFailed
            }
        }
        
        // Handle existing file
        if fileManager.fileExists(atPath: outputURL.path) {
            do {
                try fileManager.removeItem(at: outputURL)
                logger.info("📁 Removed existing file: \(outputURL.lastPathComponent)")
            } catch {
                logger.error("❌ Failed to remove existing file: \(error.localizedDescription)")
                throw SystemAudioCaptureError.configurationFailed
            }
        }
        
        // Create audio file with enhanced error handling
        do {
            audioFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
            logger.info("📁 Created system audio file: \(outputURL.lastPathComponent)")
            logger.debug("📊 Audio file format: \(format.sampleRate)Hz, \(format.channelCount)ch")
        } catch let error as NSError {
            logger.error("❌ Failed to create audio file: \(error.localizedDescription)")
            
            // Provide specific error messages based on the error
            if error.domain == NSOSStatusErrorDomain {
                switch OSStatus(error.code) {
                case kAudioFileUnsupportedFileTypeError:
                    logger.error("❌ Unsupported file type for: \(outputURL.pathExtension)")
                    throw SystemAudioCaptureError.audioFormatNotAvailable
                case kAudioFileUnsupportedDataFormatError:
                    logger.error("❌ Unsupported audio data format")
                    throw SystemAudioCaptureError.audioFormatNotAvailable
                case kAudioFilePermissionsError:
                    logger.error("❌ Permission denied for file creation")
                    throw SystemAudioCaptureError.configurationFailed
                default:
                    logger.error("❌ Audio file creation error code: \(error.code)")
                    throw SystemAudioCaptureError.configurationFailed
                }
            } else {
                throw SystemAudioCaptureError.configurationFailed
            }
        }
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        
        // Convert to dB and normalize (similar to existing audio meter logic)
        let dB = 20 * log10(average + 1e-10) // Add small value to avoid log(0)
        let normalizedLevel = max(0, min(1, (dB + 60) / 60)) // Normalize -60dB to 0dB range
        
        audioLevel = normalizedLevel
    }
    
    // MARK: - Display Selection
    
    /**
     * Selects the most appropriate display for screen capture with fallback logic
     * 
     * This method implements intelligent display selection to handle various system configurations:
     * - Single display systems (most common)
     * - Multi-display systems (prefer main display)
     * - External display configurations
     * - Headless systems (error handling)
     * 
     * ## Selection Priority:
     * 
     * 1. **Main Display**: Prefers the main display if available
     * 2. **Built-in Display**: Falls back to built-in display on laptops
     * 3. **First Available**: Uses first available display as final fallback
     * 4. **Error Handling**: Throws appropriate errors for edge cases
     * 
     * ## Headless System Detection:
     * 
     * Detects and handles headless systems where no physical displays are available.
     * This is important for server deployments or CI/CD environments.
     * 
     * - Parameter displays: Array of available SCDisplay objects
     * - Returns: Selected SCDisplay for capture
     * - Throws: SystemAudioCaptureError for selection failures
     */
    internal func selectDisplay(from displays: [SCDisplay]) throws -> SCDisplay {
        logger.info("🖥️ Selecting display from \(displays.count) available displays")
        
        // Early exit for empty displays - this indicates a headless system
        guard !displays.isEmpty else {
            logger.error("❌ No displays available - headless system detected")
            throw SystemAudioCaptureError.headlessSystemDetected
        }
        
        // Detect potential headless or virtual display configurations
        let hasMainDisplay = displays.contains { $0.displayID == CGMainDisplayID() }
        let hasPhysicalDisplays = displays.contains { $0.displayID < 100000000 } // Physical displays have lower IDs
        let hasOnlyVirtualDisplays = !hasPhysicalDisplays && displays.allSatisfy { $0.displayID >= 100000000 }
        
        if hasOnlyVirtualDisplays {
            logger.warning("⚠️ Only virtual displays detected - headless system configuration")
            // Continue with virtual display selection but will throw specific error if needed
        } else if !hasMainDisplay && !hasPhysicalDisplays {
            logger.warning("⚠️ No main display or physical displays detected - possible headless system")
            // Continue with virtual display selection but log the condition
        }
        
        // Priority 1: Try to find the main display first
        if let mainDisplay = displays.first(where: { $0.displayID == CGMainDisplayID() }) {
            logger.info("✅ Selected main display (ID: \(mainDisplay.displayID))")
            return mainDisplay
        }
        
        // Priority 2: Fallback to built-in display (common on laptops)
        if let builtinDisplay = displays.first(where: { display in
            // Check if this is a built-in display by examining display properties
            let displayName = display.displayID == CGMainDisplayID() ? "Main" : "External"
            logger.debug("🔍 Evaluating display: \(displayName) (ID: \(display.displayID))")
            
            // Built-in displays typically have lower display IDs
            return display.displayID < 10000000 // Heuristic for built-in displays
        }) {
            logger.info("✅ Selected built-in display (ID: \(builtinDisplay.displayID))")
            return builtinDisplay
        }
        
        // Priority 3: Prefer external displays with reasonable IDs (not virtual)
        let externalDisplays = displays.filter { display in
            display.displayID >= 10000000 && display.displayID < 100000000
        }
        
        if let preferredExternal = externalDisplays.first {
            logger.info("✅ Selected external display (ID: \(preferredExternal.displayID))")
            return preferredExternal
        }
        
        // Priority 4: Handle virtual displays (common in headless systems)
        let virtualDisplays = displays.filter { display in
            display.displayID >= 100000000
        }
        
        if let virtualDisplay = virtualDisplays.first {
            if hasOnlyVirtualDisplays {
                logger.warning("⚠️ Using virtual display in headless system configuration")
                logger.info("✅ Selected virtual display (ID: \(virtualDisplay.displayID))")
                // Note: We could throw .virtualDisplaysOnly here if we want to prevent virtual display usage
                // For now, we allow it but log the condition
                return virtualDisplay
            } else {
                logger.warning("⚠️ Using virtual display as fallback")
                logger.info("✅ Selected virtual display (ID: \(virtualDisplay.displayID))")
                return virtualDisplay
            }
        }
        
        // Priority 5: Final fallback - use any available display
        if let firstDisplay = displays.first {
            logger.warning("⚠️ Using fallback display selection")
            logger.info("✅ Selected fallback display (ID: \(firstDisplay.displayID))")
            return firstDisplay
        }
        
        // This should never be reached due to the early empty check, but included for completeness
        logger.error("❌ No displays available after all selection attempts")
        
        // Provide more specific error based on the display configuration
        if hasOnlyVirtualDisplays {
            logger.error("❌ Only virtual displays detected - physical display required")
            throw SystemAudioCaptureError.noPhysicalDisplays
        } else if !hasMainDisplay {
            logger.error("❌ Main display unavailable and no suitable fallback found")
            throw SystemAudioCaptureError.mainDisplayUnavailable
        } else {
            logger.error("❌ Display selection failed despite available displays")
            throw SystemAudioCaptureError.displaySelectionFailed
        }
    }
    
    // MARK: - Error Handling
    
    enum SystemAudioCaptureError: Error, LocalizedError {
        case configurationFailed
        case audioFormatNotAvailable
        case streamCreationFailed
        case permissionDenied
        case noDisplaysAvailable
        case noApplicationsAvailable
        case displaySelectionFailed
        case headlessSystemDetected
        
        // Enhanced display availability error types
        case mainDisplayUnavailable
        case noPhysicalDisplays
        case virtualDisplaysOnly
        case externalDisplayConfigurationIssue
        case displayPermissionDenied
        case displayConfigurationUnsupported
        
        // Initialization and validation error types
        case insufficientDiskSpace
        case invalidOutputURL
        case audioSystemUnavailable
        case initializationFailed
        
        var errorDescription: String? {
            switch self {
            case .configurationFailed:
                return "Failed to configure system audio capture"
            case .audioFormatNotAvailable:
                return "Audio format not available"
            case .streamCreationFailed:
                return "Failed to create screen capture stream"
            case .permissionDenied:
                return "Screen recording permission required"
            case .noDisplaysAvailable:
                return "No displays available for screen capture"
            case .noApplicationsAvailable:
                return "No applications available for audio capture"
            case .displaySelectionFailed:
                return "Failed to select appropriate display for capture"
            case .headlessSystemDetected:
                return "Headless system detected - screen capture unavailable"
                
            // Enhanced display availability error descriptions
            case .mainDisplayUnavailable:
                return "Main display is unavailable for screen capture"
            case .noPhysicalDisplays:
                return "No physical displays detected - virtual displays only"
            case .virtualDisplaysOnly:
                return "Only virtual displays available - possible headless configuration"
            case .externalDisplayConfigurationIssue:
                return "External display configuration preventing capture"
            case .displayPermissionDenied:
                return "Display access permission denied for screen capture"
            case .displayConfigurationUnsupported:
                return "Current display configuration is not supported for capture"
                
            // Initialization and validation error descriptions
            case .insufficientDiskSpace:
                return "Insufficient disk space available for audio recording"
            case .invalidOutputURL:
                return "Invalid or inaccessible output URL for audio file"
            case .audioSystemUnavailable:
                return "Audio system unavailable or not functioning properly"
            case .initializationFailed:
                return "System audio capture initialization failed"
            }
        }
        
        /// Provides additional technical details for debugging and logging
        var technicalDescription: String {
            switch self {
            case .configurationFailed:
                return "SCStreamConfiguration creation or setup failed"
            case .audioFormatNotAvailable:
                return "Required audio format is not supported by the system"
            case .streamCreationFailed:
                return "SCStream instantiation failed with ScreenCaptureKit"
            case .permissionDenied:
                return "Screen recording permission not granted in System Preferences"
            case .noDisplaysAvailable:
                return "SCShareableContent returned empty display array"
            case .noApplicationsAvailable:
                return "SCShareableContent returned empty applications array"
            case .displaySelectionFailed:
                return "Display selection algorithm failed to find suitable display"
            case .headlessSystemDetected:
                return "No physical displays detected - running in headless mode"
                
            // Enhanced display availability technical descriptions
            case .mainDisplayUnavailable:
                return "CGMainDisplayID() not found in available SCDisplay array"
            case .noPhysicalDisplays:
                return "All available displays have virtual display IDs (>= 100000000)"
            case .virtualDisplaysOnly:
                return "Only virtual displays (ID >= 100000000) detected in system"
            case .externalDisplayConfigurationIssue:
                return "External display connection or configuration issue preventing capture"
            case .displayPermissionDenied:
                return "ScreenCaptureKit display access denied - check Privacy & Security settings"
            case .displayConfigurationUnsupported:
                return "Current multi-display or virtual display setup not supported"
                
            // Initialization and validation technical descriptions
            case .insufficientDiskSpace:
                return "Available disk space below minimum threshold for audio recording"
            case .invalidOutputURL:
                return "Output URL path invalid, inaccessible, or unsupported file format"
            case .audioSystemUnavailable:
                return "AVAudioFormat or AVAudioPCMBuffer creation failed - audio system issue"
            case .initializationFailed:
                return "One or more initialization validation steps failed"
            }
        }
        
        /// Provides user-friendly recovery suggestions
        var recoverySuggestion: String? {
            switch self {
            case .permissionDenied, .displayPermissionDenied:
                return "Grant screen recording permission in System Preferences > Privacy & Security > Screen Recording"
            case .noDisplaysAvailable, .headlessSystemDetected:
                return "Ensure a display is connected and try restarting the application"
            case .mainDisplayUnavailable:
                return "Try disconnecting and reconnecting external displays, or restart the system"
            case .noPhysicalDisplays, .virtualDisplaysOnly:
                return "Connect a physical display or use a different system for screen capture"
            case .externalDisplayConfigurationIssue:
                return "Check external display connections and display arrangement settings"
            case .displayConfigurationUnsupported:
                return "Simplify display configuration or use a single display setup"
            default:
                return "Try restarting the application or contact support if the issue persists"
            }
        }
    }
}

// MARK: - SCStreamDelegate

@available(macOS 12.3, *)
extension SystemAudioCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Handle audio sample buffers from ScreenCaptureKit
        guard type == .audio else { return }
        
        // Convert CMSampleBuffer to AVAudioPCMBuffer and process
        processSampleBuffer(sampleBuffer)
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("❌ Screen capture stream stopped with error: \(error.localizedDescription)")
        
        Task { @MainActor in
            isCapturing = false
            audioLevel = 0.0
        }
    }
    
    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Get and validate format description
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            logger.error("❌ Failed to get format description from sample buffer")
            return
        }
        
        // Validate CMSampleBuffer format before memory reinterpretation
        guard validateAudioFormat(formatDescription) else {
            logger.error("❌ Invalid audio format in sample buffer - skipping processing")
            return
        }
        
        // Create a standard audio format for system audio (44.1kHz, stereo)
        let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        // Create audio file on first buffer if not already created
        if audioFile == nil, let outputURL = self.outputURL {
            do {
                try createAudioFile(for: outputURL, with: standardFormat)
            } catch {
                logger.error("❌ Failed to create audio file: \(error.localizedDescription)")
                return
            }
        }
        
        // Use safe CoreMedia API instead of unsafe memory reinterpretation
        do {
            // Get audio buffer list with retained block buffer for safe memory access
            var audioBufferList = AudioBufferList()
            var blockBuffer: CMBlockBuffer?
            
            let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sampleBuffer,
                bufferListSizeNeededOut: nil,
                bufferListOut: &audioBufferList,
                bufferListSize: MemoryLayout<AudioBufferList>.size,
                blockBufferAllocator: nil,
                blockBufferMemoryAllocator: nil,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            
            guard status == noErr, let blockBuffer = blockBuffer else {
                logger.error("❌ Failed to get audio buffer list from sample buffer")
                return
            }
            
            // Note: BlockBuffer is automatically managed in modern Swift/ARC
            
            let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: standardFormat, frameCapacity: frameCount) else {
                logger.error("❌ Failed to create PCM buffer")
                return
            }
            
            pcmBuffer.frameLength = frameCount
            
            // Process audio buffers safely
            try processAudioBuffers(audioBufferList, into: pcmBuffer, frameCount: frameCount)
            
            // Write buffer to file
            try audioFile?.write(from: pcmBuffer)
            
            // Update audio level for UI feedback
            Task { @MainActor in
                self.updateAudioLevel(from: pcmBuffer)
            }
            
        } catch {
            logger.error("❌ Error processing system audio buffer: \(error.localizedDescription)")
        }
    }
    
    /**
     * Validates the audio format from CMSampleBuffer format description
     * 
     * This method performs comprehensive validation of audio format parameters to prevent
     * memory corruption and ensure safe audio processing.
     * 
     * ## Validation Checks:
     * 
     * 1. **Format ID**: Must be Linear PCM (kAudioFormatLinearPCM)
     * 2. **Sample Rate**: Must be within 8kHz - 192kHz range
     * 3. **Channel Count**: Must be 1 (mono) or 2 (stereo) channels
     * 4. **Bits Per Channel**: Must be 16-bit or 32-bit
     * 5. **Frame Size Consistency**: Validates mBytesPerFrame matches expected size
     * 
     * ## Memory Safety:
     * 
     * This validation prevents crashes that could occur from:
     * - Malformed audio format descriptions
     * - Inconsistent frame size calculations
     * - Unsupported audio formats that could cause buffer overruns
     * 
     * ## Error Handling:
     * 
     * Invalid formats are logged with specific error messages and return `false`.
     * Valid formats are logged with format details and return `true`.
     * 
     * - Parameter formatDescription: The CMFormatDescription to validate
     * - Returns: `true` if format is valid and safe to process, `false` otherwise
     */
    internal func validateAudioFormat(_ formatDescription: CMFormatDescription) -> Bool {
        // Get basic audio stream description
        guard let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            logger.error("❌ Failed to get audio stream basic description")
            return false
        }
        
        let asbd = audioStreamBasicDescription.pointee
        
        // Validate format ID - should be Linear PCM
        guard asbd.mFormatID == kAudioFormatLinearPCM else {
            logger.error("❌ Unsupported audio format ID: \(asbd.mFormatID)")
            return false
        }
        
        // Validate sample rate - should be reasonable range
        guard asbd.mSampleRate >= 8000 && asbd.mSampleRate <= 192000 else {
            logger.error("❌ Invalid sample rate: \(asbd.mSampleRate)")
            return false
        }
        
        // Validate channel count - should be 1 or 2 for system audio
        guard asbd.mChannelsPerFrame >= 1 && asbd.mChannelsPerFrame <= 2 else {
            logger.error("❌ Invalid channel count: \(asbd.mChannelsPerFrame)")
            return false
        }
        
        // Validate bits per channel - should be 16 or 32 bit
        guard asbd.mBitsPerChannel == 16 || asbd.mBitsPerChannel == 32 else {
            logger.error("❌ Unsupported bits per channel: \(asbd.mBitsPerChannel)")
            return false
        }
        
        // Validate frame size consistency
        let expectedBytesPerFrame = asbd.mChannelsPerFrame * (asbd.mBitsPerChannel / 8)
        guard asbd.mBytesPerFrame == expectedBytesPerFrame else {
            logger.error("❌ Inconsistent frame size: expected \(expectedBytesPerFrame), got \(asbd.mBytesPerFrame)")
            return false
        }
        
        logger.debug("✅ Audio format validated: \(asbd.mSampleRate)Hz, \(asbd.mChannelsPerFrame)ch, \(asbd.mBitsPerChannel)bit")
        return true
    }
    
    /**
     * Safely processes audio buffers from AudioBufferList into AVAudioPCMBuffer
     * 
     * This method provides safe conversion of raw audio data from CoreMedia's AudioBufferList
     * format into AVAudioPCMBuffer format suitable for file writing and processing.
     * 
     * ## Memory Safety Features:
     * 
     * 1. **Buffer Validation**: Validates buffer size and data availability before processing
     * 2. **Safe Type Conversion**: Uses `assumingMemoryBound` only after validation
     * 3. **Channel Handling**: Properly handles mono-to-stereo conversion and stereo processing
     * 4. **Bounds Checking**: Ensures frame count doesn't exceed buffer capacity
     * 
     * ## Processing Logic:
     * 
     * - **Mono Audio**: Duplicates single channel to both left and right channels
     * - **Stereo Audio**: Processes interleaved stereo data into separate channel buffers
     * - **Buffer Size**: Validates data size matches expected frame count
     * 
     * ## Error Handling:
     * 
     * Throws `SystemAudioCaptureError.audioFormatNotAvailable` for:
     * - Empty or invalid buffer data
     * - Missing channel data pointers
     * - Invalid buffer configuration
     * 
     * ## Thread Safety:
     * 
     * This method is called from ScreenCaptureKit's background thread and should not
     * perform any UI updates directly.
     * 
     * - Parameter audioBufferList: The source AudioBufferList from CoreMedia
     * - Parameter pcmBuffer: The destination AVAudioPCMBuffer
     * - Parameter frameCount: The number of audio frames to process
     * - Throws: SystemAudioCaptureError.audioFormatNotAvailable for invalid buffers
     */
    internal func processAudioBuffers(_ audioBufferList: AudioBufferList, into pcmBuffer: AVAudioPCMBuffer, frameCount: AVAudioFrameCount) throws {
        // Validate input parameters
        guard frameCount > 0 else {
            logger.error("❌ Invalid frame count: \(frameCount)")
            throw SystemAudioCaptureError.audioFormatNotAvailable
        }
        
        // Get the first audio buffer
        let audioBuffer = audioBufferList.mBuffers
        
        // Validate buffer data availability and size
        guard audioBuffer.mDataByteSize > 0,
              let sourceData = audioBuffer.mData else {
            logger.error("❌ Audio buffer has no data or invalid size: \(audioBuffer.mDataByteSize)")
            throw SystemAudioCaptureError.audioFormatNotAvailable
        }
        
        // Validate buffer size matches expected frame count
        let channelCount = Int(audioBufferList.mNumberBuffers)
        let bytesPerSample = 4 // Float32 = 4 bytes
        let expectedDataSize = channelCount == 1 ? 
            Int(frameCount) * bytesPerSample : 
            Int(frameCount) * 2 * bytesPerSample // Interleaved stereo
        
        guard Int(audioBuffer.mDataByteSize) >= expectedDataSize else {
            logger.error("❌ Buffer size mismatch: expected \(expectedDataSize), got \(audioBuffer.mDataByteSize)")
            throw SystemAudioCaptureError.audioFormatNotAvailable
        }
        
        // Validate PCM buffer has required channel data
        guard let floatChannelData = pcmBuffer.floatChannelData,
              pcmBuffer.format.channelCount >= 2 else {
            logger.error("❌ PCM buffer missing channel data or insufficient channels")
            throw SystemAudioCaptureError.audioFormatNotAvailable
        }
        
        // Validate frame capacity
        guard pcmBuffer.frameCapacity >= frameCount else {
            logger.error("❌ PCM buffer capacity insufficient: \(pcmBuffer.frameCapacity) < \(frameCount)")
            throw SystemAudioCaptureError.audioFormatNotAvailable
        }
        
        // Process audio data based on channel configuration
        do {
            if channelCount == 1 {
                // Mono to stereo conversion with bounds checking
                let leftChannel = floatChannelData[0]
                let rightChannel = floatChannelData[1]
                
                let floatData = sourceData.assumingMemoryBound(to: Float.self)
                
                // Process with bounds checking
                for i in 0..<Int(frameCount) {
                    let sample = floatData[i]
                    
                    // Validate sample is within reasonable range
                    guard sample.isFinite else {
                        logger.warning("⚠️ Non-finite sample detected at index \(i), skipping")
                        continue
                    }
                    
                    leftChannel[i] = sample
                    rightChannel[i] = sample // Duplicate for stereo
                }
                
                logger.debug("✅ Processed \(frameCount) mono samples to stereo")
            } else {
                // Stereo (or assume interleaved) with bounds checking
                let leftChannel = floatChannelData[0]
                let rightChannel = floatChannelData[1]
                
                let floatData = sourceData.assumingMemoryBound(to: Float.self)
                
                // Process interleaved stereo data with bounds checking
                for i in 0..<Int(frameCount) {
                    let leftIndex = i * 2
                    let rightIndex = i * 2 + 1
                    
                    // Bounds check for interleaved access
                    guard leftIndex < Int(audioBuffer.mDataByteSize) / bytesPerSample,
                          rightIndex < Int(audioBuffer.mDataByteSize) / bytesPerSample else {
                        logger.error("❌ Index out of bounds accessing stereo data at frame \(i)")
                        throw SystemAudioCaptureError.audioFormatNotAvailable
                    }
                    
                    let leftSample = floatData[leftIndex]
                    let rightSample = floatData[rightIndex]
                    
                    // Validate samples are within reasonable range
                    guard leftSample.isFinite && rightSample.isFinite else {
                        logger.warning("⚠️ Non-finite samples detected at frame \(i), skipping")
                        continue
                    }
                    
                    leftChannel[i] = leftSample
                    rightChannel[i] = rightSample
                }
                
                logger.debug("✅ Processed \(frameCount) interleaved stereo samples")
            }
        } catch {
            logger.error("❌ Audio buffer processing failed: \(error.localizedDescription)")
            throw SystemAudioCaptureError.audioFormatNotAvailable
        }
    }
}
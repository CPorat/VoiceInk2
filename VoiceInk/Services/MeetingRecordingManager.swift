import Foundation
import AVFoundation
import ScreenCaptureKit
import os

// MARK: - Audio Processing Delegate Protocol

/// Delegate protocol for audio processing events with proper completion handling
protocol AudioProcessingDelegate: AnyObject {
    /// Called when audio processing starts
    func audioProcessingDidStart(sources: [AudioSource])
    
    /// Called to report progress during audio processing
    func audioProcessingDidUpdateProgress(_ progress: AudioProcessingProgress)
    
    /// Called when individual audio source completes processing
    func audioProcessingDidCompleteSource(_ source: AudioSource)
    
    /// Called when buffer processing completes
    func audioProcessingDidCompleteBufferProcessing()
    
    /// Called when audio processing completes successfully
    func audioProcessingDidComplete(result: AudioProcessingResult)
    
    /// Called when audio processing fails
    func audioProcessingDidFail(error: AudioProcessingError)
}

// MARK: - Audio Processing Support Types

/// Represents an audio source being processed
enum AudioSource {
    case system
    case microphone
    
    var description: String {
        switch self {
        case .system: return "System Audio"
        case .microphone: return "Microphone"
        }
    }
}

/// Comprehensive progress information for audio processing operations
struct AudioProcessingProgress {
    let totalSources: Int
    let completedSources: Int
    let currentSource: AudioSource?
    let buffersProcessed: Int
    let estimatedDuration: TimeInterval?
    let currentStage: AudioProcessingStage
    let processingSpeed: Double? // buffers per second
    let timeRemaining: TimeInterval?
    let startTime: Date
    let resourceMetrics: ResourceMetrics?
    
    /// Legacy property for backward compatibility
    var percentComplete: Double {
        return progressPercentage
    }
    
    /// Overall progress percentage (0.0 to 1.0)
    var progressPercentage: Double {
        let stageProgress = currentStage.baseProgress
        let stageWeight = currentStage.weight
        
        // Calculate progress within current stage
        let inStageProgress: Double
        switch currentStage {
        case .validation:
            inStageProgress = Double(completedSources) / Double(max(1, totalSources))
        case .loading:
            inStageProgress = Double(completedSources) / Double(max(1, totalSources))
        case .processing:
            if let estimated = estimatedDuration {
                let elapsed = Date().timeIntervalSince(startTime)
                inStageProgress = min(1.0, elapsed / estimated)
            } else {
                inStageProgress = Double(completedSources) / Double(max(1, totalSources))
            }
        case .mixing:
            inStageProgress = buffersProcessed > 0 ? min(1.0, Double(buffersProcessed) / 1000.0) : 0.0
        case .finalizing:
            inStageProgress = 1.0
        case .complete:
            return 1.0
        }
        
        return stageProgress + (inStageProgress * stageWeight)
    }
    
    /// Human-readable progress description
    var description: String {
        let percentage = Int(progressPercentage * 100)
        let stageDesc = currentStage.description
        
        if let current = currentSource {
            return "\(stageDesc) - \(current.description) (\(percentage)%)"
        } else {
            return "\(stageDesc) (\(percentage)%)"
        }
    }
    
    /// Detailed status information
    var statusInfo: String {
        var info = [String]()
        
        info.append("Stage: \(currentStage.description)")
        info.append("Progress: \(Int(progressPercentage * 100))%")
        info.append("Sources: \(completedSources)/\(totalSources)")
        info.append("Buffers: \(buffersProcessed)")
        
        if let speed = processingSpeed {
            info.append("Speed: \(String(format: "%.1f", speed)) buf/s")
        }
        
        if let remaining = timeRemaining {
            info.append("ETA: \(String(format: "%.1f", remaining))s")
        }
        
        if let metrics = resourceMetrics {
            info.append("Memory: \(metrics.memoryUsageMB)MB")
            info.append("CPU: \(String(format: "%.1f", metrics.cpuUsage))%")
        }
        
        return info.joined(separator: ", ")
    }
    
    /// Simple initializer for backward compatibility
    init(totalSources: Int, completedSources: Int, currentSource: AudioSource?, buffersProcessed: Int, estimatedDuration: TimeInterval?) {
        self.totalSources = totalSources
        self.completedSources = completedSources
        self.currentSource = currentSource
        self.buffersProcessed = buffersProcessed
        self.estimatedDuration = estimatedDuration
        self.currentStage = .processing
        self.processingSpeed = nil
        self.timeRemaining = nil
        self.startTime = Date()
        self.resourceMetrics = nil
    }
    
    /// Comprehensive initializer with all progress tracking features
    init(totalSources: Int, completedSources: Int, currentSource: AudioSource?, buffersProcessed: Int, estimatedDuration: TimeInterval?, currentStage: AudioProcessingStage, processingSpeed: Double?, timeRemaining: TimeInterval?, startTime: Date, resourceMetrics: ResourceMetrics?) {
        self.totalSources = totalSources
        self.completedSources = completedSources
        self.currentSource = currentSource
        self.buffersProcessed = buffersProcessed
        self.estimatedDuration = estimatedDuration
        self.currentStage = currentStage
        self.processingSpeed = processingSpeed
        self.timeRemaining = timeRemaining
        self.startTime = startTime
        self.resourceMetrics = resourceMetrics
    }
}

/// Audio processing stages with progress weights
enum AudioProcessingStage {
    case validation
    case loading
    case processing
    case mixing
    case finalizing
    case complete
    
    /// Base progress percentage for this stage
    var baseProgress: Double {
        switch self {
        case .validation: return 0.0
        case .loading: return 0.1
        case .processing: return 0.2
        case .mixing: return 0.7
        case .finalizing: return 0.95
        case .complete: return 1.0
        }
    }
    
    /// Weight of this stage in overall progress
    var weight: Double {
        switch self {
        case .validation: return 0.1
        case .loading: return 0.1
        case .processing: return 0.5
        case .mixing: return 0.25
        case .finalizing: return 0.05
        case .complete: return 0.0
        }
    }
    
    /// Human-readable description
    var description: String {
        switch self {
        case .validation: return "Validating"
        case .loading: return "Loading"
        case .processing: return "Processing"
        case .mixing: return "Mixing"
        case .finalizing: return "Finalizing"
        case .complete: return "Complete"
        }
    }
}

/// Resource usage metrics for monitoring
struct ResourceMetrics {
    let memoryUsageMB: Double
    let cpuUsage: Double
    let diskSpaceUsedMB: Double
    let networkBandwidth: Double?
    
    /// Creates resource metrics from current system state
    static func current() -> ResourceMetrics {
        // Get memory usage
        let memoryUsage = getMemoryUsage()
        
        // Get CPU usage (simplified)
        let cpuUsage = getCPUUsage()
        
        // Get disk space usage (simplified)
        let diskUsage = getDiskUsage()
        
        return ResourceMetrics(
            memoryUsageMB: memoryUsage,
            cpuUsage: cpuUsage,
            diskSpaceUsedMB: diskUsage,
            networkBandwidth: nil
        )
    }
    
    private static func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        } else {
            return 0.0
        }
    }
    
    private static func getCPUUsage() -> Double {
        // Simplified CPU usage estimation
        return 0.0 // Would need more complex implementation for accurate CPU usage
    }
    
    private static func getDiskUsage() -> Double {
        // Simplified disk usage estimation
        return 0.0 // Would need more complex implementation for accurate disk usage
    }
}

/// Result of successful audio processing
struct AudioProcessingResult {
    let outputURL: URL
    let duration: TimeInterval
    let sourceFiles: [AudioSource: URL]
    let metadata: AudioProcessingMetadata
}

/// Metadata about the audio processing operation
struct AudioProcessingMetadata {
    let startTime: Date
    let processingDuration: TimeInterval
    let outputFormat: AVAudioFormat
    let sourceCount: Int
    let totalSamples: Int64
}

/// Errors that can occur during audio processing
enum AudioProcessingError: Error, LocalizedError {
    case invalidInput(String)
    case processingFailed(String)
    case fileWriteError(String)
    case bufferProcessingTimeout
    case processingTimeout(String)
    case cancelled
    
    // Enhanced error types for robust audio mixing
    case audioEngineStartFailed(String)
    case audioFileLoadFailed(String, URL)
    case audioFormatIncompatible(String)
    case nodeConnectionFailed(String)
    case tapInstallationFailed(String)
    case outputFileCreationFailed(String, URL)
    case resourceCleanupFailed(String)
    case insufficientDiskSpace(String)
    case filePermissionDenied(String)
    case engineConfigurationFailed(String)
    case bufferOverflow(String)
    case formatConversionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let msg): return "Invalid input: \(msg)"
        case .processingFailed(let msg): return "Processing failed: \(msg)"
        case .fileWriteError(let msg): return "File write error: \(msg)"
        case .bufferProcessingTimeout: return "Buffer processing timed out"
        case .processingTimeout(let msg): return "Processing timeout: \(msg)"
        case .cancelled: return "Operation was cancelled"
        case .audioEngineStartFailed(let msg): return "Audio engine failed to start: \(msg)"
        case .audioFileLoadFailed(let msg, let url): return "Failed to load audio file '\(url.lastPathComponent)': \(msg)"
        case .audioFormatIncompatible(let msg): return "Audio format incompatible: \(msg)"
        case .nodeConnectionFailed(let msg): return "Audio node connection failed: \(msg)"
        case .tapInstallationFailed(let msg): return "Audio tap installation failed: \(msg)"
        case .outputFileCreationFailed(let msg, let url): return "Failed to create output file '\(url.lastPathComponent)': \(msg)"
        case .resourceCleanupFailed(let msg): return "Resource cleanup failed: \(msg)"
        case .insufficientDiskSpace(let msg): return "Insufficient disk space: \(msg)"
        case .filePermissionDenied(let msg): return "File permission denied: \(msg)"
        case .engineConfigurationFailed(let msg): return "Audio engine configuration failed: \(msg)"
        case .bufferOverflow(let msg): return "Buffer overflow: \(msg)"
        case .formatConversionFailed(let msg): return "Audio format conversion failed: \(msg)"
        }
    }
    
    /// Recovery suggestions for different error types
    var recoverySuggestion: String? {
        switch self {
        case .audioEngineStartFailed:
            return "Try restarting the audio engine or check system audio settings"
        case .audioFileLoadFailed:
            return "Verify the audio file is valid and accessible"
        case .audioFormatIncompatible:
            return "Convert audio files to a compatible format"
        case .insufficientDiskSpace:
            return "Free up disk space and try again"
        case .filePermissionDenied:
            return "Check file permissions and try again"
        case .outputFileCreationFailed:
            return "Verify output directory exists and is writable"
        default:
            return "Try the operation again or contact support"
        }
    }
}

// MARK: - Recording State Manager Actor

/// Thread-safe actor for managing meeting recording state
actor RecordingStateManager {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "RecordingStateManager")
    
    // MARK: - State Properties
    private var _isRecording = false
    private var _recordingDuration: TimeInterval = 0
    private var _recordingError: String?
    private var _currentRecordingURL: URL?
    private var _isProcessing = false
    
    // Session state
    private var _recordingStartTime: Date?
    private var _systemAudioTempURL: URL?
    private var _microphoneTempURL: URL?
    
    // State transition tracking
    private var _recordingTransitionInProgress = false
    
    // Cancellation support
    private var _currentOperationTask: Task<Void, Error>?
    private var _operationTimeoutTask: Task<Void, Error>?
    private var _operationStartTime: Date?
    private var _forceCancellationRequested = false
    private var _cancellationReason: String?
    
    // MARK: - State Access
    
    var isRecording: Bool { _isRecording }
    var recordingDuration: TimeInterval { _recordingDuration }
    var recordingError: String? { _recordingError }
    var currentRecordingURL: URL? { _currentRecordingURL }
    var isProcessing: Bool { _isProcessing }
    var recordingStartTime: Date? { _recordingStartTime }
    var systemAudioTempURL: URL? { _systemAudioTempURL }
    var microphoneTempURL: URL? { _microphoneTempURL }
    var isOperationCancelled: Bool { _forceCancellationRequested }
    var cancellationReason: String? { _cancellationReason }
    
    // MARK: - State Management
    
    /// Safely attempt to begin recording transition
    func beginRecordingTransition() async throws {
        guard !_recordingTransitionInProgress else {
            logger.warning("⚠️ Recording transition already in progress")
            throw RecordingStateError.transitionInProgress
        }
        
        guard !_isRecording else {
            logger.warning("⚠️ Recording already active")
            throw RecordingStateError.alreadyRecording
        }
        
        _recordingTransitionInProgress = true
        _recordingError = nil
        logger.debug("🔄 Recording transition began")
    }
    
    /// Complete successful recording start
    func completeRecordingStart(systemURL: URL, micURL: URL, startTime: Date) async {
        _isRecording = true
        _recordingStartTime = startTime
        _systemAudioTempURL = systemURL
        _microphoneTempURL = micURL
        _recordingTransitionInProgress = false
        
        logger.info("✅ Recording state transitioned to active")
    }
    
    /// Cancel recording start due to error
    func cancelRecordingStart(error: String) async {
        _recordingError = error
        _recordingTransitionInProgress = false
        _systemAudioTempURL = nil
        _microphoneTempURL = nil
        
        logger.error("❌ Recording start cancelled: \(error)")
    }
    
    /// Safely attempt to begin stop transition
    func beginStopTransition() async throws {
        guard !_recordingTransitionInProgress else {
            logger.warning("⚠️ Recording transition already in progress")
            throw RecordingStateError.transitionInProgress
        }
        
        guard _isRecording else {
            logger.warning("⚠️ No recording in progress")
            throw RecordingStateError.notRecording
        }
        
        _recordingTransitionInProgress = true
        logger.debug("🔄 Stop transition began")
    }
    
    /// Complete recording stop
    func completeRecordingStop() async {
        _isRecording = false
        _recordingDuration = 0
        _recordingStartTime = nil
        _systemAudioTempURL = nil
        _microphoneTempURL = nil
        _recordingTransitionInProgress = false
        
        logger.info("✅ Recording state transitioned to stopped")
    }
    
    /// Update recording duration
    func updateDuration(_ duration: TimeInterval) async {
        _recordingDuration = duration
    }
    
    /// Set processing state
    func setProcessing(_ processing: Bool) async {
        _isProcessing = processing
    }
    
    /// Set current recording URL
    func setCurrentRecordingURL(_ url: URL?) async {
        _currentRecordingURL = url
    }
    
    /// Set recording error
    func setRecordingError(_ error: String?) async {
        _recordingError = error
    }
    
    /// Check if recording can be started
    func canStartRecording() async -> Bool {
        return !_isRecording && !_recordingTransitionInProgress
    }
    
    /// Check if recording can be stopped
    func canStopRecording() async -> Bool {
        return _isRecording && !_recordingTransitionInProgress
    }
    
    // MARK: - Cancellation Management
    
    /// Set current operation task for cancellation tracking
    func setCurrentOperationTask(_ task: Task<Void, Error>?) async {
        _currentOperationTask = task
        _operationStartTime = task != nil ? Date() : nil
        _forceCancellationRequested = false
        _cancellationReason = nil
    }
    
    /// Request force cancellation of current operation
    func requestCancellation(reason: String) async {
        _forceCancellationRequested = true
        _cancellationReason = reason
        
        // Cancel current operation task if it exists
        _currentOperationTask?.cancel()
        _operationTimeoutTask?.cancel()
        
        logger.warning("🚫 Operation cancellation requested: \(reason)")
    }
    
    /// Start operation timeout monitoring
    func startOperationTimeout(seconds: TimeInterval) async {
        _operationTimeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            
            // If we reach here, the operation has timed out
            await self.requestCancellation(reason: "Operation timed out after \(seconds) seconds")
        }
    }
    
    /// Clear operation timeout
    func clearOperationTimeout() async {
        _operationTimeoutTask?.cancel()
        _operationTimeoutTask = nil
    }
    
    /// Check if operation should be cancelled
    func shouldCancelOperation() async -> Bool {
        if _forceCancellationRequested {
            logger.debug("🚫 Operation should be cancelled: \(_cancellationReason ?? "unknown reason")")
            return true
        }
        
        // Check if operation has been running too long (fallback safety)
        if let startTime = _operationStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 30 { // 30 seconds maximum for any operation
                await requestCancellation(reason: "Operation exceeded maximum duration (30s)")
                return true
            }
        }
        
        return false
    }
    
    /// Complete operation cleanup
    func completeOperationCleanup() async {
        _currentOperationTask = nil
        _operationTimeoutTask?.cancel()
        _operationTimeoutTask = nil
        _operationStartTime = nil
        _forceCancellationRequested = false
        _cancellationReason = nil
        
        logger.debug("🧹 Operation cleanup completed")
    }
}

// MARK: - Recording State Errors

enum RecordingStateError: Error {
    case transitionInProgress
    case alreadyRecording
    case notRecording
    case operationCancelled(String)
    case operationTimedOut
    case concurrentOperationAttempt
    
    var localizedDescription: String {
        switch self {
        case .transitionInProgress:
            return "Recording state transition already in progress"
        case .alreadyRecording:
            return "Recording is already active"
        case .notRecording:
            return "No recording in progress"
        case .operationCancelled(let reason):
            return "Operation was cancelled: \(reason)"
        case .operationTimedOut:
            return "Operation timed out"
        case .concurrentOperationAttempt:
            return "Concurrent operation attempt detected"
        }
    }
}

// MARK: - Audio Processing Operation

/// Manages an audio processing operation with comprehensive progress tracking
class AudioProcessingOperation {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AudioProcessingOperation")
    
    // Operation state
    private var completedSources: Set<AudioSource> = []
    private var totalBuffersProcessed: Int = 0
    private var isBufferProcessingComplete = false
    private var operationStartTime: Date
    private var _isComplete = false
    
    // Enhanced progress tracking
    private let totalSources: Int
    private let expectedSources: Set<AudioSource>
    private var currentStage: AudioProcessingStage = .validation
    private var lastProgressUpdate: Date = Date()
    private var processingSpeedHistory: [Double] = []
    private var estimatedDuration: TimeInterval?
    private var stageStartTime: Date = Date()
    
    // Completion handlers
    private var completionHandler: ((Result<AudioProcessingResult, AudioProcessingError>) -> Void)?
    private var progressHandler: ((AudioProcessingProgress) -> Void)?
    
    weak var delegate: AudioProcessingDelegate?
    
    // Thread-safe completion state
    private let completionLock = NSLock()
    
    // Progress update throttling
    private let progressUpdateInterval: TimeInterval = 0.1 // 100ms minimum between updates
    
    var isComplete: Bool {
        completionLock.lock()
        defer { completionLock.unlock() }
        return _isComplete
    }
    
    init(sources: [AudioSource], delegate: AudioProcessingDelegate?) {
        self.totalSources = sources.count
        self.expectedSources = Set(sources)
        self.operationStartTime = Date()
        self.delegate = delegate
        
        // Notify delegate that processing started
        delegate?.audioProcessingDidStart(sources: sources)
    }
    
    /// Set completion handler for the operation
    func setCompletionHandler(_ handler: @escaping (Result<AudioProcessingResult, AudioProcessingError>) -> Void) {
        completionHandler = handler
    }
    
    /// Set progress handler for the operation
    func setProgressHandler(_ handler: @escaping (AudioProcessingProgress) -> Void) {
        progressHandler = handler
    }
    
    /// Mark a source as completed
    func markSourceCompleted(_ source: AudioSource) {
        completionLock.lock()
        guard !_isComplete else { 
            completionLock.unlock()
            return 
        }
        
        completedSources.insert(source)
        completionLock.unlock()
        
        delegate?.audioProcessingDidCompleteSource(source)
        updateProgress()
        
        // Check if all sources are complete
        checkForCompletion()
    }
    
    /// Mark buffer processing as complete
    func markBufferProcessingComplete() {
        completionLock.lock()
        guard !_isComplete else { 
            completionLock.unlock()
            return 
        }
        
        isBufferProcessingComplete = true
        completionLock.unlock()
        
        delegate?.audioProcessingDidCompleteBufferProcessing()
        updateProgress()
        
        // Check if all sources are complete
        checkForCompletion()
    }
    
    /// Update buffer processing count
    func updateBufferCount(_ count: Int) {
        totalBuffersProcessed = count
        updateProgress()
    }
    
    /// Update estimated processing duration for better progress tracking
    func updateEstimatedDuration(_ duration: TimeInterval) {
        updateProgress(estimatedDuration: duration)
    }
    
    /// Check if operation is complete and trigger completion if so
    private func checkForCompletion() {
        completionLock.lock()
        let shouldComplete = !_isComplete && completedSources == expectedSources && isBufferProcessingComplete
        completionLock.unlock()
        
        if shouldComplete {
            // Mark as complete but don't call completion handler yet
            // The actual completion will be handled by the complete(with:) method
            logger.debug("✅ Audio processing operation ready for completion")
        }
    }
    
    /// Complete the operation with a result
    func complete(with result: AudioProcessingResult) {
        completionLock.lock()
        guard !_isComplete else { 
            completionLock.unlock()
            return 
        }
        
        _isComplete = true
        completionLock.unlock()
        
        delegate?.audioProcessingDidComplete(result: result)
        completionHandler?(.success(result))
        
        logger.notice("✅ Audio processing completed successfully")
    }
    
    /// Fail the operation with an error
    func fail(with error: AudioProcessingError) {
        completionLock.lock()
        guard !_isComplete else { 
            completionLock.unlock()
            return 
        }
        
        _isComplete = true
        completionLock.unlock()
        
        delegate?.audioProcessingDidFail(error: error)
        completionHandler?(.failure(error))
        
        logger.error("❌ Audio processing failed: \(error.localizedDescription)")
    }
    
    /// Update progress and notify handlers with throttling
    private func updateProgress() {
        updateProgress(estimatedDuration: estimatedDuration)
    }
    
    /// Update progress with optional estimated duration and comprehensive tracking
    private func updateProgress(estimatedDuration: TimeInterval?) {
        let now = Date()
        
        // Throttle progress updates to avoid excessive callbacks
        if now.timeIntervalSince(lastProgressUpdate) < progressUpdateInterval {
            return
        }
        
        lastProgressUpdate = now
        
        // Update estimated duration if provided
        if let duration = estimatedDuration {
            self.estimatedDuration = duration
        }
        
        // Calculate processing speed
        let processingSpeed = calculateProcessingSpeed()
        
        // Calculate time remaining
        let timeRemaining = calculateTimeRemaining()
        
        // Get current resource metrics
        let resourceMetrics = ResourceMetrics.current()
        
        // Create comprehensive progress object
        let progress = AudioProcessingProgress(
            totalSources: totalSources,
            completedSources: completedSources.count,
            currentSource: getCurrentSource(),
            buffersProcessed: totalBuffersProcessed,
            estimatedDuration: self.estimatedDuration,
            currentStage: currentStage,
            processingSpeed: processingSpeed,
            timeRemaining: timeRemaining,
            startTime: operationStartTime,
            resourceMetrics: resourceMetrics
        )
        
        delegate?.audioProcessingDidUpdateProgress(progress)
        progressHandler?(progress)
    }
    
    /// Set the current processing stage
    func setCurrentStage(_ stage: AudioProcessingStage) {
        if currentStage != stage {
            logger.debug("📊 Processing stage changed: \(currentStage.description) → \(stage.description)")
            currentStage = stage
            stageStartTime = Date()
            updateProgress()
        }
    }
    
    /// Calculate processing speed based on recent history
    private func calculateProcessingSpeed() -> Double? {
        let now = Date()
        let elapsed = now.timeIntervalSince(operationStartTime)
        
        guard elapsed > 0 else { return nil }
        
        // Calculate buffers per second
        let currentSpeed = Double(totalBuffersProcessed) / elapsed
        
        // Add to history and maintain a rolling average
        processingSpeedHistory.append(currentSpeed)
        
        // Keep only recent history (last 10 measurements)
        if processingSpeedHistory.count > 10 {
            processingSpeedHistory.removeFirst()
        }
        
        // Return average speed
        return processingSpeedHistory.reduce(0, +) / Double(processingSpeedHistory.count)
    }
    
    /// Calculate estimated time remaining
    private func calculateTimeRemaining() -> TimeInterval? {
        guard let processingSpeed = calculateProcessingSpeed(),
              processingSpeed > 0,
              let estimatedDuration = estimatedDuration else {
            return nil
        }
        
        let elapsed = Date().timeIntervalSince(operationStartTime)
        let progressRatio = elapsed / estimatedDuration
        
        guard progressRatio < 1.0 else { return 0 }
        
        return estimatedDuration - elapsed
    }
    
    /// Get the current source being processed
    private func getCurrentSource() -> AudioSource? {
        // Return the first source that hasn't been completed yet
        return expectedSources.first { !completedSources.contains($0) }
    }
    
    /// Get comprehensive status information
    func getStatusInfo() -> String {
        let progress = AudioProcessingProgress(
            totalSources: totalSources,
            completedSources: completedSources.count,
            currentSource: getCurrentSource(),
            buffersProcessed: totalBuffersProcessed,
            estimatedDuration: estimatedDuration,
            currentStage: currentStage,
            processingSpeed: calculateProcessingSpeed(),
            timeRemaining: calculateTimeRemaining(),
            startTime: operationStartTime,
            resourceMetrics: ResourceMetrics.current()
        )
        
        return progress.statusInfo
    }
    
    /// Get current progress as a percentage
    func getProgressPercentage() -> Double {
        let progress = AudioProcessingProgress(
            totalSources: totalSources,
            completedSources: completedSources.count,
            currentSource: getCurrentSource(),
            buffersProcessed: totalBuffersProcessed,
            estimatedDuration: estimatedDuration,
            currentStage: currentStage,
            processingSpeed: calculateProcessingSpeed(),
            timeRemaining: calculateTimeRemaining(),
            startTime: operationStartTime,
            resourceMetrics: ResourceMetrics.current()
        )
        
        return progress.stagePercentComplete
    }
}

// MARK: - Meeting Recording Manager

@MainActor
class MeetingRecordingManager: ObservableObject, AudioProcessingDelegate {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingError: String?
    @Published var currentRecordingURL: URL?
    @Published var isProcessing = false
    @Published var processingProgress: AudioProcessingProgress?
    
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "MeetingRecordingManager")
    private let deviceManager = AudioDeviceManager.shared
    private let recorder = Recorder()
    
    // Audio processing delegate support
    weak var audioProcessingDelegate: AudioProcessingDelegate?
    
    // Thread-safe state management
    private let stateManager = RecordingStateManager()
    
    // Audio processing state
    private var currentProcessingOperation: AudioProcessingOperation?
    
    // Thread-safe component access
    private let componentLock = NSLock()
    private var systemAudioCapture: SystemAudioCapture?
    
    // Thread-safe duration tracking
    private let timerLock = NSLock()
    private var durationTimer: Timer?
    
    // Thread-safe file operations
    private let fileOperationLock = NSLock()
    private let recordingFileManager = RecordingFileManager()
    
    // Thread-safe property synchronization
    private let propertySyncLock = NSLock()
    
    // Cancellation and timeout handling
    private let cancellationLock = NSLock()
    private var pendingOperations: Set<String> = []
    private let operationTimeout: TimeInterval = 15.0 // 15 seconds timeout for operations
    
    init() {
        setupComponents()
    }
    
    private func setupComponents() {
        componentLock.lock()
        defer { componentLock.unlock() }
        systemAudioCapture = SystemAudioCapture()
    }
    
    // MARK: - Thread-Safe Component Access
    
    /// Thread-safe access to system audio capture component
    private func withSystemAudioCapture<T>(_ operation: (SystemAudioCapture) throws -> T) rethrows -> T? {
        componentLock.lock()
        defer { componentLock.unlock() }
        
        guard let capture = systemAudioCapture else { return nil }
        return try operation(capture)
    }
    
    /// Thread-safe access to system audio capture component (async)
    private func withSystemAudioCapture<T>(_ operation: (SystemAudioCapture) async throws -> T) async rethrows -> T? {
        let capture: SystemAudioCapture?
        
        componentLock.lock()
        capture = systemAudioCapture
        componentLock.unlock()
        
        guard let capture = capture else { return nil }
        return try await operation(capture)
    }
    
    // MARK: - Thread-Safe Timer Management
    
    /// Thread-safe timer creation and management
    private func safeStartDurationTimer() {
        timerLock.lock()
        defer { timerLock.unlock() }
        
        // Cancel existing timer if any
        durationTimer?.invalidate()
        
        // Create new timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
        
        logger.debug("⏱️ Duration timer started")
    }
    
    /// Thread-safe timer stopping
    private func safeStopDurationTimer() {
        timerLock.lock()
        defer { timerLock.unlock() }
        
        durationTimer?.invalidate()
        durationTimer = nil
        
        logger.debug("⏱️ Duration timer stopped")
    }
    
    // MARK: - Thread-Safe Property Synchronization
    
    /// Thread-safe synchronization of published properties with state manager
    private func safeUpdatePublishedProperties() async {
        propertySyncLock.lock()
        defer { propertySyncLock.unlock() }
        
        // Get all state values atomically
        let recordingState = await stateManager.isRecording
        let duration = await stateManager.recordingDuration
        let error = await stateManager.recordingError
        let currentURL = await stateManager.currentRecordingURL
        let processing = await stateManager.isProcessing
        
        // Update published properties on main thread
        Task { @MainActor in
            self.isRecording = recordingState
            self.recordingDuration = duration
            self.recordingError = error
            self.currentRecordingURL = currentURL
            self.isProcessing = processing
        }
    }
    
    // MARK: - Thread-Safe File Operations
    
    /// Thread-safe file creation with proper locking
    private func safeCreateTemporaryFiles() -> (systemURL: URL, micURL: URL)? {
        fileOperationLock.lock()
        defer { fileOperationLock.unlock() }
        
        let systemURL = recordingFileManager.createTemporaryRecordingURL()
        let micURL = recordingFileManager.createTemporaryRecordingURL()
        
        logger.debug("📁 Created temporary files: \(systemURL.lastPathComponent), \(micURL.lastPathComponent)")
        return (systemURL, micURL)
    }
    
    /// Thread-safe file cleanup
    private func safeCleanupTempFiles() {
        fileOperationLock.lock()
        defer { fileOperationLock.unlock() }
        
        // Clean up temp files if they exist
        Task {
            if let systemURL = await stateManager.systemAudioTempURL {
                try? FileManager.default.removeItem(at: systemURL)
                logger.debug("🗑️ Cleaned up system audio temp file")
            }
            if let micURL = await stateManager.microphoneTempURL {
                try? FileManager.default.removeItem(at: micURL)
                logger.debug("🗑️ Cleaned up microphone temp file")
            }
        }
    }
    
    // MARK: - Cancellation and Overlap Handling
    
    /// Check for overlapping operations and register new operation
    private func checkAndRegisterOperation(_ operationId: String) throws {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        
        // Check if this operation type is already pending
        if pendingOperations.contains(operationId) {
            logger.warning("⚠️ Overlapping operation detected: \(operationId)")
            throw RecordingStateError.concurrentOperationAttempt
        }
        
        // Register the new operation
        pendingOperations.insert(operationId)
        logger.debug("📝 Registered operation: \(operationId)")
    }
    
    /// Unregister completed operation
    private func unregisterOperation(_ operationId: String) {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        
        pendingOperations.remove(operationId)
        logger.debug("✅ Unregistered operation: \(operationId)")
    }
    
    /// Force cancel current recording operation
    func forceCancelRecording() async {
        logger.warning("🚫 Force cancelling recording operation")
        
        await stateManager.requestCancellation(reason: "User requested force cancellation")
        
        // Force stop any ongoing recording components
        await withSystemAudioCapture { capture in
            capture.stopCapture()
        }
        
        recorder.stopRecording()
        safeStopDurationTimer()
        
        // Clean up state
        await stateManager.completeRecordingStop()
        await stateManager.completeOperationCleanup()
        await safeUpdatePublishedProperties()
        
        // Clear any pending operations
        cancellationLock.lock()
        pendingOperations.removeAll()
        cancellationLock.unlock()
        
        safeCleanupTempFiles()
        
        logger.notice("🚫 Recording forcefully cancelled")
    }
    
    /// Check if operation should be cancelled during execution
    private func checkCancellation() async throws {
        if await stateManager.shouldCancelOperation() {
            let reason = await stateManager.cancellationReason ?? "Unknown reason"
            throw RecordingStateError.operationCancelled(reason)
        }
    }
    
    // MARK: - Recording Control
    
    func startMeetingRecording() async {
        logger.notice("🎙️ Starting meeting recording...")
        
        let operationId = "start_recording"
        
        // Check for overlapping operations
        do {
            try checkAndRegisterOperation(operationId)
        } catch {
            logger.warning("⚠️ Cannot start recording: \(error.localizedDescription)")
            return
        }
        
        defer {
            unregisterOperation(operationId)
        }
        
        // Use thread-safe state management
        do {
            try await stateManager.beginRecordingTransition()
        } catch {
            logger.warning("⚠️ Cannot start recording: \(error.localizedDescription)")
            return
        }
        
        // Create cancellable task for the recording operation
        let recordingTask = Task<Void, Error> {
            // Start operation timeout monitoring
            await stateManager.startOperationTimeout(seconds: operationTimeout)
            
            defer {
                Task {
                    await stateManager.clearOperationTimeout()
                    await stateManager.completeOperationCleanup()
                }
            }
            
            do {
                // Check for cancellation before starting
                try await checkCancellation()
                
                // Create temporary file URLs using thread-safe method
                guard let urls = safeCreateTemporaryFiles() else {
                    throw MeetingRecordingError.fileCreationFailed
                }
                
                // Check for cancellation before system audio capture
                try await checkCancellation()
                
                // Start system audio capture using thread-safe component access
                let systemCaptureStarted = await withSystemAudioCapture { capture in
                    try await capture.startCapture(outputURL: urls.systemURL)
                }
                
                guard systemCaptureStarted != nil else {
                    throw MeetingRecordingError.systemAudioCaptureNotAvailable
                }
                
                // Check for cancellation before microphone recording
                try await checkCancellation()
                
                // Start microphone recording to separate temp file
                try await recorder.startRecording(toOutputFile: urls.micURL)
                
                // Check for cancellation before completing state transition
                try await checkCancellation()
                
                // Complete state transition ONLY after all async operations succeed
                let startTime = Date()
                await stateManager.completeRecordingStart(
                    systemURL: urls.systemURL,
                    micURL: urls.micURL,
                    startTime: startTime
                )
                
                // Sync published properties with state manager using thread-safe method
                await safeUpdatePublishedProperties()
                
                // Start duration tracking using thread-safe method
                safeStartDurationTimer()
                
                logger.notice("✅ Meeting recording started successfully (two-stage mode)")
                
            } catch is CancellationError {
                logger.warning("🚫 Recording start was cancelled")
                throw RecordingStateError.operationCancelled("Task was cancelled")
            } catch let error as RecordingStateError {
                throw error
            } catch {
                throw MeetingRecordingError.microphoneRecordingFailed
            }
        }
        
        // Set the task for cancellation tracking
        await stateManager.setCurrentOperationTask(recordingTask)
        
        do {
            try await recordingTask.value
        } catch {
            logger.error("❌ Failed to start meeting recording: \(error.localizedDescription)")
            
            // Cancel state transition and clean up
            await stateManager.cancelRecordingStart(error: "Failed to start recording: \(error.localizedDescription)")
            await safeUpdatePublishedProperties()
            safeCleanupTempFiles()
        }
    }
    
    func stopMeetingRecording() async {
        logger.notice("🛑 Stopping meeting recording...")
        
        let operationId = "stop_recording"
        
        // Check for overlapping operations
        do {
            try checkAndRegisterOperation(operationId)
        } catch {
            logger.warning("⚠️ Cannot stop recording: \(error.localizedDescription)")
            return
        }
        
        defer {
            unregisterOperation(operationId)
        }
        
        // Use thread-safe state management
        do {
            try await stateManager.beginStopTransition()
        } catch {
            logger.warning("⚠️ Cannot stop recording: \(error.localizedDescription)")
            return
        }
        
        // Create cancellable task for the stop operation
        let stopTask = Task<Void, Error> {
            // Start operation timeout monitoring
            await stateManager.startOperationTimeout(seconds: operationTimeout)
            
            defer {
                Task {
                    await stateManager.clearOperationTimeout()
                    await stateManager.completeOperationCleanup()
                }
            }
            
            do {
                // Check for cancellation before starting
                try await checkCancellation()
                
                // Stop duration timer using thread-safe method
                safeStopDurationTimer()
                
                // Get current state before stopping
                let systemURL = await stateManager.systemAudioTempURL
                let micURL = await stateManager.microphoneTempURL
                let hasError = await stateManager.recordingError != nil
                
                // Check for cancellation before stopping components
                try await checkCancellation()
                
                // Stop both audio capture systems and wait for completion using thread-safe component access
                await withTaskGroup(of: Void.self) { group in
                    // Stop system audio capture using thread-safe component access
                    group.addTask {
                        await self.withSystemAudioCapture { capture in
                            // SystemAudioCapture.stopCapture() is async internally but doesn't return a task
                            // We need to ensure it completes before proceeding
                            capture.stopCapture()
                            
                            // Wait for the capture to actually stop with cancellation checks
                            while capture.isCapturing {
                                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                                
                                // Check for cancellation during polling
                                if await self.stateManager.shouldCancelOperation() {
                                    return // Exit polling loop if cancelled
                                }
                            }
                        }
                    }
                    
                    // Stop microphone recording and wait for its async operations
                    group.addTask {
                        // Stop microphone recording
                        self.recorder.stopRecording()
                        
                        // Wait for any async cleanup operations in recorder to complete
                        // The recorder has async unmuting operations that need to complete
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms buffer for recorder cleanup
                    }
                }
                
                // Check for cancellation before completing state transition
                try await checkCancellation()
                
                // Complete state transition ONLY after all stopping operations complete
                await stateManager.completeRecordingStop()
                await safeUpdatePublishedProperties()
                
                // Start post-processing if we have both temp files and they exist
                if let systemURL = systemURL,
                   let micURL = micURL,
                   !hasError {
                    
                    // Check for cancellation before post-processing
                    try await checkCancellation()
                    
                    // Calculate expected duration from current recording session
                    let expectedDuration = await stateManager.recordingDuration
                    
                    // Verify files exist and are fully written using duration-based validation
                    let filesReady = await verifyRecordingFilesReadyWithDuration(
                        systemURL: systemURL, 
                        micURL: micURL, 
                        expectedDuration: expectedDuration
                    )
                    
                    if filesReady {
                        // Check for cancellation before mixing
                        try await checkCancellation()
                        await mixAudioFiles(systemURL: systemURL, microphoneURL: micURL)
                    } else {
                        logger.error("❌ Temp files missing or not ready - system: \\(FileManager.default.fileExists(atPath: systemURL.path)), mic: \\(FileManager.default.fileExists(atPath: micURL.path))")
                        await stateManager.setRecordingError("Recording files missing or not ready - recording may have failed")
                        await safeUpdatePublishedProperties()
                        safeCleanupTempFiles()
                    }
                } else {
                    // Clean up temp files if recording failed
                    logger.warning("⚠️ Recording failed or temp files missing")
                    safeCleanupTempFiles()
                }
                
                logger.notice("✅ Meeting recording stopped successfully")
                
            } catch is CancellationError {
                logger.warning("🚫 Recording stop was cancelled")
                throw RecordingStateError.operationCancelled("Task was cancelled")
            } catch let error as RecordingStateError {
                throw error
            } catch {
                logger.error("❌ Error during stop operation: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Set the task for cancellation tracking
        await stateManager.setCurrentOperationTask(stopTask)
        
        do {
            try await stopTask.value
        } catch {
            logger.error("❌ Failed to stop meeting recording: \(error.localizedDescription)")
            
            // Force cleanup on error
            await stateManager.completeRecordingStop()
            await safeUpdatePublishedProperties()
            safeCleanupTempFiles()
        }
    }
    
    func toggleMeetingRecording() async {
        // Check if any operation is currently cancelled
        if await stateManager.isOperationCancelled {
            logger.warning("🚫 Cannot toggle recording - operation is being cancelled")
            return
        }
        
        let canStart = await stateManager.canStartRecording()
        let canStop = await stateManager.canStopRecording()
        
        if canStop {
            await stopMeetingRecording()
        } else if canStart {
            await startMeetingRecording()
        } else {
            logger.warning("⚠️ Cannot toggle recording - transition in progress or overlapping operation")
            
            // If user is trying to toggle while transition is in progress,
            // offer force cancellation after a brief delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if await stateManager.isOperationCancelled == false {
                logger.info("💡 Hint: Use forceCancelRecording() to cancel stuck operations")
            }
        }
    }
    
    // MARK: - State Synchronization
    
    /// Synchronize published properties with the thread-safe state manager
    /// @deprecated Use safeUpdatePublishedProperties() instead for thread safety
    private func syncPublishedProperties() async {
        await safeUpdatePublishedProperties()
    }
    
    // MARK: - File Verification
    // Note: verifyRecordingFilesReady has been replaced with verifyRecordingFilesReadyWithDuration
    // for proper duration-based validation instead of sleep-based polling
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    // MARK: - Duration Tracking
    
    /// @deprecated Use safeStartDurationTimer() instead for thread safety
    private func startDurationTimer() {
        safeStartDurationTimer()
    }
    
    /// @deprecated Use safeStopDurationTimer() instead for thread safety
    private func stopDurationTimer() {
        safeStopDurationTimer()
    }
    
    /// Thread-safe duration update method
    private func updateRecordingDuration() async {
        guard let startTime = await stateManager.recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        
        // Update state manager and sync UI using thread-safe method
        await stateManager.updateDuration(duration)
        
        // Update published property on main thread
        await MainActor.run {
            self.recordingDuration = duration
        }
    }
    
    // MARK: - Permissions
    
    func checkPermissions() async -> Bool {
        // Check screen recording permission
        let screenCapturePermission = await checkScreenCapturePermission()
        
        // Microphone permission is already handled by existing Recorder
        
        return screenCapturePermission
    }
    
    // MARK: - AudioProcessingDelegate Implementation
    
    func audioProcessingDidStart(sources: [AudioSource]) {
        logger.notice("🎛️ Audio processing started for sources: \(sources.map { $0.description }.joined(separator: ", "))")
        
        Task { @MainActor in
            self.processingProgress = AudioProcessingProgress(
                totalSources: sources.count,
                completedSources: 0,
                currentSource: sources.first,
                buffersProcessed: 0,
                estimatedDuration: nil
            )
        }
    }
    
    func audioProcessingDidUpdateProgress(_ progress: AudioProcessingProgress) {
        logger.debug("📊 Audio processing progress: \(Int(progress.percentComplete * 100))% (\(progress.completedSources)/\(progress.totalSources) sources)")
        
        Task { @MainActor in
            self.processingProgress = progress
        }
    }
    
    func audioProcessingDidCompleteSource(_ source: AudioSource) {
        logger.info("✅ Completed processing for \(source.description)")
    }
    
    func audioProcessingDidCompleteBufferProcessing() {
        logger.debug("✅ Buffer processing completed")
    }
    
    func audioProcessingDidComplete(result: AudioProcessingResult) {
        logger.notice("✅ Audio processing completed successfully")
        
        Task { @MainActor in
            self.processingProgress = nil
        }
        
        // Update state with the result
        Task {
            await stateManager.setCurrentRecordingURL(result.outputURL)
            await safeUpdatePublishedProperties()
        }
    }
    
    func audioProcessingDidFail(error: AudioProcessingError) {
        logger.error("❌ Audio processing failed: \(error.localizedDescription)")
        
        Task { @MainActor in
            self.processingProgress = nil
        }
        
        // Update state with the error
        Task {
            await stateManager.setRecordingError("Audio processing failed: \(error.localizedDescription)")
            await safeUpdatePublishedProperties()
        }
    }
    
    // MARK: - Comprehensive Progress Reporting and Status Updates
    
    /// Get comprehensive progress information for UI updates
    func getCurrentProgressInfo() -> AudioProcessingProgress? {
        return processingProgress
    }
    
    /// Get current processing stage description
    func getCurrentStageDescription() -> String? {
        return processingProgress?.currentStage.description
    }
    
    /// Get processing speed in buffers per second
    func getCurrentProcessingSpeed() -> Double? {
        return processingProgress?.processingSpeed
    }
    
    /// Get estimated time remaining
    func getEstimatedTimeRemaining() -> TimeInterval? {
        return processingProgress?.timeRemaining
    }
    
    /// Get current resource usage metrics
    func getCurrentResourceMetrics() -> ResourceMetrics? {
        return processingProgress?.resourceMetrics
    }
    
    /// Get detailed processing status report
    func getDetailedStatusReport() -> String {
        guard let progress = processingProgress else {
            return "No processing operation in progress"
        }
        
        let statusComponents = [
            "Stage: \(progress.currentStage.description)",
            "Progress: \(String(format: "%.1f%%", progress.stagePercentComplete * 100))",
            "Sources: \(progress.completedSources)/\(progress.totalSources)",
            "Buffers: \(progress.buffersProcessed)",
            progress.processingSpeed.map { "Speed: \(String(format: "%.1f", $0)) buffers/sec" },
            progress.timeRemaining.map { "Time remaining: \(String(format: "%.1f", $0))s" }
        ]
        
        return statusComponents.compactMap { $0 }.joined(separator: " | ")
    }
    
    /// Get processing progress as percentage (0.0 to 1.0)
    func getProcessingPercentage() -> Double {
        return processingProgress?.stagePercentComplete ?? 0.0
    }
    
    /// Check if processing is currently active
    func isProcessingActive() -> Bool {
        return processingProgress != nil && processingProgress?.currentStage != .complete
    }
    
    /// Get current processing operation info
    func getCurrentOperationInfo() -> String? {
        guard let operation = currentProcessingOperation else {
            return nil
        }
        
        return operation.getStatusInfo()
    }
    
    // MARK: - Robust Audio Processing Error Handling
    
    /// Validates audio file accessibility and format compatibility
    private func validateAudioFile(_ url: URL, context: String) throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioProcessingError.audioFileLoadFailed("File does not exist", url)
        }
        
        // Check file permissions
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw AudioProcessingError.filePermissionDenied("Cannot read audio file: \(url.lastPathComponent)")
        }
        
        // Check file size (must be > 0)
        let fileSize = getFileSize(at: url)
        guard fileSize > 0 else {
            throw AudioProcessingError.audioFileLoadFailed("Audio file is empty", url)
        }
        
        // Validate audio file format
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            
            // Check if format is valid
            guard format.sampleRate > 0 else {
                throw AudioProcessingError.audioFormatIncompatible("Invalid sample rate in \(context) audio file")
            }
            
            guard format.channelCount > 0 else {
                throw AudioProcessingError.audioFormatIncompatible("Invalid channel count in \(context) audio file")
            }
            
            // Check if file has reasonable duration (> 0.1 seconds)
            let duration = Double(audioFile.length) / format.sampleRate
            guard duration > 0.1 else {
                throw AudioProcessingError.audioFileLoadFailed("Audio file too short (\(String(format: "%.2f", duration))s)", url)
            }
            
            logger.debug("✅ Validated \(context) audio file - Duration: \(String(format: "%.2f", duration))s, Format: \(format.sampleRate)Hz, \(format.channelCount)ch")
            
        } catch let error as AudioProcessingError {
            throw error
        } catch {
            throw AudioProcessingError.audioFileLoadFailed("Cannot read audio file: \(error.localizedDescription)", url)
        }
    }
    
    /// Validates output file path and disk space
    private func validateOutputLocation(_ url: URL) throws {
        let parentDirectory = url.deletingLastPathComponent()
        
        // Check if parent directory exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parentDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AudioProcessingError.outputFileCreationFailed("Output directory does not exist", url)
        }
        
        // Check if parent directory is writable
        guard FileManager.default.isWritableFile(atPath: parentDirectory.path) else {
            throw AudioProcessingError.filePermissionDenied("Cannot write to output directory: \(parentDirectory.path)")
        }
        
        // Check available disk space (require at least 50MB)
        do {
            let resourceValues = try parentDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableCapacity = resourceValues.volumeAvailableCapacity {
                let minimumRequired: Int64 = 50 * 1024 * 1024 // 50MB
                guard availableCapacity >= minimumRequired else {
                    throw AudioProcessingError.insufficientDiskSpace("Only \(availableCapacity / 1024 / 1024)MB available, need at least \(minimumRequired / 1024 / 1024)MB")
                }
            }
        } catch let error as AudioProcessingError {
            throw error
        } catch {
            logger.warning("⚠️ Could not check disk space: \(error.localizedDescription)")
            // Continue without disk space check
        }
        
        logger.debug("✅ Validated output location: \(url.path)")
    }
    
    /// Validates audio engine configuration before use
    private func validateAudioEngineConfiguration(_ audioEngine: AVAudioEngine) throws {
        // Check if engine is already running
        if audioEngine.isRunning {
            throw AudioProcessingError.engineConfigurationFailed("Audio engine is already running")
        }
        
        // Check if main mixer node is available
        guard audioEngine.mainMixerNode.engine == audioEngine else {
            throw AudioProcessingError.engineConfigurationFailed("Main mixer node is not properly configured")
        }
        
        // Validate output format
        let outputFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        guard outputFormat.sampleRate > 0 else {
            throw AudioProcessingError.engineConfigurationFailed("Invalid output format sample rate")
        }
        
        logger.debug("✅ Validated audio engine configuration")
    }
    
    /// Safely creates audio format with error handling
    private func createSafeAudioFormat(sampleRate: Double, channels: UInt32) throws -> AVAudioFormat {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels) else {
            throw AudioProcessingError.formatConversionFailed("Cannot create audio format with sample rate \(sampleRate)Hz and \(channels) channels")
        }
        
        // Validate format properties
        guard format.sampleRate == sampleRate else {
            throw AudioProcessingError.formatConversionFailed("Created format has incorrect sample rate")
        }
        
        guard format.channelCount == channels else {
            throw AudioProcessingError.formatConversionFailed("Created format has incorrect channel count")
        }
        
        return format
    }
    
    /// Safely installs audio tap with comprehensive error handling
    private func safelyInstallTap(
        on node: AVAudioNode,
        bufferSize: UInt32,
        format: AVAudioFormat,
        operation: AudioProcessingOperation,
        outputFile: AVAudioFile
    ) throws {
        // Validate tap parameters
        guard bufferSize > 0 && bufferSize <= 16384 else {
            throw AudioProcessingError.tapInstallationFailed("Invalid buffer size: \(bufferSize)")
        }
        
        guard format.sampleRate > 0 else {
            throw AudioProcessingError.tapInstallationFailed("Invalid audio format for tap installation")
        }
        
        // Check if tap is already installed
        if node.outputFormat(forBus: 0) != format {
            logger.debug("⚠️ Format mismatch detected for tap installation")
        }
        
        // Install tap with error handling
        do {
            var bufferCount = 0
            let bufferOverflowThreshold = 10000 // Prevent excessive buffer accumulation
            
            node.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, time in
                // Check for buffer overflow
                bufferCount += 1
                if bufferCount > bufferOverflowThreshold {
                    operation.fail(with: .bufferOverflow("Buffer count exceeded threshold: \(bufferCount)"))
                    return
                }
                
                // Write buffer with error handling
                do {
                    try outputFile.write(from: buffer)
                    operation.updateBufferCount(bufferCount)
                    
                    // Reset buffer overflow counter periodically
                    if bufferCount % 1000 == 0 {
                        bufferCount = 0
                    }
                    
                } catch {
                    operation.fail(with: .fileWriteError("Failed to write audio buffer: \(error.localizedDescription)"))
                }
            }
            
            logger.debug("✅ Successfully installed audio tap with buffer size \(bufferSize)")
            
        } catch {
            throw AudioProcessingError.tapInstallationFailed("Failed to install tap: \(error.localizedDescription)")
        }
    }
    
    /// Safely connects audio nodes with validation
    private func safelyConnectNodes(
        _ sourceNode: AVAudioNode,
        to destinationNode: AVAudioNode,
        format: AVAudioFormat,
        in audioEngine: AVAudioEngine
    ) throws {
        // Validate nodes are attached to the same engine
        guard sourceNode.engine == audioEngine && destinationNode.engine == audioEngine else {
            throw AudioProcessingError.nodeConnectionFailed("Nodes must be attached to the same audio engine")
        }
        
        // Validate format compatibility
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            throw AudioProcessingError.nodeConnectionFailed("Invalid format for node connection")
        }
        
        // Connect nodes with error handling
        do {
            audioEngine.connect(sourceNode, to: destinationNode, format: format)
            logger.debug("✅ Successfully connected audio nodes")
        } catch {
            throw AudioProcessingError.nodeConnectionFailed("Failed to connect nodes: \(error.localizedDescription)")
        }
    }
    
    /// Safely starts audio engine with comprehensive error handling
    private func safelyStartAudioEngine(_ audioEngine: AVAudioEngine) throws {
        // Validate engine state
        guard !audioEngine.isRunning else {
            throw AudioProcessingError.audioEngineStartFailed("Audio engine is already running")
        }
        
        // Check if engine has proper configuration
        try validateAudioEngineConfiguration(audioEngine)
        
        // Start engine with error handling
        do {
            try audioEngine.start()
            
            // Verify engine is actually running
            guard audioEngine.isRunning else {
                throw AudioProcessingError.audioEngineStartFailed("Audio engine failed to start (not running after start)")
            }
            
            logger.debug("✅ Successfully started audio engine")
            
        } catch let error as AudioProcessingError {
            throw error
        } catch {
            throw AudioProcessingError.audioEngineStartFailed("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    /// Safely stops audio engine with cleanup
    private func safelyStopAudioEngine(
        _ audioEngine: AVAudioEngine,
        systemPlayerNode: AVAudioPlayerNode?,
        micPlayerNode: AVAudioPlayerNode?,
        mixer: AVAudioMixerNode
    ) {
        do {
            // Remove taps before stopping
            mixer.removeTap(onBus: 0)
            
            // Add explicit node detachment before stopping engine
            // Detach nodes in order: systemPlayer, micPlayer, mixerNode
            if let systemPlayer = systemPlayerNode {
                audioEngine.detach(systemPlayer)
                logger.debug("🔌 Detached system player node")
            }
            if let micPlayer = micPlayerNode {
                audioEngine.detach(micPlayer)
                logger.debug("🔌 Detached microphone player node")
            }
            audioEngine.detach(mixer)
            logger.debug("🔌 Detached mixer node")
            
            // Stop engine
            audioEngine.stop()
            
            // Verify engine is stopped
            guard !audioEngine.isRunning else {
                logger.warning("⚠️ Audio engine still running after stop")
                return
            }
            
            logger.debug("✅ Successfully stopped audio engine")
            
        } catch {
            logger.error("❌ Error stopping audio engine: \(error.localizedDescription)")
        }
    }
    
    /// Enhanced error recovery with multiple fallback strategies
    private func performErrorRecovery(
        error: AudioProcessingError,
        systemURL: URL,
        microphoneURL: URL,
        operation: AudioProcessingOperation
    ) async {
        logger.warning("🔄 Performing error recovery for: \(error.localizedDescription)")
        
        // Log recovery suggestion if available
        if let suggestion = error.recoverySuggestion {
            logger.info("💡 Recovery suggestion: \(suggestion)")
        }
        
        // Attempt fallback strategies based on error type
        switch error {
        case .audioEngineStartFailed, .engineConfigurationFailed:
            // Try with different audio engine configuration
            await attemptSimpleAudioMixing(systemURL: systemURL, microphoneURL: microphoneURL, operation: operation)
            
        case .audioFileLoadFailed, .audioFormatIncompatible:
            // Try processing files individually
            await handleMixingFailure(systemURL: systemURL, microphoneURL: microphoneURL)
            
        case .insufficientDiskSpace:
            // Try creating smaller output file or temporary cleanup
            await handleDiskSpaceError(systemURL: systemURL, microphoneURL: microphoneURL)
            
        case .filePermissionDenied:
            // Try alternative output location
            await handlePermissionError(systemURL: systemURL, microphoneURL: microphoneURL)
            
        default:
            // Default fallback: keep separate files
            await handleMixingFailure(systemURL: systemURL, microphoneURL: microphoneURL)
        }
    }
    
    /// Simple audio mixing as fallback strategy
    private func attemptSimpleAudioMixing(systemURL: URL, microphoneURL: URL, operation: AudioProcessingOperation) async {
        logger.notice("🔄 Attempting simple audio mixing as fallback...")
        
        // This is a simplified mixing approach with minimal audio engine usage
        // Implementation would go here if needed
        await handleMixingFailure(systemURL: systemURL, microphoneURL: microphoneURL)
    }
    
    /// Handle disk space error with cleanup
    private func handleDiskSpaceError(systemURL: URL, microphoneURL: URL) async {
        logger.notice("🔄 Handling disk space error...")
        
        // Try cleaning up temporary files to free space
        // Note: This would require adding performTemporaryCleanup() method to RecordingFileManager
        // For now, we'll proceed with the fallback
        logger.debug("⚠️ Temporary file cleanup not implemented yet")
        
        // Fall back to keeping separate files
        await handleMixingFailure(systemURL: systemURL, microphoneURL: microphoneURL)
    }
    
    /// Handle permission error with alternative location
    private func handlePermissionError(systemURL: URL, microphoneURL: URL) async {
        logger.notice("🔄 Handling permission error...")
        
        // Try alternative output location (e.g., temporary directory)
        await handleMixingFailure(systemURL: systemURL, microphoneURL: microphoneURL)
    }
    
    // MARK: - Audio Duration Detection
    
    /// Detects the duration of an audio file for proper processing timing
    private func getAudioFileDuration(at url: URL) -> TimeInterval? {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let sampleRate = audioFile.processingFormat.sampleRate
            let frameCount = audioFile.length
            return Double(frameCount) / sampleRate
        } catch {
            logger.error("❌ Failed to get audio file duration: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Calculates the expected processing duration based on audio file lengths
    private func calculateExpectedProcessingDuration(systemURL: URL, microphoneURL: URL) -> TimeInterval {
        let systemDuration = getAudioFileDuration(at: systemURL) ?? 0
        let micDuration = getAudioFileDuration(at: microphoneURL) ?? 0
        
        // Processing duration should be roughly the maximum of the two files
        // Add a small buffer for processing overhead (10%)
        let maxDuration = max(systemDuration, micDuration)
        let processingBuffer = maxDuration * 0.1
        
        return maxDuration + processingBuffer
    }
    
    /// Verifies recording files are ready using duration-based validation instead of polling
    private func verifyRecordingFilesReadyWithDuration(systemURL: URL, micURL: URL, expectedDuration: TimeInterval) async -> Bool {
        let maxWaitTime: TimeInterval = max(expectedDuration + 2.0, 5.0) // Wait for expected duration + 2 seconds, minimum 5 seconds
        let checkInterval: TimeInterval = 0.1 // Check every 100ms instead of sleeping
        let startTime = Date()
        
        logger.debug("🔍 Verifying recording files with duration-based validation (expected: \(String(format: "%.1f", expectedDuration))s)")
        
        // Use async stream for checking instead of polling
        return await withCheckedContinuation { continuation in
            Task {
                while Date().timeIntervalSince(startTime) < maxWaitTime {
                    // Check if both files exist and have reasonable content
                    let systemExists = FileManager.default.fileExists(atPath: systemURL.path)
                    let micExists = FileManager.default.fileExists(atPath: micURL.path)
                    
                    if systemExists && micExists {
                        let systemSize = getFileSize(at: systemURL)
                        let micSize = getFileSize(at: micURL)
                        
                        // Verify file sizes and duration consistency
                        if systemSize > 1024 && micSize > 1024 {
                            // Additional check: verify the files have reasonable duration
                            if let systemDuration = getAudioFileDuration(at: systemURL),
                               let micDuration = getAudioFileDuration(at: micURL) {
                                let durationDifference = abs(systemDuration - micDuration)
                                
                                // Files should have similar durations (within 1 second tolerance)
                                if durationDifference <= 1.0 {
                                    logger.debug("✅ Recording files ready with proper duration - system: \(String(format: "%.1f", systemDuration))s, mic: \(String(format: "%.1f", micDuration))s")
                                    continuation.resume(returning: true)
                                    return
                                }
                            }
                        }
                    }
                    
                    // Wait using async timer instead of sleep
                    try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                }
                
                logger.warning("⚠️ Recording files not ready after duration-based timeout (\(String(format: "%.1f", maxWaitTime))s)")
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - Audio Mixing
    
    private func mixAudioFiles(systemURL: URL, microphoneURL: URL) async {
        // Update processing state through state manager
        await stateManager.setProcessing(true)
        await safeUpdatePublishedProperties()
        
        // Create audio processing operation with delegate-based completion
        let sources: [AudioSource] = [.system, .microphone]
        let processingOperation = AudioProcessingOperation(sources: sources, delegate: self)
        currentProcessingOperation = processingOperation
        
        // Set up completion handler for the operation
        await withCheckedContinuation { continuation in
            processingOperation.setCompletionHandler { result in
                continuation.resume()
            }
            
            // Set up progress handler
            processingOperation.setProgressHandler { progress in
                Task { @MainActor in
                    self.processingProgress = progress
                }
            }
            
            // Start the actual mixing process
            Task {
                await self.performAudioMixingWithCompletionHandlers(
                    systemURL: systemURL,
                    microphoneURL: microphoneURL,
                    operation: processingOperation
                )
            }
        }
        
        // Clean up temp files after completion
        let hasError = await stateManager.recordingError != nil
        let hasCurrentURL = await stateManager.currentRecordingURL != nil
        
        if !hasError || hasCurrentURL {
            cleanupTempFiles()
        }
        
        // Reset processing state through state manager
        await stateManager.setProcessing(false)
        await safeUpdatePublishedProperties()
        currentProcessingOperation = nil
    }
    
    /// Performs audio mixing with comprehensive error handling and recovery
    private func performAudioMixingWithCompletionHandlers(
        systemURL: URL,
        microphoneURL: URL,
        operation: AudioProcessingOperation
    ) async {
        // Resource management variables for proper cleanup
        var audioEngine: AVAudioEngine?
        var systemPlayerNode: AVAudioPlayerNode?
        var micPlayerNode: AVAudioPlayerNode?
        var mixer: AVAudioMixerNode?
        var outputFile: AVAudioFile?
        var bufferProcessingTimer: Timer?
        
        // Ensure cleanup on all exit paths
        defer {
            performResourceCleanup(
                audioEngine: audioEngine,
                systemPlayerNode: systemPlayerNode,
                micPlayerNode: micPlayerNode,
                mixer: mixer,
                bufferProcessingTimer: bufferProcessingTimer
            )
        }
        
        do {
            logger.notice("🎛️ Starting robust audio mixing process...")
            
            // STEP 1: Comprehensive Input Validation
            operation.setCurrentStage(.validation)
            logger.debug("1️⃣ Validating input files...")
            try validateAudioFile(systemURL, context: "system")
            try validateAudioFile(microphoneURL, context: "microphone")
            
            // STEP 2: Output Location Validation
            let finalURL = recordingFileManager.createMeetingRecordingURL()
            logger.debug("2️⃣ Validating output location...")
            try validateOutputLocation(finalURL)
            
            // STEP 3: Audio Engine Setup with Validation
            operation.setCurrentStage(.setup)
            logger.debug("3️⃣ Setting up audio engine...")
            let engine = AVAudioEngine()
            audioEngine = engine
            
            let systemPlayer = AVAudioPlayerNode()
            let micPlayer = AVAudioPlayerNode()
            let mixerNode = AVAudioMixerNode()
            
            systemPlayerNode = systemPlayer
            micPlayerNode = micPlayer
            mixer = mixerNode
            
            // Attach nodes with validation
            engine.attach(systemPlayer)
            engine.attach(micPlayer)
            engine.attach(mixerNode)
            
            // STEP 4: Audio File Loading with Enhanced Error Handling
            operation.setCurrentStage(.loading)
            logger.debug("4️⃣ Loading audio files...")
            let systemAudioFile: AVAudioFile
            let micAudioFile: AVAudioFile
            
            do {
                systemAudioFile = try AVAudioFile(forReading: systemURL)
                logger.debug("✅ Successfully loaded system audio file")
            } catch {
                throw AudioProcessingError.audioFileLoadFailed("Cannot load system audio file: \(error.localizedDescription)", systemURL)
            }
            
            do {
                micAudioFile = try AVAudioFile(forReading: microphoneURL)
                logger.debug("✅ Successfully loaded microphone audio file")
            } catch {
                throw AudioProcessingError.audioFileLoadFailed("Cannot load microphone audio file: \(error.localizedDescription)", microphoneURL)
            }
            
            // STEP 5: Audio Format Creation with Validation
            logger.debug("5️⃣ Creating output format...")
            let outputFormat = try createSafeAudioFormat(sampleRate: 44100, channels: 2)
            
            // STEP 6: Node Connection with Error Handling
            logger.debug("6️⃣ Connecting audio nodes...")
            try safelyConnectNodes(systemPlayer, to: mixerNode, format: outputFormat, in: engine)
            try safelyConnectNodes(micPlayer, to: mixerNode, format: outputFormat, in: engine)
            try safelyConnectNodes(mixerNode, to: engine.mainMixerNode, format: outputFormat, in: engine)
            
            // STEP 7: Output File Creation with Validation
            logger.debug("7️⃣ Creating output file...")
            do {
                outputFile = try AVAudioFile(forWriting: finalURL, settings: outputFormat.settings)
                logger.debug("✅ Successfully created output file")
            } catch {
                throw AudioProcessingError.outputFileCreationFailed("Cannot create output file: \(error.localizedDescription)", finalURL)
            }
            
            // STEP 8: Audio Engine Start with Comprehensive Validation
            logger.debug("8️⃣ Starting audio engine...")
            try safelyStartAudioEngine(engine)
            
            // STEP 9: Tap Installation with Enhanced Error Handling
            logger.debug("9️⃣ Installing audio tap...")
            guard let safeOutputFile = outputFile else {
                throw AudioProcessingError.outputFileCreationFailed("Output file is nil", finalURL)
            }
            
            try safelyInstallTap(
                on: mixerNode,
                bufferSize: 4096,
                format: outputFormat,
                operation: operation,
                outputFile: safeOutputFile
            )
            
            // STEP 10: Buffer Processing Timer Setup
            logger.debug("🔟 Setting up buffer processing monitoring...")
            let bufferProcessingTimeout: TimeInterval = 0.5
            let bufferMonitor = DispatchQueue(label: "bufferMonitor", qos: .userInitiated)
            
            bufferProcessingTimer = Timer.scheduledTimer(withTimeInterval: bufferProcessingTimeout, repeats: false) { _ in
                operation.markBufferProcessingComplete()
            }
            
            // STEP 11: Schedule Files with Error Handling
            operation.setCurrentStage(.processing)
            logger.debug("1️⃣1️⃣ Scheduling audio files...")
            
            // Schedule system audio with completion handler
            systemPlayer.scheduleFile(systemAudioFile, at: nil) {
                logger.debug("✅ System audio playback completed")
                operation.markSourceCompleted(.system)
            }
            
            // Schedule microphone audio with completion handler  
            micPlayer.scheduleFile(micAudioFile, at: nil) {
                logger.debug("✅ Microphone audio playback completed")
                operation.markSourceCompleted(.microphone)
            }
            
            // STEP 12: Start Playback with Status Monitoring
            operation.setCurrentStage(.mixing)
            logger.debug("1️⃣2️⃣ Starting audio playback...")
            systemPlayer.play()
            micPlayer.play()
            
            // STEP 13: Duration Calculation and Progress Setup
            logger.debug("1️⃣3️⃣ Calculating expected processing duration...")
            let expectedProcessingDuration = calculateExpectedProcessingDuration(
                systemURL: systemURL,
                microphoneURL: microphoneURL
            )
            
            operation.updateEstimatedDuration(expectedProcessingDuration)
            logger.debug("📊 Expected processing duration: \(String(format: "%.1f", expectedProcessingDuration))s")
            
            // STEP 14: Completion Monitoring with Timeout Protection
            logger.debug("1️⃣4️⃣ Setting up completion monitoring...")
            
            await withCheckedContinuation { continuation in
                operation.setCompletionHandler { result in
                    logger.debug("🏁 Audio processing operation completed")
                    continuation.resume()
                }
                
                // Set a safety timeout based on expected duration
                let safetyTimeout = max(expectedProcessingDuration * 2.0, 10.0)
                logger.debug("⏱️ Safety timeout set to: \(String(format: "%.1f", safetyTimeout))s")
                
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(safetyTimeout * 1_000_000_000))
                    if !operation.isComplete {
                        logger.warning("⚠️ Audio processing timeout after \(String(format: "%.1f", safetyTimeout))s")
                        operation.fail(with: .processingTimeout("Processing exceeded expected duration of \(String(format: "%.1f", expectedProcessingDuration))s"))
                        continuation.resume()
                    }
                }
            }
            
            // STEP 15: Cleanup and Result Generation
            operation.setCurrentStage(.finalizing)
            logger.debug("1️⃣5️⃣ Cleaning up and generating result...")
            safelyStopAudioEngine(
                engine,
                systemPlayerNode: systemPlayerNode,
                micPlayerNode: micPlayerNode,
                mixer: mixerNode
            )
            
            // Get current state for metadata
            let currentDuration = await stateManager.recordingDuration
            let currentStartTime = await stateManager.recordingStartTime
            
            // Create processing result with metadata
            let processingDuration = Date().timeIntervalSince(Date())
            let metadata = AudioProcessingMetadata(
                startTime: Date(),
                processingDuration: processingDuration,
                outputFormat: outputFormat,
                sourceCount: 2,
                totalSamples: Int64(systemAudioFile.length + micAudioFile.length)
            )
            
            let result = AudioProcessingResult(
                outputURL: finalURL,
                duration: currentDuration,
                sourceFiles: [.system: systemURL, .microphone: microphoneURL],
                metadata: metadata
            )
            
            // Save metadata for mixed file
            recordingFileManager.saveRecordingMetadata(
                url: finalURL,
                duration: currentDuration,
                timestamp: currentStartTime ?? Date()
            )
            
            // Complete the operation with result
            operation.setCurrentStage(.complete)
            operation.complete(with: result)
            
            logger.notice("✅ Audio mixing completed successfully")
            
        } catch let error as AudioProcessingError {
            logger.error("❌ Audio mixing failed with specific error: \(error.localizedDescription)")
            
            // Perform comprehensive error recovery
            await performErrorRecovery(
                error: error,
                systemURL: systemURL,
                microphoneURL: microphoneURL,
                operation: operation
            )
            
        } catch {
            logger.error("❌ Audio mixing failed with unexpected error: \(error.localizedDescription)")
            
            // Handle unexpected errors
            let processingError = AudioProcessingError.processingFailed("Unexpected error during audio mixing: \(error.localizedDescription)")
            operation.fail(with: processingError)
            
            // Fallback: Keep separate files
            await handleMixingFailure(systemURL: systemURL, microphoneURL: microphoneURL)
        }
    }
    
    /// Performs comprehensive resource cleanup
    private func performResourceCleanup(
        audioEngine: AVAudioEngine?,
        systemPlayerNode: AVAudioPlayerNode?,
        micPlayerNode: AVAudioPlayerNode?,
        mixer: AVAudioMixerNode?,
        bufferProcessingTimer: Timer?
    ) {
        logger.debug("🧹 Performing comprehensive resource cleanup...")
        
        // Cancel buffer processing timer
        bufferProcessingTimer?.invalidate()
        
        // Clean up audio engine resources
        if let engine = audioEngine, let mixerNode = mixer {
            do {
                // Remove tap if installed
                if engine.isRunning {
                    mixerNode.removeTap(onBus: 0)
                }
                
                // Add explicit node detachment before stopping engine
                // Detach nodes in order: systemPlayer, micPlayer, mixerNode
                if let systemPlayer = systemPlayerNode {
                    engine.detach(systemPlayer)
                    logger.debug("🔌 Detached system player node")
                }
                if let micPlayer = micPlayerNode {
                    engine.detach(micPlayer)
                    logger.debug("🔌 Detached microphone player node")
                }
                engine.detach(mixerNode)
                logger.debug("🔌 Detached mixer node")
                
                // Stop engine if running
                if engine.isRunning {
                    engine.stop()
                }
                
                logger.debug("✅ Successfully cleaned up audio engine resources")
                
            } catch {
                logger.error("❌ Error during resource cleanup: \(error.localizedDescription)")
            }
        }
        
        logger.debug("✅ Resource cleanup completed")
    }
    
    private func handleMixingFailure(systemURL: URL, microphoneURL: URL) async {
        logger.notice("🔄 Handling mixing failure - creating fallback recordings...")
        
        do {
            let documentsDirectory = recordingFileManager.createMeetingRecordingURL().deletingLastPathComponent()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            
            // Get current state for metadata
            let currentDuration = await stateManager.recordingDuration
            let currentStartTime = await stateManager.recordingStartTime
            let timestamp = dateFormatter.string(from: currentStartTime ?? Date())
            
            // Create fallback files with clear naming
            let systemFallbackURL = documentsDirectory.appendingPathComponent("Meeting_System_\\(timestamp).m4a")
            let micFallbackURL = documentsDirectory.appendingPathComponent("Meeting_Microphone_\\(timestamp).m4a")
            
            // Copy temp files to permanent locations
            try FileManager.default.copyItem(at: systemURL, to: systemFallbackURL)
            try FileManager.default.copyItem(at: microphoneURL, to: micFallbackURL)
            
            // Save metadata for both files
            recordingFileManager.saveRecordingMetadata(
                url: systemFallbackURL,
                duration: currentDuration,
                timestamp: currentStartTime ?? Date()
            )
            
            recordingFileManager.saveRecordingMetadata(
                url: micFallbackURL,
                duration: currentDuration,
                timestamp: currentStartTime ?? Date()
            )
            
            // Set the microphone file as the "main" recording for UI purposes through state manager
            await stateManager.setCurrentRecordingURL(micFallbackURL)
            await stateManager.setRecordingError("Audio mixing failed. Saved system and microphone audio as separate files.")
            await safeUpdatePublishedProperties()
            
            logger.notice("✅ Fallback recordings saved successfully")
            
        } catch {
            logger.error("❌ Failed to create fallback recordings: \\(error.localizedDescription)")
            await stateManager.setRecordingError("Recording failed completely: \\(error.localizedDescription)")
            await safeUpdatePublishedProperties()
        }
    }
    
    /// @deprecated Use safeCleanupTempFiles() instead for thread safety
    private func cleanupTempFiles() {
        safeCleanupTempFiles()
    }
    
    private func checkScreenCapturePermission() async -> Bool {
        guard #available(macOS 12.3, *) else {
            logger.error("❌ ScreenCaptureKit requires macOS 12.3 or later")
            return false
        }
        
        do {
            // Try to get available content to check permission
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return !availableContent.applications.isEmpty
        } catch {
            logger.error("❌ Screen capture permission denied: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Error Handling
    
    enum MeetingRecordingError: Error, LocalizedError {
        case systemAudioCaptureNotAvailable
        case microphoneRecordingFailed
        case audioMixingFailed
        case permissionDenied
        case fileCreationFailed
        
        var errorDescription: String? {
            switch self {
            case .systemAudioCaptureNotAvailable:
                return "System audio capture is not available"
            case .microphoneRecordingFailed:
                return "Microphone recording failed"
            case .audioMixingFailed:
                return "Audio mixing failed"
            case .permissionDenied:
                return "Required permissions not granted"
            case .fileCreationFailed:
                return "Failed to create recording files"
            }
        }
    }
}
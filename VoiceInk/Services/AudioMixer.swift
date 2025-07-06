import Foundation
import AVFoundation
import os

class AudioMixer: ObservableObject {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AudioMixer")
    
    @Published var systemAudioLevel: Float = 0.0
    @Published var microphoneAudioLevel: Float = 0.0
    @Published var isMixing = false
    
    // Audio engine components
    private var audioEngine = AVAudioEngine()
    private var systemAudioNode = AVAudioMixerNode()
    private var microphoneAudioNode = AVAudioMixerNode()
    private var masterMixerNode = AVAudioMixerNode()
    
    // Audio format configuration
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    
    // Recording components
    private var audioFile: AVAudioFile?
    private var isRecording = false
    
    init() {
        setupAudioEngine()
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        // Attach mixer nodes to engine
        audioEngine.attach(systemAudioNode)
        audioEngine.attach(microphoneAudioNode)
        audioEngine.attach(masterMixerNode)
        
        // Connect system audio node to master mixer
        audioEngine.connect(systemAudioNode, to: masterMixerNode, format: audioFormat)
        
        // Connect microphone audio node to master mixer
        audioEngine.connect(microphoneAudioNode, to: masterMixerNode, format: audioFormat)
        
        // Connect master mixer to main output
        audioEngine.connect(masterMixerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        
        logger.info("✅ Audio mixer engine setup completed")
    }
    
    // MARK: - Mixing Control
    
    func startMixing(outputURL: URL) throws {
        logger.notice("🎛️ Starting audio mixing...")
        
        guard !isMixing else {
            logger.warning("⚠️ Audio mixing already in progress")
            return
        }
        
        // Create audio file for recording mixed output with error handling
        do {
            audioFile = try AVAudioFile(forWriting: outputURL, settings: audioFormat.settings)
            logger.debug("📁 Created audio file for mixing: \(outputURL.lastPathComponent)")
        } catch {
            logger.error("❌ Failed to create audio file for mixing: \(error.localizedDescription)")
            throw AudioMixerError.audioFileCreationFailed
        }
        
        // Install tap on master mixer to capture mixed audio
        masterMixerNode.installTap(onBus: 0, bufferSize: 4096, format: audioFormat) { [weak self] buffer, when in
            guard let self = self else { return }
            
            do {
                // Write mixed audio to file
                try self.audioFile?.write(from: buffer)
                
                // Update overall audio level monitoring
                Task { @MainActor in
                    self.updateMixedAudioLevel(from: buffer)
                }
            } catch {
                self.logger.error("❌ Error writing mixed audio: \(error.localizedDescription)")
            }
        }
        
        // Start the audio engine
        try audioEngine.start()
        
        isMixing = true
        isRecording = true
        
        logger.notice("✅ Audio mixing started successfully")
    }
    
    func stopMixing() {
        logger.notice("🛑 Stopping audio mixing...")
        
        guard isMixing else {
            logger.warning("⚠️ No audio mixing in progress")
            return
        }
        
        // Remove taps
        masterMixerNode.removeTap(onBus: 0)
        
        // Stop audio engine
        audioEngine.stop()
        
        // Explicitly close audio file with proper error handling
        if audioFile != nil {
            logger.debug("📁 Closing audio file...")
            audioFile = nil // AVAudioFile automatically closes when deallocated
            logger.debug("✅ Audio file closed successfully")
        }
        
        // Reset state
        isMixing = false
        isRecording = false
        systemAudioLevel = 0.0
        microphoneAudioLevel = 0.0
        
        logger.notice("✅ Audio mixing stopped successfully")
    }
    
    // MARK: - Audio Source Management
    
    func addSystemAudioSource(_ audioBuffer: AVAudioPCMBuffer) {
        guard isMixing else { return }
        
        // For now, we'll handle audio mixing in a different way
        // AudioMixerNode doesn't have scheduleBuffer - we'll use the input directly
        
        // Update system audio level
        Task { @MainActor in
            updateSystemAudioLevel(from: audioBuffer)
        }
    }
    
    func addMicrophoneAudioSource(_ audioBuffer: AVAudioPCMBuffer) {
        guard isMixing else { return }
        
        // For now, we'll handle audio mixing in a different way
        // AudioMixerNode doesn't have scheduleBuffer - we'll use the input directly
        
        // Update microphone audio level
        Task { @MainActor in
            updateMicrophoneAudioLevel(from: audioBuffer)
        }
    }
    
    // MARK: - Audio Level Monitoring
    
    private func updateSystemAudioLevel(from buffer: AVAudioPCMBuffer) {
        systemAudioLevel = calculateAudioLevel(from: buffer)
    }
    
    private func updateMicrophoneAudioLevel(from buffer: AVAudioPCMBuffer) {
        microphoneAudioLevel = calculateAudioLevel(from: buffer)
    }
    
    private func updateMixedAudioLevel(from buffer: AVAudioPCMBuffer) {
        // This could be used for overall recording level indication
        let mixedLevel = calculateAudioLevel(from: buffer)
        logger.debug("📊 Mixed audio level: \(mixedLevel)")
    }
    
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0.0 }
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        
        // Convert to dB and normalize (similar to existing Recorder logic)
        let dB = 20 * log10(average + 1e-10)
        let minVisibleDb: Float = -60.0
        let maxVisibleDb: Float = 0.0
        
        let normalizedLevel: Float
        if dB < minVisibleDb {
            normalizedLevel = 0.0
        } else if dB >= maxVisibleDb {
            normalizedLevel = 1.0
        } else {
            normalizedLevel = (dB - minVisibleDb) / (maxVisibleDb - minVisibleDb)
        }
        
        return normalizedLevel
    }
    
    // MARK: - Volume Control
    
    func setSystemAudioVolume(_ volume: Float) {
        systemAudioNode.outputVolume = max(0.0, min(1.0, volume))
        logger.debug("🔊 System audio volume set to: \(volume)")
    }
    
    func setMicrophoneAudioVolume(_ volume: Float) {
        microphoneAudioNode.outputVolume = max(0.0, min(1.0, volume))
        logger.debug("🎤 Microphone audio volume set to: \(volume)")
    }
    
    func setMasterVolume(_ volume: Float) {
        masterMixerNode.outputVolume = max(0.0, min(1.0, volume))
        logger.debug("🎛️ Master volume set to: \(volume)")
    }
    
    // MARK: - Audio Format Configuration
    
    func getAudioFormat() -> AVAudioFormat {
        return audioFormat
    }
    
    func configureAudioFormat(sampleRate: Double, channels: UInt32) -> AVAudioFormat? {
        return AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)
    }
    
    // MARK: - Error Handling
    
    enum AudioMixerError: Error, LocalizedError {
        case engineStartFailed
        case audioFileCreationFailed
        case invalidAudioFormat
        case mixingInProgress
        
        var errorDescription: String? {
            switch self {
            case .engineStartFailed:
                return "Failed to start audio engine"
            case .audioFileCreationFailed:
                return "Failed to create audio file"
            case .invalidAudioFormat:
                return "Invalid audio format"
            case .mixingInProgress:
                return "Audio mixing already in progress"
            }
        }
    }
}
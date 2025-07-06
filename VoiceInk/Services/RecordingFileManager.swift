import Foundation
import os

class RecordingFileManager: ObservableObject {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "RecordingFileManager")
    
    @Published var availableRecordings: [MeetingRecording] = []
    
    // Directory paths
    private let documentsDirectory: URL
    private let meetingRecordingsDirectory: URL
    
    init() {
        // Create meeting recordings directory in user's Documents folder
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        meetingRecordingsDirectory = documentsDirectory
            .appendingPathComponent("VoiceInk")
            .appendingPathComponent("Recordings")
        
        createDirectoriesIfNeeded()
        loadAvailableRecordings()
    }
    
    // MARK: - Directory Management
    
    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: meetingRecordingsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.info("✅ Meeting recordings directory created/verified at: \(self.meetingRecordingsDirectory.path)")
        } catch {
            logger.error("❌ Failed to create meeting recordings directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Creation
    
    func createMeetingRecordingURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let fileName = "Meeting_\(timestamp).m4a"
        let recordingURL = meetingRecordingsDirectory.appendingPathComponent(fileName)
        
        logger.info("📁 Created meeting recording URL: \(recordingURL.lastPathComponent)")
        return recordingURL
    }
    
    func createTemporaryRecordingURL() -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "temp_meeting_\(UUID().uuidString).m4a"
        return tempDirectory.appendingPathComponent(fileName)
    }
    
    // MARK: - Recording Metadata
    
    func saveRecordingMetadata(url: URL, duration: TimeInterval, timestamp: Date) {
        let recording = MeetingRecording(
            id: UUID(),
            url: url,
            fileName: url.lastPathComponent,
            duration: duration,
            timestamp: timestamp,
            fileSize: getFileSize(at: url)
        )
        
        // Save metadata to JSON file alongside recording
        saveRecordingMetadataToFile(recording)
        
        // Update in-memory list
        availableRecordings.append(recording)
        availableRecordings.sort { $0.timestamp > $1.timestamp }
        
        logger.info("💾 Saved recording metadata for: \(recording.fileName)")
    }
    
    private func saveRecordingMetadataToFile(_ recording: MeetingRecording) {
        let metadataURL = recording.url.appendingPathExtension("json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(recording)
            
            // Use atomic write to prevent corruption and ensure proper file handle closure
            try data.write(to: metadataURL, options: .atomic)
            logger.debug("📁 Metadata file written atomically: \(metadataURL.lastPathComponent)")
        } catch {
            logger.error("❌ Failed to save recording metadata: \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Management
    
    func loadAvailableRecordings() {
        logger.info("📂 Loading available meeting recordings...")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: meetingRecordingsDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            let audioFiles = fileURLs.filter { url in
                let pathExtension = url.pathExtension.lowercased()
                return pathExtension == "m4a" || pathExtension == "wav" || pathExtension == "mp3"
            }
            
            var recordings: [MeetingRecording] = []
            
            for audioURL in audioFiles {
                let metadataURL = audioURL.appendingPathExtension("json")
                
                if FileManager.default.fileExists(atPath: metadataURL.path) {
                    // Load from metadata file
                    if let recording = loadRecordingFromMetadata(metadataURL) {
                        recordings.append(recording)
                    }
                } else {
                    // Create recording from file attributes
                    let recording = createRecordingFromFile(audioURL)
                    recordings.append(recording)
                }
            }
            
            availableRecordings = recordings.sorted { $0.timestamp > $1.timestamp }
            logger.info("📊 Loaded \(self.availableRecordings.count) meeting recordings")
            
        } catch {
            logger.error("❌ Failed to load available recordings: \(error.localizedDescription)")
        }
    }
    
    private func loadRecordingFromMetadata(_ metadataURL: URL) -> MeetingRecording? {
        do {
            // Use coordinated read for better file handle management
            var coordinatedError: NSError?
            var result: MeetingRecording?
            
            NSFileCoordinator().coordinate(readingItemAt: metadataURL, options: [], error: &coordinatedError) { (url) in
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    let recording = try decoder.decode(MeetingRecording.self, from: data)
                    
                    // Verify the audio file still exists
                    if FileManager.default.fileExists(atPath: recording.url.path) {
                        result = recording
                    } else {
                        logger.warning("⚠️ Audio file missing for metadata: \(metadataURL.lastPathComponent)")
                        // Clean up orphaned metadata file
                        try? FileManager.default.removeItem(at: metadataURL)
                        result = nil
                    }
                } catch {
                    logger.error("❌ Failed to load recording metadata from \(metadataURL.lastPathComponent): \(error.localizedDescription)")
                    result = nil
                }
            }
            
            if let coordinatedError = coordinatedError {
                logger.error("❌ File coordination error: \(coordinatedError.localizedDescription)")
                return nil
            }
            
            return result
        } catch {
            logger.error("❌ Failed to load recording metadata from \(metadataURL.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func createRecordingFromFile(_ fileURL: URL) -> MeetingRecording {
        let fileName = fileURL.lastPathComponent
        let fileSize = getFileSize(at: fileURL)
        
        // Try to get creation date from file attributes
        let timestamp: Date
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            timestamp = attributes[.creationDate] as? Date ?? Date()
        } catch {
            timestamp = Date()
        }
        
        return MeetingRecording(
            id: UUID(),
            url: fileURL,
            fileName: fileName,
            duration: 0, // Would need audio processing to determine actual duration
            timestamp: timestamp,
            fileSize: fileSize
        )
    }
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            logger.error("❌ Failed to get file size for \(url.lastPathComponent): \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - File Operations
    
    func deleteRecording(_ recording: MeetingRecording) {
        logger.info("🗑️ Deleting recording: \(recording.fileName)")
        
        do {
            // Delete audio file
            try FileManager.default.removeItem(at: recording.url)
            
            // Delete metadata file if it exists
            let metadataURL = recording.url.appendingPathExtension("json")
            if FileManager.default.fileExists(atPath: metadataURL.path) {
                try FileManager.default.removeItem(at: metadataURL)
            }
            
            // Remove from in-memory list
            availableRecordings.removeAll { $0.id == recording.id }
            
            logger.info("✅ Successfully deleted recording: \(recording.fileName)")
            
        } catch {
            logger.error("❌ Failed to delete recording \(recording.fileName): \(error.localizedDescription)")
        }
    }
    
    func renameRecording(_ recording: MeetingRecording, to newName: String) {
        logger.info("✏️ Renaming recording from \(recording.fileName) to \(newName)")
        
        let newURL = recording.url.deletingLastPathComponent().appendingPathComponent(newName)
        
        do {
            // Rename audio file
            try FileManager.default.moveItem(at: recording.url, to: newURL)
            
            // Rename metadata file if it exists
            let oldMetadataURL = recording.url.appendingPathExtension("json")
            let newMetadataURL = newURL.appendingPathExtension("json")
            
            if FileManager.default.fileExists(atPath: oldMetadataURL.path) {
                try FileManager.default.moveItem(at: oldMetadataURL, to: newMetadataURL)
                
                // Update metadata with new URL
                if var updatedRecording = loadRecordingFromMetadata(newMetadataURL) {
                    updatedRecording.url = newURL
                    updatedRecording.fileName = newName
                    saveRecordingMetadataToFile(updatedRecording)
                }
            }
            
            // Update in-memory list
            if let index = availableRecordings.firstIndex(where: { $0.id == recording.id }) {
                availableRecordings[index].url = newURL
                availableRecordings[index].fileName = newName
            }
            
            logger.info("✅ Successfully renamed recording to: \(newName)")
            
        } catch {
            logger.error("❌ Failed to rename recording: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupOldRecordings(olderThan days: Int) {
        logger.info("🧹 Cleaning up recordings older than \(days) days...")
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recordingsToDelete = availableRecordings.filter { $0.timestamp < cutoffDate }
        
        for recording in recordingsToDelete {
            deleteRecording(recording)
        }
        
        logger.info("✅ Cleaned up \(recordingsToDelete.count) old recordings")
    }
    
    func getTotalStorageUsed() -> Int64 {
        return availableRecordings.reduce(0) { total, recording in
            total + recording.fileSize
        }
    }
    
    func getFormattedStorageUsed() -> String {
        let bytes = getTotalStorageUsed()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - MeetingRecording Model

struct MeetingRecording: Identifiable, Codable {
    let id: UUID
    var url: URL
    var fileName: String
    let duration: TimeInterval
    let timestamp: Date
    let fileSize: Int64
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
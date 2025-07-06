import SwiftUI
import SwiftData

struct MeetingRecordingView: View {
    @EnvironmentObject private var whisperState: WhisperState
    @State private var showingRecordingsList = false
    @State private var showingPermissionAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.accentColor)
                    
                    Text("Meeting Recording")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Record system audio and microphone for meetings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Recording Control Section
                VStack(spacing: 16) {
                    // Main Recording Button
                    Button(action: {
                        Task {
                            await whisperState.toggleMeetingRecording()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: whisperState.isMeetingRecording ? "stop.circle.fill" : "record.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text(whisperState.isMeetingRecording ? "Stop Recording" : "Start Meeting Recording")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(whisperState.isMeetingRecording ? Color.red : Color.accentColor)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(whisperState.isRecording || whisperState.isMeetingRecordingProcessing) // Prevent conflicts
                    
                    // Recording Status
                    if whisperState.isMeetingRecording {
                        VStack(spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .opacity(0.8)
                                
                                Text("Recording in progress...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let manager = whisperState.meetingRecordingManager {
                                Text(formatDuration(manager.recordingDuration))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                    
                    // Processing Status
                    if whisperState.isMeetingRecordingProcessing {
                        VStack(spacing: 8) {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                
                                Text("Processing audio...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Mixing system and microphone audio")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    
                    // Error Message
                    if let error = whisperState.meetingRecordingError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
                .padding(.horizontal, 32)
                
                Divider()
                    .padding(.horizontal, 32)
                
                // Information Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("How It Works")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            icon: "speaker.wave.2",
                            title: "System Audio",
                            description: "Captures audio from meetings, calls, and applications"
                        )
                        
                        InfoRow(
                            icon: "mic",
                            title: "Microphone",
                            description: "Records your voice and comments during meetings"
                        )
                        
                        InfoRow(
                            icon: "folder",
                            title: "Auto-Save",
                            description: "Recordings saved to ~/Documents/VoiceInk/Recordings/"
                        )
                        
                        InfoRow(
                            icon: "shield",
                            title: "Privacy First",
                            description: "All processing happens locally on your device"
                        )
                    }
                }
                .padding(.horizontal, 32)
                
                Divider()
                    .padding(.horizontal, 32)
                
                // Quick Actions
                VStack(spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            showingRecordingsList = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                
                                Text("View Recordings")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            if let recordingsURL = getRecordingsDirectory() {
                                NSWorkspace.shared.open(recordingsURL)
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "externaldrive")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                
                                Text("Open Folder")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            showingPermissionAlert = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "gear")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                
                                Text("Permissions")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer(minLength: 32)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .sheet(isPresented: $showingRecordingsList) {
            RecordingsListView()
        }
        .alert("Screen Recording Permission", isPresented: $showingPermissionAlert) {
            Button("Open System Preferences") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("VoiceInk needs Screen Recording permission to capture system audio from meetings. Please enable it in System Preferences > Privacy & Security > Screen Recording.")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func getRecordingsDirectory() -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory
            .appendingPathComponent("VoiceInk")
            .appendingPathComponent("Recordings")
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct RecordingsListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fileManager = RecordingFileManager()
    
    var body: some View {
        NavigationView {
            VStack {
                if fileManager.availableRecordings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Recordings Yet")
                            .font(.headline)
                        
                        Text("Start your first meeting recording to see it here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(fileManager.availableRecordings) { recording in
                        RecordingRowView(recording: recording, fileManager: fileManager)
                    }
                }
            }
            .navigationTitle("Meeting Recordings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct RecordingRowView: View {
    let recording: MeetingRecording
    let fileManager: RecordingFileManager
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.fileName)
                    .font(.headline)
                
                Text(recording.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(recording.formattedDuration)
                    Text("•")
                    Text(recording.formattedFileSize)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    NSWorkspace.shared.open(recording.url)
                }) {
                    Image(systemName: "play.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .alert("Delete Recording", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                fileManager.deleteRecording(recording)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(recording.fileName)'? This action cannot be undone.")
        }
    }
}

#Preview {
    MeetingRecordingView()
        .environmentObject(WhisperState(modelContext: ModelContext(try! ModelContainer(for: Transcription.self))))
}
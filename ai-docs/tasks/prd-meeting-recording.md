# Product Requirements Document: Meeting Recording Feature (V1)

## 1. Introduction/Overview

VoiceInk will introduce a Meeting Recording feature that enables users to capture complete conversations from video/audio calls by simultaneously recording system audio (remote participants) and microphone audio (user's voice) in separate channels. This feature addresses the critical gap where users can currently transcribe their own voice but lose the other half of conversations, providing a seamless path from recording to high-quality, speaker-separated transcription.

**Problem Statement:** Remote professionals frequently need to reference decisions, action items, and key discussion points from meetings, but current solutions are either video-focused (screen recording), cumbersome to use, or produce poor-quality audio that results in inaccurate transcriptions and speaker identification.

**Solution:** A reliable meeting recording system that captures pristine, channel-separated audio optimized specifically for VoiceInk's transcription engine, enabling superior "mechanical split diarization" and searchable meeting transcripts.

**V1 Scope:** This PRD defines the minimal viable version focused on the core recording-to-transcription workflow, with robust error handling and a foundation for future enhancements.

## 2. Goals

### V1 Core Goals
1. **Reliable Core Workflow:** Enable users to successfully record meetings and transcribe with speaker separation 95%+ of the time
2. **Mechanical Diarization:** Deliver channel-separated audio that enables perfect "You vs. Remote" speaker identification  
3. **Privacy-First Implementation:** Maintain 100% local processing with clear recording indicators and user consent
4. **Architectural Foundation:** Build modular, extensible architecture that supports future enhancements without major refactoring

### Success Criteria for V1
- 30% of MAU try the recording feature within 3 months
- 70% of users who record attempt transcription within 24 hours  
- 95% session success rate (recording completes without errors)
- User satisfaction 4+ stars for recording quality

## 3. User Stories

### Primary User: Remote Professional

**User Story 1 - Quick Meeting Capture**
As a remote professional, I want to quickly start recording my Zoom call so that I can focus on the conversation without worrying about taking notes.

**User Story 2 - Instant Transcription**
As a team lead, I want to immediately transcribe my recorded meeting so that I can extract action items and share key decisions with my team within minutes of the call ending.

**User Story 3 - Speaker Identification**
As a project manager, I want to clearly see who said what in my meeting transcript so that I can accurately attribute decisions and follow up with the right people.

**User Story 4 - Privacy Assurance**
As a professional handling sensitive information, I want to be certain that my meeting recordings are processed entirely on my device and never leave my control.

### Secondary Users

**User Story 5 - Student Use Case**
As a student, I want to record my online lectures and study sessions so that I can review complex topics and have accurate notes for studying.

**User Story 6 - Content Creator**
As a podcaster, I want to record remote interviews with separate audio tracks so that I have clean audio for both speakers during editing.

## 4. Functional Requirements

### V1 Core Requirements (Must-Have)

#### 4.1 Recording Initiation & Control
1. **Menu Bar Access:** Provide a menu bar icon for global access to recording functionality
2. **Application Selection:** Present ScreenCaptureKit application picker for every recording session (V1 simplification)
3. **Permission Management:** Require explicit user permission for microphone access and screen recording (audio capture)
4. **Recording Indicator:** Display persistent, unmistakable visual indicator in menu bar during active recording (red icon with timer)
5. **Stop Control:** Provide one-click stop recording button accessible from the menu bar
6. **Session Protection:** Prevent multiple simultaneous recording sessions

#### 4.2 Audio Capture
7. **Application-Specific Capture:** Capture audio from user-selected application using ScreenCaptureKit
8. **Microphone Capture:** Simultaneously capture microphone audio using AVAudioEngine  
9. **Stereo Recording:** Record both sources to single stereo file (Left=System Audio, Right=Microphone)
10. **Audio Format:** Use AAC format (.m4a) with 48kHz sample rate and VBR 128-192 kbps
11. **Audio Exclusion:** Exclude VoiceInk's own audio from system capture (ScreenCaptureKit `excludesCurrentProcessAudio = true`)

#### 4.3 Post-Recording Processing
12. **In-Memory Channel Processing:** Read each channel from stereo file into separate AVAudioPCMBuffer objects (no intermediate files)
13. **Sequential Transcription:** Transcribe left channel (system) and right channel (microphone) separately using whisper.cpp
14. **Transcript Merging:** Merge timestamped transcripts chronologically based on segment start times
15. **Speaker Labeling:** Label speakers as "You" (microphone) and "Remote" (system audio)

#### 4.4 Data Management
16. **SQLite Storage:** Store recording metadata in SQLite database using GRDB.swift (replaces JSON sidecar files)
17. **File Organization:** Save recordings to Documents/VoiceInk/Recordings/ with "Meeting_YYYY-MM-DD_HH-MM-SS.m4a" naming
18. **Atomic Operations:** Ensure atomic file writes to prevent corruption
19. **Processing States:** Track recording status (recorded, processing, completed, failed) in database

#### 4.5 User Interface
20. **Recording List:** Display recordings in main VoiceInk interface with current processing status
21. **Transcription Trigger:** Provide "Transcribe" button for each completed recording
22. **Simple Progress:** Show basic "Processing..." state during transcription (detailed progress deferred to V2)
23. **Error Handling:** Provide clear error states and retry options for failed processing

#### 4.6 Privacy & Safety
24. **Local Processing:** All recording and transcription occurs entirely on-device
25. **Privacy Notice:** Display notice explaining only audio is captured, not screen video
26. **Headphone Recommendation:** Provide guidance recommending headphone use to prevent audio bleed
27. **User Control:** Allow easy deletion of recordings and transcripts

### V1 Deferred to V2+ (Future Enhancement)
- Remember last-used application (always show picker for V1 simplicity)
- Global keyboard shortcuts (high-value polish for V2)
- Background processing persistence (V1 = "online" processing only)
- Detailed progress stages (V1 = simple spinner)
- Speaker label editing (nice-to-have enhancement)
- Automatic transcription (V1 = manual trigger only)

## 5. Non-Goals (Out of Scope)

1. **Video Recording:** This feature will not capture video content - audio only
2. **Cloud Processing:** No cloud-based transcription or storage options
3. **Real-time Transcription:** Transcription occurs post-recording only, not during the call
4. **Advanced Audio Editing:** No built-in audio editing capabilities beyond basic channel separation
5. **Recording Sharing:** No direct sharing or export features beyond standard file system access
6. **Multi-participant Diarization:** Beyond basic "You vs. Remote" labeling - no individual speaker identification within the remote channel
7. **Call Integration:** No direct integration with Zoom/Teams APIs - captures system audio output only
8. **Background Recording:** No always-on or automated recording triggers

## 6. Design Considerations

### 6.1 User Experience Flow
- **First-Time Setup:** Clear onboarding explaining permissions and recommending headphone use
- **Quick Access:** Menu bar icon provides instant access without opening the main app
- **Visual Feedback:** Impossible-to-miss recording indicators for ethical recording practices
- **Error Prevention:** Clear guidance to prevent common issues (no headphones, multiple audio apps)

### 6.2 Technical Architecture
- **Native Implementation:** Use ScreenCaptureKit + AVFoundation exclusively (no external dependencies)
- **Performance:** Ensure recording doesn't impact system performance during resource-intensive video calls
- **Reliability:** Robust error handling for audio format changes, device switching, and app termination

### 6.3 Privacy by Design
- **Minimal Permissions:** Request only essential permissions with clear explanations
- **Local Processing:** All audio processing and transcription occurs on-device
- **User Control:** Easy access to recordings and deletion options
- **Transparency:** Clear indicators when recording is active

## 7. Technical Considerations

### 7.1 V1 Architecture Decisions
- **Platform:** Requires macOS 14.0+ for optimal ScreenCaptureKit support
- **Storage:** SQLite via GRDB.swift for robust metadata management and future extensibility
- **Audio Processing:** Native AVFoundation in-memory channel separation (no intermediate files)
- **Frameworks:** ScreenCaptureKit, AVFoundation, whisper.cpp (existing), GRDB.swift

### 7.2 Critical Edge Cases for V1
- **Permission Revocation:** Gracefully stop recording and save partial audio if permissions are revoked mid-session
- **Device Changes:** If audio device changes during recording, stop recording with clear error message
- **App Termination:** If user quits VoiceInk during processing, abandon transcription (state not persisted in V1)
- **Disk Space:** Handle storage full scenarios with atomic writes and clear error messages

### 7.3 Audio Quality & Performance
- **Cross-talk Handling:** Provide strong guidance for headphone use; accept some audio bleed as V1 limitation
- **Memory Usage:** Process channels sequentially to minimize peak memory usage during transcription
- **Accuracy Trade-off:** Accept slight whisper.cpp accuracy reduction from channel splitting in exchange for perfect diarization

### 7.4 Future-Proofing Decisions
- **Modular Architecture:** Separate recording, processing, and storage concerns for easy V2 enhancement
- **Database Schema:** Design SQLite schema with versioning to support future metadata expansion
- **Interface Abstraction:** Abstract audio processing interface to support future transcription engines

## 8. Success Metrics

### 8.1 Adoption Metrics
- **Feature Adoption Rate:** Target 30% of Monthly Active Users trying the recording feature within 3 months of launch
- **Recording Frequency:** Target average of 2+ recordings per user per week among adopters
- **Retention:** 70% of users who record a meeting attempt transcription within 24 hours

### 8.2 Quality Metrics
- **Session Success Rate:** 95%+ of recording sessions complete without errors or crashes
- **Transcription Accuracy:** Maintain or improve current transcription accuracy rates with channel-separated audio
- **User Satisfaction:** Post-transcription rating of 4+ stars on 5-star scale for recording quality

### 8.3 Technical Performance
- **Processing Time:** Complete audio processing (split + transcribe + merge) within 2x the recording duration
- **Error Recovery:** 90%+ of failed processing jobs successfully retry and complete
- **Resource Usage:** Recording adds <10% CPU overhead during active video calls

### 8.4 Business Impact
- **Transcription Volume:** 50%+ increase in total transcription minutes processed
- **Support Reduction:** 25% reduction in support tickets related to transcription quality from external sources
- **User Engagement:** Increased session duration and feature usage within VoiceInk

## 8. V1 Implementation Plan

### Phase 1: Core Recording (Week 1-2)
1. **Audio Capture Setup:** Implement ScreenCaptureKit + AVAudioEngine recording to stereo file
2. **Menu Bar Interface:** Basic record/stop controls with visual indicator
3. **SQLite Integration:** Set up GRDB.swift with recording metadata schema
4. **Permission Handling:** Implement permission requests and validation

### Phase 2: Processing Pipeline (Week 3-4)  
1. **Channel Separation:** Implement in-memory AVFoundation channel processing
2. **Transcription Integration:** Adapt existing whisper.cpp wrapper for channel-specific processing
3. **Transcript Merging:** Implement chronological merge with speaker labeling
4. **Error Handling:** Add robust error states and recovery options

### Phase 3: UI Integration (Week 5-6)
1. **Recording List:** Display recordings in main interface with status
2. **Transcription Trigger:** Add "Transcribe" button and processing feedback
3. **File Management:** Implement deletion and basic file operations
4. **Polish & Testing:** Edge case handling and user testing

## 9. Open Questions for V2+ Planning

### Future Enhancement Considerations
1. **Background Processing:** How should long transcriptions behave when app is closed?
2. **Advanced UI:** What detailed progress indicators would be most valuable?
3. **Workflow Integration:** Should we auto-suggest transcription after recording?
4. **Storage Management:** What automatic cleanup policies make sense?
5. **Multi-Speaker Diarization:** Is it feasible to identify individual speakers within "Remote" channel?

### User Feedback Targets
- How often do users want to edit speaker labels?
- What's the optimal balance between transcription speed and accuracy?
- Do users prefer automatic or manual transcription triggers?
- What additional metadata would be valuable (meeting title, participants, etc.)?

---

## V1 Success Definition

**Ready to Ship When:**
- Core recording workflow succeeds 95%+ of the time
- Clear error messages for all failure scenarios  
- Transcription quality meets or exceeds single-channel recordings
- Privacy and safety requirements fully implemented
- No data loss scenarios (partial recordings always preserved)

**V1 provides a solid foundation** that delivers core value while establishing the architectural patterns needed for rapid V2/V3 iteration based on real user feedback.
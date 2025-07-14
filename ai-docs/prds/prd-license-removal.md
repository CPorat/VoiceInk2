# Product Requirements Document: License Removal

## Introduction/Overview

This feature removes all licensing requirements from VoiceInk to convert it from a trial/paid model to a completely free tool. The goal is to eliminate the Polar.sh-based licensing system, trial period restrictions, and all associated UI elements while maintaining full application functionality for all users.

## Goals

1. **Complete License System Removal**: Eliminate all licensing, trial, and payment logic from the codebase
2. **Zero Functionality Loss**: Ensure all transcription and AI features remain fully accessible 
3. **Clean Codebase**: Remove all license-related code, UI elements, and dependencies
4. **Smooth User Transition**: Existing users experience seamless transition with no data loss
5. **Professional Implementation**: Maintain code quality with proper cleanup and no orphaned artifacts

## User Stories

1. **As a new user**, I want to access all VoiceInk features immediately without trial limitations or license requirements
2. **As an existing trial user**, I want my app to continue working normally without license prompts or restrictions
3. **As an existing licensed user**, I want to continue using the app without any licensing UI or management screens
4. **As a developer**, I want a clean codebase free of licensing infrastructure for future development

## Functional Requirements

### Core License Removal
1. The system must remove all license validation and API calls to Polar.sh
2. The system must remove trial period tracking and expiration logic
3. The system must eliminate all functionality blocking based on license status
4. The system must remove device activation and license key management

### UI Cleanup  
5. The system must remove the "VoiceInk Pro" sidebar navigation item
6. The system must remove the "PRO" badge from the app header
7. The system must remove all trial warning messages and license prompts
8. The system must delete license management and activation screens

### Data Management
9. The system must clean up legacy UserDefaults keys related to licensing
10. The system must preserve all user transcription data and preferences (non-license related)
11. The system must perform one-time migration to remove license artifacts

### Code Quality
12. The system must remove all license-related files and dependencies
13. The system must ensure no compiler errors or broken references remain
14. The system must maintain existing app architecture and functionality

## Non-Goals (Out of Scope)

- Adding new features or functionality 
- Changing core transcription or AI capabilities
- Modifying data storage or SwiftData schemas
- Updating app branding or visual design (beyond license removal)
- Implementing analytics or usage tracking
- Creating new user onboarding flows

## Technical Considerations

### Architecture Impact
- **LicenseViewModel**: Will be completely removed after being neutered
- **PolarService**: Direct deletion as it only handles license API calls
- **WhisperState**: Remove license dependency while preserving core functionality
- **ContentView**: Update navigation and remove license-related UI elements

### Dependencies
- Remove Polar.sh SDK if installed via Swift Package Manager
- No changes required to SwiftData, Whisper, or AI service dependencies

### Data Migration
- Clean up UserDefaults keys: `VoiceInkActivationId`, `VoiceInkLicenseRequiresActivation`, `VoiceInkHasLaunchedBefore`, `trialStartDate`, `VoiceInkDeviceIdentifier`
- Preserve all user preferences and transcription history

## Success Metrics

### Functional Success
- App launches successfully without license checks
- All transcription features work immediately upon first launch
- No license-related error messages or UI elements appear
- Existing user workflows remain unchanged (except license management)

### Code Quality Success  
- Zero compiler warnings or errors related to licensing
- Complete removal of license-related files and code
- Clean project structure with no orphaned license artifacts
- Successful app build and distribution

### User Experience Success
- Seamless transition for existing users with no data loss
- New users can immediately access all features
- No broken navigation or missing functionality
- Professional, clean interface without license remnants

## Open Questions

1. **Package Dependencies**: Should we verify and document any Polar.sh dependencies to remove from package manager?
2. **App Store Metadata**: Will app store description and metadata need updates to reflect the free model?
3. **Version Numbering**: Should this change be marked as a major version bump given the business model change?
4. **User Communication**: Do we need to communicate this change to existing licensed users?
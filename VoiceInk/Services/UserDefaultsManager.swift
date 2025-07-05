import Foundation

extension UserDefaults {
    enum Keys {
        static let aiProviderApiKey = "VoiceInkAIProviderKey"
        static let licenseKey = "VoiceInkLicense"
        static let trialStartDate = "VoiceInkTrialStartDate"
        static let audioInputMode = "audioInputMode"
        static let selectedAudioDeviceUID = "selectedAudioDeviceUID"
        static let prioritizedDevices = "prioritizedDevices"
        static let activationId = "VoiceInkActivationId"
        static let licenseRequiresActivation = "VoiceInkLicenseRequiresActivation"
        static let hasLaunchedBefore = "VoiceInkHasLaunchedBefore"
        static let deviceIdentifier = "VoiceInkDeviceIdentifier"
    }
    
    // MARK: - AI Provider API Key
    var aiProviderApiKey: String? {
        get { string(forKey: Keys.aiProviderApiKey) }
        set { setValue(newValue, forKey: Keys.aiProviderApiKey) }
    }
    
    // MARK: - License Key
    var licenseKey: String? {
        get { string(forKey: Keys.licenseKey) }
        set { setValue(newValue, forKey: Keys.licenseKey) }
    }
    
    // MARK: - Trial Start Date
    var trialStartDate: Date? {
        get { object(forKey: Keys.trialStartDate) as? Date }
        set { setValue(newValue, forKey: Keys.trialStartDate) }
    }

    // MARK: - Audio Input Mode
    var audioInputModeRawValue: String? {
        get { string(forKey: Keys.audioInputMode) }
        set { setValue(newValue, forKey: Keys.audioInputMode) }
    }

    // MARK: - Selected Audio Device UID
    var selectedAudioDeviceUID: String? {
        get { string(forKey: Keys.selectedAudioDeviceUID) }
        set { setValue(newValue, forKey: Keys.selectedAudioDeviceUID) }
    }

    // MARK: - Prioritized Devices
    var prioritizedDevicesData: Data? {
        get { data(forKey: Keys.prioritizedDevices) }
        set { setValue(newValue, forKey: Keys.prioritizedDevices) }
    }
    
    // MARK: - License Cleanup
    func clearLicenseData() {
        removeObject(forKey: Keys.licenseKey)
        removeObject(forKey: Keys.trialStartDate)
        removeObject(forKey: Keys.activationId)
        removeObject(forKey: Keys.licenseRequiresActivation)
        removeObject(forKey: Keys.hasLaunchedBefore)
        removeObject(forKey: Keys.deviceIdentifier)
    }
} 
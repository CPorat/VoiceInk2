import Foundation
import AppKit

@MainActor
class LicenseViewModel: ObservableObject {
    enum LicenseState: Equatable {
        case trial(daysRemaining: Int)
        case trialExpired
        case licensed
    }
    
    @Published private(set) var licenseState: LicenseState = .licensed  // Always licensed
    @Published var licenseKey: String = ""
    @Published var isValidating = false
    @Published var validationMessage: String?
    @Published private(set) var activationsLimit: Int = 0
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadLicenseState()
    }
    
    
    private func loadLicenseState() {
        // Always set to licensed state - no trial restrictions
        licenseState = .licensed
    }
    
    var canUseApp: Bool {
        return true  // Always allow app usage
    }
    
    func openPurchaseLink() {
        if let url = URL(string: "https://tryvoiceink.com/buy") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func validateLicense() async {
        // Simplified license validation - always successful
        isValidating = true
        
        // Store the license key if provided
        if !licenseKey.isEmpty {
            userDefaults.licenseKey = licenseKey
        }
        
        // Always set to licensed state
        licenseState = .licensed
        validationMessage = "License activated successfully!"
        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
        
        isValidating = false
    }
    
    func removeLicense() {
        // Clean up all license-related data
        userDefaults.clearLicenseData()
        
        // Always stay in licensed state
        licenseState = .licensed
        licenseKey = ""
        validationMessage = nil
        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
    }
}

extension Notification.Name {
    static let licenseStatusChanged = Notification.Name("licenseStatusChanged")
}

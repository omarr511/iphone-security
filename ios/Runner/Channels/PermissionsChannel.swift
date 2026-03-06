import Flutter
import UIKit

class PermissionsChannel {
    private let channel: FlutterMethodChannel
    
    init(controller: FlutterViewController) {
        channel = FlutterMethodChannel(
            name: "com.security.checker/permissions",
            binaryMessenger: controller.binaryMessenger
        )
    }
    
    func register() {
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getAppPermissions":
                result(self?.getThisAppPermissions())
            case "getBackgroundApps":
                result(self?.getBackgroundAppsInfo())
            case "getConfigProfiles":
                result(self?.getConfigurationProfiles())
            case "getMdmStatus":
                result(self?.getMdmStatus())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - This app's own permissions
    private func getThisAppPermissions() -> [String: Any] {
        var apps: [[String: Any]] = []
        var permissions: [String] = []
        
        // Check what THIS app has access to
        let avStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if avStatus == .authorized { permissions.append("microphone") }
        
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if camStatus == .authorized { permissions.append("camera") }
        
        if CLLocationManager.authorizationStatus() != .denied &&
           CLLocationManager.authorizationStatus() != .notDetermined {
            permissions.append("location")
        }
        
        let cnStatus = CNContactStore.authorizationStatus(for: .contacts)
        if cnStatus == .authorized { permissions.append("contacts") }
        
        let calStatus = EKEventStore.authorizationStatus(for: .event)
        if calStatus == .authorized { permissions.append("calendar") }
        
        let photoStatus = PHPhotoLibrary.authorizationStatus()
        if photoStatus == .authorized || photoStatus == .limited {
            permissions.append("photos")
        }
        
        if !permissions.isEmpty {
            apps.append([
                "bundleId": Bundle.main.bundleIdentifier ?? "this_app",
                "appName":  "هذا التطبيق",
                "permissions": permissions
            ])
        }
        
        return ["apps": apps]
    }
    
    // MARK: - Background activity (what we can observe)
    private func getBackgroundAppsInfo() -> [String: Any] {
        // iOS sandboxing prevents listing other apps — return what we can observe
        var observed: [String] = []
        
        // Check if background refresh is enabled for this app
        let bgStatus = UIApplication.shared.backgroundRefreshStatus
        if bgStatus == .available {
            observed.append("Background Refresh: enabled")
        }
        
        return ["apps": observed]
    }
    
    // MARK: - Configuration Profiles
    private func getConfigurationProfiles() -> [String: Any] {
        var profiles: [[String: String]] = []
        
        // Check for MDM enrollment evidence
        let lockdownPath = "/var/mobile/Library/ConfigurationProfiles"
        if FileManager.default.fileExists(atPath: lockdownPath) {
            profiles.append([
                "name": "Configuration Profiles directory exists",
                "identifier": lockdownPath
            ])
        }
        
        // Check profile database
        let profileDB = "/private/var/Managed Preferences/mobile"
        if FileManager.default.fileExists(atPath: profileDB) {
            profiles.append([
                "name": "Managed Preferences found",
                "identifier": profileDB
            ])
        }
        
        return ["profiles": profiles]
    }
    
    // MARK: - MDM Status
    private func getMdmStatus() -> [String: Any] {
        // Strong MDM indicators
        var indicators: [String] = []
        
        let mdmPaths = [
            "/var/mobile/Library/ConfigurationProfiles/MDMProfile.mobileconfig",
            "/var/Managed Preferences",
            "/Library/Managed Preferences",
        ]
        
        for path in mdmPaths {
            if FileManager.default.fileExists(atPath: path) {
                indicators.append(path)
            }
        }
        
        // Check if device is supervised
        let isSupervised = checkIsSupervised()
        
        return [
            "enrolled": !indicators.isEmpty || isSupervised,
            "supervised": isSupervised,
            "indicators": indicators,
            "server": "Unknown"
        ]
    }
    
    private func checkIsSupervised() -> Bool {
        // On iOS 16+, supervision info is restricted
        // This checks for presence of supervision certificate
        let supervisionPath = "/var/db/MobileAsset/AssetsV2/com_apple_MobileAsset_MDMModule"
        return FileManager.default.fileExists(atPath: supervisionPath)
    }
}

// Needed imports (add to top of file in real Xcode project)
import AVFoundation
import CoreLocation
import Contacts
import EventKit
import Photos

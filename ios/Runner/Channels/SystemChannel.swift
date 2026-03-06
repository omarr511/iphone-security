import Flutter
import UIKit
import DiskArbitration

class SystemChannel {
    private let channel: FlutterMethodChannel
    
    init(controller: FlutterViewController) {
        channel = FlutterMethodChannel(
            name: "com.security.checker/system",
            binaryMessenger: controller.binaryMessenger
        )
    }
    
    func register() {
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getSystemInfo":
                result(self?.getSystemInfo())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func getSystemInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        // Storage
        if let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ) {
            let totalBytes = attrs[.systemSize] as? Int64 ?? 0
            let freeBytes  = attrs[.systemFreeSize] as? Int64 ?? 0
            info["totalStorageGB"] = Double(totalBytes) / 1_073_741_824
            info["freeStorageGB"]  = Double(freeBytes)  / 1_073_741_824
        }
        
        // Battery
        UIDevice.current.isBatteryMonitoringEnabled = true
        info["batteryLevel"]  = Int(UIDevice.current.batteryLevel * 100)
        info["batteryHealth"] = 100  // Real health needs private API
        
        // Untrusted certificates — check keychain
        info["untrustedCerts"] = getUntrustedCertificates()
        
        // System uptime (very low uptime may indicate recent reboot after exploit)
        let uptime = ProcessInfo.processInfo.systemUptime
        info["uptimeSeconds"] = Int(uptime)
        info["uptimeLow"]     = uptime < 60  // Less than 1 minute
        
        // Check if running in simulator
        info["isSimulator"] = isRunningOnSimulator()
        
        return info
    }
    
    // MARK: - Untrusted certificates
    private func getUntrustedCertificates() -> [String] {
        var untrusted: [String] = []
        let query: [String: Any] = [
            kSecClass as String:            kSecClassCertificate,
            kSecMatchLimit as String:       kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnRef as String:        true,
        ]
        var items: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess,
           let certs = items as? [[String: Any]] {
            for cert in certs {
                if let label = cert[kSecAttrLabel as String] as? String,
                   !label.contains("Apple") && !label.isEmpty {
                    untrusted.append(label)
                }
            }
        }
        return untrusted
    }
    
    // MARK: - Simulator check
    private func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

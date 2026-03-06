import UIKit
import Flutter
import Network
import NetworkExtension
import AVFoundation
import CoreLocation
import Contacts
import EventKit
import Photos
import MachO

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController

        // Jailbreak Channel
        let jailbreakChannel = FlutterMethodChannel(name: "com.security.checker/jailbreak", binaryMessenger: controller.binaryMessenger)
        jailbreakChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "deepJailbreakCheck": result(self.deepJailbreakCheck())
            case "checkUrlSchemes":
                let args = call.arguments as? [String: Any]
                result(self.checkUrlSchemes(args?["schemes"] as? [String] ?? []))
            default: result(FlutterMethodNotImplemented)
            }
        }

        // Network Channel
        let networkChannel = FlutterMethodChannel(name: "com.security.checker/network", binaryMessenger: controller.binaryMessenger)
        networkChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "getActiveConnections": self.getActiveConnections(result: result)
            case "getVpnStatus": self.getVpnStatus(result: result)
            case "getDnsServers": result(["servers": [] as [String]])
            default: result(FlutterMethodNotImplemented)
            }
        }

        // Permissions Channel
        let permissionsChannel = FlutterMethodChannel(name: "com.security.checker/permissions", binaryMessenger: controller.binaryMessenger)
        permissionsChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "getAppPermissions": result(self.getAppPermissions())
            case "getBackgroundApps":
                let bg = UIApplication.shared.backgroundRefreshStatus == .available
                result(["apps": bg ? ["Background Refresh: enabled"] : []])
            case "getConfigProfiles":
                let exists = FileManager.default.fileExists(atPath: "/var/mobile/Library/ConfigurationProfiles")
                result(["profiles": exists ? [["name": "ConfigurationProfiles exists"]] : []])
            case "getMdmStatus": result(self.getMdmStatus())
            default: result(FlutterMethodNotImplemented)
            }
        }

        // System Channel
        let systemChannel = FlutterMethodChannel(name: "com.security.checker/system", binaryMessenger: controller.binaryMessenger)
        systemChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "getSystemInfo": result(self.getSystemInfo())
            default: result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Jailbreak
    private func deepJailbreakCheck() -> [String: Any] {
        var detected: [String] = []
        let paths = ["/Applications/Cydia.app","/Applications/Sileo.app","/bin/bash",
                     "/usr/sbin/sshd","/etc/apt","/private/var/lib/cydia",
                     "/Library/MobileSubstrate/MobileSubstrate.dylib","/usr/bin/cycript"]
        for path in paths { if FileManager.default.fileExists(atPath: path) { detected.append("file:\(path)") } }
        let testPath = "/private/jb_test_\(UUID().uuidString).txt"
        if (try? "t".write(toFile: testPath, atomically: true, encoding: .utf8)) != nil {
            try? FileManager.default.removeItem(atPath: testPath)
            detected.append("sandbox_escape")
        }
        let suspLibs = ["MobileSubstrate","FridaGadget","SSLKillSwitch","libhooker"]
        for i in 0..<_dyld_image_count() {
            if let n = _dyld_get_image_name(i) {
                let s = String(cString: n)
                for lib in suspLibs { if s.contains(lib) { detected.append("dylib:\(lib)") } }
            }
        }
        return ["detected": detected, "isJailbroken": !detected.isEmpty]
    }

    private func checkUrlSchemes(_ schemes: [String]) -> [String] {
        schemes.filter { s in
            guard let url = URL(string: "\(s.replacingOccurrences(of: "://", with: ""))://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    // MARK: - Network
    private func getActiveConnections(result: @escaping FlutterResult) {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            monitor.cancel()
            let conns = path.availableInterfaces.map { iface -> [String: Any] in
                let t: String
                switch iface.type { case .wifi: t = "WiFi"; case .cellular: t = "Cellular"; default: t = "Other" }
                return ["interface": iface.name, "type": t, "remote": ""]
            }
            DispatchQueue.main.async { result(["connections": conns]) }
        }
        monitor.start(queue: DispatchQueue(label: "net.mon"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { monitor.cancel() }
    }

    private func getVpnStatus(result: @escaping FlutterResult) {
        NEVPNManager.shared().loadFromPreferences { _ in
            let s = NEVPNManager.shared().connection.status
            result(["isVpn": s == .connected || s == .connecting,
                    "vpnName": NEVPNManager.shared().localizedDescription ?? ""])
        }
    }

    // MARK: - Permissions
    private func getAppPermissions() -> [String: Any] {
        var perms: [String] = []
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { perms.append("microphone") }
        if AVCaptureDevice.authorizationStatus(for: .video)  == .authorized { perms.append("camera") }
        if PHPhotoLibrary.authorizationStatus() == .authorized { perms.append("photos") }
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized { perms.append("contacts") }
        return ["apps": perms.isEmpty ? [] : [["bundleId": Bundle.main.bundleIdentifier ?? "", "appName": "هذا التطبيق", "permissions": perms]]]
    }

    private func getMdmStatus() -> [String: Any] {
        let found = ["/var/mobile/Library/ConfigurationProfiles/MDMProfile.mobileconfig",
                     "/var/Managed Preferences"].filter { FileManager.default.fileExists(atPath: $0) }
        return ["enrolled": !found.isEmpty, "supervised": false, "server": "Unknown"]
    }

    // MARK: - System
    private func getSystemInfo() -> [String: Any] {
        var info: [String: Any] = ["batteryHealth": 100, "untrustedCerts": [String]()]
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            info["freeStorageGB"] = Double((attrs[.systemFreeSize] as? Int64 ?? 0)) / 1_073_741_824
        }
        UIDevice.current.isBatteryMonitoringEnabled = true
        info["batteryLevel"] = Int(UIDevice.current.batteryLevel * 100)
        info["uptimeSeconds"] = Int(ProcessInfo.processInfo.systemUptime)
        return info
    }
}

import UIKit
import Flutter
import Network
import CFNetwork
import AVFoundation
import Contacts
import Photos

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        // Jailbreak Channel
        FlutterMethodChannel(name: "com.security.checker/jailbreak", binaryMessenger: controller.binaryMessenger)
            .setMethodCallHandler { [weak self] call, result in
                guard let self = self else { return }
                switch call.method {
                case "deepJailbreakCheck":
                    result(self.deepJailbreakCheck())
                case "checkUrlSchemes":
                    let schemes = (call.arguments as? [String: Any])?["schemes"] as? [String] ?? []
                    result(self.checkUrlSchemes(schemes))
                default:
                    result(FlutterMethodNotImplemented)
                }
            }

        // Network Channel
        FlutterMethodChannel(name: "com.security.checker/network", binaryMessenger: controller.binaryMessenger)
            .setMethodCallHandler { [weak self] call, result in
                guard let self = self else { return }
                switch call.method {
                case "getActiveConnections": self.getActiveConnections(result: result)
                case "getVpnStatus":        self.getVpnStatus(result: result)
                case "getDnsServers":       result(["servers": [String]()])
                case "getProxyStatus":      result(self.getProxyStatus())
                default: result(FlutterMethodNotImplemented)
                }
            }

        // Permissions Channel
        FlutterMethodChannel(name: "com.security.checker/permissions", binaryMessenger: controller.binaryMessenger)
            .setMethodCallHandler { [weak self] call, result in
                guard let self = self else { return }
                switch call.method {
                case "getAppPermissions":  result(self.getAppPermissions())
                case "getMdmStatus":       result(self.getMdmStatus())
                case "getBackgroundApps":
                    let enabled = UIApplication.shared.backgroundRefreshStatus == .available
                    result(["apps": enabled ? ["Background Refresh"] : []])
                case "getConfigProfiles":
                    let exists = FileManager.default.fileExists(atPath: "/var/mobile/Library/ConfigurationProfiles")
                    result(["profiles": exists ? [["name": "Profiles found"]] : []])
                default: result(FlutterMethodNotImplemented)
                }
            }

        // System Channel
        FlutterMethodChannel(name: "com.security.checker/system", binaryMessenger: controller.binaryMessenger)
            .setMethodCallHandler { [weak self] call, result in
                guard let self = self else { return }
                switch call.method {
                case "getSystemInfo": result(self.getSystemInfo())
                default: result(FlutterMethodNotImplemented)
                }
            }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Jailbreak
    private func deepJailbreakCheck() -> [String: Any] {
        var detected: [String] = []
        let suspPaths = [
            "/Applications/Cydia.app", "/Applications/Sileo.app",
            "/bin/bash", "/usr/sbin/sshd", "/etc/apt",
            "/private/var/lib/cydia",
            "/Library/MobileSubstrate/MobileSubstrate.dylib"
        ]
        for path in suspPaths {
            if FileManager.default.fileExists(atPath: path) {
                detected.append("file:\(path)")
            }
        }
        // Sandbox escape test
        let testPath = "/private/jailbreak_test_\(Int.random(in: 1000...9999)).txt"
        if (try? "x".write(toFile: testPath, atomically: true, encoding: .utf8)) != nil {
            try? FileManager.default.removeItem(atPath: testPath)
            detected.append("sandbox_escape")
        }
        return ["detected": detected, "isJailbroken": !detected.isEmpty]
    }

    private func checkUrlSchemes(_ schemes: [String]) -> [String] {
        return schemes.filter { scheme in
            let clean = scheme.replacingOccurrences(of: "://", with: "")
            guard let url = URL(string: "\(clean)://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    // MARK: - Network
    private func getActiveConnections(result: @escaping FlutterResult) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.security.network")
        var didRespond = false

        let respond: ([[String: Any]]) -> Void = { conns in
            guard !didRespond else { return }
            didRespond = true
            monitor.cancel()
            DispatchQueue.main.async { result(["connections": conns]) }
        }

        monitor.pathUpdateHandler = { path in
            let conns: [[String: Any]] = path.availableInterfaces.map { iface in
                var type = "Other"
                switch iface.type {
                case .wifi:     type = "WiFi"
                case .cellular: type = "Cellular"
                case .wiredEthernet: type = "Ethernet"
                default: break
                }
                return ["interface": iface.name, "type": type, "remote": ""]
            }
            respond(conns)
        }
        monitor.start(queue: queue)

        queue.asyncAfter(deadline: .now() + 2.0) {
            respond([])
        }
    }

    private func getVpnStatus(result: @escaping FlutterResult) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.security.vpn")
        var didRespond = false

        let respond: (Bool) -> Void = { isVpn in
            guard !didRespond else { return }
            didRespond = true
            monitor.cancel()
            DispatchQueue.main.async {
                result(["isVpn": isVpn, "vpnName": isVpn ? "VPN Active" : ""])
            }
        }

        monitor.pathUpdateHandler = { path in
            let isVpn = path.availableInterfaces.contains { $0.type == .other }
            respond(isVpn)
        }
        monitor.start(queue: queue)

        queue.asyncAfter(deadline: .now() + 2.0) {
            respond(false)
        }
    }

    private func getProxyStatus() -> [String: Any] {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return ["enabled": false, "host": "", "port": 0]
        }

        let httpEnabled = (settings[kCFNetworkProxiesHTTPEnable as String] as? NSNumber)?.boolValue ?? false
        let httpsEnabled = (settings[kCFNetworkProxiesHTTPSEnable as String] as? NSNumber)?.boolValue ?? false
        let host = (settings[kCFNetworkProxiesHTTPProxy as String] as? String)
            ?? (settings[kCFNetworkProxiesHTTPSProxy as String] as? String)
            ?? ""
        let port = (settings[kCFNetworkProxiesHTTPPort as String] as? NSNumber)?.intValue
            ?? (settings[kCFNetworkProxiesHTTPSPort as String] as? NSNumber)?.intValue
            ?? 0

        return [
            "enabled": httpEnabled || httpsEnabled,
            "host": host,
            "port": port
        ]
    }

    // MARK: - Permissions
    private func getAppPermissions() -> [String: Any] {
        var granted: [String] = []
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { granted.append("microphone") }
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized { granted.append("camera") }
        if PHPhotoLibrary.authorizationStatus() == .authorized { granted.append("photos") }
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized { granted.append("contacts") }
        guard !granted.isEmpty else { return ["apps": []] }
        return ["apps": [["bundleId": Bundle.main.bundleIdentifier ?? "", "appName": "Security Checker", "permissions": granted]]]
    }

    private func getMdmStatus() -> [String: Any] {
        let mdmPaths = [
            "/var/mobile/Library/ConfigurationProfiles/MDMProfile.mobileconfig",
            "/var/Managed Preferences"
        ]
        let enrolled = mdmPaths.contains { FileManager.default.fileExists(atPath: $0) }
        return ["enrolled": enrolled, "supervised": false, "server": "Unknown"]
    }

    // MARK: - System
    private func getSystemInfo() -> [String: Any] {
        var info: [String: Any] = ["batteryHealth": 100, "untrustedCerts": [String]()]
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let free = attrs[.systemFreeSize] as? Int64 {
            info["freeStorageGB"] = Double(free) / 1_073_741_824
        }

        let proxy = getProxyStatus()
        info["proxyEnabled"] = proxy["enabled"] as? Bool ?? false
        info["proxyHost"] = proxy["host"] as? String ?? ""
        info["isDeveloperMode"] = false

        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        info["batteryLevel"] = level >= 0 ? Int(level * 100) : -1
        info["uptimeSeconds"] = Int(ProcessInfo.processInfo.systemUptime)
        return info
    }
}

import Flutter
import UIKit
import MachO

class JailbreakChannel {
    private let channel: FlutterMethodChannel
    
    init(controller: FlutterViewController) {
        channel = FlutterMethodChannel(
            name: "com.security.checker/jailbreak",
            binaryMessenger: controller.binaryMessenger
        )
    }
    
    func register() {
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "deepJailbreakCheck":
                result(self?.deepJailbreakCheck())
            case "checkUrlSchemes":
                let args = call.arguments as? [String: Any]
                let schemes = args?["schemes"] as? [String] ?? []
                result(self?.checkUrlSchemes(schemes))
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Deep Jailbreak Check
    private func deepJailbreakCheck() -> [String: Any] {
        var detected: [String] = []
        
        // 1. Check suspicious file paths
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/bin/bash", "/bin/sh",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/bin/cycript",
            "/usr/lib/libcycript.dylib",
            "/private/etc/dpkg/origins/debian",
            "/var/cache/apt",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                detected.append("file:\(path)")
            }
        }
        
        // 2. Sandbox escape test
        if sandboxEscapeTest() {
            detected.append("sandbox_escape")
        }
        
        // 3. Check for dylib injection (Substrate / Substitute)
        if checkDylibInjection() {
            detected.append("dylib_injection")
        }
        
        // 4. Check for suspicious environment variables
        if let dyldInsert = ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"],
           !dyldInsert.isEmpty {
            detected.append("DYLD_INSERT_LIBRARIES=\(dyldInsert)")
        }
        
        // 5. Check fork capability (not available on non-JB)
        if checkForkAllowed() {
            detected.append("fork_allowed")
        }
        
        // 6. Verify app signature
        if checkSignatureViolation() {
            detected.append("signature_violation")
        }
        
        return [
            "detected": detected,
            "isJailbroken": !detected.isEmpty
        ]
    }
    
    // MARK: - Sandbox escape
    private func sandboxEscapeTest() -> Bool {
        let testPath = "/private/jailbreak_test_\(UUID().uuidString).txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true  // Wrote outside sandbox → jailbroken
        } catch {
            return false  // Normal behavior
        }
    }
    
    // MARK: - Dylib injection check
    private func checkDylibInjection() -> Bool {
        let suspiciousLibs = [
            "MobileSubstrate",
            "CydiaSubstrate",
            "SubstrateBootstrap",
            "SubstrateInserter",
            "substitute-inserter",
            "libhooker",
            "SSLKillSwitch",
            "FridaGadget",
        ]
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let name = _dyld_get_image_name(i) {
                let imageName = String(cString: name)
                for lib in suspiciousLibs {
                    if imageName.contains(lib) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    // MARK: - Fork check
    private func checkForkAllowed() -> Bool {
        let pid = fork()
        if pid >= 0 {
            if pid > 0 { kill(pid, SIGTERM) }
            return true
        }
        return false
    }
    
    // MARK: - Signature verification
    private func checkSignatureViolation() -> Bool {
        // Check if the app binary has been tampered
        guard let execPath = Bundle.main.executablePath else { return false }
        let attrs = try? FileManager.default.attributesOfItem(atPath: execPath)
        // If modification date is very recent and doesn't match install, possible tampering
        return false  // Conservative — expand with codesign check if needed
    }
    
    // MARK: - URL scheme check
    private func checkUrlSchemes(_ schemes: [String]) -> [String] {
        var detected: [String] = []
        for scheme in schemes {
            let cleanScheme = scheme.replacingOccurrences(of: "://", with: "")
            if let url = URL(string: "\(cleanScheme)://"),
               UIApplication.shared.canOpenURL(url) {
                detected.append(scheme)
            }
        }
        return detected
    }
}

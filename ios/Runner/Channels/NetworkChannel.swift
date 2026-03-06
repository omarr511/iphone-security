import Flutter
import UIKit
import Network
import NetworkExtension

class NetworkChannel {
    private let channel: FlutterMethodChannel
    private var monitor: NWPathMonitor?
    
    init(controller: FlutterViewController) {
        channel = FlutterMethodChannel(
            name: "com.security.checker/network",
            binaryMessenger: controller.binaryMessenger
        )
    }
    
    func register() {
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getActiveConnections":
                self?.getActiveConnections(result: result)
            case "getVpnStatus":
                self?.getVpnStatus(result: result)
            case "getDnsServers":
                self?.getDnsServers(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Active Connections
    private func getActiveConnections(result: @escaping FlutterResult) {
        // Use NWPathMonitor to get interface info
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "network.monitor")
        
        monitor.pathUpdateHandler = { path in
            monitor.cancel()
            
            var connections: [[String: Any]] = []
            
            // Gather interface info
            for iface in path.availableInterfaces {
                connections.append([
                    "interface": iface.name,
                    "type": self.interfaceTypeName(iface.type),
                    "remote": "",
                    "status": path.status == .satisfied ? "active" : "inactive"
                ])
            }
            
            DispatchQueue.main.async {
                result(["connections": connections, "vpn": path.usesInterfaceType(.other)])
            }
        }
        monitor.start(queue: queue)
        
        // Timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            monitor.cancel()
        }
    }
    
    private func interfaceTypeName(_ type: NWInterface.InterfaceType) -> String {
        switch type {
        case .wifi:      return "WiFi"
        case .cellular:  return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback:  return "Loopback"
        default:         return "Other/VPN"
        }
    }
    
    // MARK: - VPN Status
    private func getVpnStatus(result: @escaping FlutterResult) {
        // Check NEVPNManager
        NEVPNManager.shared().loadFromPreferences { error in
            let status = NEVPNManager.shared().connection.status
            let isConnected = (status == .connected || status == .connecting)
            let vpnName = NEVPNManager.shared().localizedDescription ?? ""
            result([
                "isVpn": isConnected,
                "vpnName": vpnName,
                "status": self.vpnStatusName(status)
            ])
        }
    }
    
    private func vpnStatusName(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid:      return "invalid"
        case .disconnected: return "disconnected"
        case .connecting:   return "connecting"
        case .connected:    return "connected"
        case .reasserting:  return "reasserting"
        case .disconnecting:return "disconnecting"
        @unknown default:   return "unknown"
        }
    }
    
    // MARK: - DNS Servers
    private func getDnsServers(result: @escaping FlutterResult) {
        var servers: [String] = []
        
        // Read /etc/resolv.conf on jailbroken devices, or use CFDictionaryRef
        if let resolvConf = try? String(contentsOfFile: "/etc/resolv.conf") {
            for line in resolvConf.components(separatedBy: "\n") {
                if line.hasPrefix("nameserver") {
                    let parts = line.components(separatedBy: " ")
                    if parts.count >= 2 { servers.append(parts[1]) }
                }
            }
        }
        
        // Fallback: check via system config
        if servers.isEmpty {
            // Use SystemConfiguration if available
            servers = ["Could not read DNS - normal on non-JB device"]
        }
        
        result(["servers": servers])
    }
}

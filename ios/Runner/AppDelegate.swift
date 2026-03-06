import UIKit
import Flutter
import Network
import NetworkExtension
import MobileCoreServices

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let controller = window?.rootViewController as! FlutterViewController

        // Register all platform channels
        JailbreakChannel(controller: controller).register()
        NetworkChannel(controller: controller).register()
        PermissionsChannel(controller: controller).register()
        SystemChannel(controller: controller).register()

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

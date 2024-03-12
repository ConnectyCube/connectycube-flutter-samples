import UIKit
import Flutter
import flutter_local_notifications
import FBSDKCoreKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // This is required to make any communication available in the action isolate.
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
            GeneratedPluginRegistrant.register(with: registry)
        }
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
        }
        
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme != nil {
            let facebookAppId: String? = Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String
            if facebookAppId != nil && url.scheme!.hasPrefix("fb\(facebookAppId!)") && url.host ==  "authorize" {
                print("is login by facebook")
                return ApplicationDelegate.shared.application(app, open: url, options: options)
            }
        }
        
        return false
    }
}

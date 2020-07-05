import UIKit
import Flutter
import flutter_voip_push_notification
import flutter_call_kit
import PushKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    /* Add PushKit delegate method */

    // Handle updated push credentials
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void){
        // Register VoIP push token (a property of PKPushCredentials) with server
        FlutterVoipPushNotificationPlugin.didReceiveIncomingPush(with: payload, forType: type.rawValue)
        
        FlutterCallKitPlugin.reportNewIncomingCall(String!, handle: <#T##String!#>, "generic"<#T##String!#>, false, callerName, YES)
        
         [FlutterCallKitPlugin reportNewIncomingCall:uuid handle:handle handleType:@"generic" hasVideo:false localizedCallerName:callerName fromPushKit: YES];
    }

    // Handle incoming pushes
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        // Process the received push
        FlutterVoipPushNotificationPlugin.didUpdate(pushCredentials, forType: type.rawValue);
    }
}

//
//  BroadcastSetupViewController.swift
//  com.connectycube.flutter.p2p-screensharingSetupUI
//
//  Created by Tereha on 21.12.2021.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

import ReplayKit

class BroadcastSetupViewController: UIViewController {

    // Call this method when the user has finished interacting with the view controller and a broadcast stream can start
    func userDidFinishSetup() {
        // URL of the resource where broadcast can be viewed that will be returned to the application
        let broadcastURL = URL(string:"http://apple.com/broadcast/streamID")
        
        // Dictionary with setup information that will be provided to broadcast extension when broadcast is started
        let setupInfo: [String : NSCoding & NSObjectProtocol] = ["broadcastName": "example" as NSCoding & NSObjectProtocol]
        
        // Tell ReplayKit that the extension is finished setting up and can begin broadcasting
        self.extensionContext?.completeRequest(withBroadcast: broadcastURL!, setupInfo: setupInfo)
    }
    
    func userDidCancelSetup() {
        let error = NSError(domain: "YouAppDomain", code: -1, userInfo: nil)
        // Tell ReplayKit that the extension was cancelled by the user
        self.extensionContext?.cancelRequest(withError: error)
    }
}

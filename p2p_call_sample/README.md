# P2P Calls code sample for Flutter for ConnectyCube platform

This README introduces [ConnectyCube](https://connectycube.com) P2P Calls code sample for Flutter

Project contains the following features implemented:

- User authorization
- Group video/audio calls (up to 4 users)
- Mute/unmute microphone
- Switch cameras
- Disable/enable video stream
- Switch speaker phone and earpiece
- Background calls (via push notifications)

## Documentation

ConnectyCube Flutter getting started - [https://developers.connectycube.com/flutter](https://developers.connectycube.com/flutter)

ConnectyCube P2P Calls API documentation - [https://developers.connectycube.com/flutter/videocalling](https://developers.connectycube.com/flutter/videocalling)

## Screenshots

<kbd><img alt="Flutter P2P Calls code sample, login" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/login_screen.png" height="440" /></kbd> <kbd><img alt="Flutter P2P Calls code sample, select users" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/select_opponents_screen.png" height="440" /></kbd> <kbd><img alt="Flutter P2P Calls code sample, video chat" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/call_screen.png" height="440" /></kbd>

## Roadmap

- Members call statuses

## Quick start and develop

Quick start [Flutter](https://flutter.dev/docs/get-started) app.


## Run

Prepare environment for Flutter and clone the project.

### Run on Android:
- Right mouse button click on `main.dart`;
- Chose 'Run 'main.dart''.

App will automatically run on your Android device.

### Run on iOS:
- Start Xcode;
- Select `Runner.xcworkspace` to run Xcode project;
- Press 'Build' button to start project building.

App will automatically run on selected iOS device or simulator.

## Background calls

<kbd><img alt="Flutter P2P Calls code sample, incoming call in background Android" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/background_call_android.png" height="440" /></kbd>
<kbd><img alt="Flutter P2P Calls code sample, incoming call locked Android" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/background_call_android_locked.png" height="440" /></kbd>
<kbd><img alt="Flutter P2P Calls code sample, incoming call in background iOS" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/background_call_ios.PNG" height="440" /></kbd>
<kbd><img alt="Flutter P2P Calls code sample, incoming call locked iOS" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/background_call_ios_locked.PNG" height="440" /></kbd>

For background calls we use Connectycube Push notifications feature and some helpful plugins:
- For iOS we use:
    * [flutter_voip_push_notification](https://pub.dev/packages/flutter_voip_push_notification);
    * [flutter_call_kit](https://pub.dev/packages/flutter_call_kit) (from the [GitHub repository](https://github.com/peerwaya/flutter_call_kit));

- For Android we use:
    * [firebase_messaging](https://pub.dev/packages/firebase_messaging)
    * [connectycube_flutter_call_kit](https://pub.dev/packages/connectycube_flutter_call_kit)


### Configure Push notifications:
1. Create an own app in the ConnectyCube admin panel (if not created yet);
2. Create a project in the Firebase developer console (if not created yet);
3. Add the Server API key from the Firebase developer console to the ConnectyCube admin panel for the Android platform ([short guide](https://developers.connectycube.com/flutter/push-notifications?id=android));
4. Add Apple certificate for the iOS platform ([short guide, how to generate and set it to the admin panel](https://developers.connectycube.com/ios/push-notifications?id=create-apns-certificate)). But instead of APNS certificate you should choose VoIP certificate;
5. Add config files from the Firebase developer console to this project:
    - for Android - file `google-services.json` by path `p2p_call_sample/android/app/`;
    - for iOS - file `GoogleService-Info.plist` by path `p2p_call_sample/ios/Runner/` (if you have build problems on this step, try add this file via Xcode);
6. Configure file `p2p_call_sample/lib/src/utils/configs.dart` with your endpoints from the 1st. point of this guide;
7. Create users in the ConnectyCube admin panel and add them to the configure file `p2p_call_sample/lib/src/utils/configs.dart`
8. Build and run the app as usual;

## Can't build yourself?

Got troubles with building Flutter code sample? Just create an issue at [Issues page](https://github.com/ConnectyCube/connectycube-flutter-samples/issues) - we will create the sample for you. For FREE!
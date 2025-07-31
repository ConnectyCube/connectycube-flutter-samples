# P2P Calls code sample for Flutter for ConnectyCube platform

This README introduces [ConnectyCube](https://connectycube.com) P2P Calls code sample for Flutter

The project contains the following features implemented:

- User authorization
- Group video/audio calls (up to 4 users)
- Mute/unmute microphone
- Switch cameras
- Disable/enable the video stream
- Switch speakerphone and earpiece
- Opponents' Mic level monitoring
- Opponents' Video bitrate monitoring
- Screen Sharing
- Background calls (via push notifications)

## Screenshots

<kbd><img alt="Flutter P2P Calls code sample, login" src="https://developers.connectycube.com/images/code_samples/flutter/login_screen.png" height="440" /></kbd>
<kbd><img alt="Flutter P2P Calls code sample, select users" src="https://developers.connectycube.com/images/code_samples/flutter/select_opponents_screen.png" height="440" /></kbd>
<kbd><img alt="Flutter P2P Calls code sample, video chat" src="https://developers.connectycube.com/images/code_samples/flutter/call_screen.png" height="440" /></kbd>
<kbd><img alt="Flutter P2P Calls code sample, video chat (macOS)" src="https://developers.connectycube.com/images/code_samples/flutter/call_screen_macos.png" height="440" /></kbd>

## Quick start

### Preparations

1. Prepare environment for Flutter and clone the project.
2. Install dependencies via `flutter pub get`

### Obtain ConnectyCube credentials

Register new account and application at https://admin.connectycube.com and then put **_Application credentials_** from `Overview` page into config file `lib/src/config.dart` instead of the following vars:

- `REPLACE_APP_ID`
- `REPLACE_APP_AUTH_KEY`

Also, go to ConnectyCube dashboard, `Users` page, create 4 test users (if it's not created yet) and set their credentials in config file `lib/src/config.dart` instead of `REPLACE_USER_x_ID, REPLACE_USER_x_LOGIN, REPLACE_USER_x_FULL_NAME, REPLACE_USER_x_PASSWORD`

### Run on Android:

- Right mouse button click on `main.dart`
- Chose 'Run 'main.dart''

The app will automatically run on your Android device.

### Run on iOS:

- `cd ios`
- `pod install`
- Open `Runner.xcworkspace` from `ios` dir
- Run project

The app will automatically run on a selected iOS device or simulator.

### Run on macOS

- Run command from the Terminal `flutter run -d macos`

### Run on Windows

- Run command from the Terminal `flutter run -d windows`

### Run on Web

- Run command from the Terminal `flutter run -d chrome`

### Run on Linux

- Run command from the Terminal `flutter run -d linux`

## Receiving calls on the mobile platforms

<kbd><img alt="Flutter P2P Calls code sample, incoming call in background Android" src="https://developers.connectycube.com/images/code_samples/flutter/background_call_android.png" height="440" /></kbd>
<kbd><img alt="Flutter P2P Calls code sample, incoming call locked Android" src="https://developers.connectycube.com/images/code_samples/flutter/background_call_android_locked.png" height="440" /></kbd>
<kbd><img alt="Flutter P2P Calls code sample, incoming call in background iOS" src="https://developers.connectycube.com/images/code_samples/flutter/background_call_ios.PNG" height="440" /></kbd>
<kbd><img alt="Flutter P2P Calls code sample, incoming call locked iOS" src="https://developers.connectycube.com/images/code_samples/flutter/background_call_ios_locked.PNG" height="440" /></kbd>

For notifying mobile platforms we use Connectycube Push notifications feature and own [Connectycube Call Kit plugin](https://pub.dev/packages/connectycube_flutter_call_kit) for supporting Call Kit feature.

## Configure Push notifications:

1. Create your own app in the ConnectyCube admin panel (if not created yet);
2. Create a project in the Firebase developer console (if not created yet);
3. Add the Server API key from the Firebase developer console to the ConnectyCube admin panel for the Android platform ([short guide](https://developers.connectycube.com/flutter/push-notifications?id=android));
4. Add Apple certificate for the iOS platform ([short guide, how to generate and set it to the admin panel](https://developers.connectycube.com/ios/push-notifications?id=create-apns-certificate)). But instead of an APNS certificate, you should choose a VoIP certificate;
5. Add `google-services.json` file from the Firebase developer console to the Android app by path `p2p_call_sample/android/app/`
6. Configure file `p2p_call_sample/lib/src/utils/configs.dart` with your endpoints from the 1st. point of this guide;
7. Create users in the ConnectyCube admin panel and add them to the configure file `p2p_call_sample/lib/src/utils/configs.dart`
8. Build and run the app as usual;

## Documentation

Make first call guide - https://developers.connectycube.com/flutter/getting-started/make-first-call/

Advanced Video calling documentation - https://developers.connectycube.com/flutter/videocalling/

## Have an issue?

Join our [Discord](https://discord.com/invite/zqbBWNCCFJ) community to get real-time help from our team or create an issue at [GitHub issues page](https://github.com/ConnectyCube/connectycube-flutter-samples/issues).

## Community

- [Blog](https://connectycube.com/blog)
- X (twitter)[@ConnectyCube](https://x.com/ConnectyCube)
- [Facebook](https://www.facebook.com/ConnectyCube)
- [Medium](https://medium.com/@connectycube)
- [YouTube](https://www.youtube.com/@ConnectyCube)

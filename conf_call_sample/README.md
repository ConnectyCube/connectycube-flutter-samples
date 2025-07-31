# Conference Calls code sample for Flutter for ConnectyCube platform

This README introduces [ConnectyCube](https://connectycube.com) Conference Calls code sample for Flutter

Project contains the following features implemented:

- User authorization
- Guest User authorization
- Conference video calls (up to 12 users)
- Mute/unmute microphone
- Switch cameras
- Disable/enable video stream
- Switch audio output
- Switch audio input
- Screen sharing
- Opponents' mic level monitoring
- Opponents' video bitrate monitoring
- Speaker/grid/private modes (the Simulcast feature is applied)
- CallKit
- Pre-join screen for video calls
- Switching from audio call to video without reconnection
- Shared conferences (join by link)

[**Conference calls Sample Web app**](https://connectycube.github.io/connectycube-flutter-samples/conf_call_sample/build/web)

## Screenshots

<kbd><img alt="Flutter Conference Calls code sample, select users" src="https://developers.connectycube.com/images/code_samples/flutter/select_opponents_screen_conf.png" height="440" /></kbd>
<kbd><img alt="Flutter Conference Calls code sample, video chat private" src="https://developers.connectycube.com/images/code_samples/flutter/call_screen_private.png" height="440" /></kbd></kbd>
<kbd><img alt="Flutter Conference Calls code sample, video chat" src="https://developers.connectycube.com/images/code_samples/flutter/call_screen_group_conf.png" height="440" /></kbd></kbd>
<kbd><img alt="Flutter Conference Calls code sample, video chat (macOS)" src="https://developers.connectycube.com/images/code_samples/flutter/call_screen_macos_conf.png" height="440" /></kbd>

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

- Right mouse button click on `main.dart`;
- Chose 'Run 'main.dart''.

App will automatically run on your Android device.

### Run on iOS:

- Start Xcode;
- Select `Runner.xcworkspace` to run Xcode project;
- Press 'Build' button to start project building.

The app will automatically run on the selected iOS device or simulator.

### Run on macOS

- Run command from the Terminal `flutter run -d macos`;

### Run on Windows

- Run command from the Terminal `flutter run -d windows`;

### Run on Linux

- Run command from the Terminal `flutter run -d linux`;

## Config for the CallKit feature

The CallKit feature is enabled by default in current version.

The push notification feature is used for implementation the participants notification about the
new call event. Do the next for configuration:

1. Create your own app in the ConnectyCube admin panel (if not created yet);
2. Create a project in the Firebase developer console (if not created yet);
3. Add the Server API key from the Firebase developer console to the ConnectyCube admin panel for the Android platform ([short guide](https://developers.connectycube.com/flutter/push-notifications?id=android));
4. Add Apple certificate for the iOS platform ([short guide, how to generate and set it to the admin panel](https://developers.connectycube.com/ios/push-notifications?id=create-apns-certificate)). But instead of an APNS certificate, you should choose a VoIP certificate;
5. Add `google-services.json` file from the Firebase developer console to the Android app by path `conf_call_sample/android/app/`
6. Configure file `conf_call_sample/lib/src/utils/configs.dart` with your endpoints from the 1st. point of this guide;
7. Create users in the ConnectyCube admin panel and add them to the configure file `conf_call_sample/lib/src/utils/configs.dart`
8. Build and run the app as usual;

## Documentation

Advanced Conferencing calling documentation - https://developers.connectycube.com/flutter/videocalling-conference/

## Have an issue?

Join our [Discord](https://discord.com/invite/zqbBWNCCFJ) community to get real-time help from our team or create an issue at [GitHub issues page](https://github.com/ConnectyCube/connectycube-flutter-samples/issues).

## Community

- [Blog](https://connectycube.com/blog)
- X (twitter)[@ConnectyCube](https://x.com/ConnectyCube)
- [Facebook](https://www.facebook.com/ConnectyCube)
- [Medium](https://medium.com/@connectycube)
- [YouTube](https://www.youtube.com/@ConnectyCube)

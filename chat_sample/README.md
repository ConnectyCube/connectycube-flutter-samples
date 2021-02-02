# Chat code sample for Flutter for ConnectyCube platform

This README introduces [ConnectyCube](https://connectycube.com) Chat code sample for Flutter

Project contains the following features implemented:

- User authorization
- Users search
- Chat dialogs creation
- 1-1 messaging
- Group messaging
- ‘Is typing’ statuses
- Group chat: edit group name, photo; list of participants, add/remove participants; leave group
- Push notification: subscribe/unsubscribe, show local notification, navigate to the app click on local notification

## Documentation

ConnectyCube Flutter getting started - [https://developers.connectycube.com/flutter](https://developers.connectycube.com/flutter)

ConnectyCube Chat API documentation - [https://developers.connectycube.com/flutter/messaging](https://developers.connectycube.com/flutter/messaging)

## Screenshots

<kbd><img alt="Flutter Chat sample, select dialogs" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/dialogs_screen.png" height="440" /></kbd> <kbd><img alt="Flutter Chat code sample, chat" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/chat_screen.png" height="440" /></kbd>

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

### Configure Push notifications:
1. Create an own app in the ConnectyCube admin panel (if not created yet);
2. Create a project in the Firebase developer console (if not created yet);
3. Add the Server API key from the Firebase developer console to the ConnectyCube admin panel for the Android platform ([short guide](https://developers.connectycube.com/flutter/push-notifications?id=android));
4. Add Apple certificate for the iOS platform ([short guide, how to generate and set it to the admin panel](https://developers.connectycube.com/ios/push-notifications?id=create-apns-certificate));
5. Add config files from the Firebase developer console to this project:
    - for Android - file `google-services.json` by path `chat_sample/android/app/`;
    - for iOS - file `GoogleService-Info.plist` by path `chat_sample/ios/Runner/` (if you have build problems on this step, try add this file via Xcode);
6. Configure file `chat_sample/lib/src/utils/configs.dart` with your endpoints from the 1st. point of this guide;
7. Build and run the app as usual;

## Can't build yourself?

Got troubles with building Flutter code sample? Just create an issue at [Issues page](https://github.com/ConnectyCube/connectycube-flutter-samples/issues) - we will create the sample for you. For FREE!
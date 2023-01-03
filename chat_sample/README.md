# Chat code sample for Flutter for ConnectyCube platform

This README introduces [ConnectyCube](https://connectycube.com) Chat code sample for Flutter

The project contains the following features implemented:

- User authorization
- Users search
- Chat dialogs creation
- 1-1 messaging
- Group messaging
- ‘Is typing’ statuses
- Group chat: edit a name, photo; list of participants, add/remove participants; leave a group
- Push notification: subscribe/unsubscribe, show local notification, navigate to the app click on a local notification

## Documentation

ConnectyCube Flutter getting started - [https://developers.connectycube.com/flutter](https://developers.connectycube.com/flutter)

ConnectyCube Chat API documentation - [https://developers.connectycube.com/flutter/messaging](https://developers.connectycube.com/flutter/messaging)

## Screenshots

<kbd><img alt="Flutter Chat sample, select dialogs" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/dialogs_screen.png" height="440" />
</kbd> <kbd><img alt="Flutter Chat code sample, chat" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/chat_screen.png" height="440" /></kbd>
</kbd> <kbd><img alt="Flutter Chat code sample, chat (Windows)" src="https://developers.connectycube.com/docs/_images/code_samples/flutter/chat_screen_windows.png" height="440" /></kbd>

## Quickstart and develop

Quickstart [Flutter](https://flutter.dev/docs/get-started) app.


## Run

Prepare environment for Flutter and clone the project.

### Run on Android:
- Right mouse button click on `main.dart`;
- Chose 'Run 'main.dart''.

The app will automatically run on your Android device.

### Run on iOS:
- Start Xcode;
- Select `Runner.xcworkspace` to run Xcode project;
- Press the' Build' button to start project building.

The app will automatically run on a selected iOS device or simulator.

### Run on macOS
- Run command from the  Terminal `flutter run -d macos`;
### Run on Windows
- Run command from the  Terminal `flutter run -d windows`;
### Run on Web
- Run command from the  Terminal `flutter run -d chrome`;

### Configure Push notifications:
1. Create your own app in the ConnectyCube admin panel (if not created yet);
2. Create a project in the Firebase developer console (if not created yet);
3. Add the Server API key from the Firebase developer console to the ConnectyCube admin panel for the Android platform ([short guide](https://developers.connectycube.com/flutter/push-notifications?id=android));
4. Add Apple certificate for the iOS platform ([short guide, how to generate and set it to the admin panel](https://developers.connectycube.com/ios/push-notifications?id=create-apns-certificate));
5. Generate config file `firebase_options.dart` via [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)(the simple util provided for avoiding manual configuration for each platforms) and put it by place `lib/firebase_options.dart`;
6. Build and run the app as usual;

> **Note:** For working with push notifications on the macOS platform you should generate a separate certificate similar to p.4 but with other app bundle id.

> **Note:** For displaying notifications on the Web platform from the background you should feel the file `web/firebase-messaging-sw.js` with data from your Firebase developer console.


## Can't build yourself?

Got troubles with building Flutter code samples? Just create an issue at [Issues page](https://github.com/ConnectyCube/connectycube-flutter-samples/issues) - we will create the sample for you. For FREE!

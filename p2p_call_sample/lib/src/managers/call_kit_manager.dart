import 'package:flutter_call_kit/flutter_call_kit.dart';
import 'package:universal_io/io.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';

class CallKitManager {
  static CallKitManager get instance => _getInstance();
  static CallKitManager? _instance;
  static String TAG = "CallKitManager";

  static CallKitManager _getInstance() {
    return _instance ??= CallKitManager._internal();
  }

  factory CallKitManager() => _getInstance();

  CallKitManager._internal() {
    this._callKit = FlutterCallKit();
  }

  late FlutterCallKit _callKit;

  late Function(String uuid) onCallAccepted;
  late Function(String uuid) onCallEnded;
  late Function(String error, String uuid, String handle,
      String localizedCallerName, bool fromPushKit) onNewCallShown;
  late Function(bool mute, String uuid) onMuteCall;

  init({
    required onCallAccepted(uuid),
    required onCallEnded(uuid),
    required onNewCallShown(error, uuid, handle, callerName, fromPushKit),
    required onMuteCall(mute, uuid),
  }) {
    this.onCallAccepted = onCallAccepted;
    this.onCallEnded = onCallEnded;
    this.onNewCallShown = onNewCallShown;
    this.onMuteCall = onMuteCall;

    // TODO temporary used 'flutter_call_kit' for iOS
    if (Platform.isIOS) {
      _callKit.configure(
        IOSOptions("P2P Call Sample",
            imageName: 'sim_icon',
            supportsVideo: true,
            maximumCallGroups: 1,
            maximumCallsPerCallGroup: 1,
            includesCallsInRecents: false),
        performAnswerCallAction: _performAnswerCallAction,
        performEndCallAction: _performEndCallAction,
        didDisplayIncomingCall: _didDisplayIncomingCall,
        didPerformSetMutedCallAction: _didPerformSetMutedCallAction,
      );
    } else if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.instance.init(
        onCallAccepted: _onCallAccepted,
        onCallRejected: _onCallRejected,
      );
    }
  }

  // call when opponent(s) end call
  Future<void> reportEndCallWithUUID(String uuid) async {
    if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
      ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: false);
    } else if (Platform.isIOS) {
      await _callKit.reportEndCallWithUUID(uuid, EndReason.remoteEnded);
    }
  }

  Future<void> endCall(String uuid) async {
    if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
      ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: false);
    } else if (Platform.isIOS) {
      await _callKit.endCall(uuid);
    }
  }

  Future<void> rejectCall(String uuid) async {
    if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
      ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: false);
    } else if (Platform.isIOS) {
      await _callKit.rejectCall(uuid);
    }
  }

  /// Event Listener Callbacks for 'flutter_call_kit'

  Future<void> _performAnswerCallAction(String uuid) async {
    // Called when the user answers an incoming call
    onCallAccepted.call(uuid);
  }

  Future<void> _performEndCallAction(String uuid) async {
    await _callKit.endCall(uuid);
    onCallEnded.call(uuid);
  }

  Future<void> _didDisplayIncomingCall(String error, String uuid, String handle,
      String localizedCallerName, bool fromPushKit) async {
    onNewCallShown.call(error, uuid, handle, localizedCallerName, fromPushKit);
  }

  Future<void> _didPerformSetMutedCallAction(bool mute, String uuid) async {
    onMuteCall.call(mute, uuid);
  }

  /// Event Listener Callbacks for 'connectycube_flutter_call_kit'

  Future<void> _onCallAccepted(
      String sessionId,
      int callType,
      int callerId,
      String callerName,
      Set<int> opponentsIds,
      Map<String, String>? userInfo) async {
    onCallAccepted.call(sessionId);
  }

  Future<void> _onCallRejected(
      String sessionId,
      int callType,
      int callerId,
      String callerName,
      Set<int> opponentsIds,
      Map<String, String>? userInfo) async {
    onCallEnded.call(sessionId);
  }
}

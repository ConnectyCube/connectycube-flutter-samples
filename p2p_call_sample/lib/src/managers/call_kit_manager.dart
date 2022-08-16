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

  CallKitManager._internal();

  late Function(String uuid) onCallAccepted;
  late Function(String uuid) onCallEnded;
  late Function(bool mute, String uuid) onMuteCall;

  init({
    required onCallAccepted(uuid),
    required onCallEnded(uuid),
    required onMuteCall(mute, uuid),
  }) {
    this.onCallAccepted = onCallAccepted;
    this.onCallEnded = onCallEnded;
    this.onMuteCall = onMuteCall;

    ConnectycubeFlutterCallKit.instance.init(
        onCallAccepted: _onCallAccepted,
        onCallRejected: _onCallRejected,
        icon: Platform.isAndroid ? 'default_avatar' : 'CallkitIcon',
        color: '#07711e',
        ringtone:
            Platform.isAndroid ? 'custom_ringtone' : 'custom_ringtone.caf');

    if (Platform.isIOS) {
      ConnectycubeFlutterCallKit.onCallMuted = _onCallMuted;
    }
  }

  Future<void> processCallFinished(String uuid) async {
    ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
    ConnectycubeFlutterCallKit.setOnLockScreenVisibility(isVisible: false);
  }

  /// Event Listener Callbacks for 'connectycube_flutter_call_kit'
  ///
  Future<void> _onCallMuted(bool mute, String uuid) async {
    onMuteCall.call(mute, uuid);
  }

  Future<void> _onCallAccepted(CallEvent callEvent) async {
    onCallAccepted.call(callEvent.sessionId);
  }

  Future<void> _onCallRejected(CallEvent callEvent) async {
    onCallEnded.call(callEvent.sessionId);
  }
}

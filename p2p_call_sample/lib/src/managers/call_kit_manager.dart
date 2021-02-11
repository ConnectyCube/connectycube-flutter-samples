import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_call_kit/flutter_call_kit.dart';

import 'package:connectycube_flutter_call_kit/connectycube_flutter_call_kit.dart';
import 'package:connectycube_sdk/connectycube_core.dart';

class CallKitManager {
  static CallKitManager get instance => _getInstance();
  static CallKitManager _instance;
  static String TAG = "CallKitManager";

  static CallKitManager _getInstance() {
    if (_instance == null) {
      _instance = CallKitManager._internal();
    }
    return _instance;
  }

  factory CallKitManager() => _getInstance();

  CallKitManager._internal() {
    this._callKit = FlutterCallKit();
  }

  FlutterCallKit _callKit;

  Function(String uuid) onCallAccepted;
  Function(String uuid) onCallEnded;
  Function(String error, String uuid, String handle, String localizedCallerName,
      bool fromPushKit) onNewCallShown;
  Function(bool mute, String uuid) onMuteCall;

  init({
    @required onCallAccepted(uuid),
    @required onCallEnded(uuid),
    @required onNewCallShown(error, uuid, handle, callerName, fromPushKit),
    @required onMuteCall(mute, uuid),
  }) {
    this.onCallAccepted = onCallAccepted;
    this.onCallEnded = onCallEnded;
    this.onNewCallShown = onNewCallShown;
    this.onMuteCall = onMuteCall;

    _callKit.configure(
      IOSOptions("P2P Call Sample",
          imageName: 'sim_icon',
          supportsVideo: true,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          includesCallsInRecents: false),
      didReceiveStartCallAction: _didReceiveStartCallAction,
      onProviderReset: _onProviderReset,
      performAnswerCallAction: _performAnswerCallAction,
      performEndCallAction: _performEndCallAction,
      didActivateAudioSession: _didActivateAudioSession,
      didDeactivateAudioSession: _didDeactivateAudioSession,
      didDisplayIncomingCall: _didDisplayIncomingCall,
      didPerformSetMutedCallAction: _didPerformSetMutedCallAction,
      didPerformDTMFAction: _didPerformDTMFAction,
      didToggleHoldAction: _didToggleHoldAction,
      handleStartCallNotification: _handleStartCallNotification,
    );

    ConnectycubeFlutterCallKit().init(
      onCallAccepted: _performAnswerCallAction,
      onCallRejected: _performEndCallAction,
    );
  }

  // call when opponent(s) end call
  Future<void> reportEndCallWithUUID(String uuid) async {
    log('[reportEndCallWithUUID] uuid: $uuid',
        CallKitManager.TAG);
    if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
    } else {
      await _callKit.reportEndCallWithUUID(uuid, EndReason.remoteEnded);
    }
  }

  Future<void> endCall(String uuid) async {
    log('[endCall] uuid: $uuid', CallKitManager.TAG);
    if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
    } else {
      await _callKit.endCall(uuid);
    }
  }

  Future<void> rejectCall(String uuid) async {
    log('[rejectCall] uuid: $uuid', CallKitManager.TAG);

    if (Platform.isAndroid) {
      ConnectycubeFlutterCallKit.reportCallEnded(sessionId: uuid);
    } else {
      await _callKit.rejectCall(uuid);
    }
  }

  /// Event Listener Callbacks

  Future<void> _didReceiveStartCallAction(String uuid, String handle) async {
    // Get this event after the system decides you can start a call
    // You can now start a call from within your app
    log('[_didReceiveStartCallAction] uuid: $uuid, handle: $handle',
        CallKitManager.TAG);
  }

  Future<void> _performAnswerCallAction(String uuid) async {
    // Called when the user answers an incoming call
    log('[_performAnswerCallAction] uuid: $uuid', CallKitManager.TAG);
    onCallAccepted.call(uuid);
  }

  Future<void> _performEndCallAction(String uuid) async {
    await _callKit.endCall(uuid);
    log('[_performEndCallAction] uuid: $uuid', CallKitManager.TAG);
    onCallEnded.call(uuid);
  }

  Future<void> _didActivateAudioSession() async {
    // you might want to do following things when receiving this event:
    // - Start playing ringback if it is an outgoing call
    log('[_didActivateAudioSession]', CallKitManager.TAG);
  }

  Future<void> _didDisplayIncomingCall(String error, String uuid, String handle,
      String localizedCallerName, bool fromPushKit) async {
    // You will get this event after RNCallKeep finishes showing incoming call UI
    // You can check if there was an error while displaying
    log('[_didDisplayIncomingCall] error: $error, uuid: $uuid, handle: $handle, localizedCallerName: $localizedCallerName, fromPushKit: $fromPushKit',
        CallKitManager.TAG);

    onNewCallShown.call(error, uuid, handle, localizedCallerName, fromPushKit);
  }

  Future<void> _didPerformSetMutedCallAction(bool mute, String uuid) async {
    // Called when the system or user mutes a call
    log('[_didPerformSetMutedCallAction] mute: $mute, uuid: $uuid',
        CallKitManager.TAG);
    onMuteCall.call(mute, uuid);
  }

  Future<void> _didPerformDTMFAction(String digit, String uuid) async {
    // Called when the system or user performs a DTMF action
    log('[_didPerformDTMFAction] digit: $digit, uuid: $uuid',
        CallKitManager.TAG);
  }

  Future<void> _didToggleHoldAction(bool hold, String uuid) async {
    // Called when the system or user holds a call
    log('[_didToggleHoldAction] hold: $hold, uuid: $uuid', CallKitManager.TAG);
  }

  void _onProviderReset() {
    log('[_onProviderReset]', CallKitManager.TAG);
  }

  Future<void> _didDeactivateAudioSession() async {
    log('[_didDeactivateAudioSession]', CallKitManager.TAG);
  }

  Future<void> _handleStartCallNotification(String handle, bool video) async {
    log('[_handleStartCallNotification] handle: $handle, video: $video',
        CallKitManager.TAG);
  }
}

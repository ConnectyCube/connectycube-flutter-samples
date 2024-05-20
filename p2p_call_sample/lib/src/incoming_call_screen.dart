import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'managers/call_manager.dart';

class IncomingCallScreen extends StatelessWidget {
  static const String tag = "IncomingCallScreen";
  final P2PSession _callSession;

  const IncomingCallScreen(this._callSession, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    _callSession.onSessionClosed = (callSession) {
      log("_onSessionClosed", tag);
      Navigator.pop(context);
    };

    return PopScope(
        canPop: false,
        child: Scaffold(
            body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(36),
                child:
                    Text(_getCallTitle(), style: const TextStyle(fontSize: 28)),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 36, bottom: 8),
                child: Text("Members:", style: TextStyle(fontSize: 20)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 86),
                child: Text(_callSession.opponentsIds.join(", "),
                    style: const TextStyle(fontSize: 18)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 36),
                    child: FloatingActionButton(
                      heroTag: "RejectCall",
                      backgroundColor: Colors.red,
                      onPressed: () => _rejectCall(context, _callSession),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: FloatingActionButton(
                      heroTag: "AcceptCall",
                      backgroundColor: Colors.green,
                      onPressed: () => _acceptCall(context, _callSession),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )));
  }

  _getCallTitle() {
    String? callType;

    switch (_callSession.callType) {
      case CallType.VIDEO_CALL:
        callType = "Video";
        break;
      case CallType.AUDIO_CALL:
        callType = "Audio";
        break;
    }

    return "Incoming ${callType ?? ''} call";
  }

  void _acceptCall(BuildContext context, P2PSession callSession) {
    CallManager.instance.acceptCall(callSession.sessionId, false);
  }

  void _rejectCall(BuildContext context, P2PSession callSession) {
    CallManager.instance.reject(callSession.sessionId, false);
  }
}

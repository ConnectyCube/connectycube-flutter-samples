import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../managers/call_manager.dart';
import '../utils/configs.dart' as utils;
import '../utils/consts.dart';
import '../utils/platform_utils.dart';
import '../utils/pref_util.dart';

class SelectOpponentsScreen extends StatelessWidget {
  final CubeUser currentUser;

  SelectOpponentsScreen(this.currentUser);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Logged in as ${currentUser.fullName}',
          ),
          actions: <Widget>[
            IconButton(
              onPressed: () => _logOut(context),
              icon: Icon(
                Icons.exit_to_app,
              ),
            ),
          ],
        ),
        body: BodyLayout(currentUser),
      ),
    );
  }

  Future<bool> _onBackPressed() {
    return Future.value(true);
  }

  _logOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Logout"),
          content: Text("Are you sure you want logout current user"),
          actions: <Widget>[
            TextButton(
              child: Text("CANCEL"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text("OK"),
              onPressed: () {
                signOut().then(
                  (voidValue) {
                    CubeChatConnection.instance.destroy();
                    SharedPrefs.deleteSessionData();
                    SharedPrefs.deleteUserData();
                    Navigator.pop(context); // cancel current Dialog
                    _navigateToLoginScreen(context);
                  },
                ).catchError(
                  (onError) {
                    Navigator.pop(context); // cancel current Dialog
                    _navigateToLoginScreen(context);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  _navigateToLoginScreen(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(LOGIN_SCREEN);
  }
}

class BodyLayout extends StatefulWidget {
  final CubeUser currentUser;

  BodyLayout(this.currentUser);

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState(currentUser);
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static final String TAG = 'SelectOpponentsScreen';

  Set<int> _selectedUsers = {};
  final CubeUser _currentUser;

  _BodyLayoutState(this._currentUser);

  @override
  Widget build(BuildContext context) {
    log('[build]', TAG);
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(top: 48, bottom: 24, left: 24, right: 24),
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  startSharedCall();
                },
                child: Container(
                  width: 400,
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Start shared call',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'or',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 16),
              Text(
                "Select users to start call:",
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 8),
              _getOpponentsList(),
              SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FloatingActionButton(
                    heroTag: "VideoCall",
                    child: Icon(
                      _selectedUsers.isNotEmpty
                          ? Icons.videocam
                          : Icons.video_call,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.blue,
                    onPressed: () =>
                        _startCall(_selectedUsers, CallType.VIDEO_CALL),
                  ),
                  SizedBox(width: 32),
                  FloatingActionButton(
                    heroTag: "AudioCall",
                    child: Icon(
                      _selectedUsers.isNotEmpty ? Icons.call : Icons.add_call,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.green,
                    onPressed: () =>
                        _startCall(_selectedUsers, CallType.AUDIO_CALL),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getOpponentsList() {
    log('[_getOpponentsList]', TAG);
    CubeUser? currentUser = _currentUser;
    final users =
        utils.users.where((user) => user.id != currentUser.id).toList();
    return ListView.builder(
      shrinkWrap: true,
      itemCount: users.length,
      itemBuilder: (context, index) {
        log('[itemBuilder] index $index', TAG);
        return Card(
          child: CheckboxListTile(
            title: Center(
              child: Text(
                users[index].fullName!,
              ),
            ),
            value: _selectedUsers.contains(users[index].id),
            onChanged: ((checked) {
              log('[CheckboxListTile][onChanged]', TAG);
              setState(() {
                if (checked!) {
                  _selectedUsers.add(users[index].id!);
                } else {
                  _selectedUsers.remove(users[index].id);
                }
              });
            }),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    log('[initState]', TAG);

    initForegroundService();
    checkSystemAlertWindowPermission(context);
    requestNotificationsPermission();
    CallManager.instance.context = context;
    requestFullScreenIntentsPermission(context);

    _initCalls();
  }

  void _initCalls() {
    log('[_initCalls]', TAG);
    CallManager.instance.onReceiveNewCall =
        (callId, meetingId, initiatorId, participantIds, callType, callName) {
      _showIncomingCallScreen(
          callId, meetingId, initiatorId, participantIds, callType, callName);
    };
  }

  void _startCall(Set<int> opponents, int callType) async {
    log('[_startCall] call type $callType', TAG);

    var attendees = opponents.map((entry) {
      return CubeMeetingAttendee(userId: entry);
    }).toList();

    var startDate = DateTime.now().microsecondsSinceEpoch ~/ 1000;
    var endDate = startDate + 2 * 60 * 60; //create meeting for two hours

    CubeMeeting meeting = CubeMeeting(
      name: 'Conference Call',
      startDate: startDate,
      endDate: endDate,
      attendees: attendees.isEmpty
          ? [CubeMeetingAttendee(userId: _currentUser.id)]
          : attendees,
    );
    createMeeting(meeting).then((createdMeeting) async {
      var callSession = await ConferenceClient.instance.createCallSession(
        createdMeeting.hostId!,
        callType: callType,
      );

      Navigator.of(context).pushNamed(CONVERSATION_SCREEN, arguments: {
        ARG_USER: _currentUser,
        ARG_CALL_SESSION: callSession,
        ARG_MEETING_ID: createdMeeting.meetingId!,
        ARG_OPPONENTS: opponents.toList(),
        ARG_IS_INCOMING: false,
        ARG_CALL_NAME: opponents.isEmpty
            ? 'Shared conference'
            : '${_currentUser.fullName ?? 'Unknown User'}${opponents.length > 1 ? ' (in Group call)' : ''}',
        ARG_IS_SHARED_CALL: opponents.isEmpty
      });
    });
  }

  void _showIncomingCallScreen(String callId, String meetingId, int initiatorId,
      List<int> participantIds, int callType, String callName) {
    log('[_showIncomingCallScreen]', TAG);

    Navigator.of(context).pushNamed(
      INCOMING_CALL_SCREEN,
      arguments: {
        ARG_USER: _currentUser,
        ARG_CALL_ID: callId,
        ARG_MEETING_ID: meetingId,
        ARG_INITIATOR_ID: initiatorId,
        ARG_OPPONENTS: participantIds,
        ARG_CALL_TYPE: callType,
        ARG_CALL_NAME: callName,
      },
    );
  }

  startSharedCall() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create Shared Conference'),
          content: Text(
              'The shared Video conference will be created. Any user can join it by link.'),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text("OK"),
              onPressed: () {
                _startCall({}, CallType.VIDEO_CALL);
              },
            ),
          ],
        );
      },
    );
  }
}

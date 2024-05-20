import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../managers/call_manager.dart';
import '../utils/configs.dart' as utils;
import '../utils/consts.dart';
import '../utils/platform_utils.dart';
import '../utils/pref_util.dart';

class SelectOpponentsScreen extends StatelessWidget {
  final CubeUser currentUser;

  const SelectOpponentsScreen(this.currentUser, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Logged in as ${currentUser.fullName}',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => _logOut(context),
            icon: const Icon(
              Icons.exit_to_app,
            ),
          ),
        ],
      ),
      body: BodyLayout(currentUser),
    );
  }

  _logOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want logout current user"),
          actions: <Widget>[
            TextButton(
              child: const Text("CANCEL"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text("OK"),
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
    Navigator.of(context).pushReplacementNamed(loginScreen);
  }
}

class BodyLayout extends StatefulWidget {
  final CubeUser currentUser;

  const BodyLayout(this.currentUser, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState();
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static const String tag = 'SelectOpponentsScreen';

  final Set<int> _selectedUsers = {};

  @override
  Widget build(BuildContext context) {
    log('[build]', tag);
    return SingleChildScrollView(
      child: Container(
        padding:
            const EdgeInsets.only(top: 48, bottom: 24, left: 24, right: 24),
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  startSharedCall();
                },
                child: const SizedBox(
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
              const SizedBox(height: 16),
              const Text(
                'or',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              const Text(
                "Select users to start call:",
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              _getOpponentsList(),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FloatingActionButton(
                    heroTag: "VideoCall",
                    backgroundColor: Colors.blue,
                    onPressed: () =>
                        _startCall(_selectedUsers, CallType.VIDEO_CALL),
                    child: Icon(
                      _selectedUsers.isNotEmpty
                          ? Icons.videocam
                          : Icons.video_call,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 32),
                  FloatingActionButton(
                    heroTag: "AudioCall",
                    backgroundColor: Colors.green,
                    onPressed: () =>
                        _startCall(_selectedUsers, CallType.AUDIO_CALL),
                    child: Icon(
                      _selectedUsers.isNotEmpty ? Icons.call : Icons.add_call,
                      color: Colors.white,
                    ),
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
    log('[_getOpponentsList]', tag);
    CubeUser? currentUser = widget.currentUser;
    final users =
        utils.users.where((user) => user.id != currentUser.id).toList();
    return ListView.builder(
      shrinkWrap: true,
      itemCount: users.length,
      itemBuilder: (context, index) {
        log('[itemBuilder] index $index', tag);
        return Card(
          child: CheckboxListTile(
            title: Center(
              child: Text(
                users[index].fullName!,
              ),
            ),
            value: _selectedUsers.contains(users[index].id),
            onChanged: ((checked) {
              log('[CheckboxListTile][onChanged]', tag);
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
    log('[initState]', tag);

    initForegroundService();
    checkSystemAlertWindowPermission(context);
    requestNotificationsPermission();
    CallManager.instance.context = context;
    requestFullScreenIntentsPermission(context);

    _initCalls();
  }

  void _initCalls() {
    log('[_initCalls]', tag);
    CallManager.instance.onReceiveNewCall =
        (callId, meetingId, initiatorId, participantIds, callType, callName) {
      _showIncomingCallScreen(
          callId, meetingId, initiatorId, participantIds, callType, callName);
    };
  }

  void _startCall(Set<int> opponents, int callType) async {
    log('[_startCall] call type $callType', tag);

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
          ? [CubeMeetingAttendee(userId: widget.currentUser.id)]
          : attendees,
    );
    createMeeting(meeting).then((createdMeeting) {
      ConferenceClient.instance
          .createCallSession(
        createdMeeting.hostId!,
        callType: callType,
      )
          .then((callSession) {
        Navigator.of(context).pushNamed(conversationScreen, arguments: {
          argUser: widget.currentUser,
          argCallSession: callSession,
          argMeetingId: createdMeeting.meetingId!,
          argOpponents: opponents.toList(),
          argIsIncoming: false,
          argCallName: opponents.isEmpty
              ? 'Shared conference'
              : '${widget.currentUser.fullName ?? 'Unknown User'}${opponents.length > 1 ? ' (in Group call)' : ''}',
          argIsSharedCall: opponents.isEmpty
        });
      });
    });
  }

  void _showIncomingCallScreen(String callId, String meetingId, int initiatorId,
      List<int> participantIds, int callType, String callName) {
    log('[_showIncomingCallScreen]', tag);

    Navigator.of(context).pushNamed(
      incomingCallScreen,
      arguments: {
        argUser: widget.currentUser,
        argCallId: callId,
        argMeetingId: meetingId,
        argInitiatorId: initiatorId,
        argOpponents: participantIds,
        argCallType: callType,
        argCallName: callName,
      },
    );
  }

  startSharedCall() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Shared Conference'),
          content: const Text(
              'The shared Video conference will be created. Any user can join it by link.'),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text("OK"),
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

import 'package:conf_call_sample/src/utils/call_manager.dart';
import 'package:conf_call_sample/src/utils/video_config.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'call_screen.dart';
import 'utils/configs.dart' as utils;

class SelectDialogScreen extends StatelessWidget {
  final CubeUser currentUser;
  SelectDialogScreen(this.currentUser);

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
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: BodyLayout(currentUser),
      ),
    );
  }

  Future<bool> _onBackPressed() {
    return Future.value(false);
  }

  _logOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Logout"),
          content: Text("Are you sure you want logout current user"),
          actions: <Widget>[
            FlatButton(
              child: Text("CANCEL"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            FlatButton(
              child: Text("OK"),
              onPressed: () {
                signOut().then(
                      (voidValue) {
                    CubeChatConnection.instance.destroy();
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
    Navigator.pop(context);
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
  Set<int> _selectedUsers = {};
  final CubeUser currentUser;
  String joinRoomId;
  CallManager _callManager;
  ConferenceClient _callClient;
  ConferenceSession _currentCall;

  _BodyLayoutState(this.currentUser);

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            Text(
              "Select users to start call:",
              style: TextStyle(fontSize: 22),
            ),
            Expanded(
              child: _getOpponentsList(context),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FloatingActionButton(
                  heroTag: "VideoCall",
                  child: Icon(
                    Icons.videocam,
                    color: Colors.white,
                  ),
                  backgroundColor: Colors.blue,
                  onPressed: () =>
                      _startCall(_selectedUsers),
                ),
              ],
            ),
          ],
        ));
  }

  Widget _getOpponentsList(BuildContext context) {
    CubeUser currentUser = CubeChatConnection.instance.currentUser;
    final users =
    utils.users.where((user) => user.id != currentUser.id).toList();
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        return Card(
          child: CheckboxListTile(
            title: Center(
              child: Text(
                users[index].fullName,
              ),
            ),
            value: _selectedUsers.contains(users[index].id),
            onChanged: ((checked) {
              setState(() {
                if (checked) {
                  _selectedUsers.add(users[index].id);
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
    _initConferenceConfig();
    _initCalls();
    joinRoomId = currentUser.id.toString();
  }

  void _initCalls() {
    _callClient = ConferenceClient.instance;
    _callManager = CallManager.instance;
    _callManager.onReceiveNewCall = (roomId, participantIds) {
      _showIncomingCallScreen(roomId, participantIds);
    };

    _callManager.onCloseCall = () {
      _currentCall = null;
    };
  }

  void _startCall(Set<int> opponents) async {
    if (opponents.isEmpty) return;
    _currentCall = await _callClient.createCallSession(currentUser.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationCallScreen(_currentCall, joinRoomId, opponents.toList(), false),
      ),
    );
  }

  void _showIncomingCallScreen(String roomId, List<int> participantIds) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(roomId, participantIds),
      ),
    );
  }

  void _initConferenceConfig() {
    ConferenceConfig.instance.url = utils.SERVER_ENDPOINT;
  }
}

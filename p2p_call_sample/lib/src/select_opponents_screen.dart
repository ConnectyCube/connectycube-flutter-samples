import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'managers/call_manager.dart';
import 'managers/push_notifications_manager.dart';
import 'utils/configs.dart' as utils;
import 'utils/pref_util.dart';

class SelectOpponentsScreen extends StatelessWidget {
  final CubeUser currentUser;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Logged in as ${CubeChatConnection.instance.currentUser.fullName}',
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
              onPressed: () async {
                CallManager.instance.destroy();
                CubeChatConnection.instance.destroy();
                await PushNotificationsManager.instance.unsubscribe();
                await SharedPrefs.instance
                    .init()
                    .then((value) => value.deleteUserData());
                await signOut();

                Navigator.pop(context); // cancel current Dialog
                _navigateToLoginScreen(context);
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

  SelectOpponentsScreen(this.currentUser);
}

class BodyLayout extends StatefulWidget {
  final CubeUser currentUser;



  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState(currentUser);
  }

  BodyLayout(this.currentUser);
}

class _BodyLayoutState extends State<BodyLayout> {
  final CubeUser currentUser;
  Set<int> _selectedUsers;


  _BodyLayoutState(this.currentUser);

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            Text(
              "Select users to call:",
              style: TextStyle(fontSize: 22),
            ),
            Expanded(
              child: _getOpponentsList(context),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 24),
                  child: FloatingActionButton(
                    heroTag: "VideoCall",
                    child: Icon(
                      Icons.videocam,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.blue,
                    onPressed: () => CallManager.instance.startNewCall(
                        context, CallType.VIDEO_CALL, _selectedUsers),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 24),
                  child: FloatingActionButton(
                    heroTag: "AudioCall",
                    child: Icon(
                      Icons.call,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.green,
                    onPressed: () => CallManager.instance.startNewCall(
                        context, CallType.AUDIO_CALL, _selectedUsers),
                  ),
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

    _selectedUsers = {};

    PushNotificationsManager.instance.init();
  }
}

import 'dart:async';

import 'package:chat_sample/src/chat_dialog_screen.dart';
import 'package:chat_sample/src/select_dialog_screen.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class ChatDialogResizableScreen extends StatelessWidget {
  static const String TAG = "SelectDialogScreen";
  final CubeUser currentUser;
  final CubeDialog? selectedDialog;

  ChatDialogResizableScreen(this.currentUser, this.selectedDialog);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(),
      child: Scaffold(
        body: BodyLayout(currentUser, selectedDialog),
      ),
    );
  }

  Future<bool> _onBackPressed() {
    return Future.value(true);
  }
}

class BodyLayout extends StatefulWidget {
  final CubeUser currentUser;
  final CubeDialog? selectedDialog;

  BodyLayout(this.currentUser, this.selectedDialog);

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState(currentUser, selectedDialog);
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static const String TAG = "_BodyLayoutState";

  final CubeUser currentUser;
  CubeDialog? selectedDialog;

  _BodyLayoutState(this.currentUser, CubeDialog? selectedDialog) {
    this.selectedDialog = selectedDialog;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      child: Row(
        children: [
          if (isBigScreen || selectedDialog == null)
            Expanded(
              flex: 1,
              child: SelectDialogScreen(currentUser, selectedDialog,
                  (selectedDialog) {
                setState(() {
                  this.selectedDialog = null;
                  Future.delayed(Duration(milliseconds: 50), () {
                    setState(() {
                      this.selectedDialog = selectedDialog;
                    });
                  });
                });
              }),
            ),
          VerticalDivider(
            width: 1,
          ),
          getSelectedDialog()
        ],
      ),
    );
  }

  Widget getSelectedDialog() {
    if (selectedDialog != null) {
      return Flexible(
        flex: 2,
        child: Stack(
          children: [
            ChatDialogScreen(currentUser, selectedDialog!),
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: AppBar().preferredSize.height,
                child: AppBar(
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  leading: !isBigScreen && selectedDialog != null
                      ? IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              selectedDialog = null;
                            });
                          },
                        )
                      : null,
                  title: Text(
                    selectedDialog?.name ?? '',
                  ),
                  centerTitle: false,
                  actions: <Widget>[
                    IconButton(
                      onPressed: () => showChatDetails(
                          context, currentUser, selectedDialog!),
                      icon: Icon(
                        Icons.info_outline,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (isBigScreen) {
      return Expanded(
        flex: 2,
        child: Container(
          child: Center(
            child: Text('No dialog selected'),
          ),
        ),
      );
    } else {
      return Container();
    }
  }

  get isBigScreen => MediaQuery.of(context).size.width >= 800;
}

import 'dart:async';

import 'package:chat_sample/src/chat_dialog_screen.dart';
import 'package:chat_sample/src/select_dialog_screen.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

const double dialogsListWidth = 300;
const double minScreenSize = 800;
const double dividerWidth = 1;

class ChatDialogResizableScreen extends StatelessWidget {
  static const String tag = "SelectDialogScreen";
  final CubeUser currentUser;
  final CubeDialog? selectedDialog;

  const ChatDialogResizableScreen(this.currentUser, this.selectedDialog,
      {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BodyLayout(currentUser, selectedDialog),
    );
  }
}

class BodyLayout extends StatefulWidget {
  final CubeUser currentUser;
  final CubeDialog? selectedDialog;

  const BodyLayout(this.currentUser, this.selectedDialog, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState();
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static const String tag = "_BodyLayoutState";

  late CubeDialog? selectedDialog;

  @override
  void initState() {
    super.initState();

    selectedDialog = widget.selectedDialog;
  }

  @override
  void didUpdateWidget(BodyLayout oldWidget) {
    super.didUpdateWidget(oldWidget);

    selectedDialog = widget.selectedDialog;
  } // _BodyLayoutState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Row(
        children: [
          if (isBigScreen || selectedDialog == null)
            LayoutBuilder(builder: (context, constraint) {
              var width = MediaQuery.of(context).size.width;

              return SizedBox(
                width: isBigScreen
                    ? width / 4 <= dialogsListWidth
                        ? dialogsListWidth
                        : width / 4
                    : width,
                child: SelectDialogScreen(widget.currentUser, selectedDialog,
                    (selectedDialog) {
                  setState(() {
                    this.selectedDialog = null;
                    Future.delayed(const Duration(milliseconds: 50), () {
                      setState(() {
                        this.selectedDialog = selectedDialog;
                      });
                    });
                  });
                }),
              );
            }),
          Visibility(
            visible: isBigScreen,
            child: const VerticalDivider(
              width: dividerWidth,
            ),
          ),
          getSelectedDialog()
        ],
      ),
    );
  }

  Widget getSelectedDialog() {
    if (selectedDialog != null) {
      return Flexible(
        child: Stack(
          children: [
            ChatDialogScreen(widget.currentUser, selectedDialog!),
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: AppBar().preferredSize.height,
                child: AppBar(
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  leading: !isBigScreen && selectedDialog != null
                      ? IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
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
                          context, widget.currentUser, selectedDialog!),
                      icon: const Icon(
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
        child: Container(
          margin: EdgeInsets.only(top: AppBar().preferredSize.height),
          child: const Center(
            child: Text(
              'No dialog selected',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      );
    } else {
      return Container();
    }
  }

  get isBigScreen => MediaQuery.of(context).size.width >= minScreenSize;
}

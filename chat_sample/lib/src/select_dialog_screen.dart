import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'create_dialog_flow.dart';
import 'managers/chat_manager.dart';
import 'settings_screen.dart';
import 'utils/api_utils.dart';
import 'utils/consts.dart';
import 'utils/platform_utils.dart';
import 'widgets/common.dart';

class SelectDialogScreen extends StatelessWidget {
  static const String tag = "SelectDialogScreen";
  final CubeUser currentUser;
  final Function(CubeDialog)? onDialogSelectedCallback;
  final CubeDialog? selectedDialog;

  const SelectDialogScreen(
      this.currentUser, this.selectedDialog, this.onDialogSelectedCallback,
      {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Logged in as ${currentUser.fullName ?? currentUser.login ?? currentUser.email ?? currentUser.phone ?? currentUser.facebookId}',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => _openSettings(context),
            icon: const Icon(
              Icons.settings,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: BodyLayout(currentUser, selectedDialog, onDialogSelectedCallback),
    );
  }

  _openSettings(BuildContext context) {
    showModal(context: context, child: SettingsScreen(currentUser));
  }
}

class BodyLayout extends StatefulWidget {
  final CubeUser currentUser;
  final Function(CubeDialog)? onDialogSelectedCallback;
  final CubeDialog? selectedDialog;

  const BodyLayout(
      this.currentUser, this.selectedDialog, this.onDialogSelectedCallback,
      {super.key});

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState();
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static const String tag = "_BodyLayoutState";

  List<ListItem<CubeDialog>> dialogList = [];
  var _isDialogContinues = true;

  StreamSubscription<CubeMessage>? msgSubscription;
  StreamSubscription<MessageStatus>? msgDeliveringSubscription;
  StreamSubscription<MessageStatus>? msgReadingSubscription;
  StreamSubscription<MessageStatus>? msgLocalReadingSubscription;
  StreamSubscription<CubeMessage>? msgSendingSubscription;
  StreamSubscription<CubeDialog>? addDialogSubscription;

  final ChatMessagesManager? chatMessagesManager =
      CubeChatConnection.instance.chatMessagesManager;

  CubeDialog? selectedDialog;

  Map<String, Set<String>> unreadMessages = {};

  _BodyLayoutState();

  @override
  void didUpdateWidget(BodyLayout oldWidget) {
    super.didUpdateWidget(oldWidget);

    selectedDialog = widget.selectedDialog;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          children: [
            Visibility(
              visible: _isDialogContinues && dialogList.isEmpty,
              child: Container(
                margin: const EdgeInsets.all(40),
                alignment: FractionalOffset.center,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
            Expanded(
              child: _getDialogsList(context),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "New dialog",
        backgroundColor: Colors.blue,
        onPressed: () => _createNewDialog(context),
        child: const Icon(
          Icons.add_comment,
          color: Colors.white,
        ),
      ),
    );
  }

  void _createNewDialog(BuildContext context) async {
    showModal(context: context, child: CreateDialog(widget.currentUser));
  }

  void _processGetDialogError(exception) {
    log("GetDialog error $exception", tag);
    setState(() {
      _isDialogContinues = false;
    });
    showDialogError(exception, context);
  }

  Widget _getDialogsList(BuildContext context) {
    if (_isDialogContinues) {
      getDialogs().then((dialogs) {
        _isDialogContinues = false;
        log("getDialogs: $dialogs", tag);
        setState(() {
          dialogList.clear();
          dialogList.addAll(
              dialogs?.items.map((dialog) => ListItem(dialog)).toList() ?? []);
        });
      }).catchError((exception) {
        _processGetDialogError(exception);
      });
    }
    if (_isDialogContinues && dialogList.isEmpty) {
      return const SizedBox.shrink();
    } else if (dialogList.isEmpty) {
      return const Center(
        child: Text(
          'No dialogs yet',
          style: TextStyle(fontSize: 20),
        ),
      );
    } else {
      return ListView.separated(
        itemCount: dialogList.length,
        itemBuilder: _getListItemTile,
        separatorBuilder: (context, index) {
          return const Divider(
            thickness: 1,
            indent: 68,
            height: 1,
          );
        },
      );
    }
  }

  Widget _getListItemTile(BuildContext context, int index) {
    Widget getDialogIcon() {
      var dialog = dialogList[index].data;
      if (dialog.type == CubeDialogType.PRIVATE) {
        return const Icon(
          Icons.person,
          size: 40.0,
          color: greyColor,
        );
      } else {
        return const Icon(
          Icons.group,
          size: 40.0,
          color: greyColor,
        );
      }
    }

    getDialogAvatar() {
      var dialog = dialogList[index].data;

      return getDialogAvatarWidget(dialog, 25,
          placeholder: getDialogIcon(), errorWidget: getDialogIcon());
    }

    return Container(
      color: selectedDialog != null &&
              selectedDialog!.dialogId == dialogList[index].data.dialogId
          ? const Color.fromARGB(100, 168, 228, 160)
          : null,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Row(
          children: <Widget>[
            getDialogAvatar(),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(left: 8.0),
                child: Column(
                  children: <Widget>[
                    Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dialogList[index].data.name ?? 'Unknown dialog',
                        style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                            overflow: TextOverflow.ellipsis),
                        maxLines: 1,
                      ),
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dialogList[index].data.lastMessage ?? '',
                        style: const TextStyle(
                            color: primaryColor,
                            overflow: TextOverflow.ellipsis),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Visibility(
              maintainAnimation: true,
              maintainState: true,
              visible: dialogList[index].isSelected,
              child: IconButton(
                iconSize: 25.0,
                icon: const Icon(
                  Icons.delete,
                  color: themeColor,
                ),
                onPressed: () {
                  _deleteDialog(context, dialogList[index].data);
                },
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    getMessageStateWidget(
                        dialogList[index].data.lastMessageState),
                    Text(
                      DateFormat('MMM dd').format(
                          dialogList[index].data.lastMessageDateSent != null
                              ? DateTime.fromMillisecondsSinceEpoch(
                                  dialogList[index].data.lastMessageDateSent! *
                                      1000)
                              : dialogList[index].data.updatedAt!),
                      style: const TextStyle(color: primaryColor),
                    ),
                  ],
                ),
                if (dialogList[index].data.unreadMessageCount != null &&
                    dialogList[index].data.unreadMessageCount != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 6),
                      decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10.0)),
                      child: Text(
                        dialogList[index].data.unreadMessageCount.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        onLongPress: () {
          setState(() {
            dialogList[index].isSelected = !dialogList[index].isSelected;
          });
        },
        onTap: () {
          _selectDialog(context, dialogList[index].data);
        },
      ),
    );
  }

  void _deleteDialog(BuildContext context, CubeDialog dialog) async {
    log("_deleteDialog= $dialog");
    Fluttertoast.showToast(msg: 'Coming soon');
  }

  void _selectDialog(BuildContext context, CubeDialog dialog) async {
    if (widget.onDialogSelectedCallback != null) {
      widget.onDialogSelectedCallback?.call(dialog);
      setState(() {
        selectedDialog = dialog;
      });
    } else {
      Navigator.pushNamed(context, 'chat_dialog',
          arguments: {userArgName: widget.currentUser, dialogArgName: dialog});
    }
  }

  void refresh() {
    setState(() {
      _isDialogContinues = true;
    });
  }

  @override
  void initState() {
    super.initState();
    selectedDialog = widget.selectedDialog;

    refreshBadgeCount();

    msgSubscription =
        chatMessagesManager!.chatMessagesStream.listen(onReceiveMessage);
    msgDeliveringSubscription = CubeChatConnection
        .instance.messagesStatusesManager?.deliveredStream
        .listen(onMessageDelivered);
    msgReadingSubscription = CubeChatConnection
        .instance.messagesStatusesManager?.readStream
        .listen(onMessageRead);
    msgLocalReadingSubscription =
        ChatManager.instance.readMessagesStream.listen(onMessageRead);
    msgSendingSubscription =
        ChatManager.instance.sentMessagesStream.listen(onReceiveMessage);
    addDialogSubscription =
        ChatManager.instance.addDialogStream.listen(onAddDialog);
  }

  @override
  void dispose() {
    super.dispose();
    log("dispose", tag);
    msgSubscription?.cancel();
    msgDeliveringSubscription?.cancel();
    msgReadingSubscription?.cancel();
    msgLocalReadingSubscription?.cancel();
    msgSendingSubscription?.cancel();
    addDialogSubscription?.cancel();
  }

  void onReceiveMessage(CubeMessage message) {
    log("onReceiveMessage global message= $message");
    updateDialog(message);
  }

  void onAddDialog(CubeDialog cubeDialog) {
    log("[onAddDialog] $cubeDialog");
    setState(() {
      dialogList.add(ListItem(cubeDialog));
      sortDialogsList();
    });
  }

  updateDialog(CubeMessage msg) {
    refreshBadgeCount();

    ListItem<CubeDialog>? dialogItem = dialogList
        .where((dlg) => dlg.data.dialogId == msg.dialogId)
        .firstOrNull;
    if (dialogItem == null) return;

    setState(() {
      dialogItem.data.lastMessage = msg.body;
      dialogItem.data.lastMessageId = msg.messageId;

      if (msg.senderId != widget.currentUser.id) {
        dialogItem.data.unreadMessageCount =
            dialogItem.data.unreadMessageCount == null
                ? 1
                : dialogItem.data.unreadMessageCount! + 1;

        unreadMessages[msg.dialogId!] = <String>{
          ...unreadMessages[msg.dialogId] ?? [],
          msg.messageId!
        };

        dialogItem.data.lastMessageState = null;
      } else {
        dialogItem.data.lastMessageState = MessageState.sent;
      }

      dialogItem.data.lastMessageDateSent = msg.dateSent;
      sortDialogsList();
    });
  }

  void sortDialogsList() {
    dialogList.sort((a, b) {
      DateTime dateA;
      if (a.data.lastMessageDateSent != null) {
        dateA = DateTime.fromMillisecondsSinceEpoch(
            a.data.lastMessageDateSent! * 1000);
      } else {
        dateA = a.data.updatedAt!;
      }

      DateTime dateB;
      if (b.data.lastMessageDateSent != null) {
        dateB = DateTime.fromMillisecondsSinceEpoch(
            b.data.lastMessageDateSent! * 1000);
      } else {
        dateB = b.data.updatedAt!;
      }

      if (dateA.isAfter(dateB)) {
        return -1;
      } else if (dateA.isBefore(dateB)) {
        return 1;
      } else {
        return 0;
      }
    });
  }

  void onMessageDelivered(MessageStatus messageStatus) {
    _updateLastMessageState(messageStatus, MessageState.delivered);
  }

  void onMessageRead(MessageStatus messageStatus) {
    _updateLastMessageState(messageStatus, MessageState.read);

    if (messageStatus.userId == widget.currentUser.id &&
        unreadMessages.containsKey(messageStatus.dialogId)) {
      if (unreadMessages[messageStatus.dialogId]
              ?.remove(messageStatus.messageId) ??
          false) {
        setState(() {
          var dialog = dialogList
              .where((dlg) => dlg.data.dialogId == messageStatus.dialogId)
              .firstOrNull
              ?.data;

          if (dialog == null) return;

          dialog.unreadMessageCount = dialog.unreadMessageCount == null ||
                  dialog.unreadMessageCount == 0
              ? 0
              : dialog.unreadMessageCount! - 1;
        });
      }
    }
  }

  void _updateLastMessageState(
      MessageStatus messageStatus, MessageState state) {
    var dialog = dialogList
        .where((dlg) => dlg.data.dialogId == messageStatus.dialogId)
        .firstOrNull
        ?.data;

    if (dialog == null) return;

    if (messageStatus.messageId == dialog.lastMessageId &&
        messageStatus.userId != widget.currentUser.id) {
      if (dialog.lastMessageState != state) {
        setState(() {
          dialog.lastMessageState = state;
        });
      }
    }
  }
}

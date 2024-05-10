import 'package:chat_sample/src/utils/consts.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:flutter/material.dart';

import 'new_dialog_screen.dart';
import 'new_group_dialog_screen.dart';
import 'utils/route_utils.dart';

class CreateDialog extends StatelessWidget {
  final CubeUser currentUser;

  const CreateDialog(this.currentUser, {super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
        key: Navigation.createDialogNavigation,
        initialRoute: 'search_users',
        onGenerateRoute: (RouteSettings settings) {
          Map<String, dynamic>? args =
              settings.arguments as Map<String, dynamic>?;

          Widget page;

          switch (settings.name) {
            case 'search_users':
              page = CreateChatScreen(currentUser);
              break;
            case 'configure_group_dialog':
              page = NewGroupDialogScreen(
                args![userArgName],
                args[dialogArgName],
                args[selectedUsersArgName],
              );
              break;
            default:
              page = CreateChatScreen(args![userArgName]);
              break;
          }

          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => page,
          );
        });
  }
}

import 'package:chat_sample/src/utils/consts.dart';
import 'package:connectycube_sdk/src/core/users/models/cube_user.dart';
import 'package:flutter/material.dart';

import 'new_dialog_screen.dart';
import 'new_group_dialog_screen.dart';
import 'utils/route_utils.dart';

class CreateDialog extends StatelessWidget {
  final CubeUser currentUser;

  CreateDialog(this.currentUser);

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
                args![USER_ARG_NAME],
                args[DIALOG_ARG_NAME],
                args[SELECTED_USERS_ARG_NAME],
              );
              break;
            default:
              page = CreateChatScreen(args![USER_ARG_NAME]);
              break;
          }

          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => page,
          );
        });
  }
}

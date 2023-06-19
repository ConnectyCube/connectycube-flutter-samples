import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'add_occupant_screen.dart';
import 'chat_details_screen.dart';
import 'utils/consts.dart';
import 'utils/route_utils.dart';

class UpdateDialog extends StatelessWidget {
  final CubeUser currentUser;
  final CubeDialog currentDialog;

  UpdateDialog(this.currentUser, this.currentDialog);

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: Navigation.updateDialogNavigation,
      initialRoute: 'dialog_info',
      onGenerateRoute: (RouteSettings settings) {
        Map<String, dynamic>? args =
            settings.arguments as Map<String, dynamic>?;

        MaterialPageRoute pageRout;

        switch (settings.name) {
          case 'dialog_info':
            pageRout = MaterialPageRoute(
                builder: (context) =>
                    ChatDetailsScreen(currentUser, currentDialog));
            break;
          case 'search_users':
            pageRout = MaterialPageRoute<List<int>?>(
                builder: (context) => AddOccupantScreen(
                      args![USER_ARG_NAME],
                    ));
            break;
          default:
            pageRout = MaterialPageRoute(
                builder: (context) => ChatDetailsScreen(
                      args![USER_ARG_NAME],
                      args[DIALOG_ARG_NAME],
                    ));
            break;
        }

        return pageRout;
      },
    );
  }
}

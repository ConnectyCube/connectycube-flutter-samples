import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'add_occupant_screen.dart';
import 'chat_details_screen.dart';
import 'utils/consts.dart';
import 'utils/route_utils.dart';

class UpdateDialog extends StatelessWidget {
  final CubeUser currentUser;
  final CubeDialog currentDialog;

  const UpdateDialog(this.currentUser, this.currentDialog, {super.key});

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
                      args![userArgName],
                    ));
            break;
          default:
            pageRout = MaterialPageRoute(
                builder: (context) => ChatDetailsScreen(
                      args![userArgName],
                      args[dialogArgName],
                    ));
            break;
        }

        return pageRout;
      },
    );
  }
}

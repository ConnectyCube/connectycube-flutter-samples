import 'package:connectycube_sdk/connectycube_sdk.dart';

import '../config.dart';

Future<String> getUserNameCached(int userId) async {
  var cachedUser = users.where((user) => user.id == userId).firstOrNull;

  if (cachedUser != null) {
    return cachedUser.fullName ??
        cachedUser.login ??
        cachedUser.email ??
        cachedUser.id?.toString() ??
        'Unknown';
  } else {
    return getUserById(userId).then((cubeUser) {
      if (cubeUser != null) {
        users.add(cubeUser);
      }

      return cubeUser?.fullName ??
          cubeUser?.login ??
          cubeUser?.email ??
          cubeUser?.id?.toString() ??
          'Unknown';
    }).catchError((onError) {
      return 'Unknown';
    });
  }
}

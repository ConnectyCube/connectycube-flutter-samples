import 'package:conf_call_sample/src/utils/configs.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';

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

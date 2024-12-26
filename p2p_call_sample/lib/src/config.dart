import 'package:connectycube_sdk/connectycube_sdk.dart';

const String appId = 'REPLACE_APP_ID';
const String authKey = 'REPLACE_APP_AUTH_KEY';
const String authSecret = 'REPLACE_APP_AUTH_SECRET';

const String apiEndpoint = 'https://api.connectycube.com';
const String chatEndpoint = 'chat.connectycube.com';

List<CubeUser> users = [
  CubeUser(
    id: int.parse('REPLACE_USER_1_ID'),
    login: "REPLACE_USER_1_LOGIN",
    fullName: "REPLACE_USER_1_FULL_NAME",
    password: "REPLACE_USER_1_PASSWORD",
  ),
  CubeUser(
    id: int.parse('REPLACE_USER_2_ID'),
    login: "REPLACE_USER_2_LOGIN",
    fullName: "REPLACE_USER_2_FULL_NAME",
    password: "REPLACE_USER_2_PASSWORD",
  ),
  CubeUser(
    id: int.parse('REPLACE_USER_3_ID'),
    login: "REPLACE_USER_3_LOGIN",
    fullName: "REPLACE_USER_3_FULL_NAME",
    password: "REPLACE_USER_3_PASSWORD",
  ),
  CubeUser(
    id: int.parse('REPLACE_USER_4_ID'),
    login: "REPLACE_USER_4_LOGIN",
    fullName: "REPLACE_USER_4_FULL_NAME",
    password: "REPLACE_USER_4_PASSWORD",
  ),
];

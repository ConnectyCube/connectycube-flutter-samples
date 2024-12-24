import 'package:connectycube_sdk/connectycube_sdk.dart';

const String appId = "476";
const String authKey = "PDZjPBzAO8WPfCp";
const String authSecret = "6247kjxXCLRaua6";
const String apiEndpoint = 'https://api.connectycube.com';
const String chatEndpoint = 'chat.connectycube.com';

const String defaultPass = "xxasBUM3gQs36bhj";

List<CubeUser> users = [
  CubeUser(
    id: 1253158,
    login: "call_user_1",
    fullName: "User 1",
    password: defaultPass,
  ),
  CubeUser(
    id: 1253159,
    login: "call_user_2",
    fullName: "User 2",
    password: defaultPass,
  ),
  CubeUser(
    id: 1253160,
    login: "call_user_3",
    fullName: "User 3",
    password: defaultPass,
  ),
  CubeUser(
    id: 1253162,
    login: "call_user_4",
    fullName: "User 4",
    password: defaultPass,
  ),
];

import 'package:connectycube_sdk/connectycube_sdk.dart';

const String APP_ID = "476";
const String AUTH_KEY = "PDZjPBzAO8WPfCp";
const String AUTH_SECRET = "6247kjxXCLRaua6";
const String ACCOUNT_ID = "TpuBZox_HPxofh7PVZdP";
const String DEFAULT_PASS = "xxasBUM3gQs36bhj";
const String SERVER_ENDPOINT = "wss://janus.connectycube.com:8989";

List<CubeUser> users = [
  CubeUser(
    id: 1253158,
    login: "call_user_1",
    fullName: "User 1",
    password: DEFAULT_PASS,
  ),
  CubeUser(
    id: 1253159,
    login: "call_user_2",
    fullName: "User 2",
    password: DEFAULT_PASS,
  ),
  CubeUser(
    id: 1253160,
    login: "call_user_3",
    fullName: "User 3",
    password: DEFAULT_PASS,
  ),
  CubeUser(
    id: 1253162,
    login: "call_user_4",
    fullName: "User 4",
    password: DEFAULT_PASS,
  ),
];

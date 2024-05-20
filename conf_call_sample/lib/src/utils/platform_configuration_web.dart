import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void configureNavigation() {
  setUrlStrategy(PathUrlStrategy());
}

String getHostUrl() {
  return '${Uri.base.origin}/connectycube-flutter-samples/conf_call_sample/build/web';
}

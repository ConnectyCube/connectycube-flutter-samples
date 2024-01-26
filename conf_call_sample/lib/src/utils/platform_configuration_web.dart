import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void configureNavigation() {
  setUrlStrategy(PathUrlStrategy());
}

String getHostUrl() {
  return Uri.base.origin;
}

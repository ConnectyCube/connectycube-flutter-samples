import 'package:flutter/material.dart';

class Navigation {
  static GlobalKey<NavigatorState> mainNavigation = GlobalKey();
  static GlobalKey<NavigatorState> createDialogNavigation = GlobalKey();
  static GlobalKey<NavigatorState> updateDialogNavigation = GlobalKey();
  static GlobalKey<NavigatorState> verifyPhoneNavigation = GlobalKey();
}

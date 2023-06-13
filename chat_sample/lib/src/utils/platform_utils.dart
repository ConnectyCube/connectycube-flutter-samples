import 'package:universal_io/io.dart';

bool isDesktop() {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}

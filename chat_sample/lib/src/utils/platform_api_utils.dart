import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:file_picker/file_picker.dart';

Future<CubeFile> getUploadingMediaPlatformFuture(
    FilePickerResult result) async {
  throw UnsupportedError('No implementation provided for current platform');
}

Future<CubeFile> getUploadingFilePlatformFuture(
  String path,
  String mimeType,
  String fileName, {
  bool isPublic = true,
}) {
  throw UnsupportedError('No implementation provided for current platform');
}

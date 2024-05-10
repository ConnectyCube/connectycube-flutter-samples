import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_io/io.dart';

export 'platform_api_utils.dart';

Future<CubeFile> getUploadingMediaPlatformFuture(
    FilePickerResult result) async {
  return uploadFile(File(result.files.single.path!), isPublic: true,
      onProgress: (progress) {
    log('[getUploadingImagePlatformFuture] uploadImageFile progress= $progress');
  });
}

Future<CubeFile> getUploadingFilePlatformFuture(
  String path,
  String mimeType,
  String fileName, {
  bool isPublic = true,
}) {
  return uploadFile(File(path), isPublic: isPublic, onProgress: (progress) {
    log('[getUploadingFilePlatformFuture] uploadingIOPlatformFile progress= $progress');
  });
}

import 'dart:async';
import 'dart:html' as html;

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:file_picker/file_picker.dart';

export 'platform_api_utils.dart';

Future<CubeFile> getUploadingMediaPlatformFuture(
    FilePickerResult result) async {
  return uploadRawFile(result.files.single.bytes!, result.files.single.name,
      isPublic: true, onProgress: (progress) {
    log('[getUploadingImagePlatformFuture] uploadImageFile progress= $progress');
  });
}

Future<CubeFile> getUploadingFilePlatformFuture(
  String path,
  String mimeType,
  String fileName, {
  bool isPublic = true,
}) async {
  return html.HttpRequest.request(path, responseType: 'blob').then((request) {
    if (request.status == 200) {
      final html.Blob blobRaw = request.response;
      var blob = blobRaw.slice(0, blobRaw.size, mimeType);

      final html.FileReader reader = html.FileReader();

      var completer = Completer<List<int>>();

      reader.onLoadEnd.listen((_) {
        completer.complete(reader.result as List<int>);
      });

      reader.onError.listen((event) {
        completer.completeError('Error: ${reader.error?.message}');
      });

      reader.readAsArrayBuffer(blob);

      return completer.future.then((data) {
        return uploadRawFile(data, fileName,
            isPublic: isPublic, mimeType: mimeType, onProgress: (progress) {
          log('[getUploadingFilePlatformFuture] progress= $progress');
        });
      });
    } else {
      return Future.error('Can\'t load file from the blob data');
    }
  });
}

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'consts.dart';

bool canShowVideo(
    int? userId, MediaStream? mediaStream, Map<int, Map<String, bool>> config) {
  if (userId == null || mediaStream == null) return false;

  if (mediaStream.getVideoTracks().isEmpty) return false;

  var hasEnabledVideo = false;

  mediaStream.getVideoTracks().forEach((videoTrack) {
    if (!hasEnabledVideo && videoTrack.enabled) {
      hasEnabledVideo = true;
    }
  });

  return hasEnabledVideo && isUserCameraEnabled(userId, config);
}

bool isUserCameraEnabled(int userId, Map<int, Map<String, bool>> config,
    {bool defaultValue = false}) {
  return config[userId]?[PARAM_IS_CAMERA_ENABLED] ?? defaultValue;
}

int? getUserWithEnabledVideo(Map<int, RTCVideoRenderer> renderers,
    int currentUserId, Map<int, Map<String, bool>> config) {
  var resultUserId = -1;

  renderers.forEach((userId, renderer) {
    if ((resultUserId == -1 || resultUserId == currentUserId) &&
        canShowVideo(userId, renderer.srcObject, config)) {
      resultUserId = userId;
    }
  });

  return resultUserId == -1 ? null : resultUserId;
}

void chooseOpponentsStreamsQuality(ConferenceSession callSession,
    int currentUserId, Map<int, StreamType> config) {
  config.remove(currentUserId);

  if (config.isEmpty) return;

  callSession.requestPreferredStreamsForOpponents(config);
}

void updatePrimaryUser(
  int userId,
  bool force,
  int currentUserId,
  MapEntry<int, RTCVideoRenderer>? primaryRenderer,
  Map<int, RTCVideoRenderer> minorRenderers,
  Map<int, Map<String, bool>> participantsMediaConfigs, {
  required Function(MapEntry<int, RTCVideoRenderer>? primaryRenderer,
          Map<int, RTCVideoRenderer> minorRenderers)?
      onRenderersUpdated,
}) {
  if (!minorRenderers.containsKey(userId) ||
      userId == primaryRenderer?.key ||
      (userId == currentUserId && !force) ||
      getUserWithEnabledVideo(
              minorRenderers, currentUserId, participantsMediaConfigs) ==
          null) return;

  if (primaryRenderer?.key != userId) {
    minorRenderers.addEntries([primaryRenderer!]);
  }

  primaryRenderer = MapEntry(userId, minorRenderers.remove(userId)!);

  onRenderersUpdated?.call(primaryRenderer, minorRenderers);
}

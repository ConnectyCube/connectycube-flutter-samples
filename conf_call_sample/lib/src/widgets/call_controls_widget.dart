import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class CallControls extends StatelessWidget {
  final bool isMicMuted;
  final Function() onMute;

  final bool isCameraButtonVisible;
  final bool isCameraEnabled;
  final Function() onToggleCamera;

  final bool isScreenSharingButtonVisible;
  final bool isScreenSharingEnabled;
  final Function() onToggleScreenSharing;

  final bool isSpeakerEnabled;
  final Function() onSwitchSpeaker;

  final Function() onSwitchAudioInput;

  final bool isSwitchCameraButtonVisible;
  final Function() onSwitchCamera;

  final Function() onEndCall;

  const CallControls({
    super.key,
    required this.isMicMuted,
    required this.onMute,
    required this.isCameraButtonVisible,
    required this.isCameraEnabled,
    required this.onToggleCamera,
    required this.isScreenSharingButtonVisible,
    required this.isScreenSharingEnabled,
    required this.onToggleScreenSharing,
    required this.isSpeakerEnabled,
    required this.onSwitchSpeaker,
    required this.onSwitchAudioInput,
    required this.isSwitchCameraButtonVisible,
    required this.onSwitchCamera,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.all(
            Radius.circular(Theme.of(context).useMaterial3 ? 16 : 32)),
        child: Container(
          padding: const EdgeInsets.all(4),
          color: Colors.black26,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FloatingActionButton(
                  elevation: 0,
                  heroTag: "Mute",
                  onPressed: onMute,
                  backgroundColor: Colors.black38,
                  child: Icon(
                    isMicMuted ? Icons.mic_off : Icons.mic,
                    color: isMicMuted ? Colors.grey : Colors.white,
                  ),
                ),
              ),
              Visibility(
                visible: isCameraButtonVisible,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FloatingActionButton(
                    elevation: 0,
                    heroTag: "ToggleCamera",
                    onPressed: onToggleCamera,
                    backgroundColor: Colors.black38,
                    child: Icon(
                      isCameraEnabled ? Icons.videocam : Icons.videocam_off,
                      color: isCameraEnabled ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
              SpeedDial(
                heroTag: "Options",
                icon: Icons.more_vert,
                activeIcon: Icons.close,
                backgroundColor: Colors.black38,
                switchLabelPosition: true,
                overlayColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                overlayOpacity: 0.5,
                children: [
                  SpeedDialChild(
                    visible: isScreenSharingButtonVisible,
                    child: Icon(
                      isScreenSharingEnabled
                          ? Icons.stop_screen_share
                          : Icons.screen_share,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    label:
                        '${isScreenSharingEnabled ? 'Stop' : 'Start'} Screen Sharing',
                    onTap: onToggleScreenSharing,
                  ),
                  SpeedDialChild(
                    visible: !(kIsWeb &&
                        (Browser().browserAgent == BrowserAgent.Safari ||
                            Browser().browserAgent == BrowserAgent.Firefox)),
                    child: Icon(
                      kIsWeb || WebRTC.platformIsDesktop
                          ? Icons.surround_sound
                          : isSpeakerEnabled
                              ? Icons.volume_up
                              : Icons.volume_off,
                      color: isSpeakerEnabled ? Colors.white : Colors.grey,
                    ),
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    label:
                        'Switch ${kIsWeb || WebRTC.platformIsDesktop ? 'Audio output' : 'Speakerphone'}',
                    onTap: onSwitchSpeaker,
                  ),
                  SpeedDialChild(
                    visible: kIsWeb || WebRTC.platformIsDesktop,
                    child: const Icon(
                      Icons.record_voice_over,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    label: 'Switch Audio Input device',
                    onTap: onSwitchAudioInput,
                  ),
                  SpeedDialChild(
                    visible: isSwitchCameraButtonVisible,
                    child: Icon(
                      Icons.cameraswitch,
                      color: isCameraEnabled ? Colors.white : Colors.grey,
                    ),
                    backgroundColor: Colors.black38,
                    foregroundColor: Colors.white,
                    label: 'Switch Camera',
                    onTap: onSwitchCamera,
                  ),
                ],
              ),
              const Expanded(
                flex: 1,
                child: SizedBox(),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 0),
                child: FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: onEndCall,
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

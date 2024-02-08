import 'package:flutter/material.dart';

import '../utils/duration_timer.dart';
import '../utils/string_utils.dart';

class CallInfo extends StatelessWidget {
  final String callName;
  final String callStatus;
  final DurationTimer callTimer;

  CallInfo(this.callName, this.callStatus, this.callTimer);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          callName,
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            decoration: TextDecoration.none,
            shadows: [
              Shadow(
                color: Colors.grey.shade900,
                offset: Offset(2, 1),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        Text(
          callStatus,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            decoration: TextDecoration.none,
            shadows: [
              Shadow(
                color: Colors.grey.shade900,
                offset: Offset(2, 1),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        StreamBuilder<int>(
            stream: callTimer.durationStream,
            builder: (context, snapshot) {
              return Text(
                snapshot.hasData ? formatHHMMSS(snapshot.data!) : '00:00',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                  shadows: [
                    Shadow(
                      color: Colors.grey.shade900,
                      offset: Offset(2, 1),
                      blurRadius: 12,
                    ),
                  ],
                ),
              );
            })
      ],
    );
  }
}

// lib/widgets/listening_overlay.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_service.dart';
import 'package:sizer/sizer.dart';

class ListeningOverlay extends StatefulWidget {
  final String titleText;
  const ListeningOverlay({Key? key, this.titleText = 'Listening...'}) : super(key: key);

  @override
  State<ListeningOverlay> createState() => _ListeningOverlayState();
}

class _ListeningOverlayState extends State<ListeningOverlay> {
  @override
  void initState() {
    super.initState();
    // nothing to kick off here; parent starts captureNoteInteractive separately
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceService>();
    final transcript = voice.lastTranscript;
    final listening = voice.listening;

    return WillPopScope(
      onWillPop: () async {
        // prevent back button from popping accidentally; require explicit cancel/stop
        return false;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              children: [
                Expanded(child: Text(widget.titleText, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp))),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white70),
                  onPressed: () async {
                    // Cancel: stop listening and close
                    await voice.stopCurrentListen();
                    if (mounted) Navigator.of(context, rootNavigator: true).pop(false);
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: 12.h),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text(
                  transcript.isNotEmpty ? transcript : (listening ? 'Listening...' : 'Ready'),
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: listening
                        ? () async {
                      // Stop -> finalize current listen, then close
                      await voice.stopCurrentListen();
                      if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
                    }
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // Cancel (same as close)
                      await voice.stopCurrentListen();
                      if (mounted) Navigator.of(context, rootNavigator: true).pop(false);
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  ),
                )
              ],
            )
          ]),
        ),
      ),
    );
  }
}

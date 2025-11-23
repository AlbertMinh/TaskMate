// lib/services/voice_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt_result;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

typedef TranscriptCallback = void Function(String text);

class VoiceService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _available = false;
  bool get available => _available;

  bool _listening = false;
  bool get listening => _listening;

  String lastTranscript = '';
  String lastError = '';

  Completer<String>? _listenCompleter;
  bool _internalStopRequested = false;

  VoiceService() {
    _initTts();
    _init();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(0.9);
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('[VoiceService] tts init error: $e');
    }
  }
  Future<void> stopCurrentListen() async {
    try {
      debugPrint('[VoiceService] stopCurrentListen called');
      _internalStopRequested = true;
      if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
        // return whatever transcript we have so far (may be empty)
        _listenCompleter!.complete(lastTranscript);
      }
      // attempt to stop recognition engine
      await _speech.stop();
    } catch (e) {
      debugPrint('[VoiceService] stopCurrentListen error: $e');
    } finally {
      _listening = false;
      _internalStopRequested = false;
      notifyListeners();
    }
  }

  Future<void> _init() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _available = false;
        notifyListeners();
        return;
      }

      _available = await _speech.initialize(
        onStatus: (s) {
          debugPrint('[VoiceService] stt status: $s');
          if (s == 'listening') {
            _listening = true;
            notifyListeners();
          } else {
            _listening = false;
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('[VoiceService] stt error: $e');
          lastError = e.toString();
          _listening = false;
          notifyListeners();
        },
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[VoiceService] init error: $e');
      _available = false;
      notifyListeners();
    }
  }

  Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[VoiceService] speak error: $e');
    }
  }

  /// Play a short system sound + haptic for start/stop feedback
  Future<void> _playStartFeedback() async {
    try {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  Future<void> _playStopFeedback() async {
    try {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Single-shot speech capture.
  Future<String> listenOnce({int listenForSeconds = 6, required int pauseForSeconds, String? localeId}) async {
    if (!_available) {
      debugPrint('[VoiceService] listenOnce: speech not available');
      return '';
    }
    if (_listening) {
      debugPrint('[VoiceService] already listening');
      return '';
    }

    _listenCompleter = Completer<String>();
    lastTranscript = '';
    _internalStopRequested = false;
    _listening = true;
    notifyListeners();

    httpStopSafety() async {
      // safety timeout to ensure completer completes
      await Future.delayed(Duration(seconds: listenForSeconds + 1));
      if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
        _listenCompleter!.complete(lastTranscript);
      }
    }

    try {
      await _speech.listen(
        onResult: (stt_result.SpeechRecognitionResult r) {
          lastTranscript = r.recognizedWords ?? '';
          // final result
          if (r.finalResult) {
            if (_listenCompleter != null && !_listenCompleter!.isCompleted) {
              _listenCompleter!.complete(lastTranscript);
            }
          }
        },
        listenFor: Duration(seconds: listenForSeconds),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'en_US',
      );

      // start safety timeout
      httpStopSafety();
    } catch (e) {
      debugPrint('[VoiceService] listen start error: $e');
      if (_listenCompleter != null && !_listenCompleter!.isCompleted) _listenCompleter!.complete('');
    }

    // Wait for result or external stop
    String result = '';
    try {
      result = await _listenCompleter!.future.timeout(Duration(seconds: listenForSeconds + 2), onTimeout: () {
        return lastTranscript;
      });
    } catch (e) {
      // Completed by external stop or timeout
      result = lastTranscript;
    }

    try {
      await _speech.stop();
    } catch (_) {}
    _listening = false;
    notifyListeners();
    return result ?? '';
  }


  /// Interactive capture: title then description.
  /// - retriesTitle: max attempts for title (default 2 retries)
  /// - description listen window is long (default 40s)
  Future<Map<String, String>> captureNoteInteractive({
    bool speakPrompts = true,
    Function(String)? onPrompt,
    int titleListenFor = 8,
    int titlePauseFor = 4,
    int descListenFor = 40, // increased
    int descPauseFor = 5,
    int retriesTitle = 2,
    String? localeId,
  }) async {
    final out = {'title': '', 'description': ''};
    if (!_available) {
      debugPrint('[VoiceService] capture: not available');
      return out;
    }

    int attempts = 0;
    String title = '';

    while (attempts <= retriesTitle) {
      attempts += 1;
      onPrompt?.call('Listening for title (attempt $attempts)...');
      if (speakPrompts) await speak('Please say the title of the note now.');
      title = (await listenOnce(listenForSeconds: titleListenFor, pauseForSeconds: titlePauseFor, localeId: localeId)).trim();

      if (title.isNotEmpty) break;

      // title empty -> ask retry
      onPrompt?.call('No title detected');
      if (speakPrompts) await speak('I did not hear a title. Would you like to try again? Say yes to retry or no to cancel.');

      final ans = (await listenOnce(listenForSeconds: 4, pauseForSeconds: 2, localeId: localeId)).trim().toLowerCase();
      if (ans.contains('yes') || ans.contains('yeah') || ans.contains('retry') || ans.contains('sure')) {
        continue; // retry loop
      } else {
        // cancel
        if (speakPrompts) await speak('Okay, cancelling note creation.');
        return out;
      }
    }

    if (title.isEmpty) {
      // exhausted attempts
      onPrompt?.call('No title after attempts');
      if (speakPrompts) await speak('Could not detect a title. Cancelling.');
      return out;
    }

    out['title'] = title;

    // Description step
    onPrompt?.call('Listening for description...');
    if (speakPrompts) await speak('Now say the description. Say no description to skip. You have up to 40 seconds.');
    final description = (await listenOnce(listenForSeconds: descListenFor, pauseForSeconds: descPauseFor, localeId: localeId)).trim();

    if (description.isEmpty) {
      out['description'] = '';
    } else {
      final low = description.toLowerCase();
      if (low == 'no' || low.contains('no description') || low == 'none') {
        out['description'] = '';
      } else {
        out['description'] = description;
      }
    }

    return out;
  }

  // Foreground wake phrase listener (checks partial results for phrase)
  bool _wakeListening = false;
  String _wakePhrase = 'write a note';
  VoidCallback? _onWakeDetected;

  Future<void> startWakeForeground({String wakePhrase = 'write a note'}) async {
    if (!_available) return;
    if (_wakeListening) return;
    _wakeListening = true;
    _wakePhrase = wakePhrase.toLowerCase();

    try {
      await _speech.listen(
        onResult: (r) {
          final txt = (r.recognizedWords ?? '').toLowerCase();
          lastTranscript = txt;
          notifyListeners();
          if (txt.contains(_wakePhrase)) {
            _wakeListening = false;
            try {
              _speech.stop();
            } catch (_) {}
            if (_onWakeDetected != null) _onWakeDetected!();
          }
        },
        listenFor: const Duration(seconds: 120),
        partialResults: true,
      );
    } catch (e) {
      debugPrint('[VoiceService] startWakeForeground error: $e');
      _wakeListening = false;
    }
  }

  Future<void> stopWakeForeground() async {
    if (!_wakeListening) return;
    try {
      await _speech.stop();
    } catch (e) {}
    _wakeListening = false;
  }

  void setOnWakeDetected(VoidCallback cb) => _onWakeDetected = cb;

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
    try {
      _speech.stop();
    } catch (_) {}
    super.dispose();
  }
}

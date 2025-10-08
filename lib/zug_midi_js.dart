import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

// ==============================
// === JS Function Bindings ====
// ==============================

// Init / Tempo
@JS('initAudio')
external void _initAudio(JSFunction callback);

@JS('setTempo')
external void _setTempo(num t);

// Instruments / Drums
@JS('setInstrument')
external JSAny? _setInstrument(JSString type, int patch, JSFunction callback);

@JS('setDrumKit')
external JSAny? _setDrumKit(JSString type, int patch, JSFunction callback);

// Playback
@JS('playNote')
external JSAny? _playNote(int i, num t, int p, num d, num volume);

@JS('playMelody')
external JSAny? _playMelody(int i, num t, int p, num volume);

@JS('playChord')
external JSAny? _playChord(int i, num t, JSArray pitches, num d, num volume);

@JS('playDrum')
external JSAny? _playDrum(int i, num t, num d, num volume);

// (Optional future-proofed Promise-returning API)
@JS('fetchInstrument') // Example: if you add async JS methods later
external JSPromise _fetchInstrument(JSString name);

// ==============================
// === Dart Wrappers ============
// ==============================

Future<void> initAudio() async {
  final completer = Completer<void>();
  final callback = (() => completer.complete()).toJS;
  _initAudio(callback);
  await completer.future;
}

void setTempo(double bpm) => _setTempo(bpm);

Future<void> setInstrument(String type, int patch) async {
  final completer = Completer<void>();
  final callback = ((JSAny type, JSAny patch) => completer.complete()).toJS;
  _setInstrument(type.toJS, patch, callback);
  await completer.future;
}

Future<void> setDrumKit(String type, int patch) async {
  final completer = Completer<void>();
  final callback = ((JSAny type, JSAny patch) => completer.complete()).toJS;
  _setDrumKit(type.toJS, patch, callback);
  await completer.future;
}

// --- Playback ---

void playNote(int instrument, double startTime, int pitch, double duration, double volume) {
  _playNote(instrument, startTime, pitch, duration, volume);
}

void playChord(int instrument, double startTime, List<int> pitches, double duration, double volume) {
  final jsArray = JSArray.from(pitches.map((p) => p.toJS) as JSObject);
  _playChord(instrument, startTime, jsArray, duration, volume);
}

void playDrum(int drumIndex, double startTime, double duration, double volume) {
  _playDrum(drumIndex, startTime, duration, volume);
}

// --- Optional: Example of async JS interop (Promises) ---

Future<void> fetchInstrument(String name) async {
  // If you define in JS:
  // async function fetchInstrument(name) { await someFetch(); }
  await _fetchInstrument(name.toJS).toDart;
}

// ==============================
// === Dart-Side Queue System ===
// ==============================

class QueuedNote {
  final int instrument;
  final List<int> pitches;
  final double duration;
  final double volume;

  QueuedNote(this.instrument, this.pitches, this.duration, this.volume);
}

class DartMelodizer {
  final _noteQueue = <QueuedNote>[];
  final _random = Random();
  bool _running = false;
  double tempoMultiplier = 1.0;

  void addNote(int instrument, int pitch, double duration, double volume) {
    _noteQueue.add(QueuedNote(instrument, [pitch], duration, volume));
  }

  void addChord(int instrument, List<int> pitches, double duration, double volume) {
    _noteQueue.add(QueuedNote(instrument, pitches, duration, volume));
  }

  void start() {
    if (_running) return;
    _running = true;
    _processQueue();
  }

  void stop() {
    _running = false;
  }

  void _processQueue() async {
    while (_running) {
      if (_noteQueue.isNotEmpty) {
        final note = _noteQueue.removeAt(0);
        final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
        playChord(note.instrument, now, note.pitches, note.duration, note.volume);

        final waitTime = note.duration * tempoMultiplier * 1000;
        await Future.delayed(Duration(milliseconds: waitTime.toInt()));
      } else {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }
}

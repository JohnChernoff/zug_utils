/// ZugMusic - A unified music theory and MIDI library for Dart/Flutter
library zug_music;

import 'dart:math' as math;

// ============================================================================
// Constants
// ============================================================================

const int octave = 12;
const int defMinPitch = 12;
const int defMaxPitch = 127;

// ============================================================================
// ZugNote Enum (replaces MidiNote)
// ============================================================================

enum ZugNote {
  noteC,
  noteDb,
  noteD,
  noteEb,
  noteE,
  noteF,
  noteGb,
  noteG,
  noteAb,
  noteA,
  noteBb,
  noteB;

  /// Get a display-friendly name for the note
  String get displayName => toString().replaceAll('note', '');

  /// Get the chromatic value (0-11)
  int get chromaticValue => index;
}

// ============================================================================
// Scale Enum with Intervals
// ============================================================================

enum Scale {
  // Traditional scales
  majorScale([2, 2, 1, 2, 2, 2, 1]),
  naturalMinorScale([2, 1, 2, 2, 1, 2, 2]),
  harmonicMinorScale([2, 1, 2, 2, 1, 3, 1]),
  melodicMinorScale([2, 1, 2, 2, 2, 2, 1]),

  // Pentatonic scales
  pentatonicMajorScale([2, 2, 3, 2, 3]),
  pentatonicMinorScale([3, 2, 2, 3, 2]),

  // Blues and special scales
  bluesScale([3, 2, 1, 1, 3, 2]),

  // Modal scales
  dorianScale([2, 1, 2, 2, 2, 1, 2]),
  phrygianScale([1, 2, 2, 2, 1, 2, 2]),
  lydianScale([2, 2, 2, 1, 2, 2, 1]),
  mixolydianScale([2, 2, 1, 2, 2, 1, 2]),
  locrianScale([1, 2, 2, 1, 2, 2, 2]),

  // Chromatic
  chromaticScale([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]);

  final List<int> intervals;

  const Scale(this.intervals);

  /// Find the scale degree for a given chromatic degree
  Degree findScaleDegree(int chromaticDegree) {
    int p = 0;
    int interval = 0;
    for (int i in intervals) {
      if (p >= chromaticDegree) return Degree(p, interval);
      p += i;
      interval++;
    }
    return Degree(p, interval);
  }

  /// Get the number of notes in the scale
  int get length => intervals.length;

  /// Calculate which scale degree a pitch belongs to in this scale
  /// Returns -1 if the pitch is not in the scale
  int calcScaleDegree(int pitch, ZugNote rootNote) {
    int pitchClass = pitch % octave;
    int rootClass = rootNote.index;
    int relativePitch = (pitchClass - rootClass + octave) % octave;

    int currentPitch = 0;
    for (int degree = 0; degree < intervals.length; degree++) {
      if (currentPitch == relativePitch) return degree;
      currentPitch += intervals[degree];
    }
    return -1; // Not in scale
  }
}

// ============================================================================
// Data Classes
// ============================================================================

/// Represents a degree in a scale (chromatic and scale degree)
class Degree {
  final int chromaticDegree;
  final int scaleDegree;

  const Degree(this.chromaticDegree, this.scaleDegree);

  @override
  String toString() => 'Degree(chromatic: $chromaticDegree, scale: $scaleDegree)';
}

// ============================================================================
// ZugPitch Class
// ============================================================================

class ZugPitch {
  int _pitch;
  final int minPitch;
  final int maxPitch;

  ZugPitch(int pitch, {this.minPitch = defMinPitch, this.maxPitch = defMaxPitch})
      : _pitch = 0 {
    _pitch = attenuatePitch(pitch);
  }

  /// Get the current pitch value (MIDI note number)
  int get pitch => _pitch;

  /// Set the pitch value (with attenuation)
  set pitch(int value) {
    _pitch = attenuatePitch(value);
  }

  /// Constrain pitch to min/max range
  int attenuatePitch(int p) {
    return p.clamp(minPitch, maxPitch);
  }

  /// Set pitch to the middle of the range
  void setMiddlePitch() {
    _pitch = minPitch + ((maxPitch - minPitch) ~/ 2);
  }

  /// Get the note name for this pitch
  ZugNote get note => ZugNote.values[_pitch % octave];

  /// Get the octave number (MIDI standard: middle C is octave 4)
  int get octaveNumber => (_pitch ~/ octave) - 1;

  /// Transpose the pitch by a number of semitones
  ZugPitch transpose(int semitones) {
    return ZugPitch(_pitch + semitones, minPitch: minPitch, maxPitch: maxPitch);
  }

  /// Create a copy of this pitch
  ZugPitch copy() {
    return ZugPitch(_pitch, minPitch: minPitch, maxPitch: maxPitch);
  }

  /// Check if two pitches are the same note (ignoring octave)
  bool samePitchClass(ZugPitch other) {
    return (_pitch % octave) == (other._pitch % octave);
  }

  @override
  String toString() => '$_pitch:${note.displayName}$octaveNumber';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ZugPitch && runtimeType == other.runtimeType && _pitch == other._pitch;

  @override
  int get hashCode => _pitch.hashCode;
}

// ============================================================================
// ZugKey Class (Musical Key with Scale)
// ============================================================================

class ZugKey {
  final ZugNote keyNote;
  final Scale keyScale;

  const ZugKey(this.keyNote, this.keyScale);

  /// Get the next pitch by moving a number of steps in the scale
  ZugPitch getNextPitch(ZugPitch currentPitch, int steps) {
    int chromaticDegree = (currentPitch.pitch % octave) - keyNote.index;
    if (chromaticDegree < 0) chromaticDegree += octave;

    Degree degree = keyScale.findScaleDegree(chromaticDegree);
    int nextPitch = currentPitch.pitch;
    nextPitch += (degree.chromaticDegree - chromaticDegree);

    int id = steps > 0 ? 1 : -1;
    for (int step = 0; steps > 0 ? step < steps : step > steps; step += id) {
      int v = degree.scaleDegree + step;
      int i = (v % keyScale.intervals.length).abs();
      if (v <= 0) i = keyScale.intervals.length - i - 1;
      nextPitch += steps > 0 ? keyScale.intervals[i] : -keyScale.intervals[i];
    }

    return ZugPitch(nextPitch,
        minPitch: currentPitch.minPitch, maxPitch: currentPitch.maxPitch);
  }

  /// Get all pitches in the scale within a given range
  List<ZugPitch> getScalePitches({int startPitch = 60, int octaves = 1}) {
    List<ZugPitch> pitches = [];
    ZugPitch current = ZugPitch(startPitch);
    pitches.add(current);

    int totalSteps = keyScale.length * octaves;
    for (int i = 1; i <= totalSteps; i++) {
      current = getNextPitch(current, 1);
      pitches.add(current);
    }

    return pitches;
  }

  /// Check if a pitch is in this key/scale
  bool containsPitch(ZugPitch pitch) {
    return keyScale.calcScaleDegree(pitch.pitch, keyNote) >= 0;
  }

  /// Get the scale degree of a pitch in this key (0-based)
  /// Returns -1 if not in scale
  int getScaleDegree(ZugPitch pitch) {
    return keyScale.calcScaleDegree(pitch.pitch, keyNote);
  }

  @override
  String toString() => '${keyNote.displayName} ${keyScale.name}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ZugKey &&
              runtimeType == other.runtimeType &&
              keyNote == other.keyNote &&
              keyScale == other.keyScale;

  @override
  int get hashCode => keyNote.hashCode ^ keyScale.hashCode;
}

// ============================================================================
// ZugMelody Class
// ============================================================================

class ZugMelody extends ZugPitch {
  double currentTick = 0;
  final List<int> pitchHistory = [];
  final List<double> durationHistory = [];

  ZugMelody(super.pitch, {super.minPitch, super.maxPitch});

  /// Set pitch from another ZugPitch object
  void setPitchFrom(ZugPitch p) {
    pitch = p.pitch;
  }

  /// Add a note to the melody history
  void addNote(int pitch, double duration) {
    pitchHistory.add(pitch);
    durationHistory.add(duration);
    currentTick += duration;
  }

  /// Reset the melody
  void reset() {
    currentTick = 0;
    pitchHistory.clear();
    durationHistory.clear();
    setMiddlePitch();
  }

  /// Get the total duration of the melody
  double get totalDuration => currentTick;

  /// Get the number of notes in the melody
  int get noteCount => pitchHistory.length;

  /// Get the pitch at a specific index in history
  int? getPitchAt(int index) {
    if (index >= 0 && index < pitchHistory.length) {
      return pitchHistory[index];
    }
    return null;
  }

  /// Get the duration at a specific index in history
  double? getDurationAt(int index) {
    if (index >= 0 && index < durationHistory.length) {
      return durationHistory[index];
    }
    return null;
  }

  /// Get all notes as a list of (pitch, duration) pairs
  List<(int, double)> getNotes() {
    List<(int, double)> notes = [];
    for (int i = 0; i < noteCount; i++) {
      notes.add((pitchHistory[i], durationHistory[i]));
    }
    return notes;
  }

  @override
  String toString() {
    return 'ZugMelody(current: ${super.toString()}, notes: $noteCount, duration: $totalDuration)';
  }
}

// ============================================================================
// ZugChord Class
// ============================================================================

enum ChordType {
  // Triads
  major([0, 4, 7]),
  minor([0, 3, 7]),
  diminished([0, 3, 6]),
  augmented([0, 4, 8]),
  sus2([0, 2, 7]),
  sus4([0, 5, 7]),

  // Seventh chords
  major7([0, 4, 7, 11]),
  minor7([0, 3, 7, 10]),
  dominant7([0, 4, 7, 10]),
  diminished7([0, 3, 6, 9]),
  halfDiminished7([0, 3, 6, 10]),
  minorMajor7([0, 3, 7, 11]),
  augmented7([0, 4, 8, 10]),

  // Extended chords
  major9([0, 4, 7, 11, 14]),
  minor9([0, 3, 7, 10, 14]),
  dominant9([0, 4, 7, 10, 14]);

  final List<int> intervals;

  const ChordType(this.intervals);

  /// Get the number of notes in the chord
  int get noteCount => intervals.length;
}

class ZugChord {
  final ZugPitch root;
  final ChordType type;

  ZugChord(this.root, this.type);

  /// Constructor from MIDI note number
  ZugChord.fromMidi(int midiNote, this.type)
      : root = ZugPitch(midiNote);

  /// Constructor from note and octave
  ZugChord.fromNote(ZugNote note, int octave, this.type)
      : root = ZugPitch((octave + 1) * 12 + note.index);

  /// Get all pitches in the chord
  List<ZugPitch> getPitches() {
    return type.intervals
        .map((interval) => root.transpose(interval))
        .toList();
  }

  /// Get all MIDI note numbers in the chord
  List<int> getMidiNotes() {
    return type.intervals
        .map((interval) => root.pitch + interval)
        .toList();
  }

  /// Invert the chord (move bottom note up an octave)
  ZugChord invert([int inversions = 1]) {
    // This would require a more complex implementation
    // For now, return the same chord
    return this;
  }

  @override
  String toString() => '${root.note.displayName} ${type.name}';
}

// ============================================================================
// ZugProgression Class (Chord Progression)
// ============================================================================

class ZugProgression {
  final ZugKey key;
  final List<(ChordType, int)> progression; // (chord type, scale degree)

  ZugProgression(this.key, this.progression);

  /// Common progressions
  static ZugProgression iiVI(ZugKey key) {
    return ZugProgression(key, [
      (ChordType.minor7, 2),
      (ChordType.dominant7, 5),
      (ChordType.major7, 1),
    ]);
  }

  static ZugProgression iVviIV(ZugKey key) {
    return ZugProgression(key, [
      (ChordType.major, 1),
      (ChordType.major, 5),
      (ChordType.minor, 6),
      (ChordType.major, 4),
    ]);
  }

  static ZugProgression blues(ZugKey key) {
    return ZugProgression(key, [
      (ChordType.dominant7, 1),
      (ChordType.dominant7, 4),
      (ChordType.dominant7, 1),
      (ChordType.dominant7, 5),
      (ChordType.dominant7, 4),
      (ChordType.dominant7, 1),
    ]);
  }

  /// Get the chords in the progression
  List<ZugChord> getChords() {
    List<ZugChord> chords = [];
    List<ZugPitch> scalePitches = key.getScalePitches(startPitch: 60, octaves: 1);

    for (var (chordType, degree) in progression) {
      if (degree > 0 && degree <= scalePitches.length) {
        chords.add(ZugChord(scalePitches[degree - 1], chordType));
      }
    }

    return chords;
  }
}

// ============================================================================
// ZugRhythm Class
// ============================================================================

class ZugRhythm {
  final List<double> pattern; // Duration values (e.g., 1.0 = quarter note)
  int currentIndex = 0;

  ZugRhythm(this.pattern);

  /// Common rhythm patterns
  static ZugRhythm quarter() => ZugRhythm([1.0]);
  static ZugRhythm eighth() => ZugRhythm([0.5, 0.5]);
  static ZugRhythm dotted() => ZugRhythm([0.75, 0.25]);
  static ZugRhythm swing() => ZugRhythm([0.67, 0.33]);
  static ZugRhythm triplet() => ZugRhythm([0.33, 0.33, 0.34]);

  /// Get the next duration in the pattern
  double next() {
    double duration = pattern[currentIndex];
    currentIndex = (currentIndex + 1) % pattern.length;
    return duration;
  }

  /// Reset to the beginning of the pattern
  void reset() {
    currentIndex = 0;
  }

  /// Get total duration of one complete pattern
  double get totalDuration {
    return pattern.reduce((a, b) => a + b);
  }
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Get note from a pitch value
ZugNote getNote(ZugPitch pitch) {
  return ZugNote.values[pitch.pitch % octave];
}

/// Get note from a MIDI number
ZugNote getNoteFromMidi(int midiNote) {
  return ZugNote.values[midiNote % octave];
}

/// Check if two pitches represent the same note (ignoring octave)
bool samePitchClass(int pitch1, int pitch2) {
  return (pitch1 % octave) == (pitch2 % octave);
}

/// Convert MIDI note number to frequency in Hz
double midiToFrequency(int midiNote) {
  return 440.0 * math.pow(2.0, (midiNote - 69) / 12.0);
}

/// Convert frequency to nearest MIDI note number
int frequencyToMidi(double frequency) {
  return (69 + 12 * math.log(frequency / 440.0) / math.log(2.0)).round();
}

/// Get a random note
ZugNote getRandomNote([math.Random? rng]) {
  rng ??= math.Random();
  return ZugNote.values[rng.nextInt(ZugNote.values.length)];
}

/// Get a random note different from the current one
ZugNote getNewNote(ZugNote currentNote, [math.Random? rng]) {
  rng ??= math.Random();
  ZugNote newNote;
  do {
    newNote = ZugNote.values[rng.nextInt(ZugNote.values.length)];
  } while (newNote == currentNote);
  return newNote;
}

/// Get a random scale different from the current one
Scale getNewScale(Scale? currentScale, [math.Random? rng]) {
  rng ??= math.Random();
  Scale newScale;
  do {
    newScale = Scale.values[rng.nextInt(Scale.values.length)];
  } while (newScale == currentScale);
  return newScale;
}

/// Debug logging
void log(String msg) {
  print(msg);
}

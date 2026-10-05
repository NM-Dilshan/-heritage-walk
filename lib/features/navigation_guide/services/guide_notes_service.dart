import 'package:flutter/foundation.dart';

import '../models/guide_note.dart';

class GuideNotesService extends ChangeNotifier {
  final Map<String, GuideNote> _notes = {};
  int _sequence = 0;
  List<GuideNote> get allNotes => List.unmodifiable(_notes.values);
  void restore(Iterable<GuideNote> notes) {
    _notes.clear();
    for (final note in notes) {
      _notes[note.id] = note;
    }
    notifyListeners();
  }

  static String? validate(String? text) {
    if (text == null || text.trim().isEmpty) return 'Enter a note';
    if (text.trim().length > 500) return 'Use no more than 500 characters';
    return null;
  }

  List<GuideNote> forPlace(String placeId) =>
      List.unmodifiable(_notes.values.where((note) => note.placeId == placeId));
  GuideNote add(String placeId, String text) {
    if (placeId.trim().isEmpty || validate(text) != null) {
      throw ArgumentError(
        'A place and non-empty note (up to 500 characters) are required.',
      );
    }
    final now = DateTime.now();
    final note = GuideNote(
      id: 'note-${now.microsecondsSinceEpoch}-${_sequence++}',
      placeId: placeId,
      text: text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _notes[note.id] = note;
    notifyListeners();
    return note;
  }

  void update(String id, String text) {
    final note = _notes[id];
    if (note == null || validate(text) != null) {
      throw ArgumentError('A valid existing note is required.');
    }
    _notes[id] = note.updated(text.trim(), DateTime.now());
    notifyListeners();
  }

  void delete(String id) {
    if (_notes.remove(id) != null) notifyListeners();
  }

  void clear() {
    _notes.clear();
    notifyListeners();
  }
}

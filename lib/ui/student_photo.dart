/// Choosing the player's own photo for the Student ID.
///
/// The picked image is copied into `<documents>/student_photos/` so it
/// outlives the gallery entry; the absolute path is stored on the run
/// (`GameState.studentPhotoPath`) and in its History record
/// (`RunRecord.studentPhoto`).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class StudentPhotos {
  StudentPhotos._();

  /// Tests replace the whole pick-and-copy step.
  @visibleForTesting
  static Future<String?> Function()? pickOverride;

  /// Opens the gallery and returns the stored copy's path, or null when the
  /// player cancelled or nothing could be stored.
  static Future<String?> pick() async {
    final override = pickOverride;
    if (override != null) return override();
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked == null) return null;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/student_photos');
      await dir.create(recursive: true);
      final dot = picked.path.lastIndexOf('.');
      final ext = dot > picked.path.lastIndexOf(RegExp(r'[\\/]')) && dot > 0
          ? picked.path.substring(dot)
          : '.jpg';
      final copy = File(
        '${dir.path}/photo_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(picked.path).copy(copy.path);
      return copy.path;
    } catch (_) {
      return null;
    }
  }
}

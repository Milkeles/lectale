part of '../ipynb.dart';

/// Preview budgets for parsing untrusted notebooks (V4-SEC-03).
final class NotebookLimits {
  /// Sets non-negative limits. Zero allows no bytes or entries of that kind.
  ///
  /// The defaults use binary units (1024 bytes per KiB).
  const NotebookLimits({
    this.maxInputBytes = 20 * 1024 * 1024,
    this.maxCells = 2000,
    this.maxOutputsPerCell = 100,
    this.maxTextBytesPerOutput = 200 * 1024,
    this.maxImageBytes = 10 * 1024 * 1024,
  }) : assert(maxInputBytes >= 0, 'maxInputBytes must be non-negative'),
       assert(maxCells >= 0, 'maxCells must be non-negative'),
       assert(maxOutputsPerCell >= 0, 'maxOutputsPerCell must be non-negative'),
       assert(
         maxTextBytesPerOutput >= 0,
         'maxTextBytesPerOutput must be non-negative',
       ),
       assert(maxImageBytes >= 0, 'maxImageBytes must be non-negative');

  /// Maximum UTF-8 input size, checked before decoding or parsing.
  final int maxInputBytes;

  /// Maximum number of leading cells retained in notebook order.
  final int maxCells;

  /// Maximum stored outputs per code cell, including unsupported MIME markers.
  final int maxOutputsPerCell;

  /// Maximum UTF-8 bytes retained across the textual fields of one output.
  final int maxTextBytesPerOutput;

  /// Maximum decoded bytes of an individual PNG or JPEG, including attachments.
  final int maxImageBytes;
}

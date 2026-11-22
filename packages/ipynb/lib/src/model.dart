part of '../ipynb.dart';

/// An immutable static preview of an nbformat 4 notebook (V4-CORE-05).
final class Notebook {
  Notebook._({
    required this.language,
    required Iterable<Cell> cells,
    required this.truncated,
  }) : cells = List.unmodifiable(cells);

  /// The language from notebook metadata, or null if missing or over 128 bytes.
  final String? language;

  /// Cells in notebook order, within [NotebookLimits.maxCells].
  final List<Cell> cells;

  /// Whether a preview limit was exceeded anywhere in the notebook.
  final bool truncated;
}

/// A static notebook cell with its bounded source text (V4-CORE-05).
sealed class Cell {
  const Cell._(this.source);

  /// Source as inert text, with fragments joined up to the UTF-8 byte limit.
  final String source;
}

/// Markdown source and the cell-local raster attachments it may reference.
///
/// A reader must display raw HTML in [source] as text (V4-SEC-03).
final class MarkdownCell extends Cell {
  MarkdownCell._(super.source, Map<String, ImageOutput> attachments)
    : attachments = Map.unmodifiable(attachments),
      super._();

  /// Safe images keyed by the filename in a cell's `attachment:` reference.
  ///
  /// Names over 255 UTF-8 bytes are omitted. Lookup performs no I/O.
  final Map<String, ImageOutput> attachments;
}

/// Previously recorded code and its static outputs (V4-CORE-05).
final class CodeCell extends Cell {
  CodeCell._(super.source, this.executionCount, Iterable<Output> outputs)
    : outputs = List.unmodifiable(outputs),
      super._();

  /// The saved execution count, or null if the notebook has no count.
  final int? executionCount;

  /// Safe output representations and unsupported MIME markers in display order.
  final List<Output> outputs;
}

/// A raw cell whose source is displayed as plain text (V4-SEC-03).
final class RawCell extends Cell {
  const RawCell._(super.source) : super._();
}

/// A static result or a placeholder from a code cell (V4-SEC-03).
sealed class Output {
  const Output._();
}

/// Captured terminal text with escape sequences removed (V4-SEC-03).
final class StreamOutput extends Output {
  const StreamOutput._(this.name, this.text) : super._();

  /// The recorded stream name, usually `stdout` or `stderr`.
  final String name;

  /// The inert stream text, within the output text budget.
  final String text;
}

/// A plain-text, Markdown, or LaTeX result (V4-CORE-05, V4-SEC-03).
final class TextOutput extends Output {
  const TextOutput._(this.mime, this.text) : super._();

  /// The selected MIME type: `text/plain`, `text/markdown`, or `text/latex`.
  final String mime;

  /// The saved text. Markdown and LaTeX require a static renderer.
  final String text;
}

/// A PNG or JPEG with a checked header and bounded pixel area (V4-SEC-03).
final class ImageOutput extends Output {
  ImageOutput._(this.mime, this.width, this.height, this._encoded) : super._();

  /// The verified raster MIME type, either `image/png` or `image/jpeg`.
  final String mime;

  /// The width in pixels declared in the raster header.
  final int width;

  /// The height in pixels declared in the raster header.
  final int height;

  final String _encoded;

  /// Read-only raster bytes, decoded and cached on first access.
  ///
  /// The header check does not establish that the full image is decodable.
  late final Uint8List bytes = base64Decode(_encoded).asUnmodifiableView();
}

/// A recorded error with terminal escapes removed (V4-SEC-03).
final class ErrorOutput extends Output {
  ErrorOutput._(this.ename, this.evalue, Iterable<String> traceback)
    : traceback = List.unmodifiable(traceback),
      super._();

  /// The saved error name.
  final String ename;

  /// The saved error message.
  final String evalue;

  /// Traceback entries in notebook order, within the shared output text budget.
  final List<String> traceback;
}

/// A placeholder for a MIME representation that the reader cannot use.
///
/// Only its MIME label survives. The payload is discarded (V4-SEC-03).
final class UnsupportedOutput extends Output {
  const UnsupportedOutput._(this.mime) : super._();

  /// The discarded MIME type, or `application/octet-stream` if unavailable.
  final String mime;
}

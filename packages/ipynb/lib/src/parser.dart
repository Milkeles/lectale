part of '../ipynb.dart';

/// Reports malformed UTF-8, JSON, or notebook structure without quoting input.
final class NotebookFormatException implements Exception {
  /// Creates an error with a static explanation suitable for the reader.
  const NotebookFormatException(this.message);

  /// A human-readable explanation of the format error.
  final String message;

  /// Returns the format error without including the original notebook input.
  @override
  String toString() => 'NotebookFormatException: $message';
}

/// Parses UTF-8 nbformat 4 JSON into a static preview (V4-CORE-05, V4-SEC-03).
///
/// Oversize input returns an empty, truncated notebook before UTF-8 decoding.
/// Other exceeded limits mark the returned preview as truncated. Invalid UTF-8,
/// malformed structure, and unsupported notebook versions throw a
/// [NotebookFormatException].
Notebook parseNotebook(
  Uint8List bytes, {
  NotebookLimits limits = const NotebookLimits(),
}) {
  if (bytes.length > limits.maxInputBytes) {
    return Notebook._(language: null, cells: const [], truncated: true);
  }

  final Object? document;
  try {
    document = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const NotebookFormatException('Expected a UTF-8 JSON notebook.');
  }

  if (document is! Map<String, Object?>) {
    throw const NotebookFormatException('Expected a notebook object.');
  }
  final version = document['nbformat'];
  if (version is! int || version != 4) {
    throw const NotebookFormatException('Expected nbformat 4.');
  }

  return _NotebookParser(limits).parse(document);
}

final class _NotebookParser {
  _NotebookParser(NotebookLimits limits) : _sanitiser = _Sanitiser(limits);

  final _Sanitiser _sanitiser;

  Notebook parse(Map<String, Object?> notebook) {
    final rawCells = notebook['cells'];
    if (rawCells is! List<Object?>) {
      throw const NotebookFormatException('Expected a notebook cells list.');
    }
    final metadata = _objectOrEmpty(notebook['metadata']);
    final languageInfo = _objectOrEmpty(metadata['language_info']);
    final kernelSpec = _objectOrEmpty(metadata['kernelspec']);
    final language = languageInfo['name'] ?? kernelSpec['language'];
    final cells = _sanitiser
        .takeEntries(rawCells, _sanitiser.limits.maxCells)
        .map(_cell)
        .toList();
    return Notebook._(
      language: language is String ? language : null,
      cells: cells,
      truncated: _sanitiser.truncated,
    );
  }

  Cell _cell(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const NotebookFormatException('Expected a cell object.');
    }
    final source = _readText(value['source']);
    switch (value['cell_type']) {
      case 'markdown':
        return MarkdownCell._(source, _attachments(value['attachments']));
      case 'code':
        final count = value['execution_count'];
        if (count != null && count is! int) {
          throw const NotebookFormatException('Expected an execution count.');
        }
        return CodeCell._(source, count as int?, _outputs(value['outputs']));
      case 'raw':
        return RawCell._(source);
      default:
        throw const NotebookFormatException('Unsupported notebook cell type.');
    }
  }

  Map<String, ImageOutput> _attachments(Object? value) {
    final attachments = <String, ImageOutput>{};
    for (final entry in _objectOrEmpty(value).entries) {
      final bundle = _objectOrEmpty(entry.value);
      for (final mime in _rasterMimes) {
        final image = _sanitiser.image(mime, bundle[mime]);
        if (image != null) {
          attachments[entry.key] = image;
          break;
        }
      }
    }
    return attachments;
  }

  List<Output> _outputs(Object? value) {
    if (value == null) return const [];
    if (value is! List<Object?>) {
      throw const NotebookFormatException('Expected a cell outputs list.');
    }
    final outputs = <Output>[];
    final limit = _sanitiser.limits.maxOutputsPerCell;
    for (final entry in _sanitiser.takeEntries(value, limit)) {
      if (outputs.length == limit) {
        _sanitiser.truncated = true;
        break;
      }
      for (final output in _output(entry)) {
        if (outputs.length == limit) {
          _sanitiser.truncated = true;
          break;
        }
        outputs.add(output);
      }
    }
    return outputs;
  }

  Iterable<Output> _output(Object? value) sync* {
    if (value is! Map<String, Object?>) {
      throw const NotebookFormatException('Expected an output object.');
    }
    switch (value['output_type']) {
      case 'stream':
        yield _sanitiser.stream(
          _readText(value['name']),
          _readText(value['text']),
        );
      case 'error':
        final traceback = value['traceback'];
        if (traceback is! List<Object?>) {
          throw const NotebookFormatException('Expected an error traceback.');
        }
        yield _sanitiser.error(
          _readText(value['ename']),
          _readText(value['evalue']),
          traceback,
        );
      case 'display_data':
      case 'execute_result':
        yield* _richOutputs(_objectOrEmpty(value['data']));
      default:
        yield const UnsupportedOutput._(_unknownMime);
    }
  }

  Iterable<Output> _richOutputs(Map<String, Object?> bundle) sync* {
    String? unusableMime;
    for (final mime in _outputMimes) {
      if (!bundle.containsKey(mime)) continue;
      final value = bundle[mime];
      final output = _rasterMimes.contains(mime)
          ? _sanitiser.image(mime, value)
          : _sanitiser.text(mime, value);
      if (output != null) {
        yield output;
        unusableMime = null;
        break;
      }
      unusableMime ??= mime;
    }
    if (unusableMime != null) yield UnsupportedOutput._(unusableMime);
    for (final mime in bundle.keys) {
      if (!_outputMimes.contains(mime)) {
        yield UnsupportedOutput._(_mimeLabel(mime));
      }
    }
    if (bundle.isEmpty) yield const UnsupportedOutput._(_unknownMime);
  }
}

Map<String, Object?> _objectOrEmpty(Object? value) =>
    value is Map<String, Object?> ? value : const {};

Iterable<String>? _textParts(Object? value) {
  if (value is String) return [value];
  if (value is List<Object?> && value.every((part) => part is String)) {
    return value.cast<String>();
  }
  return null;
}

String _readText(Object? value) =>
    _textParts(value)?.join() ??
    (throw const NotebookFormatException('Expected notebook text.'));

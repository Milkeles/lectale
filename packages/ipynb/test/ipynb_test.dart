import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ipynb/ipynb.dart';
import 'package:test/test.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mNg'
    'YGAAAAAEAAHI6uv5AAAAAElFTkSuQmCC';
const _jpeg =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8U'
    'HRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgN'
    'DRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy'
    'MjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAj/xAAU'
    'EAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAAAP/EABQRAQAAAAAA'
    'AAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AJ/AB//Z';

Uint8List _fixture(String name) =>
    File('test/fixtures/$name').readAsBytesSync();

Uint8List _notebookBytes(List<Object?> cells) =>
    utf8.encode(jsonEncode({'nbformat': 4, 'cells': cells}));

Map<String, Object?> _codeCell(List<Object?> outputs) => {
  'cell_type': 'code',
  'source': '',
  'outputs': outputs,
};

Map<String, Object?> _display(Map<String, Object?> data) => {
  'output_type': 'display_data',
  'data': data,
};

List<Output> _outputs(Notebook notebook) =>
    (notebook.cells.single as CodeCell).outputs;

void main() {
  test('reads a normal nbformat 4 notebook in cell and output order', () {
    final notebook = parseNotebook(_fixture('normal.ipynb'));
    expect(notebook.language, 'python');
    expect(notebook.truncated, isFalse);
    expect(notebook.cells, hasLength(4));
    final markdown = notebook.cells[0] as MarkdownCell;
    final code = notebook.cells[1] as CodeCell;
    final raw = notebook.cells[2] as RawCell;
    final unrun = notebook.cells[3] as CodeCell;

    expect(markdown.source, '# Addition\n\nAdd two numbers.');
    expect(markdown.attachments, isEmpty);
    expect(code.source, 'print(1 + 2)\n1 + 2');
    expect(code.executionCount, 2);
    expect(code.outputs, [
      isA<StreamOutput>()
          .having((output) => output.name, 'name', 'stdout')
          .having((output) => output.text, 'text', '3\n'),
      isA<TextOutput>()
          .having((output) => output.mime, 'mime', 'text/plain')
          .having((output) => output.text, 'text', '3'),
    ]);
    expect(raw.source, 'Sum: 3');
    expect(unrun.executionCount, isNull);
    expect(unrun.outputs, isEmpty);
    expect(notebook.cells.clear, throwsUnsupportedError);
    expect(code.outputs.clear, throwsUnsupportedError);
  });

  test('reports that nbformat 3 is unsupported', () {
    expect(
      () => parseNotebook(_fixture('legacy.ipynb')),
      throwsA(
        isA<NotebookFormatException>().having(
          (error) => error.message,
          'message',
          contains('nbformat 4'),
        ),
      ),
    );
  });

  test('reports malformed JSON and invalid UTF-8 as format errors', () {
    final error = throwsA(isA<NotebookFormatException>());
    expect(() => parseNotebook(_fixture('malformed.ipynb')), error);
    expect(() => parseNotebook(Uint8List.fromList([0xff])), error);
  });

  test('reports malformed notebook structure as a format error', () {
    final error = throwsA(isA<NotebookFormatException>());
    expect(() => parseNotebook(utf8.encode('[]')), error);
    expect(() => parseNotebook(utf8.encode('{"nbformat": 4}')), error);
    expect(() => parseNotebook(_notebookBytes([false])), error);
    expect(
      () => parseNotebook(
        _notebookBytes([
          _codeCell([false]),
        ]),
      ),
      error,
    );
  });

  test('replaces HTML, JavaScript, SVG and widgets with MIME markers', () {
    final notebook = parseNotebook(_fixture('untrusted.ipynb'));
    final outputs = (notebook.cells[1] as CodeCell).outputs;
    expect(outputs.first, isA<TextOutput>());
    expect((outputs.first as TextOutput).text, 'Static fallback');
    expect(
      outputs.whereType<UnsupportedOutput>().map((output) => output.mime),
      [
        'text/html',
        'application/javascript',
        'image/svg+xml',
        'application/vnd.jupyter.widget-view+json',
        'application/vnd.jupyter.widget-state+json',
        'text/html',
      ],
    );
    expect(notebook.truncated, isFalse);
  });

  test('preserves literal HTML in Markdown source', () {
    final notebook = parseNotebook(_fixture('untrusted.ipynb'));
    final markdown = notebook.cells.first as MarkdownCell;
    expect(
      markdown.source,
      '<script>void(0)</script>\n<div>Show the literal markup.</div>',
    );
  });

  test('strips ANSI escapes from streams and all error fields', () {
    final notebook = parseNotebook(_fixture('untrusted.ipynb'));
    final outputs = (notebook.cells[1] as CodeCell).outputs;
    final stream = outputs.whereType<StreamOutput>().single;
    final error = outputs.whereType<ErrorOutput>().single;
    expect(stream.name, 'stderr');
    expect(stream.text, 'red\tlink\n');
    expect(error.ename, 'ExampleError');
    expect(error.evalue, 'failed');
    expect(error.traceback, ['line 1', 'line 2', '']);
    expect(error.traceback.clear, throwsUnsupportedError);
  });

  test('chooses Markdown, LaTeX, PNG, JPEG and plain text in order', () {
    const mimes = [
      'text/markdown',
      'text/latex',
      'image/png',
      'image/jpeg',
      'text/plain',
    ];
    const values = <Object?>['**bold**', r'$x^2$', _png, _jpeg, 'plain'];
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          for (var start = 0; start < mimes.length; start++)
            _display({
              for (var index = mimes.length - 1; index >= start; index--)
                mimes[index]: values[index],
            }),
        ]),
      ]),
    );
    final outputs = _outputs(notebook);
    expect(
      outputs.map(
        (output) => switch (output) {
          ImageOutput(:final mime) || TextOutput(:final mime) => mime,
          _ => fail('Expected an image or text output.'),
        },
      ),
      mimes,
    );
    expect((outputs[2] as ImageOutput).bytes, base64Decode(_png));
    expect((outputs[3] as ImageOutput).bytes, base64Decode(_jpeg));
  });

  test('does not expose active content relabeled as a raster', () {
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          _display({
            'image/png': base64Encode(utf8.encode('<svg></svg>')),
            'image/jpeg': _png,
            '<script>void(0)</script>': 'invalid MIME label',
          }),
        ]),
      ]),
    );
    expect(
      _outputs(notebook).cast<UnsupportedOutput>().map((output) => output.mime),
      ['image/png', 'application/octet-stream'],
    );
  });

  test('uses a lower-priority fallback for invalid image encoding', () {
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          _display({'image/png': '${_png}AB==', 'text/plain': 'fallback'}),
        ]),
      ]),
    );
    expect((_outputs(notebook).single as TextOutput).text, 'fallback');
    expect(notebook.truncated, isFalse);
  });

  test('resolves Markdown attachments as read-only cell-local images', () {
    final notebook = parseNotebook(_fixture('attachments.ipynb'));
    final first = notebook.cells.first as MarkdownCell;
    final second = notebook.cells.last as MarkdownCell;
    expect(first.source, contains('attachment:pixel.png'));
    expect(first.attachments.keys, ['pixel.png']);
    expect(second.attachments, isEmpty);
    expect(first.attachments.clear, throwsUnsupportedError);

    final image = first.attachments['pixel.png']!;
    final bytes = image.bytes;
    expect(image.mime, 'image/png');
    expect(bytes, base64Decode(_png));
    expect(image.bytes, same(bytes));
    expect(() => bytes[0] = 0, throwsUnsupportedError);
    expect(() => bytes.buffer.asUint8List()[0] = 0, throwsUnsupportedError);
  });

  test('applies the decoded byte limit to Markdown attachments', () {
    final fixture = _fixture('attachments.ipynb');
    final imageLength = base64Decode(_png).length;
    final withinLimit = parseNotebook(
      fixture,
      limits: NotebookLimits(maxImageBytes: imageLength),
    );
    expect((withinLimit.cells.first as MarkdownCell).attachments, hasLength(1));
    expect(withinLimit.truncated, isFalse);

    final overLimit = parseNotebook(
      fixture,
      limits: NotebookLimits(maxImageBytes: imageLength - 1),
    );
    expect((overLimit.cells.first as MarkdownCell).attachments, isEmpty);
    expect(overLimit.truncated, isTrue);
  });

  test('marks oversize input before trying to decode it', () {
    final result = parseNotebook(
      Uint8List.fromList([0xff, 0xff]),
      limits: const NotebookLimits(maxInputBytes: 1),
    );
    expect(result.cells, isEmpty);
    expect(result.language, isNull);
    expect(result.truncated, isTrue);

    final fixture = _fixture('normal.ipynb');
    final exact = parseNotebook(
      fixture,
      limits: NotebookLimits(maxInputBytes: fixture.length),
    );
    expect(exact.truncated, isFalse);
  });

  test('truncates a generated base64 image of 50 MiB before decoding', () {
    const decodedLength = 50 * 1024 * 1024;
    const encodedLength = (decodedLength + 2) ~/ 3 * 4;
    final payload = 'iVBORw0KGgo${'A' * (encodedLength - 12)}=';
    final bytes = _notebookBytes([
      _codeCell([
        _display({'image/png': payload}),
      ]),
    ]);
    final notebook = parseNotebook(
      bytes,
      limits: NotebookLimits(maxInputBytes: bytes.length),
    );
    expect(notebook.truncated, isTrue);
    expect(
      _outputs(notebook).single,
      isA<UnsupportedOutput>().having(
        (output) => output.mime,
        'mime',
        'image/png',
      ),
    );
  });

  test('preserves a text fallback when an image exceeds the byte limit', () {
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          _display({'image/png': _png, 'text/plain': 'fallback'}),
        ]),
      ]),
      limits: const NotebookLimits(maxImageBytes: 10),
    );
    expect((_outputs(notebook).single as TextOutput).text, 'fallback');
    expect(notebook.truncated, isTrue);
  });

  test('caps a generated 10,000-cell notebook without reordering it', () {
    final notebook = parseNotebook(
      _notebookBytes([
        for (var index = 0; index < 10000; index++)
          {'cell_type': 'raw', 'source': 'Cell $index'},
      ]),
    );
    expect(notebook.truncated, isTrue);
    expect(notebook.cells, hasLength(2000));
    expect(notebook.cells.first.source, 'Cell 0');
    expect(notebook.cells.last.source, 'Cell 1999');
  });

  test('caps both output records and expanded MIME markers', () {
    const limits = NotebookLimits(maxOutputsPerCell: 2);
    const text = {'text/plain': 'hello'};
    final records = parseNotebook(
      _notebookBytes([
        _codeCell([_display(text), _display(text), false]),
      ]),
      limits: limits,
    );
    expect(records.truncated, isTrue);
    expect(_outputs(records), hasLength(2));

    final markers = parseNotebook(
      _notebookBytes([
        _codeCell([
          _display({
            ...text,
            'text/html': '<b>hello</b>',
            'application/javascript': 'void(0)',
          }),
        ]),
      ]),
      limits: limits,
    );
    expect(markers.truncated, isTrue);
    expect(_outputs(markers), [isA<TextOutput>(), isA<UnsupportedOutput>()]);
  });

  test('caps text at a UTF-8 boundary after stripping ANSI', () {
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          _display({
            'text/plain': ['X', '😀', 'é'],
          }),
          {
            'output_type': 'stream',
            'name': 'stdout',
            'text': '\x1b[31m😀é\x1b[0m',
          },
          {
            'output_type': 'error',
            'ename': 'Error',
            'evalue': 'msg',
            'traceback': ['ab', 'z'],
          },
        ]),
      ]),
      limits: const NotebookLimits(maxTextBytesPerOutput: 11),
    );
    final outputs = _outputs(notebook);
    expect((outputs[0] as TextOutput).text, 'X😀é');
    expect((outputs[1] as StreamOutput).text, '😀');
    expect((outputs[2] as ErrorOutput).traceback, ['ab']);
    expect(notebook.truncated, isTrue);

    final longText = parseNotebook(
      _notebookBytes([
        _codeCell([
          _display({'text/plain': 'é' * (200 * 1024)}),
        ]),
      ]),
    );
    expect((_outputs(longText).single as TextOutput).text, 'é' * (100 * 1024));
    expect(longText.truncated, isTrue);
  });
}

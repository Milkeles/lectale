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
const _jpegSof = 158;

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

  test('rejects malformed cell, output, and metadata shapes', () {
    final malformedCells = <String, Map<String, Object?>>{
      'source': {..._codeCell([]), 'source': 5},
      'outputs': {..._codeCell([]), 'outputs': <String, Object?>{}},
      'data': _codeCell([
        {..._display({}), 'data': <Object?>[]},
      ]),
      'traceback': _codeCell([
        {
          'output_type': 'error',
          'ename': 'Error',
          'evalue': '',
          'traceback': 'x',
        },
      ]),
      'execution_count': {..._codeCell([]), 'execution_count': '1'},
      'cell_type': {'cell_type': 'unknown', 'source': ''},
      'attachments': {
        'cell_type': 'markdown',
        'source': '',
        'attachments': <Object?>[],
      },
    };
    final error = throwsA(isA<NotebookFormatException>());
    for (final entry in malformedCells.entries) {
      expect(
        () => parseNotebook(_notebookBytes([entry.value])),
        error,
        reason: entry.key,
      );
    }
    expect(
      () =>
          parseNotebook(utf8.encode('{"nbformat":4,"cells":[],"metadata":[]}')),
      error,
      reason: 'metadata',
    );
  });

  test('rejects 100,000 levels of nesting before JSON decoding', () {
    final nested =
        '${'[' * 50000}${'{"x":' * 50000}0'
        '${'}' * 50000}${']' * 50000}';
    final bytes = utf8.encode('{"nbformat":4,"cells":[],"extra":$nested}');
    expect(
      () => parseNotebook(bytes),
      throwsA(
        isA<NotebookFormatException>().having(
          (error) => error.message,
          'message',
          contains('nesting'),
        ),
      ),
    );
  });

  test('counts JSON containers outside quoted and escaped text', () {
    final source = '${r'\"\\\"{' * 65}${']' * 65}\\';
    final notebook = parseNotebook(
      _notebookBytes([
        {'cell_type': 'raw', 'source': source},
      ]),
    );
    expect(notebook.cells.single.source, source);

    Uint8List nested(int arrays) => utf8.encode(
      '{"nbformat":4,"cells":[],"extra":'
      '${'[' * arrays}"\\u0022 \\" \\\\ [ ] { }"${']' * arrays}}',
    );
    expect(parseNotebook(nested(63)).cells, isEmpty);
    expect(
      () => parseNotebook(nested(64)),
      throwsA(isA<NotebookFormatException>()),
    );
  });

  test('truncates oversized source at the default UTF-8 byte budget', () {
    final prefix = 'é' * (512 * 1024 - 1);
    final notebook = parseNotebook(
      _notebookBytes([
        {
          'cell_type': 'markdown',
          'source': [prefix, '😀suffix'],
        },
        {'cell_type': 'code', 'source': '$prefix-é'},
        {'cell_type': 'raw', 'source': '$prefix--'},
      ]),
    );
    expect(notebook.cells.map((cell) => cell.source), [
      prefix,
      '$prefix-',
      '$prefix--',
    ]);
    expect(notebook.truncated, isTrue);
  });

  test('applies the source budget across split UTF-16 surrogate pairs', () {
    final bytes = _notebookBytes([
      {
        'cell_type': 'raw',
        'source': ['\ud83d', '\ude00'],
      },
    ]);
    final exact = parseNotebook(
      bytes,
      limits: const NotebookLimits(maxSourceBytesPerCell: 4),
    );
    expect(exact.cells.single.source, '😀');
    expect(exact.truncated, isFalse);
    final over = parseNotebook(
      bytes,
      limits: const NotebookLimits(maxSourceBytesPerCell: 3),
    );
    expect(over.cells.single.source, isEmpty);
    expect(over.truncated, isTrue);
  });

  test('drops oversized language and attachment names', () {
    final allowedName = '${'é' * 127}a';
    final largeName = 'é' * 128;
    final notebook = parseNotebook(
      utf8.encode(
        jsonEncode({
          'nbformat': 4,
          'metadata': {
            'language_info': {'name': 'é' * 65},
          },
          'cells': [
            {
              'cell_type': 'markdown',
              'source': '',
              'attachments': {
                allowedName: {'image/png': _png},
                largeName: {'image/png': _png},
              },
            },
          ],
        }),
      ),
    );
    expect(notebook.language, isNull);
    expect((notebook.cells.single as MarkdownCell).attachments.keys, [
      allowedName,
    ]);
    expect(notebook.truncated, isTrue);
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

  test('strips controls and bidi formatting from plain output', () {
    const text =
        'a\x00\x1b[31mb\x7f\x85\u202ec'
        '\u202a\u202c\u2066\u2067\u2068\u2069\tй\r\n';
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          _display({'text/plain': text}),
          {'output_type': 'stream', 'name': 'stdout', 'text': text},
          {
            'output_type': 'error',
            'ename': 'E\u202e',
            'evalue': '\u2066msg',
            'traceback': [text],
          },
        ]),
      ]),
    );
    final outputs = _outputs(notebook);
    expect((outputs[0] as TextOutput).text, 'abc\tй\r\n');
    expect((outputs[1] as StreamOutput).text, 'abc\tй\r\n');
    final error = outputs[2] as ErrorOutput;
    expect(error.ename, 'E');
    expect(error.evalue, 'msg');
    expect(error.traceback, ['abc\tй\r\n']);
    expect(notebook.truncated, isFalse);
  });

  test('preserves text after an unterminated OSC on the same line', () {
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          {
            'output_type': 'stream',
            'name': 'stdout',
            'text': [
              'before\x1b',
              '] keep this\n\x9dkeep this too\r\n',
              '\x1b]0;window title\x07bell ',
              '\x1b]0;another title\x1b',
              '\\escape \x9d0;last title\x9cend',
            ],
          },
        ]),
      ]),
    );
    expect(
      (_outputs(notebook).single as StreamOutput).text,
      'before keep this\nkeep this too\r\nbell escape end',
    );
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

  test('rejects PNG and JPEG headers above the default pixel budget', () {
    // Complete IHDR declaring 30000 × 30000 pixels, with a matching CRC.
    const widePng = 'iVBORw0KGgoAAAANSUhEUgAAdTAAAHUwCAIAAADpRW/t';
    final jpeg = base64Decode(_jpeg);
    ByteData.sublistView(jpeg)
      ..setUint16(_jpegSof + 5, 30000)
      ..setUint16(_jpegSof + 7, 30000);
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          _display({'image/png': widePng}),
          _display({'image/jpeg': base64Encode(jpeg)}),
        ]),
        {
          'cell_type': 'markdown',
          'source': '',
          'attachments': {
            'wide.png': {'image/png': widePng},
          },
        },
      ]),
    );
    expect((notebook.cells.first as CodeCell).outputs, [
      isA<UnsupportedOutput>().having(
        (output) => output.mime,
        'mime',
        'image/png',
      ),
      isA<UnsupportedOutput>().having(
        (output) => output.mime,
        'mime',
        'image/jpeg',
      ),
    ]);
    expect((notebook.cells.last as MarkdownCell).attachments, isEmpty);
    expect(notebook.truncated, isTrue);
  });

  test('reports dimensions and accepts the exact pixel budget', () {
    final jpeg = base64Decode(_jpeg)..[_jpegSof + 1] = 0xc2;
    ByteData.sublistView(jpeg)
      ..setUint16(_jpegSof + 5, 2)
      ..setUint16(_jpegSof + 7, 3);
    // The APP segment contains marker-like bytes. Only its length is used.
    final progressive = base64Encode([
      ...jpeg.take(2),
      0xff,
      0xff,
      0xe2,
      0,
      6,
      0xff,
      0xc0,
      0xff,
      0xda,
      ...jpeg.skip(2),
    ]);
    final bytes = _notebookBytes([
      _codeCell([
        _display({'image/png': _png}),
        _display({
          'image/jpeg': [
            progressive.substring(0, 11),
            ' \t',
            progressive.substring(11),
          ],
        }),
      ]),
    ]);

    final exact = parseNotebook(
      bytes,
      limits: const NotebookLimits(maxImagePixels: 6),
    );
    final images = _outputs(exact).cast<ImageOutput>();
    expect(images.map((image) => (image.width, image.height)), [
      (1, 1),
      (3, 2),
    ]);
    expect(images.last.bytes, base64Decode(progressive));
    expect(exact.truncated, isFalse);
    final over = parseNotebook(
      bytes,
      limits: const NotebookLimits(maxImagePixels: 5),
    );
    expect(_outputs(over), [isA<ImageOutput>(), isA<UnsupportedOutput>()]);
    expect(over.truncated, isTrue);
  });

  test('rejects malformed PNG IHDR and JPEG SOFn headers', () {
    final png = base64Decode(_png);
    final jpeg = base64Decode(_jpeg);
    final wrongChunk = Uint8List.fromList(png)..[12] = 0x4a;
    final wrongCrc = Uint8List.fromList(png)..[32] = 0;
    final wrongLength = Uint8List.fromList(jpeg)..[_jpegSof + 3] = 16;
    final zeroHeight = Uint8List.fromList(jpeg)..[_jpegSof + 6] = 0;
    final malformed = {
      'image/png': [
        png.sublist(0, 8),
        png.sublist(0, 32),
        wrongChunk,
        wrongCrc,
      ],
      'image/jpeg': [
        jpeg.sublist(0, 3),
        jpeg.sublist(0, _jpegSof + 4),
        jpeg.sublist(0, _jpegSof + 17),
        wrongLength,
        zeroHeight,
        [0xff, 0xd8, 0xff, 0xe0, 0, 1],
        [0xff, 0xd8, 0xff, 0xda, ...jpeg.sublist(_jpegSof)],
      ],
    };
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          for (final entry in malformed.entries)
            for (final bytes in entry.value)
              _display({entry.key: base64Encode(bytes)}),
        ]),
      ]),
    );
    expect(
      _outputs(notebook).map((output) => (output as UnsupportedOutput).mime),
      [
        for (final entry in malformed.entries)
          for (final _ in entry.value) entry.key,
      ],
    );
    expect(notebook.truncated, isFalse);
  });

  test('checks the total base64 budget before processing fragments', () {
    final notebook = parseNotebook(
      _notebookBytes([
        _codeCell([
          _display({
            'image/png': ['?', 'A \n' * 10000],
          }),
        ]),
      ]),
      limits: const NotebookLimits(maxImageBytes: 12),
    );
    expect(
      _outputs(notebook).single,
      isA<UnsupportedOutput>().having(
        (output) => output.mime,
        'mime',
        'image/png',
      ),
    );
    expect(notebook.truncated, isTrue);
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

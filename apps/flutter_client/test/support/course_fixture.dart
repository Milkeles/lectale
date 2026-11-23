import 'dart:convert';
import 'dart:typed_data';

import 'fake_http_adapter.dart';
import 'pump_app.dart';

/// The repository ID of the fixture course.
const int fixtureRepoId = 42;

/// The Course address of the fixture course.
const String fixtureCourse = '/preview/$fixtureRepoId/$fixtureSha';

/// The Reader address of a file in the fixture course.
String fixtureReader(String lesson, String resource) =>
    '$fixtureCourse/$lesson/$resource';

/// A 1 by 1 PNG, for a figure that exists.
final Uint8List fixturePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwAD'
  'hgGAWjR9awAAAABJRU5ErkJggg==',
);

/// The fixture's README: a heading, a formula, an image, a relative link and
/// raw HTML.
const String fixtureReadme = r'''
# Statistics 101

Read the **overview** first. The mean is $\bar{x} = \frac{1}{n}\sum x_i$.

![A histogram](figures/histogram.png)

See [the notes](lessons/reading-data/notes.md) and
[an outside page](https://example.org/stats).

<script>alert(1)</script>
''';

String _href(String lesson, String resource) =>
    '/api/preview/$fixtureRepoId/$fixtureSha/content/$lesson/$resource';

Map<String, Object?> _resource(
  String id,
  String kind,
  String title,
  String lesson, {
  String? path,
  String? extension,
  Map<String, Object?>? extra,
}) => {
  'id': id,
  'kind': kind,
  'title': title,
  'href': path == null ? null : _href(lesson, id),
  'path': ?path,
  'fileExtension': ?extension,
  ...?extra,
};

/// A `CoursePreview` body for the fixture course: two modules with lessons,
/// one lesson with two files, a code file, a PDF, a folder and an
/// assignment.
Map<String, Object?> fixturePreview({bool readme = true, String? cover}) => {
  'repoId': fixtureRepoId,
  'sha': fixtureSha,
  'readmePresent': readme,
  'outline': {
    'course': {
      'id': 'statistics-101',
      'title': 'Statistics 101',
      'summary': 'Probability and inference for beginners, with worked data.',
      'language': 'en',
      'version': '1.0.0',
      'level': 'intermediate',
      'estimatedMinutes': 40,
      'license': 'CC-BY-4.0',
      'cover': ?cover,
      'authors': [
        {'name': 'Ada Lovelace', 'url': 'https://example.org/ada'},
        {'name': 'Grace Hopper'},
      ],
    },
    'nodes': [
      {
        'id': 'data',
        'kind': 'module',
        'title': 'Module 1: Data',
        'resources': <Object?>[],
        'children': [
          {
            'id': 'reading-data',
            'kind': 'lesson',
            'title': 'Reading data',
            'description': 'How to load a CSV file.',
            'children': <Object?>[],
            'resources': [
              _resource(
                'notes',
                'markdown',
                'Data and its shape',
                'reading-data',
                path: 'lessons/reading-data/notes.md',
                extension: 'md',
              ),
              _resource(
                'survey',
                'text',
                'Survey results',
                'reading-data',
                path: 'data/survey.csv',
                extension: 'csv',
                extra: {'sizeBytes': 12000},
              ),
            ],
          },
          {
            'id': 'summaries',
            'kind': 'lesson',
            'title': 'Summaries',
            'children': <Object?>[],
            'resources': [
              _resource(
                'script',
                'code',
                'Summary script',
                'summaries',
                path: 'code/summarise.py',
                extension: 'py',
              ),
            ],
          },
        ],
      },
      {
        'id': 'inference',
        'kind': 'module',
        'title': 'Module 2: Inference',
        'resources': <Object?>[],
        'children': [
          {
            'id': 'testing',
            'kind': 'lesson',
            'title': 'Testing ideas',
            'children': <Object?>[],
            'resources': [
              _resource(
                'slides',
                'pdf',
                'Slides',
                'testing',
                path: 'slides/testing.pdf',
                extension: 'pdf',
                extra: {'sizeBytes': 2300000},
              ),
            ],
          },
        ],
      },
      {
        'id': 'homework-1',
        'kind': 'assignment',
        'title': 'Homework 1',
        'assignmentId': 'homework-1',
        'children': <Object?>[],
        'resources': <Object?>[],
      },
    ],
    'assignments': [
      {
        'id': 'homework-1',
        'title': 'Homework 1',
        'description': 'Summarise the survey.',
        'dueAt': '2026-12-04T00:59:00Z',
        'resources': [
          _resource(
            'brief',
            'markdown',
            'Brief',
            'assignment~homework-1',
            path: 'homework/brief.md',
            extension: 'md',
          ),
        ],
      },
    ],
  },
};

/// Registers the fixture course's routes on [server]: the preview, the
/// README and every file.
void serveCourse(
  FakeHttpAdapter server, {
  bool readme = true,
  Map<String, Object?>? preview,
}) {
  const base = '/api/preview/$fixtureRepoId/$fixtureSha';
  server
    ..on(
      'GET',
      base,
      FakeResponse(200, preview ?? fixturePreview(readme: readme)),
    )
    ..on('GET', '$base/readme', const FakeResponse(200, fixtureReadme))
    ..on(
      'GET',
      '$base/content/reading-data/notes',
      const FakeResponse(
        200,
        '# Notes\n\nA table has rows and columns. Cost: \$5.\n\n'
        '```python\nprint("hello")\n```\n',
      ),
    )
    ..on(
      'GET',
      '$base/content/reading-data/survey',
      const FakeResponse(200, 'name,score\nAda,10\nGrace,12\n'),
    )
    ..on(
      'GET',
      '$base/content/summaries/script',
      const FakeResponse(
        200,
        'import statistics\nprint(statistics.mean([1, 2]))\n',
      ),
    )
    ..on(
      'GET',
      '$base/content/assignment~homework-1/brief',
      const FakeResponse(200, '# Brief\n\nSummarise the survey.\n'),
    )
    ..on(
      'GET',
      '$base/files/figures/histogram.png',
      FakeResponse(200, fixturePng),
    )
    ..on('GET', '$base/files/cover.png', FakeResponse(200, fixturePng));
}

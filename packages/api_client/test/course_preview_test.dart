import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lectale_api_client/lectale_api_client.dart';

void main() {
  test('decodes a pinned preview, its outline and scoped resources', () {
    const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const href = '/api/preview/42/$sha/content/intro/notes';
    final json = jsonDecode('''
      {
        "repoId": 42,
        "sha": "$sha",
        "readmePresent": true,
        "warnings": [{
          "code": "cover_too_small", "message": "Use a larger cover.",
          "path": "images/cover.png"
        }],
        "outline": {
          "course": {
            "id": "course", "title": "Course", "summary": "Learn by reading.",
            "language": "en", "version": "1.0.0"
          },
          "nodes": [{
            "id": "start", "kind": "module", "title": "Start",
            "resources": [],
            "children": [{
              "id": "intro", "kind": "lesson", "title": "Introduction",
              "children": [],
              "resources": [
                {
                  "id": "notes", "kind": "pdf", "title": "Notes",
                  "href": "$href", "path": "lessons/notes.pdf",
                  "fileExtension": "pdf", "sizeBytes": 1200
                },
                {
                  "id": "video", "kind": "video", "title": "Lecture",
                  "href": null, "provider": "vimeo",
                  "embedUrl": "https://player.vimeo.com/video/123456"
                }
              ]
            }, {
              "id": "practice-link", "kind": "assignment", "title": "Practice",
              "assignmentId": "practice", "children": [], "resources": []
            }]
          }],
          "assignments": [{
            "id": "practice", "title": "Practice",
            "dueAt": "2026-11-25T00:00:00Z", "resources": []
          }]
        }
      }
      ''') as Map<String, Object?>;

    final preview = CoursePreview.fromJson(json);
    expect(preview.repoId.value, 42);
    expect(preview.sha.value, sha);
    expect(preview.readmePresent, isTrue);
    expect(preview.warnings?.single.code, 'cover_too_small');
    expect(preview.warnings?.single.path, 'images/cover.png');
    expect(preview.outline.course.title, 'Course');
    final module = preview.outline.nodes.single;
    expect(module.kind, CourseOutlineNodeKind.module);
    final resources = module.children.first.resources;
    expect(module.children.last.assignmentId?.value, 'practice');
    expect(resources.first.href, href);
    expect(resources.first.path, 'lessons/notes.pdf');
    expect(resources.first.fileExtension, 'pdf');
    expect(resources.first.sizeBytes, 1200);
    expect(resources.last.href, isNull);
    expect(resources.last.path, isNull);
    expect(resources.last.provider, OutlineResourceProvider.vimeo);
    expect(resources.last.embedUrl, 'https://player.vimeo.com/video/123456');
    expect(
      preview.outline.assignments.single.dueAt,
      DateTime.utc(2026, 11, 25),
    );
  });
}

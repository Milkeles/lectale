import 'package:flutter_test/flutter_test.dart';
import 'package:resource_renderers/resource_renderers.dart';

void main() {
  group('resolveRepositoryPath', () {
    test('resolves against the folder of the document', () {
      expect(
        resolveRepositoryPath('img/a.png', basePath: 'docs/guide.md'),
        'docs/img/a.png',
      );
      expect(
        resolveRepositoryPath('./a.png', basePath: 'docs/guide.md'),
        'docs/a.png',
      );
      expect(resolveRepositoryPath('a.png', basePath: 'README.md'), 'a.png');
    });

    test('collapses .. inside the repository', () {
      expect(
        resolveRepositoryPath('../img/a.png', basePath: 'docs/guide.md'),
        'img/a.png',
      );
    });

    test('takes a leading slash from the repository root', () {
      expect(
        resolveRepositoryPath('/data/x.csv', basePath: 'docs/guide.md'),
        'data/x.csv',
      );
    });

    test('drops the query and the fragment', () {
      expect(resolveRepositoryPath('b.md?x=1#top', basePath: 'a.md'), 'b.md');
    });

    test('refuses a path that leaves the repository root', () {
      expect(resolveRepositoryPath('../x.png', basePath: 'README.md'), isNull);
      expect(
        resolveRepositoryPath('../../x.png', basePath: 'docs/a.md'),
        isNull,
      );
      expect(
        resolveRepositoryPath('a/../../x.png', basePath: 'README.md'),
        isNull,
      );
    });

    test('refuses what the files route would refuse', () {
      for (final bad in [
        r'a\b.png',
        'a%2Fb.png',
        'a%5Cb.png',
        'with space.png',
        '.hidden/a.png',
        'a/.git/config',
        '%zz.png',
        '',
        '#only-fragment',
      ]) {
        expect(
          resolveRepositoryPath(bad, basePath: 'README.md'),
          isNull,
          reason: bad,
        );
      }
    });

    test('allows .well-known', () {
      expect(
        resolveRepositoryPath('.well-known/x.txt', basePath: 'README.md'),
        '.well-known/x.txt',
      );
    });

    test('refuses a path over 500 characters', () {
      expect(
        resolveRepositoryPath('${'a' * 501}.png', basePath: 'README.md'),
        isNull,
      );
    });
  });

  group('classifyLink', () {
    test('keeps an anchor in the document', () {
      expect(classifyLink('#Setup%20steps'), isA<AnchorLink>());
      expect((classifyLink('#setup') as AnchorLink).id, 'setup');
    });

    test('resolves a relative link inside the repository', () {
      final target = classifyLink('guide/two.md', basePath: 'README.md');
      expect((target as RepositoryLink).path, 'guide/two.md');
    });

    test('refuses a relative link outside the repository', () {
      expect(
        classifyLink('../secret.md', basePath: 'README.md'),
        isA<RefusedLink>(),
      );
    });

    test('opens only https outside the app', () {
      expect(classifyLink('https://example.org/a'), isA<ExternalLink>());
    });

    test('shows plain http as text with its host', () {
      final target = classifyLink('http://Example.org/a');
      expect(target, isA<RefusedLink>());
      expect((target as RefusedLink).shown, 'example.org');
    });

    test('opens and shows a host in its ASCII (Punycode) form', () {
      final target = classifyLink('https://bücher.example/a');
      expect(target, isA<ExternalLink>());
      expect((target as ExternalLink).uri.host, 'xn--bcher-kva.example');
    });

    test('refuses hosts outside letters, digits, dots and hyphens', () {
      for (final bad in [
        'https://exa_mple.org/',
        'https://exa%20mple.org/',
        'https://-bad.example/',
        'https://bad-.example/',
        'https://a..b.example/',
        'https://[::1]/',
        'https://exa!mple.org/',
      ]) {
        expect(classifyLink(bad), isA<RefusedLink>(), reason: bad);
      }
    });

    test('refuses encoded and entity-hidden schemes and hostile paths', () {
      for (final bad in [
        'javascript%3Aalert(1)',
        'JAVASCRIPT%3aalert(1)',
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///etc/passwd',
        'view-source:https://example.org',
        'ms-msdt:/id',
        '%2e%2e/x.png',
        '/%2e%2e/x.png',
        '%FF.png',
        '%E0%A4%A',
      ]) {
        expect(
          classifyLink(bad, basePath: 'README.md'),
          isA<RefusedLink>(),
          reason: bad,
        );
      }
    });

    test('a path that is not valid UTF-8 is refused, not thrown', () {
      expect(() => classifyLink('%FF.png'), returnsNormally);
      expect(() => classifyImage('%FF.png'), returnsNormally);
      expect(resolveRepositoryPath('%FF.png'), isNull);
      expect(classifyImage('%FF.png'), isA<RefusedImage>());
      expect(classifyLink('#%FF'), isA<RefusedLink>());
    });

    test('an encoded climb in an image destination is refused', () {
      final target = classifyImage('/%2e%2e/x.png', basePath: 'docs/a.md');
      expect((target as RefusedImage).reason, ImageRefusal.invalidPath);
      expect(
        (classifyImage(
          '%2e%2e/%2e%2e/x.png',
          basePath: 'a.md',
        ) as RefusedImage).reason,
        ImageRefusal.invalidPath,
      );
    });

    test('refuses scripts, data and other schemes in any spelling', () {
      for (final bad in [
        'javascript:alert(1)',
        'JavaScript:alert(1)',
        'JAVASCRIPT:alert(1)',
        '  javascript:alert(1)',
        '\tjavascript:alert(1)',
        'java\tscript:alert(1)',
        'java\nscript:alert(1)',
        'java\u0000script:alert(1)',
        ' \u0001javascript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'DATA:text/html;base64,PHNjcmlwdD4=',
        'vbscript:msgbox(1)',
        'VbScript:msgbox(1)',
        'file:///etc/passwd',
        'blob:https://example.org/uuid',
        'mailto:a@example.org',
        'ftp://example.org/a',
        '//example.org/a',
        'https://user:pass@example.org/',
        'https:///no-host',
      ]) {
        final target = classifyLink(bad, basePath: 'README.md');
        expect(target, isA<RefusedLink>(), reason: bad);
      }
    });

    test('an empty or missing target is refused', () {
      expect(classifyLink(null), isA<RefusedLink>());
      expect(classifyLink('  '), isA<RefusedLink>());
    });
  });

  group('classifyImage', () {
    test('loads a raster image from the repository', () {
      final target = classifyImage('img/a.PNG', basePath: 'docs/guide.md');
      expect((target as RepositoryImage).path, 'docs/img/a.PNG');
      for (final ext in ['png', 'jpg', 'jpeg', 'gif', 'webp']) {
        expect(classifyImage('a.$ext'), isA<RepositoryImage>(), reason: ext);
      }
    });

    test('never loads another host', () {
      final target = classifyImage('https://tracker.example/x.png');
      expect(target, isA<RefusedImage>());
      expect((target as RefusedImage).reason, ImageRefusal.otherHost);
      expect(target.shown, 'tracker.example');
      expect(
        (classifyImage('//tracker.example/x.png') as RefusedImage).reason,
        ImageRefusal.otherHost,
      );
      expect(
        (classifyImage('http://tracker.example/x.png') as RefusedImage).reason,
        ImageRefusal.otherHost,
      );
      expect(
        (classifyImage('https://bücher.example/x.png') as RefusedImage).shown,
        'xn--bcher-kva.example',
      );
    });

    test('never draws SVG, data addresses or other types', () {
      expect(
        (classifyImage('logo.svg') as RefusedImage).reason,
        ImageRefusal.svg,
      );
      expect(
        (classifyImage('LOGO.SVG') as RefusedImage).reason,
        ImageRefusal.svg,
      );
      expect(
        (classifyImage('data:image/png;base64,AAAA') as RefusedImage).reason,
        ImageRefusal.unsupported,
      );
      expect(
        (classifyImage('blob:https://example.org/x') as RefusedImage).reason,
        ImageRefusal.otherHost,
      );
      expect(
        (classifyImage('a.bmp') as RefusedImage).reason,
        ImageRefusal.unsupported,
      );
    });

    test('refuses a path outside the repository', () {
      expect(
        (classifyImage(
          '../x.png',
          basePath: 'README.md',
        ) as RefusedImage).reason,
        ImageRefusal.invalidPath,
      );
    });
  });

  group('asciiHost', () {
    test('encodes the RFC 3492 examples', () {
      expect(asciiHost('bücher.example'), 'xn--bcher-kva.example');
      expect(asciiHost('münchen.de'), 'xn--mnchen-3ya.de');
      expect(asciiHost('яндекс.рф'), 'xn--d1acpjx3f.xn--p1ai');
      expect(asciiHost('EXAMPLE.org'), 'example.org');
    });

    test('refuses what is not a host name', () {
      expect(asciiHost(''), isNull);
      expect(asciiHost('a b.example'), isNull);
      expect(asciiHost('a_b.example'), isNull);
      expect(asciiHost('${'a' * 254}.com'), isNull);
    });
  });
}

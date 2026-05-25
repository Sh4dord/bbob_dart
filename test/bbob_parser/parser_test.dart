import 'package:bbob_dart/bbob_dart.dart';
import 'package:bbob_dart/src/bbob_parser/parser.dart';
import 'package:test/test.dart';

void main() {
  // ── helpers ──────────────────────────────────────────────────────────────

  validateNodes(List<Node> ast, List<Node> output) {
    expect(ast.length, output.length,
        reason:
        'Node count mismatch.\n  AST:      $ast\n  Expected: $output');

    validateNode(Node ast, Node output) {
      if (ast is Element && output is Element) {
        expect(ast.tag, output.tag, reason: 'Tag mismatch');
        expect(ast.attributes, equals(output.attributes),
            reason: 'Attributes mismatch on tag "${ast.tag}"');
        validateNodes(ast.children, output.children);
      } else if (ast is Text && output is Text) {
        expect(ast.textContent, output.textContent,
            reason: 'Text content mismatch');
      } else {
        fail('Node type mismatch: got ${ast.runtimeType}, '
            'expected ${output.runtimeType}');
      }

      expect(ast.toString(), equals(output.toString()));
    }

    for (var i = 0; i < ast.length; i++) {
      validateNode(ast[i], output[i]);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  1. BASIC / UNIT TESTS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Basic / Unit', () {
    test('empty string produces empty AST', () {
      expect(parse(''), isEmpty);
    });

    test('plain text without any tags', () {
      final ast = parse('Hello, world!');
      validateNodes(ast, [
        Text('Hello,'),
        Text(' '),
        Text('world!'),
      ]);
    });

    test('single self-closing tag (no closing tag)', () {
      final ast = parse('[hr]');
      validateNodes(ast, [
        Element('hr', {}, []),
      ]);
    });

    test('single paired tag', () {
      final ast = parse('[b]Bold[/b]');
      validateNodes(ast, [
        Element('b', {}, [Text('Bold')]),
      ]);
    });

    test('tag with single value attribute (url style)', () {
      final ast = parse('[url=https://example.com]Link[/url]');
      validateNodes(ast, [
        Element(
          'url',
          {'https://example.com': 'https://example.com'},
          [Text('Link')],
        ),
      ]);
    });

    test('tag with named attributes', () {
      final ast = parse('[img src=photo.jpg width=100]');
      validateNodes(ast, [
        Element('img', {'src': 'photo.jpg', 'width': '100'}, []),
      ]);
    });

    test('tag with quoted attribute containing spaces', () {
      final ast = parse('[quote author="John Doe"]Hello[/quote]');
      validateNodes(ast, [
        Element(
          'quote',
          {'author': 'John Doe'},
          [Text('Hello')],
        ),
      ]);
    });

    test('text before, between, and after tags', () {
      final ast = parse('AAA [b]BBB[/b] CCC');
      validateNodes(ast, [
        Text('AAA'),
        Text(' '),
        Element('b', {}, [Text('BBB')]),
        Text(' '),
        Text('CCC'),
      ]);
    });

    test('multiple sibling tags', () {
      final ast = parse('[b]A[/b][i]B[/i][u]C[/u]');
      validateNodes(ast, [
        Element('b', {}, [Text('A')]),
        Element('i', {}, [Text('B')]),
        Element('u', {}, [Text('C')]),
      ]);
    });

    test('newline inside tag content', () {
      final ast = parse('[p]Line1\nLine2[/p]');
      validateNodes(ast, [
        Element('p', {}, [
          Text('Line1'),
          Text('\n'),
          Text('Line2'),
        ]),
      ]);
    });

    test('tag with spaces in content', () {
      final ast = parse('[b]Hello World[/b]');
      validateNodes(ast, [
        Element('b', {}, [
          Text('Hello'),
          Text(' '),
          Text('World'),
        ]),
      ]);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  2. NESTED TAGS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Nested tags', () {
    test('simple two-level nesting', () {
      final ast = parse('[b][i]Text[/i][/b]');
      validateNodes(ast, [
        Element('b', {}, [
          Element('i', {}, [Text('Text')]),
        ]),
      ]);
    });

    test('three-level deep nesting', () {
      final ast = parse('[a][b][c]Deep[/c][/b][/a]');
      validateNodes(ast, [
        Element('a', {}, [
          Element('b', {}, [
            Element('c', {}, [Text('Deep')]),
          ]),
        ]),
      ]);
    });

    test('nested tags with text at every level', () {
      final ast = parse('[a]L1 [b]L2 [c]L3[/c] L2[/b] L1[/a]');
      validateNodes(ast, [
        Element('a', {}, [
          Text('L1'),
          Text(' '),
          Element('b', {}, [
            Text('L2'),
            Text(' '),
            Element('c', {}, [Text('L3')]),
            Text(' '),
            Text('L2'),
          ]),
          Text(' '),
          Text('L1'),
        ]),
      ]);
    });

    test('nested tags with attributes', () {
      final ast =
      parse('[div class=outer][span style=bold]Hi[/span][/div]');
      validateNodes(ast, [
        Element('div', {'class': 'outer'}, [
          Element('span', {'style': 'bold'}, [Text('Hi')]),
        ]),
      ]);
    });

    test('multiple children at same nesting level', () {
      final ast = parse('[p][b]A[/b] and [i]B[/i][/p]');
      validateNodes(ast, [
        Element('p', {}, [
          Element('b', {}, [Text('A')]),
          Text(' '),
          Text('and'),
          Text(' '),
          Element('i', {}, [Text('B')]),
        ]),
      ]);
    });

    test('same tag nested (e.g. [quote] inside [quote])', () {
      final ast = parse('[quote]Outer [quote]Inner[/quote] Outer[/quote]');
      validateNodes(ast, [
        Element('quote', {}, [
          Text('Outer'),
          Text(' '),
          Element('quote', {}, [Text('Inner')]),
          Text(' '),
          Text('Outer'),
        ]),
      ]);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  3. validTags FILTERING
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('validTags filtering', () {
    test('tag without attributes rendered as text', () {
      final ast = parse('[h1]Foo [Bar] [/h1]', validTags: {'h1'});
      validateNodes(ast, [
        Element('h1', {}, [
          Text('Foo'),
          Text(' '),
          Text('[Bar]'),
          Text(' '),
        ]),
      ]);
    });

    // Issue #5: attributes must be preserved on invalid tags
    test('tag with value attribute rendered as text preserves attribute', () {
      final ast = parse('[h1]Foo [Bar=Quz]Quux[/Bar] [/h1]',
          validTags: {'h1'});
      validateNodes(ast, [
        Element('h1', {}, [
          Text('Foo'),
          Text(' '),
          Text('[Bar=Quz]'),
          Text('Quux'),
          Text('[/Bar]'),
          Text(' '),
        ]),
      ]);
    });

    test('tag with named attributes rendered as text preserves all attrs',
            () {
          final ast = parse(
              '[h1]Hello [foo bar=baz qux=123]World[/foo][/h1]',
              validTags: {'h1'});
          validateNodes(ast, [
            Element('h1', {}, [
              Text('Hello'),
              Text(' '),
              Text('[foo bar=baz qux=123]'),
              Text('World'),
              Text('[/foo]'),
            ]),
          ]);
        });

    test('invalid tag with attributes at top level (no parent)', () {
      final ast =
      parse('[invalid=value]Content[/invalid]', validTags: {'b'});
      validateNodes(ast, [
        Text('[invalid=value]'),
        Text('Content'),
        Text('[/invalid]'),
      ]);
    });

    test('all tags invalid when validTags is empty set', () {
      final ast = parse('[b]Bold[/b]', validTags: {});
      validateNodes(ast, [
        Text('[b]'),
        Text('Bold'),
        Text('[/b]'),
      ]);
    });

    test('null validTags treats every tag as valid (default)', () {
      final ast = parse('[anything]Text[/anything]');
      validateNodes(ast, [
        Element('anything', {}, [Text('Text')]),
      ]);
    });

    test('mix of valid and invalid tags', () {
      final ast =
      parse('[b]Bold [color=red]Red[/color][/b]', validTags: {'b'});
      validateNodes(ast, [
        Element('b', {}, [
          Text('Bold'),
          Text(' '),
          Text('[color=red]'),
          Text('Red'),
          Text('[/color]'),
        ]),
      ]);
    });

    test('valid tag nested inside content that has invalid siblings', () {
      final ast = parse(
        '[div][unknown]X[/unknown] [b]Y[/b][/div]',
        validTags: {'div', 'b'},
      );
      validateNodes(ast, [
        Element('div', {}, [
          Text('[unknown]'),
          Text('X'),
          Text('[/unknown]'),
          Text(' '),
          Element('b', {}, [Text('Y')]),
        ]),
      ]);
    });

    test('multiple consecutive invalid tags with attributes', () {
      final ast = parse(
        '[a=1]A[/a][b=2]B[/b]',
        validTags: {},
      );
      validateNodes(ast, [
        Text('[a=1]'),
        Text('A'),
        Text('[/a]'),
        Text('[b=2]'),
        Text('B'),
        Text('[/b]'),
      ]);
    });

    test('valid parent with attributes + invalid child with attributes', () {
      final ast = parse(
        '[h1 name=value]Foo [Bar=Quz]Quux[/Bar] [/h1]',
        validTags: {'h1'},
      );
      validateNodes(ast, [
        Element('h1', {'name': 'value'}, [
          Text('Foo'),
          Text(' '),
          Text('[Bar=Quz]'),
          Text('Quux'),
          Text('[/Bar]'),
          Text(' '),
        ]),
      ]);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  4. MALFORMED / EDGE-CASE INPUT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Malformed / edge cases', () {
    test('opening tag without closing tag', () {
      final ast = parse('[b]Bold text without close');
      // [b] is non-nested (no [/b] in input), so it becomes a standalone
      // Element and text follows at root.
      validateNodes(ast, [
        Element('b', {}, []),
        Text('Bold'),
        Text(' '),
        Text('text'),
        Text(' '),
        Text('without'),
        Text(' '),
        Text('close'),
      ]);
    });

    test('closing tag without opening tag triggers onError', () {
      bool errorTriggered = false;
      parse('[/b]', onError: (_) {
        errorTriggered = true;
      });
      // [/b] is a tag end with no matching start
      expect(errorTriggered, isTrue);
    });

    test('mismatched tags trigger onError', () {
      final errors = <ParseErrorMessage>[];
      parse('[b]Hello[/i]', onError: (e) {
        errors.add(e);
      });
      expect(errors, isNotEmpty);
    });

    test('stray close bracket treated as word', () {
      final ast = parse('Hello ] World');
      validateNodes(ast, [
        Text('Hello'),
        Text(' '),
        Text(']'),
        Text(' '),
        Text('World'),
      ]);
    });

    test('stray open bracket treated as word', () {
      final ast = parse('Hello [ World');
      validateNodes(ast, [
        Text('Hello'),
        Text(' '),
        Text('['),
        Text(' '),
        Text('World'),
      ]);
    });

    test('empty tag brackets', () {
      final ast = parse('[]');
      validateNodes(ast, [
        Text('['),
        Text(']'),
      ]);
    });

    test('only whitespace', () {
      final ast = parse('   ');
      validateNodes(ast, [
        Text('   '),
      ]);
    });

    test('only newlines', () {
      final ast = parse('\n\n');
      validateNodes(ast, [
        Text('\n'),
        Text('\n'),
      ]);
    });

    test('tag immediately followed by another tag (no space)', () {
      final ast = parse('[b]A[/b][i]B[/i]');
      validateNodes(ast, [
        Element('b', {}, [Text('A')]),
        Element('i', {}, [Text('B')]),
      ]);
    });

    test('deeply nested then abruptly closed', () {
      // [a][b][c]X[/a] — b and c are never properly closed
      // Just verify no crash.
      final ast = parse('[a][b][c]X[/a]');
      expect(ast, isNotNull);
      expect(ast, isNotEmpty);
    });

    test('tag containing equals sign in value (url query string)', () {
      final ast =
      parse('[url=https://site.com/?x=1&y=2]Link[/url]');
      validateNodes(ast, [
        Element(
          'url',
          {'https://site.com/?x=1&y=2': 'https://site.com/?x=1&y=2'},
          [Text('Link')],
        ),
      ]);
    });

    test('special characters in content', () {
      final ast = parse('[b]<>&"\'[/b]');
      validateNodes(ast, [
        Element('b', {}, [Text('<>&"\'')]),
      ]);
    });

    test('unclosed tag at end of input', () {
      final ast = parse('[b');
      validateNodes(ast, [
        Text('['),
        Text('b'),
      ]);
    });

    test('tag with no content between open/close', () {
      final ast = parse('[b][/b]');
      validateNodes(ast, [
        Element('b', {}, []),
      ]);
    });

    test('only open bracket', () {
      final ast = parse('[');
      // The lexer sees '[' then isLast, so emits Word('[').
      expect(ast, isNotNull);
    });

    test('only close bracket', () {
      final ast = parse(']');
      validateNodes(ast, [
        Text(']'),
      ]);
    });

    test('equals sign alone in brackets', () {
      final ast = parse('[=]');
      validateNodes(ast, [
        Text('['),
        Text('=]'),
      ]);
    });

    test('nested open brackets without close', () {
      // '[Hello [World' — the first [ has an inner [, so substring has
      // invalid chars and emits as word.
      final ast = parse('[Hello [World');
      expect(ast, isNotNull);
      expect(ast, isNotEmpty);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  5. COMPLEX / INTEGRATION SCENARIOS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Complex / Integration', () {
    test('realistic forum post with nested formatting', () {
      final ast = parse(
          '[quote author="Alice"]She said [b][i]hello[/i][/b][/quote]');
      validateNodes(ast, [
        Element('quote', {'author': 'Alice'}, [
          Text('She'),
          Text(' '),
          Text('said'),
          Text(' '),
          Element('b', {}, [
            Element('i', {}, [Text('hello')]),
          ]),
        ]),
      ]);
    });

    test('list with items', () {
      final ast = parse('[list][*]A[*]B[*]C[/list]');
      validateNodes(ast, [
        Element('list', {}, [
          Element('*', {}, []),
          Text('A'),
          Element('*', {}, []),
          Text('B'),
          Element('*', {}, []),
          Text('C'),
        ]),
      ]);
    });

    test('tag with multiple named attributes', () {
      final ast = parse(
        '[video width=640 height=480 autoplay=true]clip.mp4[/video]',
      );
      validateNodes(ast, [
        Element(
          'video',
          {'width': '640', 'height': '480', 'autoplay': 'true'},
          [Text('clip.mp4')],
        ),
      ]);
    });

    test('mixed valid/invalid with nesting and validTags', () {
      // Only 'b' and 'quote' are valid.
      final ast = parse(
        '[quote][b]Bold [color=red]Red[/color][/b] plain[/quote]',
        validTags: {'b', 'quote'},
      );
      validateNodes(ast, [
        Element('quote', {}, [
          Element('b', {}, [
            Text('Bold'),
            Text(' '),
            Text('[color=red]'),
            Text('Red'),
            Text('[/color]'),
          ]),
          Text(' '),
          Text('plain'),
        ]),
      ]);
    });

    test('interleaved text and tags at root', () {
      final ast = parse('Start [b]B[/b] middle [i]I[/i] end');
      validateNodes(ast, [
        Text('Start'),
        Text(' '),
        Element('b', {}, [Text('B')]),
        Text(' '),
        Text('middle'),
        Text(' '),
        Element('i', {}, [Text('I')]),
        Text(' '),
        Text('end'),
      ]);
    });

    test('rapid open/close of different tags', () {
      final ast = parse('[a][/a][b][/b][c][/c]');
      validateNodes(ast, [
        Element('a', {}, []),
        Element('b', {}, []),
        Element('c', {}, []),
      ]);
    });

    test('nested tags where inner has attributes and outer does not', () {
      final ast = parse('[outer][inner key=val]Text[/inner][/outer]');
      validateNodes(ast, [
        Element('outer', {}, [
          Element('inner', {'key': 'val'}, [Text('Text')]),
        ]),
      ]);
    });

    test('realistic bbcode with multiple formatting', () {
      final input =
          '[b]Hello[/b] [i]world[/i]! Check [url=https://example.com]this[/url].';
      final ast = parse(input);
      validateNodes(ast, [
        Element('b', {}, [Text('Hello')]),
        Text(' '),
        Element('i', {}, [Text('world')]),
        Text('!'),
        Text(' '),
        Text('Check'),
        Text(' '),
        Element(
          'url',
          {'https://example.com': 'https://example.com'},
          [Text('this')],
        ),
        Text('.'),
      ]);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  6. ESCAPE TAGS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Escape tags', () {
    test('escaped tags become literal text', () {
      final ast = parse(r'\[b\]test\[/b\]', enableEscapeTags: true);
      validateNodes(ast, [
        Text('['),
        Text('b'),
        Text(']'),
        Text('test'),
        Text('['),
        Text('/b'),
        Text(']'),
      ]);
    });

    test('escaped backslash', () {
      final ast = parse(r'\\hello', enableEscapeTags: true);
      validateNodes(ast, [
        Text(r'\'),
        Text('hello'),
      ]);
    });

    test('mix of escaped and real tags', () {
      final ast =
      parse(r'\[not-a-tag\] [b]Real[/b]', enableEscapeTags: true);
      validateNodes(ast, [
        Text('['),
        Text('not-a-tag'),
        Text(']'),
        Text(' '),
        Element('b', {}, [Text('Real')]),
      ]);
    });

    test('escape disabled by default — backslash is normal text', () {
      // With enableEscapeTags=false (default), backslash is just a char.
      final ast = parse(r'\[b]test[/b]');
      // '\' is not a token char (it's in reserved), so the lexer skips it
      // or emits it based on context. The '[b]' is still a valid tag.
      expect(ast, isNotNull);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  7. CUSTOM OPEN/CLOSE TAGS (HTML-style)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Custom delimiters (HTML-style)', () {
    parseHTML(String input, {Set<String>? validTags}) => parse(
      input,
      openTag: '<',
      closeTag: '>',
      validTags: validTags,
    );

    test('basic HTML-style tag', () {
      final ast = parseHTML('<b>Bold</b>');
      validateNodes(ast, [
        Element('b', {}, [Text('Bold')]),
      ]);
    });

    test('HTML-style nested tags', () {
      final ast = parseHTML('<div><span>Hi</span></div>');
      validateNodes(ast, [
        Element('div', {}, [
          Element('span', {}, [Text('Hi')]),
        ]),
      ]);
    });

    test('HTML-style tag with attributes', () {
      final ast = parseHTML('<a href=http://example.com>Link</a>');
      validateNodes(ast, [
        Element(
          'a',
          {'href': 'http://example.com'},
          [Text('Link')],
        ),
      ]);
    });

    test('HTML-style with validTags filtering', () {
      final ast = parseHTML(
        '<div><script>alert(1)</script></div>',
        validTags: {'div'},
      );
      validateNodes(ast, [
        Element('div', {}, [
          Text('<script>'),
          Text('alert(1)'),
          Text('</script>'),
        ]),
      ]);
    });

    test('HTML-style plain text without tags', () {
      final ast = parseHTML('Just text');
      validateNodes(ast, [
        Text('Just'),
        Text(' '),
        Text('text'),
      ]);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  8. OO-STYLE PARSER (reuse & idempotence)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('OO-style Parser reuse', () {
    test('parser returns idempotent results on repeated calls', () {
      final parser = Parser();
      final input = '[b]Hello[/b]';

      final expected = [
        Element('b', {}, [Text('Hello')]),
      ];

      validateNodes(parser.parse(input), expected);
      validateNodes(parser.parse(input), expected);
      validateNodes(parser.parse(input), expected);
    });

    test('parser reuse with different inputs', () {
      final parser = Parser();

      final ast1 = parser.parse('[b]A[/b]');
      validateNodes(ast1, [Element('b', {}, [Text('A')])]);

      final ast2 = parser.parse('[i]B[/i]');
      validateNodes(ast2, [Element('i', {}, [Text('B')])]);

      // Note: parse() returns the internal _nodes list, so ast1 and ast2
      // are the same reference. After the second parse, both point to [i]B.
      // This is a known limitation of the Parser API. If snapshot semantics
      // are needed, callers should copy the result: List.of(parser.parse(...)).
      expect(identical(ast1, ast2), isTrue);
    });

    test('parser with validTags returns idempotent results', () {
      final parser = Parser(validTags: {'b'});
      final input = '[b]Bold [i]Italic[/i][/b]';

      final result1 = parser.parse(input);
      final result2 = parser.parse(input);

      expect(result1.length, result2.length);
      expect(result1.toString(), result2.toString());
    });

    test('parser idempotence with invalid tags + attributes (issue #5)', () {
      final parser = Parser(validTags: {'h1'});
      final input = '[h1][foo=bar]Text[/foo][/h1]';

      final r1 = parser.parse(input);
      final r2 = parser.parse(input);
      final r3 = parser.parse(input);

      expect(r1.toString(), r2.toString());
      expect(r2.toString(), r3.toString());
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  9. ERROR CALLBACK
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Error callback', () {
    test('inconsistent close tag fires onError', () {
      bool onErrorCalled = false;
      parse('[b]Hello[/i]', onError: (_) {
        onErrorCalled = true;
      });
      expect(onErrorCalled, isTrue);
    });

    test('orphan close tag fires onError', () {
      bool onErrorCalled = false;
      parse('[/orphan]', onError: (_) {
        onErrorCalled = true;
      });
      expect(onErrorCalled, isTrue);
    });

    test('no error on well-formed input', () {
      bool onErrorCalled = false;
      parse('[b]OK[/b]', onError: (_) {
        onErrorCalled = true;
      });
      expect(onErrorCalled, isFalse);
    });

    test('error message contains tag name', () {
      ParseErrorMessage? received;
      parse('[b]X[/i]', onError: (e) {
        received = e;
      });
      expect(received, isNotNull);
      expect(received!.tagName, contains('i'));
    });

    test('multiple errors are all reported', () {
      final errors = <ParseErrorMessage>[];
      parse('[/a][/b][/c]', onError: (e) {
        errors.add(e);
      });
      expect(errors.length, 3);
    });

    test('no error when no onError callback is provided', () {
      // Should not throw even without an onError callback.
      expect(() => parse('[/orphan]'), returnsNormally);
    });

    test('error on multiple mismatched close tags in nested context', () {
      final errors = <ParseErrorMessage>[];
      parse('[a][b]Hello[/c][/d]', onError: (e) {
        errors.add(e);
      });
      expect(errors, isNotEmpty);
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  10. STRESS / ROBUSTNESS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Stress / Robustness', () {
    test('no crash on large input', () {
      final buf = StringBuffer();
      for (var i = 0; i < 1000; i++) {
        buf.write('[b]x[/b]');
      }
      final ast = parse(buf.toString());
      expect(ast.length, 1000);
    });

    test('no crash on deeply nested input', () {
      final buf = StringBuffer();
      const depth = 100;
      for (var i = 0; i < depth; i++) {
        buf.write('[t$i]');
      }
      buf.write('leaf');
      for (var i = depth - 1; i >= 0; i--) {
        buf.write('[/t$i]');
      }
      final ast = parse(buf.toString());
      expect(ast, isNotEmpty);
    });

    test('no crash on garbage input', () {
      const garbage = r'[[[]] ]=== \\\[not[a tag]]][/] [/ [';
      final ast = parse(garbage);
      expect(ast, isNotNull);
    });

    test('no crash on input with only brackets', () {
      final ast = parse('[][][][][][]');
      expect(ast, isNotNull);
      expect(ast, isNotEmpty);
    });

    test('no crash on unicode content', () {
      final ast = parse('[b]日本語テスト 🎉[/b]');
      expect(ast, isNotEmpty);
      final el = ast[0] as Element;
      expect(el.tag, 'b');
      expect(el.textContent, contains('日本語'));
    });

    test('no crash on very long tag name', () {
      final longTag = 'a' * 500;
      final ast = parse('[$longTag]Content[/$longTag]');
      expect(ast, isNotEmpty);
    });

    test('no crash on many attributes', () {
      final buf = StringBuffer('[tag');
      for (var i = 0; i < 100; i++) {
        buf.write(' attr$i=val$i');
      }
      buf.write(']Content[/tag]');
      final ast = parse(buf.toString());
      expect(ast, isNotEmpty);
      final el = ast[0] as Element;
      expect(el.attributes.length, 100);
    });

    test('large number of invalid tags with attributes (issue #5 stress)',
            () {
          final buf = StringBuffer();
          for (var i = 0; i < 200; i++) {
            buf.write('[inv$i=v$i]');
          }
          final ast = parse(buf.toString(), validTags: {});
          expect(ast, isNotNull);
          expect(ast.length, 200);
          // All should be Text nodes like [inv0=v0], [inv1=v1], ...
          for (var node in ast) {
            expect(node, isA<Text>());
            expect((node as Text).textContent, startsWith('[inv'));
            expect(node.textContent, endsWith(']'));
            expect(node.textContent, contains('='));
          }
        });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  11. textContent ACCESSOR
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('textContent', () {
    test('Text node returns its text', () {
      expect(Text('abc').textContent, 'abc');
    });

    test('Element with no children returns empty string', () {
      expect(Element('b').textContent, '');
    });

    test('Element concatenates all children text', () {
      final el = Element('b', {}, [
        Text('Hello'),
        Text(' '),
        Text('World'),
      ]);
      expect(el.textContent, 'Hello World');
    });

    test('Nested elements concatenate recursively', () {
      final ast = parse('[a]X[b]Y[/b]Z[/a]');
      final el = ast[0] as Element;
      expect(el.textContent, 'XYZ');
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  12. ORIGINAL UPSTREAM TESTS (preserved)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Original upstream tests', () {
    test('parses paired tags tokens', () {
      final ast = parse('[best name=value]Foo Bar[/best]');
      validateNodes(ast, [
        Element(
          'best',
          {'name': 'value'},
          [
            Text('Foo'),
            Text(' '),
            Text('Bar'),
          ],
        )
      ]);
    });

    test('parses only allowed tags', () {
      final ast = parse('[h1 name=value]Foo [Bar] [/h1]', validTags: {'h1'});
      validateNodes(ast, [
        Element(
          'h1',
          {'name': 'value'},
          [
            Text('Foo'),
            Text(' '),
            Text('[Bar]'),
            Text(' '),
          ],
        )
      ]);
    });

    test('parses inconsistent tags', () {
      final ast = parse('[h1 name=value]Foo [Bar] /h1]');
      validateNodes(ast, [
        Element('h1', {'name': 'value'}, []),
        Text('Foo'),
        Text(' '),
        Element('Bar', {}, []),
        Text(' '),
        Text('/h1]'),
      ]);
    });

    test('parses tag with value param', () {
      final ast = parse(
        '[url=https://github.com/jilizart/bbob]BBob[/url]',
      );
      validateNodes(ast, [
        Element(
          'url',
          {
            'https://github.com/jilizart/bbob':
            'https://github.com/jilizart/bbob'
          },
          [Text('BBob')],
        ),
      ]);
    });

    test('parses tag with quoted param with spaces', () {
      final ast = parse(
        '[url href=https://ru.wikipedia.org target=_blank text="Foo Bar"]Text[/url]',
      );
      validateNodes(ast, [
        Element(
          'url',
          {
            'href': 'https://ru.wikipedia.org',
            'target': '_blank',
            'text': 'Foo Bar',
          },
          [Text('Text')],
        ),
      ]);
    });

    test('parses single tag with params', () {
      final ast = parse('[url=https://github.com/jilizart/bbob]');
      validateNodes(ast, [
        Element(
          'url',
          {
            'https://github.com/jilizart/bbob':
            'https://github.com/jilizart/bbob',
          },
          [],
        ),
      ]);
    });

    test('detects inconsistent tag', () {
      bool onErrorCalled = false;
      final ast = parse('[c][/c][b]hello[/c][/b][b]', onError: (_) {
        onErrorCalled = true;
      });
      validateNodes(ast, [
        Element('c', {}, []),
        Element('b', {}, [Text('hello')]),
      ]);
      expect(onErrorCalled, isTrue);
    });

    test('parse escaped tags', () {
      final ast = parse(r'\[b\]test\[/b\]', enableEscapeTags: true);
      validateNodes(ast, [
        Text('['),
        Text('b'),
        Text(']'),
        Text('test'),
        Text('['),
        Text('/b'),
        Text(']'),
      ]);
    });

    test('oo-style parser returns idempotent result', () {
      final parser = Parser();
      final input = '[h1 name=value]Foo [Bar] /h1]';

      final expected = [
        Element('h1', {'name': 'value'}, []),
        Text('Foo'),
        Text(' '),
        Element('Bar', {}, []),
        Text(' '),
        Text('/h1]'),
      ];

      validateNodes(parser.parse(input), expected);
      validateNodes(parser.parse(input), expected);
      validateNodes(parser.parse(input), expected);
    });

    group('html', () {
      parseHTML(String input) => parse(input, openTag: '<', closeTag: '>');

      test('normal attributes', () {
        const content =
            r'<button id="test0" class="value0" title="value1">class="value0" '
            r'title="value1"</button>';
        final ast = parseHTML(content);
        validateNodes(ast, [
          Element(
            'button',
            {'id': 'test0', 'class': 'value0', 'title': 'value1'},
            [
              Text('class="value0"'),
              Text(' '),
              Text('title="value1"'),
            ],
          ),
        ]);
      });

      test('attributes with no quotes or value', () {
        const content =
            r'<button id="test1" class=value2 disabled required>class=value2 '
            r'disabled</button>';
        final ast = parseHTML(content);
        validateNodes(ast, [
          Element(
            'button',
            {
              'id': 'test1',
              'class': 'value2',
              'disabled': 'disabled',
              'required': 'required',
            },
            [
              Text('class=value2'),
              Text(' '),
              Text('disabled'),
            ],
          ),
        ]);
      });

      test(
          'attributes with no space between them. no valid, but accepted by the browser',
              () {
            const content = r'<button id="test2" class="value4"title="value5">'
                r'class="value4"title="value5"</button>';
            final ast = parseHTML(content);
            validateNodes(ast, [
              Element(
                'button',
                {
                  'id': 'test2',
                  'class': 'value4',
                  'title': 'value5',
                },
                [
                  Text('class="value4"title="value5"'),
                ],
              ),
            ]);
          });
    });
  });

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  13. QUOTED ATTRIBUTES WITH SPACES (rgb, font names, etc.)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  group('Quoted attributes with spaces', () {
    test('color tag with quoted rgb value containing spaces', () {
      final ast = parse('[color="rgb(221, 0, 67)"]Red text[/color]');
      validateNodes(ast, [
        Element(
          'color',
          {'rgb(221, 0, 67)': 'rgb(221, 0, 67)'},
          [
            Text('Red'),
            Text(' '),
            Text('text'),
          ],
        ),
      ]);
    });

    test('size tag with quoted px value', () {
      final ast = parse('[size="18px"]Big[/size]');
      validateNodes(ast, [
        Element(
          'size',
          {'18px': '18px'},
          [Text('Big')],
        ),
      ]);
    });

    test('nested color + size + bold (real-world release note)', () {
      final ast = parse(
        '[color="rgb(221, 0, 67)"][size="18px"][b]Title[/b][/size][/color]',
      );
      validateNodes(ast, [
        Element(
          'color',
          {'rgb(221, 0, 67)': 'rgb(221, 0, 67)'},
          [
            Element(
              'size',
              {'18px': '18px'},
              [
                Element('b', {}, [Text('Title')]),
              ],
            ),
          ],
        ),
      ]);
    });

    test('named attribute with quoted value containing spaces', () {
      final ast = parse('[quote author="John Doe"]Hello[/quote]');
      validateNodes(ast, [
        Element(
          'quote',
          {'author': 'John Doe'},
          [Text('Hello')],
        ),
      ]);
    });

    test('multiple attributes, one quoted with spaces', () {
      final ast = parse('[tag id=42 label="Foo Bar"]Content[/tag]');
      validateNodes(ast, [
        Element(
          'tag',
          {'id': '42', 'label': 'Foo Bar'},
          [Text('Content')],
        ),
      ]);
    });

    test('quoted url with equals and spaces', () {
      final ast = parse('[url href="https://x.com?a=1&b=2" title="My Link"]Go[/url]');
      validateNodes(ast, [
        Element(
          'url',
          {'href': 'https://x.com?a=1&b=2', 'title': 'My Link'},
          [Text('Go')],
        ),
      ]);
    });

    test('color with rgb no spaces still works', () {
      final ast = parse('[color=rgb(255,0,0)]Red[/color]');
      validateNodes(ast, [
        Element(
          'color',
          {'rgb(255,0,0)': 'rgb(255,0,0)'},
          [Text('Red')],
        ),
      ]);
    });

    test('color with hex still works', () {
      final ast = parse('[color=#FF0000]Red[/color]');
      validateNodes(ast, [
        Element(
          'color',
          {'#FF0000': '#FF0000'},
          [Text('Red')],
        ),
      ]);
    });

    test('complex real-world bbcode snippet parses without crash', () {
      const input =
          '[color="rgb(221, 0, 67)"][size="18px"][b][WEBAPP] release/8.4.0[/b][/size][/color]\n'
          '[color="#F2C000"][size="18px"]Updated Tuesday[/size][/color]';
      final ast = parse(input);
      expect(ast, isNotEmpty);

      // First element should be color with the full rgb value
      final firstColor = ast[0] as Element;
      expect(firstColor.tag, 'color');
      expect(firstColor.attributes.keys.first, 'rgb(221, 0, 67)');
    });

    test('list with color-tagged items (real-world pattern)', () {
      const input =
          '[list]'
          '[*][size="18px"][color="#FF8C00"][BUG][/color][/size] Fix crash'
          '[*][size="18px"][color="#338500"][FEATURE][/color][/size] New thing'
          '[/list]';
      final ast = parse(input);
      expect(ast, isNotEmpty);

      final list = ast[0] as Element;
      expect(list.tag, 'list');
      // Should contain * items with nested size/color elements
      final children = list.children;
      expect(children.any((c) => c is Element && c.tag == '*'), isTrue);
    });
  });
}
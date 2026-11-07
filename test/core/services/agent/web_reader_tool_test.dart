import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/web_reader_tool.dart';

void main() {
  test('forwards the parsed url to the fetcher', () async {
    final List<Uri> seen = <Uri>[];
    final WebReaderTool tool = WebReaderTool(
      fetchText: (Uri uri) async {
        seen.add(uri);
        return 'page text';
      },
    );

    final String out = await tool.execute(<String, dynamic>{
      'url': 'https://example.com/a?b=1',
    }, <String, dynamic>{});

    expect(out, 'page text');
    expect(seen.single.toString(), 'https://example.com/a?b=1');
  });

  test('a missing url defaults to the empty uri, not a crash', () async {
    final List<Uri> seen = <Uri>[];
    final WebReaderTool tool = WebReaderTool(
      fetchText: (Uri uri) async {
        seen.add(uri);
        return 'empty';
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{},
      <String, dynamic>{},
    );

    expect(out, 'empty');
    expect(seen.single, Uri.parse(''));
  });

  test('a fetcher error propagates (the webview path completes the future '
      'with an error)', () async {
    final WebReaderTool tool = WebReaderTool(
      fetchText: (Uri uri) async => throw StateError('boom'),
    );

    await expectLater(
      tool.execute(<String, dynamic>{
        'url': 'https://x.dev',
      }, <String, dynamic>{}),
      throwsStateError,
    );
  });
}

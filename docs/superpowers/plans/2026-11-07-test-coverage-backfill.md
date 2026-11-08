# Test Coverage Backfill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the five gaps from the 2026-11-07 testing coverage review: `localizeFailure` has no test, four agent tools have no tests (and no injectable seams), four repository impls have no mapping/failure tests, no coverage measurement exists in the tooling, and the test suite has no README.

**Architecture:** Pure test additions plus minimal constructor-seam refactors that mirror the codebase's own `WeatherTool` pattern (`typedef` + optional constructor param + production default). No DI changes, no ARB changes, no codegen regenerations needed. One new shell script (`scripts/fcoverage.sh`) and one doc file.

**Tech Stack:** Flutter/Dart, flutter_test, mocktail, bash+awk.

**Spec:** The coverage review delivered in-session on 2026-11-07 (recommendations 1–5). This plan is the executable form of those five recommendations.

## Global Constraints

- **Explicit types everywhere** (`always_specify_types: true`): no `var`, no type inference in new code — write `final String x = ...`, `List<Foo> ys = <Foo>[]`.
- **Relative imports** within the package (`import '../../../core/models/failure.dart';`), never `package:yofardev_ai/...` inside `lib/`.
- **mocktail, never mockito.** `registerFallbackValue` for any non-primitive used with `any()`.
- **Never display `Failure.message`** in UI or assert on it in tests — assert the Failure *type* (`isA<StorageFailure>()`).
- **Never hand-edit** `*.g.dart` / `*.freezed.dart` / `lib/core/l10n/generated/` — no task here touches them; all ARB keys used already exist.
- **Working tree has uncommitted user changes** (`lib/features/home/widgets/stage/stage_caption.dart`, `stage_line.dart`, `test/features/home/widgets/stage/stage_caption_test.dart`). NEVER run `git add -A`, `git add .`, or `git commit -a`. Stage only the exact files each task lists.
- **Quality gate before finishing** (the workflow runs it for you): `dart fix --apply`, `dart format` on the touched files, `./scripts/fverify.sh`.
- Test file paths mirror the lib path of the class under test.

---

### Task 1: `localizeFailure` table test

`localizeFailure` is the only sanctioned path from `Failure` to user-facing text (AGENTS.md rule), and it is currently untested. A wrong route (e.g. `StorageFailure` → `failureNetwork`) would ship wrong error text. The switch is exhaustive-by-construction, so the test's job is to pin each variant to its getter with the exact ARB strings.

**Files:**
- Create: `test/core/l10n/failure_localization_test.dart`

**Interfaces:**
- Consumes: `localizeFailure(AppLocalizations l10n, Failure failure)` from `lib/core/l10n/failure_localization.dart`; `Failure` variants from `lib/core/models/failure.dart`; `lookupAppLocalizations(Locale)` from `lib/core/l10n/generated/app_localizations.dart` (same pattern as `test/features/home/widgets/stage/tool_kind_test.dart:28`).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the test file**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/l10n/failure_localization.dart';
import 'package:yofardev_ai/core/l10n/generated/app_localizations.dart';
import 'package:yofardev_ai/core/models/failure.dart';

void main() {
  // Exact strings from lib/core/l10n/app_localizations_en.arb (lines 347-351)
  // and app_localizations_fr.arb (lines 125-129).
  const List<(Failure, String, String)> cases = <(Failure, String, String)>[
    (StorageFailure('disk'), 'Failed to save or load data',
      'Échec de l\'enregistrement ou de la lecture des données'),
    (NetworkFailure('offline'), 'Network error', 'Erreur réseau'),
    (TtsFailure('engine'), 'Text-to-speech error',
      'Erreur de synthèse vocale'),
    (ConfigFailure('key'), 'Configuration error', 'Erreur de configuration'),
    (UnknownFailure('??'), 'An unexpected error occurred',
      'Une erreur inattendue est survenue'),
  ];

  test('every Failure variant maps to its own localized string, both locales',
      () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations fr = lookupAppLocalizations(const Locale('fr'));
    for (final (Failure failure, String enText, String frText) in cases) {
      expect(localizeFailure(en, failure), enText, reason: '$failure en');
      expect(localizeFailure(fr, failure), frText, reason: '$failure fr');
    }
  });

  test('each variant maps to a distinct string (no mis-routed variant)', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final Set<String> seen = <String>{};
    for (final (Failure failure, _, _) in cases) {
      final String text = localizeFailure(en, failure);
      expect(seen.contains(text), isFalse,
          reason: '$failure reused another variant\'s string');
      seen.add(text);
    }
  });

  test('the diagnostic message never leaks into the localized text', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    expect(localizeFailure(en, StorageFailure('SECRET-diagnostic')),
        isNot(contains('SECRET-diagnostic')));
  });
}
```

- [ ] **Step 2: Run it, expect pass**

Run: `flutter test test/core/l10n/failure_localization_test.dart`
Expected: all 3 tests PASS (the mapping under test already exists and is correct — this pins it).

- [ ] **Step 3: Commit** (the workflow commits; files: the one test file)

Message: `test(l10n): table test for localizeFailure failure mapping`

---

### Task 2: Seams + tests for the four untested agent tools

`weather_tool_test.dart` is the codebase's own pattern: a `typedef` seam, an optional constructor param, `?? ProductionService.call` default. `tool_registry.dart` constructs all tools with no-arg constructors (`AlarmTool()`, `NewsTool()`, `GoogleSearchTool()`, `WebReaderTool()`), so default-valued constructor params leave every existing call site untouched.

**Files:**
- Modify: `lib/core/services/agent/news_tool.dart`
- Modify: `lib/core/services/agent/google_search_tool.dart`
- Modify: `lib/core/services/agent/alarm_tool.dart`
- Modify: `lib/core/services/agent/web_reader_tool.dart`
- Create: `test/core/services/agent/news_tool_test.dart`
- Create: `test/core/services/agent/google_search_tool_test.dart`
- Create: `test/core/services/agent/alarm_tool_test.dart`
- Create: `test/core/services/agent/web_reader_tool_test.dart`

**Interfaces:**
- Consumes: `AgentTool` contract (`execute(Map<String, dynamic> args, Map<String, dynamic> configValues)` → `Future<String>`).
- Produces: `NewsTool({NewsFetch? fetch})`, `GoogleSearchTool({GoogleSearchFetch? search})`, `AlarmTool({AlarmSetter? setAlarm})`, `WebReaderTool({PageTextFetcher? fetchText})` — all params optional with production defaults; no-arg construction keeps working.

- [ ] **Step 1: Add the seam to `news_tool.dart`**

Replace the class header and `execute` body start; keep `name`, `description`, `parameters`, `requiredConfigKeys` unchanged:

```dart
import '../../models/function_info.dart';

import 'news_service.dart';
import 'agent_tool.dart';

/// Fetches the day's most shared articles as the string for the LLM.
typedef NewsFetch = Future<String> Function(String apiKey);

class NewsTool extends AgentTool {
  /// [fetch] is a test seam (default: [NewsService]).
  NewsTool({NewsFetch? fetch})
    : _fetch = fetch ?? NewsService.getMostPopularNewsOfTheDay;

  final NewsFetch _fetch;

  // ... name / description / parameters / requiredConfigKeys unchanged ...

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    final String? apiKey = configValues['apiKey'] as String?;

    if (apiKey == null || apiKey.isEmpty) {
      return 'Error: New York Times API key not configured';
    }

    try {
      return await _fetch(apiKey);
    } catch (e) {
      return 'Error getting news: $e';
    }
  }
}
```

- [ ] **Step 2: Add the seam to `google_search_tool.dart`**

```dart
/// Runs the query and returns the raw result rows.
typedef GoogleSearchFetch =
    Future<List<Map<String, dynamic>>> Function(
      String query,
      String apiKey,
      String engineId,
    );

class GoogleSearchTool extends AgentTool {
  /// [search] is a test seam (default: [GoogleSearchService]).
  GoogleSearchTool({GoogleSearchFetch? search})
    : _search = search ?? GoogleSearchService.searchGoogle;

  final GoogleSearchFetch _search;

  // ... name / description / parameters / requiredConfigKeys unchanged ...
  // in execute, replace the direct service call:
  //   final List<Map<String, dynamic>> results =
  //       await GoogleSearchService.searchGoogle(query, apiKey, engineId);
  // with:
  //   final List<Map<String, dynamic>> results =
  //       await _search(query, apiKey, engineId);
}
```

- [ ] **Step 3: Add the seam to `alarm_tool.dart`**

```dart
import '../../models/function_info.dart';

import 'alarm_service.dart';
import 'agent_tool.dart';

/// Sets the alarm; returns the service's own result string.
typedef AlarmSetter =
    Future<String> Function(int minutesFromNow, String message);

class AlarmTool extends AgentTool {
  /// [setAlarm] is a test seam (default: [AlarmService]).
  AlarmTool({AlarmSetter? setAlarm})
    : _setAlarm = setAlarm ?? AlarmService.setAlarm;

  final AlarmSetter _setAlarm;

  // ... name / description / parameters / requiredConfigKeys unchanged ...

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    final int minutesFromNow = args['minutesFromNow'] as int? ?? 0;
    final String message = args['message'] as String? ?? 'Hello world!';

    // Call the service through the seam
    await _setAlarm(minutesFromNow, message);
    return 'Alarm set for $minutesFromNow minutes from now with message: "$message"';
  }
}
```

- [ ] **Step 4: Add the seam to `web_reader_tool.dart`**

Move the existing `HeadlessInAppWebView` body into a static private function; `execute` shrinks to arg parsing + the seam:

```dart
import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/function_info.dart';

import 'agent_tool.dart';

/// Reads the rendered text content of [uri].
typedef PageTextFetcher = Future<String> Function(Uri uri);

class WebReaderTool extends AgentTool {
  /// [fetchText] is a test seam (default: the headless webview reader).
  WebReaderTool({PageTextFetcher? fetchText})
    : _fetchText = fetchText ?? _readPageWithHeadlessWebView;

  final PageTextFetcher _fetchText;

  static Future<String> _readPageWithHeadlessWebView(Uri uri) async {
    final Completer<String> completer = Completer<String>();

    final HeadlessInAppWebView headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
      onLoadStop: (InAppWebViewController controller, WebUri? url) async {
        try {
          final String results =
              await controller.evaluateJavascript(
                    source: "document.body.innerText;",
                  )
                  as String? ??
                  'null';
          completer.complete(results);
        } catch (e) {
          completer.completeError(e);
        }
      },
    );

    await headlessWebView.run();
    return completer.future.whenComplete(() {
      headlessWebView.dispose();
    });
  }

  // ... name / description / parameters / requiredConfigKeys unchanged ...

  @override
  Future<String> execute(
    Map<String, dynamic> args,
    Map<String, dynamic> configValues,
  ) async {
    final String url = args['url'] as String? ?? '';
    final Uri uri = Uri.parse(url);
    return _fetchText(uri);
  }
}
```

- [ ] **Step 5: Write `test/core/services/agent/news_tool_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/news_tool.dart';

void main() {
  test('a missing key is an error and never fetches', () async {
    final List<String> keys = <String>[];
    final NewsTool tool = NewsTool(
      fetch: (String apiKey) async {
        keys.add(apiKey);
        return '[]';
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{},
      <String, dynamic>{},
    );

    expect(out, 'Error: New York Times API key not configured');
    expect(keys, isEmpty);
  });

  test('an empty key is an error too', () async {
    final NewsTool tool = NewsTool(fetch: (String apiKey) async => '[]');
    final String out = await tool.execute(
      <String, dynamic>{},
      <String, dynamic>{'apiKey': ''},
    );
    expect(out, 'Error: New York Times API key not configured');
  });

  test('forwards the configured key and returns the service string',
      () async {
    final List<String> keys = <String>[];
    final NewsTool tool = NewsTool(
      fetch: (String apiKey) async {
        keys.add(apiKey);
        return 'headlines';
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{},
      <String, dynamic>{'apiKey': 'nyt-key'},
    );

    expect(out, 'headlines');
    expect(keys, <String>['nyt-key']);
  });

  test('a throwing service becomes an error string, never an exception',
      () async {
    final NewsTool tool = NewsTool(
      fetch: (String apiKey) async => throw StateError('boom'),
    );

    final String out = await tool.execute(
      <String, dynamic>{},
      <String, dynamic>{'apiKey': 'nyt-key'},
    );

    expect(out, startsWith('Error getting news:'));
  });
}
```

- [ ] **Step 6: Write `test/core/services/agent/google_search_tool_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/google_search_tool.dart';

void main() {
  test('a missing API key is an error and never searches', () async {
    final List<String> calls = <String>[];
    final GoogleSearchTool tool = GoogleSearchTool(
      search: (String query, String apiKey, String engineId) async {
        calls.add('$query|$apiKey|$engineId');
        return <Map<String, dynamic>>[];
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{'query': 'cats'},
      <String, dynamic>{'engineId': 'e1'},
    );

    expect(out, 'Error: Google Search API key not configured');
    expect(calls, isEmpty);
  });

  test('a missing engine ID is an error too', () async {
    final GoogleSearchTool tool = GoogleSearchTool(
      search: (String query, String apiKey, String engineId) async =>
          <Map<String, dynamic>>[],
    );

    final String out = await tool.execute(
      <String, dynamic>{'query': 'cats'},
      <String, dynamic>{'apiKey': 'k'},
    );

    expect(out, 'Error: Google Search Engine ID not configured');
  });

  test('forwards query, key and engine ID; returns rows toString()',
      () async {
    final List<String> calls = <String>[];
    final GoogleSearchTool tool = GoogleSearchTool(
      search: (String query, String apiKey, String engineId) async {
        calls.add('$query|$apiKey|$engineId');
        return <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Cats'},
        ];
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{'query': 'cats'},
      <String, dynamic>{'apiKey': 'k', 'engineId': 'e1'},
    );

    expect(calls, <String>['cats|k|e1']);
    expect(out, contains('Cats'));
  });

  test('a throwing service becomes an error string, never an exception',
      () async {
    final GoogleSearchTool tool = GoogleSearchTool(
      search: (String query, String apiKey, String engineId) async =>
          throw StateError('boom'),
    );

    final String out = await tool.execute(
      <String, dynamic>{'query': 'cats'},
      <String, dynamic>{'apiKey': 'k', 'engineId': 'e1'},
    );

    expect(out, startsWith('Error executing Google Search:'));
  });
}
```

- [ ] **Step 7: Write `test/core/services/agent/alarm_tool_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/services/agent/alarm_tool.dart';

void main() {
  test('forwards minutes and message, returns the confirmation', () async {
    final List<String> calls = <String>[];
    final AlarmTool tool = AlarmTool(
      setAlarm: (int minutesFromNow, String message) async {
        calls.add('$minutesFromNow|$message');
        return 'Alarm set for soon';
      },
    );

    final String out = await tool.execute(
      <String, dynamic>{'minutesFromNow': 10, 'message': 'tea time'},
      <String, dynamic>{},
    );

    expect(calls, <String>['10|tea time']);
    expect(out, 'Alarm set for 10 minutes from now with message: "tea time"');
  });

  test('defaults are 0 minutes and Hello world!', () async {
    final List<String> calls = <String>[];
    final AlarmTool tool = AlarmTool(
      setAlarm: (int minutesFromNow, String message) async {
        calls.add('$minutesFromNow|$message');
        return 'ok';
      },
    );

    await tool.execute(<String, dynamic>{}, <String, dynamic>{});

    expect(calls, <String>['0|Hello world!']);
  });

  test('metadata exposes the contract the LLM sees', () {
    final AlarmTool tool = AlarmTool(setAlarm: (int m, String s) async => '');
    expect(tool.name, 'setAlarm');
    expect(tool.requiredConfigKeys, isEmpty);
    expect(
      tool.parameters.map((dynamic p) => (p as dynamic).name as String),
      containsAll(<String>['minutesFromNow', 'message']),
    );
  });
}
```

- [ ] **Step 8: Write `test/core/services/agent/web_reader_tool_test.dart`**

```dart
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

    final String out = await tool.execute(
      <String, dynamic>{'url': 'https://example.com/a?b=1'},
      <String, dynamic>{},
    );

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
      tool.execute(<String, dynamic>{'url': 'https://x.dev'}, <String, dynamic>{}),
      throwsStateError,
    );
  });
}
```

- [ ] **Step 9: Run the new tests plus the neighbouring agent tests**

Run: `flutter test test/core/services/agent`
Expected: all PASS, including the pre-existing weather/news/google service tests (the seam refactor must not change behavior; `tool_registry.dart` compiles unchanged — `flutter analyze` at the end confirms).

- [ ] **Step 10: Commit** (workflow commits; files: the four lib tools + four test files)

Message: `test(agent): seams + tests for news, google search, alarm and web reader tools`

---

### Task 3: Repository impl mapping/failure tests (+ `SoundRepositoryImpl` player seam)

Mirrors `test/features/settings/data/repositories/settings_repository_failure_test.dart`: mock the datasource/repository dependency with mocktail, assert DTO→domain mapping, `StorageFailure` for not-found, exception→typed-Failure translation (`TimeoutException` → `NetworkFailure`, `FormatException` → `StorageFailure` — the mapper's documented mapping).

**Files:**
- Modify: `lib/features/sound/data/repositories/sound_repository_impl.dart` (inject the player)
- Create: `test/features/avatar/data/repositories/avatar_repository_impl_test.dart`
- Create: `test/features/chat/data/repositories/global_memory_repository_impl_test.dart`
- Create: `test/features/demo/data/repositories/demo_repository_impl_test.dart`
- Create: `test/features/sound/data/repositories/sound_repository_impl_test.dart`

**Interfaces:**
- Consumes: `AvatarLocalDatasource.getChat(String) → Future<Result<Chat?>>`; `GlobalMemoryLocalDatasource` (`getMemory`, `saveMemory(GlobalMemory)`, `clear`); `ChatRepository` (`getChat`, `getCurrentChat`, `updateAvatar`); `SoundEffects.fromString` / `getPath` (valid id: `whoosh` → `assets/sounds/whoosh.mp3` → `AssetSource('sounds/whoosh.mp3')`).
- Produces: `SoundRepositoryImpl({AudioPlayer? player})` — optional, default unchanged; `service_locator.dart:244` (`SoundRepositoryImpl()`) keeps compiling.

- [ ] **Step 1: Add the player seam to `sound_repository_impl.dart`**

Only the class header changes (plus removing `final AudioPlayer _player = AudioPlayer();` inline init):

```dart
class SoundRepositoryImpl implements SoundRepository {
  SoundRepositoryImpl({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  // ... play / stop / isPlaying bodies unchanged ...
}
```

- [ ] **Step 2: Write `avatar_repository_impl_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/avatar/data/datasources/avatar_local_datasource.dart';
import 'package:yofardev_ai/features/avatar/data/repositories/avatar_repository_impl.dart';

class MockAvatarLocalDatasource extends Mock
    implements AvatarLocalDatasource {}

void main() {
  late MockAvatarLocalDatasource datasource;
  late AvatarRepositoryImpl repo;

  setUp(() {
    datasource = MockAvatarLocalDatasource();
    repo = AvatarRepositoryImpl(datasource: datasource);
  });

  test('a found chat maps through unchanged', () async {
    final Chat chat = Chat(id: 'c1');
    when(() => datasource.getChat('c1'))
        .thenAnswer((_) async => Result<Chat?>.ok(chat));

    final Result<Chat> result = await repo.getChat('c1');

    expect(
      result.when(err: (_) => throw StateError('err'), ok: (Chat c) => c),
      same(chat),
    );
  });

  test('a null chat becomes StorageFailure (not found)', () async {
    when(() => datasource.getChat('c1'))
        .thenAnswer((_) async => Result<Chat?>.ok(null));

    final Result<Chat> result = await repo.getChat('c1');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('a datasource failure passes through untouched', () async {
    const NetworkFailure failure = NetworkFailure('offline');
    when(() => datasource.getChat('c1'))
        .thenAnswer((_) async => Result<Chat?>.err(failure));

    final Result<Chat> result = await repo.getChat('c1');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      same(failure),
    );
  });

  test('a throwing datasource maps to a typed failure', () async {
    when(() => datasource.getChat('c1'))
        .thenThrow(TimeoutException('timeout'));

    final Result<Chat> result = await repo.getChat('c1');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });
}
```

- [ ] **Step 3: Write `global_memory_repository_impl_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/global_memory.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/chat/data/datasources/global_memory_datasource.dart';
import 'package:yofardev_ai/features/chat/data/repositories/global_memory_repository_impl.dart';

class MockGlobalMemoryLocalDatasource extends Mock
    implements GlobalMemoryLocalDatasource {}

void main() {
  late MockGlobalMemoryLocalDatasource datasource;
  late GlobalMemoryRepositoryImpl repo;

  setUp(() {
    datasource = MockGlobalMemoryLocalDatasource();
    repo = GlobalMemoryRepositoryImpl(datasource: datasource);
  });

  test('getMemory returns the datasource value', () async {
    final GlobalMemory memory = GlobalMemory(
      items: <GlobalMemoryItem>[
        GlobalMemoryItem(
          id: 'a',
          text: 'likes tea',
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    when(() => datasource.getMemory()).thenAnswer((_) async => memory);

    final Result<GlobalMemory> result = await repo.getMemory();

    expect(
      result.when(
        err: (_) => throw StateError('err'),
        ok: (GlobalMemory m) => m,
      ),
      same(memory),
    );
  });

  test('deleteItem removes only the named item and persists the rest',
      () async {
    final GlobalMemoryItem keep = GlobalMemoryItem(
      id: 'keep',
      text: 'keep',
      updatedAt: DateTime(2026, 1, 1),
    );
    final GlobalMemoryItem drop = GlobalMemoryItem(
      id: 'drop',
      text: 'drop',
      updatedAt: DateTime(2026, 1, 2),
    );
    when(() => datasource.getMemory())
        .thenAnswer((_) async => GlobalMemory(
              items: <GlobalMemoryItem>[keep, drop],
            ));
    final List<GlobalMemory> saved = <GlobalMemory>[];
    when(() => datasource.saveMemory(any())).thenAnswer(
      (Invocation inv) async => saved.add(
        inv.positionalArguments[0] as GlobalMemory,
      ),
    );

    final Result<GlobalMemory> result = await repo.deleteItem('drop');

    result.when(
      err: (_) => throw StateError('err'),
      ok: (GlobalMemory m) => expect(m.items, <GlobalMemoryItem>[keep]),
    );
    expect(saved.single.items, <GlobalMemoryItem>[keep]);
  });

  test('a throwing datasource maps to a typed failure', () async {
    when(() => datasource.getMemory())
        .thenThrow(const FormatException('not-json'));

    final Result<GlobalMemory> result = await repo.getMemory();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('clearAll forwards and returns ok', () async {
    when(() => datasource.clear()).thenAnswer((_) async {});

    final Result<void> result = await repo.clearAll();

    expect(result.isOk, isTrue);
    verify(() => datasource.clear()).called(1);
  });
}
```

- [ ] **Step 4: Write `demo_repository_impl_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/avatar_scene.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/core/repositories/chat_repository.dart';
import 'package:yofardev_ai/features/demo/data/repositories/demo_repository_impl.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository chatRepository;
  late DemoRepositoryImpl repo;
  late Chat chat;

  setUp(() {
    chatRepository = MockChatRepository();
    repo = DemoRepositoryImpl(chatRepository: chatRepository);
    chat = Chat(id: 'c1');
    registerFallbackValue(chat.avatar);
  });

  test('setAvatarBackground persists a copy of the avatar with the scene',
      () async {
    when(() => chatRepository.getChat('c1'))
        .thenAnswer((_) async => Result<Chat?>.ok(chat));
    when(() => chatRepository.updateAvatar('c1', any()))
        .thenAnswer((_) async => Result<void>.ok(null));

    final Result<void> result =
        await repo.setAvatarBackground('c1', AvatarScene.beach);

    expect(result.isOk, isTrue);
    final dynamic saved = verify(
      () => chatRepository.updateAvatar('c1', captureAny()),
    ).captured.single;
    expect((saved as Avatar).background, AvatarScene.beach);
  });

  test('setAvatarBackground on an unknown chat is a StorageFailure',
      () async {
    when(() => chatRepository.getChat('nope'))
        .thenAnswer((_) async => Result<Chat?>.ok(null));

    final Result<void> result =
        await repo.setAvatarBackground('nope', AvatarScene.beach);

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
    verifyNever(() => chatRepository.updateAvatar(any(), any()));
  });

  test('setAvatarBackground passes a repository error through as storage',
      () async {
    when(() => chatRepository.getChat('c1'))
        .thenAnswer((_) async => Result<Chat?>.err(
              const StorageFailure('nope'),
            ));

    final Result<void> result =
        await repo.setAvatarBackground('c1', AvatarScene.beach);

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('getCurrentChatId returns the current chat id', () async {
    when(() => chatRepository.getCurrentChat())
        .thenAnswer((_) async => Result<Chat>.ok(chat));

    final Result<String> result = await repo.getCurrentChatId();

    expect(
      result.when(err: (_) => throw StateError('err'), ok: (String id) => id),
      'c1',
    );
  });

  test('getCurrentChatId without a current chat is a StorageFailure',
      () async {
    when(() => chatRepository.getCurrentChat()).thenAnswer(
      (_) async => Result<Chat>.err(const StorageFailure('none')),
    );

    final Result<String> result = await repo.getCurrentChatId();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<StorageFailure>(),
    );
  });

  test('a throwing repository maps to a typed failure', () async {
    when(() => chatRepository.getCurrentChat())
        .thenThrow(TimeoutException('timeout'));

    final Result<String> result = await repo.getCurrentChatId();

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<NetworkFailure>(),
    );
  });
}
```

- [ ] **Step 5: Write `sound_repository_impl_test.dart`**

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yofardev_ai/core/models/failure.dart';
import 'package:yofardev_ai/core/models/result.dart';
import 'package:yofardev_ai/features/sound/data/repositories/sound_repository_impl.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late MockAudioPlayer player;
  late SoundRepositoryImpl repo;

  setUp(() {
    player = MockAudioPlayer();
    repo = SoundRepositoryImpl(player: player);
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.setSource(any()))
        .thenAnswer((_) async => Duration.zero);
    when(() => player.setVolume(any())).thenAnswer((_) async {});
    when(() => player.resume()).thenAnswer((_) async {});
  });

  test('an unknown sound id is ok and never touches the player', () async {
    final Result<void> result = await repo.play('not-a-sound');

    expect(result.isOk, isTrue);
    verifyNever(() => player.setSource(any()));
  });

  test('a known sound id maps the asset path and plays it', () async {
    final List<Source> sources = <Source>[];
    when(() => player.setSource(any()))
        .thenAnswer((Invocation inv) async {
      sources.add(inv.positionalArguments[0] as Source);
      return Duration.zero;
    });

    final Result<void> result = await repo.play('whoosh');

    expect(result.isOk, isTrue);
    expect(sources.single, isA<AssetSource>());
    expect((sources.single as AssetSource).path, 'sounds/whoosh.mp3');
    verify(() => player.setVolume(1.0)).called(1);
    verify(() => player.resume()).called(1);
  });

  test('a throwing player maps to a typed failure', () async {
    when(() => player.setSource(any())).thenThrow(StateError('no backend'));

    final Result<void> result = await repo.play('whoosh');

    expect(
      result.when(err: (Failure f) => f, ok: (_) => throw StateError('err')),
      isA<UnknownFailure>(),
    );
  });

  test('stop is forwarded and ok', () async {
    final Result<void> result = await repo.stop();

    expect(result.isOk, isTrue);
    verify(() => player.stop()).called(1);
  });
}
```

Note: `mapExceptionToFailure` maps unknown exceptions to `UnknownFailure` — check `lib/core/errors/exception_mapper.dart` if the test fails on that assertion and use the mapper's actual default type.

- [ ] **Step 6: Run the new repository tests**

Run: `flutter test test/features/avatar/data test/features/chat/data test/features/demo/data test/features/sound/data`
Expected: all PASS.

- [ ] **Step 7: Commit** (workflow commits; files: sound_repository_impl.dart + four test files)

Message: `test(data): mapping and failure tests for avatar, sound, demo and global memory repos`

---

### Task 4: `scripts/fcoverage.sh` — coverage measurement + floor

Nothing today measures line coverage. `fcoverage.sh` runs the suite with `--coverage`, scopes lcov to the pure-logic layers (`lib/core/` + `lib/features/*/domain/`), prints a per-area table, and fails below a floor. It is a standalone gate (the full suite inside it is the slow part — it is NOT added to `fverify.sh`).

**Files:**
- Create: `scripts/fcoverage.sh` (executable)
- Modify: `scripts/README.md` (one table row + one short section)

**Interfaces:**
- Consumes: `flutter test --coverage` → `coverage/lcov.info`.
- Produces: exit 0/1; stdout table `area  lines  hit  pct`.

- [ ] **Step 1: Write `scripts/fcoverage.sh`**

```bash
#!/usr/bin/env bash
# =============================================================================
# fcoverage.sh — line-coverage measurement + floor for the pure-logic layers.
#
# Runs the full test suite with --coverage, scopes coverage/lcov.info to
# lib/core/ and lib/features/*/domain/ (the layers the review flagged as
# must-stay-covered), prints a per-area table, and exits non-zero when the
# scoped total is below the floor.
#
# Floor: default 75 (%). Override for one run:
#   FCOVERAGE_MIN=80 ./scripts/fcoverage.sh     # env var
#   ./scripts/fcoverage.sh 80                   # first argument
#   ./scripts/fcoverage.sh 0                    # measure only, never fail
#
# Reuse an existing lcov (no second suite run), e.g. after CI produced one:
#   FCOVERAGE_LCOV=path/to/lcov.info ./scripts/fcoverage.sh 0
#
# Not part of fverify.sh on purpose: it runs the whole suite again.
# =============================================================================

set -euo pipefail

# -- Find project root --------------------------------------------------------
PROJECT_ROOT=""
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  [[ -f "$dir/pubspec.yaml" ]] && PROJECT_ROOT="$dir" && break
  dir="$(dirname "$dir")"
done
[[ -z "$PROJECT_ROOT" ]] && echo "fcoverage: no pubspec.yaml found" >&2 && exit 1
cd "$PROJECT_ROOT"

MIN="${FCOVERAGE_MIN:-${1:-75}}"
LCOV="${FCOVERAGE_LCOV:-coverage/lcov.info}"

if [[ -z "${FCOVERAGE_LCOV:-}" ]]; then
  echo "[fcoverage] running flutter test --coverage (the full suite)…"
  flutter test --coverage
fi

if [[ ! -f "$LCOV" ]]; then
  echo "[fcoverage] $LCOV not found — did the test run produce it?" >&2
  exit 1
fi

# -- Scoped summary -------------------------------------------------------------
# lcov sections: SF:<path> … DA:<line>,<hits> … end_of_record.
# Scope: lib/core/** (area "core") and lib/features/<name>/domain/** (area
# "domain:<name>"). Everything else is ignored.
awk -v min="$MIN" '
  function area_for(path) {
    if (path ~ /^lib\/core\//) return "core";
    if (match(path, /^lib\/features\/[^/]+\/domain\//)) {
      return "domain:" substr(path, 13, RLENGTH - 20);
    }
    return "";
  }
  /^SF:/ {
    area = area_for(substr($0, 4));
    in_scope = (area != "");
    next;
  }
  in_scope && /^DA:/ {
    split(substr($0, 4), parts, ",");
    lf[area]++; hits = parts[2] + 0;
    if (hits > 0) lh[area]++;
    next;
  }
  /^end_of_record$/ { in_scope = 0; next; }
  END {
    if (length(lf) == 0) {
      print "[fcoverage] no in-scope records found in " FILENAME " — is the lcov scoped to lib/?" > "/dev/stderr";
      exit 1;
    }
    printf "  %-28s %8s %8s %7s\n" "area" "lines" "hit" "pct";
    total_lf = 0; total_lh = 0;
    n = asorti(lf, sorted);           # gawk-only; see fallback note below
    for (i = 1; i <= n; i++) {
      a = sorted[i];
      pct = (lf[a] > 0) ? sprintf("%.1f", 100 * lh[a] / lf[a]) : "0.0";
      printf "  %-28s %8d %8d %6s%%\n" a, lf[a], lh[a], pct;
      total_lf += lf[a]; total_lh += lh[a];
    }
    total_pct = (total_lf > 0) ? 100 * total_lh / total_lf : 0;
    printf "  %-28s %8d %8d %6.1f%%\n" "TOTAL (scoped)", total_lf, total_lh, total_pct;
    if (total_pct + 0 < min + 0) {
      printf "[fcoverage] FAIL: %.1f%% < floor %s%%\n" total_pct, min > "/dev/stderr";
      exit 1;
    }
    printf "[fcoverage] ok: %.1f%% >= floor %s%%\n" total_pct, min;
  }
' "$LCOV"
```

Portability note for the implementer: macOS `awk` (BSD) has no `asorti`. Use the same approach as above but iterate with a plain two-pass sort: collect area names, pipe through `sort`, or simplest — use `awk` only to aggregate into `area lines hit` rows and do the sorting + floor check in bash. If `asorti` is unavailable on this machine, restructure so `awk` prints unsorted rows and `sort` + a small bash loop render the table and compare the total; the floor check must stay in the script. Verify with `bash -n scripts/fcoverage.sh` and a hand-made lcov fixture:

```bash
mkdir -p /tmp/fcov-fixture && cat > /tmp/fcov-fixture/lcov.info <<'EOF'
TN:
SF:lib/core/models/failure.dart
DA:1,1
DA:2,0
end_of_record
SF:lib/features/chat/presentation/bloc/chat_cubit.dart
DA:1,1
DA:2,1
end_of_record
SF:lib/features/chat/domain/services/cue_parser.dart
DA:1,1
DA:2,1
DA:3,0
end_of_record
EOF
FCOVERAGE_LCOV=/tmp/fcov-fixture/lcov.info ./scripts/fcoverage.sh 50
```

Expected fixture output: `core` 1/2 = 50.0%, `domain:chat` 2/3 ≈ 66.7%, TOTAL 3/5 = 60.0%, exit 0 (60 ≥ 50). Then with `40` as floor and TOTAL below it → exit 1. Record both outputs in the task report.

- [ ] **Step 2: Make it executable and document it in `scripts/README.md`**

```bash
chmod +x scripts/fcoverage.sh
```

Add to the scripts table in `scripts/README.md` (match the existing row style):

```markdown
| `./scripts/fcoverage.sh [min]` | Coverage floor — full suite with `--coverage`, scoped to `core/` + feature `domain/` layers; fails under `min` (default 75 %) |
```

Add a short section (after the table, matching the README's heading style):

```markdown
## Coverage floor (`fcoverage.sh`)

`fcoverage.sh` measures line coverage where regressions hurt most — `lib/core/`
and every feature's `domain/` layer — and fails below the floor (default 75 %,
`FCOVERAGE_MIN=…` or first argument to override, `0` to measure only). It runs
the whole suite itself, so it is deliberately not part of `fverify.sh`; run it
when the balance of your change touches logic in the scoped layers. The floor
should be ratcheted up as the measured baseline allows — check the table it
prints before raising it.
```

- [ ] **Step 3: Verify with the fixture** (command above; both exit codes)
- [ ] **Step 4: Commit** (workflow commits; files: scripts/fcoverage.sh, scripts/README.md)

Message: `chore(tooling): fcoverage.sh coverage floor script + docs`

---

### Task 5: `test/README.md` — the suite's map

Only `test/golden_tests_README.md` exists today. The harness patterns (the strongest assets in this suite) are undocumented.

**Files:**
- Create: `test/README.md`

- [ ] **Step 1: Write `test/README.md`**

````markdown
# Test Suite

The quality gate is local — `./scripts/fverify.sh` (format check + analyze +
the whole suite, including the architecture and DI smoke tests). Line coverage
for the logic layers: `./scripts/fcoverage.sh` (see `scripts/README.md`).

## Layout

| Path | What lives there |
|------|------------------|
| `test/core/…` | mirrors `lib/core/…` — models, services, design tokens, DI smoke test |
| `test/features/<name>/…` | mirrors `lib/features/<name>/…` — data / domain / presentation |
| `test/architecture_test.dart` (+ `test/support/`) | the layering gate: analyzer-based checker + scan rules; the checker has its own tests with negative fixtures |
| `test/core/di/service_locator_test.dart` | DI smoke test — every registration resolves |
| `test/integration/…` | feature-flow tests: real dependency chains over scripted fakes |
| `test/helpers/` | `golden_test_helper.dart` (fonts + theme wrapper), `rive_test_assets.dart` (`serveFakeRiveAssets()`) |
| `test/**/goldens/` | golden PNGs — see `golden_tests_README.md`; regenerate only on intentional visual change |
| `tool/` | critic/trace harnesses (face–speech, body language, a11y dump) — run with env-var args, not part of `fverify.sh` |
| `integration_test/` | device/emulator tests, several manual-gated (kokoro TTS, wow captures, frame cost) — see `AGENTS.md` |
| `rive/tools/tests/` | the Python suite for the Rive asset pipeline (gated by `./scripts/frive.sh`) |

## Harnesses (reuse before writing a new rig)

The suite's feature-flow tests pump the **real** dependency chain and replace
only the I/O seams with fakes — the opposite of isolated unit tests, on purpose:

- `test/features/home/widgets/stage/real_reply_rig.dart` — real
  `ChatStreamingService` + `TalkingRepositoryImpl`, mocked LLM/settings I/O
- `test/features/chat/bloc/chat_reply_failure_harness.dart` — the reply path
  driven to failure
- `test/features/home/stage_harness.dart` — the stage assembled with fakes

When you add a cross-layer test, extend a harness instead of rebuilding one.

## Conventions

- `mocktail` (never mockito); `registerFallbackValue` for non-primitives used with `any()`.
- Repository tests assert mapping + typed failures (`isA<StorageFailure>()`), never `Failure.message` strings — see any `*_failure_test.dart`.
- Cubit tests use `bloc_test`; widget tests use fake cubits pushed state via a test-only helper.
- Rive widget tests call `serveFakeRiveAssets()` and `UiKitFile.resetForTest()` in `setUp`.
- New test files mirror the lib path of the class under test.
````

- [ ] **Step 2: Commit** (workflow commits; file: `test/README.md`)

Message: `docs(test): test/README.md suite map and harness patterns`

---

## Final verification (the workflow runs these; listed here for any human executor)

1. `dart fix --apply` — must change nothing in committed files.
2. `dart format` on every file this plan touches.
3. `./scripts/fverify.sh` — format check + analyze + full suite, all green.
4. `./scripts/fcoverage.sh 0` — measures and prints the scoped baseline (never fails at floor 0). If the scoped total is below 75, the default floor must be lowered to the measured value rounded down to the nearest 5 (edit the `MIN=` default in `scripts/fcoverage.sh`) — do not leave a default floor the baseline itself cannot meet.

## Self-review notes

- Spec coverage: review recommendation 1 → Task 1; recommendation 2 → Task 2; recommendation 3 → Task 3; recommendation 4 → Task 4 (+ final verification 4); recommendation 5 → Task 5.
- All ARB keys referenced (`failure*`) already exist — no `gen-l10n` needed. No freezed models change — no `build_runner` needed.
- Cross-task file conflicts: none — every task touches disjoint files; `tool_registry.dart` is intentionally untouched (default constructor params).
- `SoundRepositoryImpl`'s `AudioPlayer` seam and the four tool seams are the only production-code changes; each keeps no-arg construction valid for `service_locator.dart` / `tool_registry.dart`.

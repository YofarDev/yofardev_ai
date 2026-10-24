import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/chat.dart';
import 'package:yofardev_ai/core/models/chat_entry.dart';

ChatEntry _entry(int i, {EntryType type = EntryType.user}) => ChatEntry(
  id: 'e$i',
  entryType: type,
  body: 'message $i',
  timestamp: DateTime(2026, 1, 1),
);

Chat _chatWithEntries(int count) => Chat(
  id: 'c',
  entries: List<ChatEntry>.generate(
    count,
    (int i) => _entry(i, type: i.isEven ? EntryType.user : EntryType.yofardev),
  ),
);

void main() {
  test('below the cap: all messages kept', () {
    expect(_chatWithEntries(10).llmMessages.length, 10);
  });

  test('just above the cap: start index snaps to the block boundary', () {
    // 41 messages: naive start would be 1; aligned start is 8 → 33 kept.
    expect(_chatWithEntries(41).llmMessages.length, 33);
    expect(_chatWithEntries(41).llmMessages.first.body, 'message 8');
  });

  test('cap boundary: 48 messages keep exactly 40', () {
    expect(_chatWithEntries(48).llmMessages.length, 40);
    expect(_chatWithEntries(48).llmMessages.first.body, 'message 8');
  });

  test('next block: 49 messages snap to start 16', () {
    expect(_chatWithEntries(49).llmMessages.length, 33);
    expect(_chatWithEntries(49).llmMessages.first.body, 'message 16');
  });

  test('start stays constant while the chat grows within a block', () {
    // Turn N has 41 entries, turn N+1 has 46: both trim to start 8, so the
    // provider prompt-cache prefix stays byte-identical.
    final List<String> at41 = _chatWithEntries(
      41,
    ).llmMessages.map((dynamic m) => m.body as String).toList();
    final List<String> at46 = _chatWithEntries(
      46,
    ).llmMessages.map((dynamic m) => m.body as String).toList();
    expect(at46.sublist(0, at41.length), at41);
  });
}

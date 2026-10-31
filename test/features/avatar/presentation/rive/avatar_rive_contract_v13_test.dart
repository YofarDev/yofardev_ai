import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_ai/core/models/avatar_gesture.dart';
import 'package:yofardev_ai/features/avatar/presentation/rive/avatar_rive_contract.dart';
import 'package:yofardev_ai/features/avatar/presentation/widgets/rive/mouth_anchor_reader.dart';

/// Contract v13 (moonshot M10): the Dart mirror equals `rive/CONTRACT.md`.
void main() {
  late String contract;
  late List<String> lines;

  setUpAll(() {
    contract = File('rive/CONTRACT.md').readAsStringSync();
    lines = contract.split('\n');
  });

  /// The cells of the AvatarVM table row of property [name].
  List<String> row(String name) {
    final String line = lines.firstWhere(
      (String l) => l.startsWith('| `$name` |'),
      orElse: () => '',
    );
    expect(line, isNotEmpty, reason: 'CONTRACT.md has a `$name` row');
    return line
        .split('|')
        .map((String c) => c.trim())
        .where((String c) => c.isNotEmpty)
        .toList();
  }

  test('the contract is v13', () {
    expect(lines.first, '# Rive contract (v13)');
  });

  test('topTint and hatTint are colours, default 00000000', () {
    expect(AvatarRiveContract.propTopTint, 'topTint');
    expect(AvatarRiveContract.propHatTint, 'hatTint');
    for (final String name in <String>[
      AvatarRiveContract.propTopTint,
      AvatarRiveContract.propHatTint,
    ]) {
      final List<String> cells = row(name);
      expect(cells[1], 'color', reason: name);
      expect(cells[2], contains('`00000000`'), reason: name);
    }
  });

  test('gestureId lists the contract values in order, signature last', () {
    final String values = row(AvatarRiveContract.propGestureId)[2];
    final List<String> contractOrder = <String>[];
    for (final String value in AvatarRiveContract.gestureIdValues) {
      expect(values, contains(value));
      contractOrder.add(value);
    }
    // in the order the row names them
    final List<int> positions = contractOrder
        .map((String v) => values.indexOf(RegExp('\\b$v\\b')))
        .toList();
    expect(positions, orderedEquals(List<int>.of(positions)..sort()));
    expect(AvatarRiveContract.gestureIdValues.last, 'signature');
    expect(values, contains('**v13 (appended):** signature'));
    expect(
      AvatarGesture.values.map((AvatarGesture g) => g.name).toList(),
      AvatarRiveContract.gestureIdValues,
    );
  });

  test('the mouth anchor node name is the contract one', () {
    expect(AvatarRiveContract.mouthAnchorNode, 'MouthAnchor');
    expect(contract, contains('named `Node` `MouthAnchor`'));
    expect(MouthAnchorReader.node, AvatarRiveContract.mouthAnchorNode);
  });

  test('SceneVM night is a v13 number written from the clock', () {
    expect(AvatarRiveContract.scenePropNight, 'night');
    final String line = lines.firstWhere(
      (String l) => l.trimLeft().startsWith('- `night`:'),
      orElse: () => '',
    );
    expect(line, contains('number, 0–1, default 0 (v13)'));
    expect(contract, contains('(1 − daylight) × (1 − dusk)'));
  });
}

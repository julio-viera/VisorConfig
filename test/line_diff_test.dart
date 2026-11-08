import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/utils/line_diff.dart';

void main() {
  test('Aligns additions and deletions with original source line numbers', () {
    final rows = compareLines(['a\nold\nc', 'a\nnew\nextra\nc']);
    expect(rows[1].changed, isTrue);
    expect(rows[1].leftNumber, 2);
    expect(rows[1].rightNumber, 2);
    expect(rows[2].leftNumber, isNull);
    expect(rows[2].rightNumber, 3);
    expect(rows.last.leftNumber, 3);
    expect(rows.last.rightNumber, 4);
    final deletion = compareLines(['a\nb\nc', 'a\nc']);
    expect(deletion[1].rightNumber, isNull);
  });
  test('Preserves source contents and repeated lines', () {
    for (final pair in [
      ['a\na\nb\n', 'b\na\na\n'],
      ['', 'x'],
      ['a\nb', 'a\nb'],
      ['x\r\ny', 'x\ny'],
    ]) {
      final rows = compareLines(pair);
      expect(
        rows.where((r) => r.leftNumber != null).map((r) => r.left).join('\n'),
        pair[0].replaceAll('\r\n', '\n'),
      );
      expect(
        rows.where((r) => r.rightNumber != null).map((r) => r.right).join('\n'),
        pair[1].replaceAll('\r\n', '\n'),
      );
    }
  });
  test('Large comparison retains unchanged unique anchors', () {
    final a = List.generate(1500, (i) => 'line $i');
    final b = [...a]
      ..[0] = 'changed first'
      ..[1499] = 'changed last';
    final rows = compareLines([a.join('\n'), b.join('\n')]);
    expect(rows.where((r) => r.changed).length, 2);
    expect(rows[700].left, 'line 700');
  });
}

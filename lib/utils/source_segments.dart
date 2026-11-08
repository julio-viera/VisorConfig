import '../models/source_segment.dart';

List<SourceSegment> splitSource(String text) {
  final rows = <SourceSegment>[];
  var start = 0, line = 1;
  while (start <= text.length) {
    final newline = text.indexOf('\n', start);
    final end = newline < 0 ? text.length : newline;
    var cursor = start;
    do {
      var cut = cursor + 4096 < end ? cursor + 4096 : end;
      // Do not split a UTF-16 surrogate pair.
      if (cut < end &&
          cut > cursor &&
          text.codeUnitAt(cut - 1) >= 0xD800 &&
          text.codeUnitAt(cut - 1) <= 0xDBFF) {
        cut--;
      }
      rows.add(SourceSegment(cursor, cut, line));
      cursor = cut;
    } while (cursor < end);
    if (newline < 0) break;
    start = end + 1;
    line++;
  }
  return rows;
}

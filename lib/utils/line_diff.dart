import 'dart:typed_data';

class DiffRow {
  const DiffRow(this.leftNumber, this.left, this.rightNumber, this.right);
  final int? leftNumber, rightNumber;
  final String? left, right;
  bool get changed => left != right;
}

/// Compares original source lines, preserving file line numbers. Small ranges use
/// LCS; large ranges use unique-line anchors to bound memory and processing cost.
List<DiffRow> compareLines(List<String> documents) {
  final a = documents[0]
      .split('\n')
      .map((s) => s.endsWith('\r') ? s.substring(0, s.length - 1) : s)
      .toList();
  final b = documents[1]
      .split('\n')
      .map((s) => s.endsWith('\r') ? s.substring(0, s.length - 1) : s)
      .toList();
  final operations = <(int?, int?)>[];
  void align(int a0, int a1, int b0, int b1) {
    while (a0 < a1 && b0 < b1 && a[a0] == b[b0]) {
      operations.add((a0++, b0++));
    }
    var suffix = 0;
    while (a0 < a1 - suffix &&
        b0 < b1 - suffix &&
        a[a1 - suffix - 1] == b[b1 - suffix - 1]) {
      suffix++;
    }
    final ae = a1 - suffix, be = b1 - suffix;
    final n = ae - a0, m = be - b0;
    if (n == 0 || m == 0) {
      for (var i = a0; i < ae; i++) {
        operations.add((i, null));
      }
      for (var j = b0; j < be; j++) {
        operations.add((null, j));
      }
    } else if (n * m <= 1000000) {
      final width = m + 1;
      final dp = Uint32List((n + 1) * width);
      for (var i = n - 1; i >= 0; i--) {
        for (var j = m - 1; j >= 0; j--) {
          final down = dp[(i + 1) * width + j], right = dp[i * width + j + 1];
          dp[i * width + j] = a[a0 + i] == b[b0 + j]
              ? dp[(i + 1) * width + j + 1] + 1
              : down > right
              ? down
              : right;
        }
      }
      var i = 0, j = 0;
      while (i < n || j < m) {
        if (i < n && j < m && a[a0 + i] == b[b0 + j]) {
          operations.add((a0 + i++, b0 + j++));
        } else if (j >= m ||
            i < n && dp[(i + 1) * width + j] >= dp[i * width + j + 1]) {
          operations.add((a0 + i++, null));
        } else {
          operations.add((null, b0 + j++));
        }
      }
    } else {
      final left = <String, int>{}, right = <String, int>{};
      for (var i = a0; i < ae; i++) {
        left.update(a[i], (_) => -1, ifAbsent: () => i);
      }
      for (var j = b0; j < be; j++) {
        right.update(b[j], (_) => -1, ifAbsent: () => j);
      }
      final candidates = <(int, int)>[];
      for (var i = a0; i < ae; i++) {
        final j = right[a[i]];
        if (left[a[i]] == i && j != null && j >= 0) {
          candidates.add((i, j));
        }
      }
      final tails = <int>[], previous = List<int>.filled(candidates.length, -1);
      for (var i = 0; i < candidates.length; i++) {
        var lo = 0, hi = tails.length;
        while (lo < hi) {
          final mid = (lo + hi) ~/ 2;
          if (candidates[tails[mid]].$2 < candidates[i].$2) {
            lo = mid + 1;
          } else {
            hi = mid;
          }
        }
        if (lo > 0) {
          previous[i] = tails[lo - 1];
        }
        if (lo == tails.length) {
          tails.add(i);
        } else {
          tails[lo] = i;
        }
      }
      final anchors = <(int, int)>[];
      var current = tails.isEmpty ? -1 : tails.last;
      while (current >= 0) {
        anchors.add(candidates[current]);
        current = previous[current];
      }
      if (anchors.isEmpty) {
        for (var i = a0; i < ae; i++) {
          operations.add((i, null));
        }
        for (var j = b0; j < be; j++) {
          operations.add((null, j));
        }
      } else {
        var i = a0, j = b0;
        for (final anchor in anchors.reversed) {
          align(i, anchor.$1, j, anchor.$2);
          operations.add((anchor.$1, anchor.$2));
          i = anchor.$1 + 1;
          j = anchor.$2 + 1;
        }
        align(i, ae, j, be);
      }
    }
    for (var k = 0; k < suffix; k++) {
      operations.add((ae + k, be + k));
    }
  }

  align(0, a.length, 0, b.length);
  final rows = <DiffRow>[];
  final removed = <int>[], added = <int>[];
  void flush() {
    final count = removed.length > added.length ? removed.length : added.length;
    for (var i = 0; i < count; i++) {
      final l = i < removed.length ? removed[i] : null;
      final r = i < added.length ? added[i] : null;
      rows.add(
        DiffRow(
          l == null ? null : l + 1,
          l == null ? null : a[l],
          r == null ? null : r + 1,
          r == null ? null : b[r],
        ),
      );
    }
    removed.clear();
    added.clear();
  }

  for (final op in operations) {
    if (op.$1 != null && op.$2 != null) {
      flush();
      rows.add(DiffRow(op.$1! + 1, a[op.$1!], op.$2! + 1, b[op.$2!]));
    } else if (op.$1 != null) {
      removed.add(op.$1!);
    } else {
      added.add(op.$2!);
    }
  }
  flush();
  return rows;
}

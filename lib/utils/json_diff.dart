import 'dart:convert';

List<String> diffJson(dynamic a, dynamic b, [String path = r'$']) {
  if (a is Map && b is Map) {
    return {...a.keys, ...b.keys}
        .expand(
          (k) => !a.containsKey(k)
              ? ['$path[${jsonEncode(k)}] + ${jsonEncode(b[k])}']
              : !b.containsKey(k)
              ? ['$path[${jsonEncode(k)}] − ${jsonEncode(a[k])}']
              : diffJson(a[k], b[k], '$path[${jsonEncode(k)}]'),
        )
        .toList();
  }
  if (a is List && b is List) {
    return List.generate(
      a.length > b.length ? a.length : b.length,
      (i) => i >= a.length
          ? ['$path[$i] + ${jsonEncode(b[i])}']
          : i >= b.length
          ? ['$path[$i] − ${jsonEncode(a[i])}']
          : diffJson(a[i], b[i], '$path[$i]'),
    ).expand((e) => e).toList();
  }
  return jsonEncode(a) == jsonEncode(b)
      ? []
      : ['$path: ${jsonEncode(a)} → ${jsonEncode(b)}'];
}

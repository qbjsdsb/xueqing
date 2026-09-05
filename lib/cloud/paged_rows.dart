typedef PagedRowLoader = Future<dynamic> Function(int from, int to);

Future<List<Map<String, dynamic>>> collectPagedRows({
  required PagedRowLoader loadPage,
  required void Function() assertSession,
  required String invalidResponseMessage,
  int pageSize = 500,
}) async {
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'Must be positive.');
  }

  final rows = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final response = await loadPage(from, from + pageSize - 1);
    assertSession();
    if (response is! List) {
      throw FormatException(invalidResponseMessage);
    }

    for (final item in response) {
      if (item is! Map) {
        throw FormatException(invalidResponseMessage);
      }
      rows.add(Map<String, dynamic>.from(item));
    }
    if (response.length < pageSize) {
      return List<Map<String, dynamic>>.unmodifiable(rows);
    }
    from += pageSize;
  }
}

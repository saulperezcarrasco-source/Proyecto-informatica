import '../../core/models/models.dart';

String normalize(String text) {
  var result = text.toLowerCase().trim();
  const accents = 'áéíóúüñ';
  const plain = 'aeiouun';
  for (var i = 0; i < accents.length; i++) {
    result = result.replaceAll(accents[i], plain[i]);
  }
  return result
      .replaceAll(RegExp('[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

List<String> searchWords(String query) {
  const ignored = {
    'de',
    'del',
    'la',
    'el',
    'los',
    'las',
    'a',
    'al',
    'en',
    'y',
    'un',
    'una',
  };
  return normalize(query)
      .split(' ')
      .where((w) => w.isNotEmpty && !ignored.contains(w))
      .toList();
}

int nationalMatchRank(List<String> terms, String query, List<String> words) {
  var rank = 4;
  for (final term in terms) {
    if (term == query) return 0;
    if (term.startsWith(query)) {
      if (rank > 1) rank = 1;
    } else if (term.contains(query)) {
      if (rank > 2) rank = 2;
    }
    if (words.length > 1 && words.every(term.contains)) {
      final tokens = searchWords(term);
      if (tokens.length == words.length &&
          words.every(tokens.contains) &&
          rank > 1) {
        rank = 1;
      }
    }
  }
  if (rank == 4 &&
      words.isNotEmpty &&
      words.every((word) => terms.any((term) => term.contains(word)))) {
    return 3;
  }
  return rank;
}

List<Place> searchPlaces(List<Place> places, String query) {
  final q = normalize(query);
  if (q.isEmpty) return [];
  int rank(Place p) => [p.name, ...p.aliases]
      .map(normalize)
      .map(
        (name) => name == q
            ? 0
            : name.startsWith(q)
            ? 1
            : name.contains(q)
            ? 2
            : 3,
      )
      .reduce((a, b) => a < b ? a : b);
  final matches = places.where((p) => rank(p) < 3).toList();
  matches.sort((a, b) {
    final order = rank(a).compareTo(rank(b));
    if (order != 0) return order;
    final name = normalize(a.name).compareTo(normalize(b.name));
    return name != 0 ? name : a.id.compareTo(b.id);
  });
  return matches.take(10).toList();
}

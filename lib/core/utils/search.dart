/// Normalise un texte pour une recherche locale insensible à la casse et aux
/// accents (par exemple « Élève » devient « eleve »).
String normalizeForSearch(String input) {
  const from =
      'àáâãäåāăąçćčďđèéêëēėęěğìíîïīįıłñńňòóôõöøōőŕřśšşťùúûüūůűųýÿžźżœæ';
  const to =
      'aaaaaaaaacccddeeeeeeeeegiiiiiiilnnnoooooooorrssstuuuuuuuuuyyzzzae';

  final lower = input.toLowerCase().trim();
  final buffer = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final char = lower[i];
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString();
}

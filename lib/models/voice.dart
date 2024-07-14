

class Voice {
  final String name;
  final String locale;

  Voice({
    required this.name,
    required this.locale,
  });

  @override
  String toString() => '$name ($locale)';

}

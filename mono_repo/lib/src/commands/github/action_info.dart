enum ActionInfo {
  checkout(
    name: 'actions/checkout',
    version: 'd0651293c4a5a52e711f25b41b05b2212f385d28', // v3
  ),
  cache(
    name: 'actions/cache',
    version: '4504faf7e9bcf8f3ed0bc863c4e1d21499ab8ef8', // v3
  ),
  setupDart(
    name: 'dart-lang/setup-dart',
    version: '6a218f2413a3e78e9087f638a238f6b40893203d', // v1.3
  ),
  setupFlutter(
    name: 'subosito/flutter-action',
    version: '2fb73e25c9488eb544b9b14b2ce00c4c2baf789e', // v2.4.0
  );

  const ActionInfo({required this.name, required this.version});

  final String name;
  final String version;

  String get usesValue => '$name@$version';
}

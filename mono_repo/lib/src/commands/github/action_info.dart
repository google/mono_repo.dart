enum ActionInfo {
  checkout(name: 'actions/checkout', version: 'v3'),
  cache(name: 'actions/cache', version: 'v3'),
  setupDart(name: 'dart-lang/setup-dart', version: 'v1.3'),
  setupFlutter(name: 'subosito/flutter-action', version: 'v2.4.0');

  const ActionInfo({required this.name, required this.version});

  final String name;
  final String version;

  String get usesValue => '$name@$version';
}

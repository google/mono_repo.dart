class PackageConfig {
  final bool published;

  PackageConfig(this.published);

  factory PackageConfig.fromJson(Map<String, dynamic> json) =>
      new PackageConfig(json['published'] as bool);

  Map<String, dynamic> toJson() => {'published': published};
}

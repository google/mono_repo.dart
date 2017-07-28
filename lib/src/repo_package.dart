class RepoPackage {
  final String name;
  final bool published;

  RepoPackage(this.name, this.published);

  Map<String, dynamic> toJson() => {'name': name, 'published': published};
}

import 'package:build_runner/build_runner.dart';
import 'package:json_serializable/generators.dart';
import 'package:source_gen/source_gen.dart';

final List<BuildAction> phases = [
  new BuildAction(
      new PartBuilder(const [
        const JsonSerializableGenerator(),
      ]),
      'mono_repo',
      inputs: const ['lib/src/*'])
];

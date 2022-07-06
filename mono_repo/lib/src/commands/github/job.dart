import 'package:json_annotation/json_annotation.dart';

import '../../yaml.dart';
import 'step.dart';

part 'job.g.dart';

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class Job implements YamlLike {
  final String? name;

  @JsonKey(name: 'runs-on')
  final String? runsOn;
  @JsonKey(name: 'if')
  String? ifContent;
  final List<Step> steps;
  List<String>? needs;

  Job({
    this.name,
    this.runsOn,
    required this.steps,
  });

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$JobToJson(this);
}

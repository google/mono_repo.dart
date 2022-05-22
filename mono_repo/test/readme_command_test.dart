import 'package:mono_repo/src/commands/readme_command.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  setUp(listReadmeSetup);
  test('show everything', () async {
    expect(
        readme(
          RootConfig(rootDirectory: d.sandbox),
          onlyPublished: false,
          pad: false,
        ),
        '''
| Package source | Description | Published Version |
| --- | --- | --- |
| [pkg1](pkg1_dir/) |  |  |
| [pkg2](pkg2_dir/) |  |  |
| [pkg3](pkg3_dir/) |  | [![pub package](https://img.shields.io/pub/v/pkg3.svg)](https://pub.dev/packages/pkg3) |
| [pkg4](pkg4_dir/) |  | [![pub package](https://img.shields.io/pub/v/pkg4.svg)](https://pub.dev/packages/pkg4) |''');
  });

  test('only published', () async {
    expect(
      readme(
        RootConfig(rootDirectory: d.sandbox),
        onlyPublished: false,
        pad: true,
      ),
      '''
| Package source    | Description | Published Version                                                                      |
| ----------------- | ----------- | -------------------------------------------------------------------------------------- |
| [pkg1](pkg1_dir/) |             |                                                                                        |
| [pkg2](pkg2_dir/) |             |                                                                                        |
| [pkg3](pkg3_dir/) |             | [![pub package](https://img.shields.io/pub/v/pkg3.svg)](https://pub.dev/packages/pkg3) |
| [pkg4](pkg4_dir/) |             | [![pub package](https://img.shields.io/pub/v/pkg4.svg)](https://pub.dev/packages/pkg4) |''',
    );
  });

  test('path & name', () async {
    expect(
      readme(
        RootConfig(rootDirectory: d.sandbox),
        onlyPublished: true,
        pad: false,
      ),
      '''
| Package source | Description | Published Version |
| --- | --- | --- |
| [pkg3](pkg3_dir/) |  | [![pub package](https://img.shields.io/pub/v/pkg3.svg)](https://pub.dev/packages/pkg3) |
| [pkg4](pkg4_dir/) |  | [![pub package](https://img.shields.io/pub/v/pkg4.svg)](https://pub.dev/packages/pkg4) |''',
    );
  });
}

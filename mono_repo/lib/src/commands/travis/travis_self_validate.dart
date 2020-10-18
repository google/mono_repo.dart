import '../../version.dart';
import 'shared.dart';

String generateSelfValidate() => '''
#!/bin/bash
${createdWith()}
# Support built in commands on windows out of the box.
${dartCommandContent('pub')}

set -v -e
pub global activate mono_repo $packageVersion
pub global run mono_repo travis --validate
''';

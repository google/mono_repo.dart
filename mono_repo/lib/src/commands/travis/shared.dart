import 'dart:async';

import '../../version.dart';

final skipCreatedWithSentinel = Object();

String createdWith() => Zone.current[skipCreatedWithSentinel] == true
    ? ''
    : '# Created with package:mono_repo v$packageVersion\n';

String dartCommandContent(String commandName) => '''
function $commandName() {
  if [[ \$TRAVIS_OS_NAME == "windows" ]]; then
    command $commandName.bat "\$@"
  else
    command $commandName "\$@"
  fi
}''';


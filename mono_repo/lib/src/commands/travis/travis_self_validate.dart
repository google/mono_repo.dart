import '../../version.dart';

String generateSelfValidate() => '''
#!/bin/bash
# Created with package:mono_repo v$packageVersion

# Support built in commands on windows out of the box.
function pub {
       if [[ \$TRAVIS_OS_NAME == "windows" ]]; then
        command pub.bat "\$@"
    else
        command pub "\$@"
    fi
}

set -v -e
pub global activate mono_repo $packageVersion
pub global run mono_repo travis --validate
''';

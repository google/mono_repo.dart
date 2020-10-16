import 'dart:convert';

import 'package:io/ansi.dart';

import '../../package_config.dart';
import '../../shell_utils.dart';
import '../../user_exception.dart';
import 'shared.dart';

final windowsBoilerplate = '''
# Support built in commands on windows out of the box.
${_dartCommandContent('pub')}
${_dartCommandContent('dartfmt')}
${_dartCommandContent('dartanalyzer')}''';

String _dartCommandContent(String commandName) => '''
function $commandName {
  if [[ \$TRAVIS_OS_NAME == "windows" ]]; then
    command $commandName.bat "\$@"
  else
    command $commandName "\$@"
  fi
}''';

String generateTravisSh(
  Map<String, String> commandsToKeys,
  bool prettyAnsi,
  String pubDependencyCommand,
) =>
    '''
#!/bin/bash
${createdWith()}
$windowsBoilerplate

if [[ -z \${PKGS} ]]; then
  ${safeEcho(prettyAnsi, red, "PKGS environment variable must be set!")}
  exit 1
fi

if [[ "\$#" == "0" ]]; then
  ${safeEcho(prettyAnsi, red, "At least one task argument must be provided!")}
  exit 1
fi

EXIT_CODE=0

for PKG in \${PKGS}; do
  echo -e "\\033[1mPKG: \${PKG}\\033[22m"
  pushd "\${PKG}" || exit \$?

  PUB_EXIT_CODE=0
  pub $pubDependencyCommand --no-precompile || PUB_EXIT_CODE=\$?

  if [[ \${PUB_EXIT_CODE} -ne 0 ]]; then
    EXIT_CODE=1
    ${safeEcho(prettyAnsi, red, "pub $pubDependencyCommand failed")}
    popd
    continue
  fi

  for TASK in "\$@"; do
    echo
    echo -e "\\033[1mPKG: \${PKG}; TASK: \${TASK}\\033[22m"
${_shellCase('TASK', _calculateTaskEntries(commandsToKeys, prettyAnsi))}
  done

  popd
done

exit \${EXIT_CODE}
''';

List<String> _calculateTaskEntries(
  Map<String, String> commandsToKeys,
  bool prettyAnsi,
) {
  final taskEntries = <String>[];

  void addEntry(String label, List<String> contentLines) {
    assert(contentLines.isNotEmpty);
    contentLines.add(';;');

    final buffer = StringBuffer('$label)\n')
      ..writeAll(contentLines.map((l) => '  $l'), '\n');

    final output = buffer.toString();
    if (!taskEntries.contains(output)) {
      taskEntries.add(output);
    }
  }

  commandsToKeys.forEach((command, taskKey) {
    addEntry(taskKey, [
      "echo '${wrapAnsi(prettyAnsi, resetAll, command)}'",
      '$command || EXIT_CODE=\$?',
    ]);
  });

  if (taskEntries.isEmpty) {
    throw UserException(
        'No entries created. Check your nested `$monoPkgFileName` files.');
  }

  taskEntries.sort();

  final echoContent =
      wrapAnsi(prettyAnsi, red, "Not expecting TASK '\${TASK}'. Error!");
  addEntry('*', ['echo -e "$echoContent"', 'EXIT_CODE=1']);
  return taskEntries;
}

String _shellCase(String scriptVariable, List<String> entries) {
  if (entries.isEmpty) return '';
  return LineSplitter.split('''
case \${$scriptVariable} in
${entries.join('\n')}
esac
''').map((l) => '    $l').join('\n');
}

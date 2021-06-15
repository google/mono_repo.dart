import 'dart:convert';

import 'package:io/ansi.dart';

import 'ci_shared.dart';
import 'package_config.dart';
import 'shell_utils.dart';
import 'user_exception.dart';

String _commandContent(String commandName) => '''
# When it is a flutter repo (check the pubspec.yaml for "sdk: flutter")
# then "flutter" is called instead of "pub".
# This assumes that the Flutter SDK has been installed in a previous step.
function $commandName() {
  if grep -Fq "sdk: flutter" "\${PWD}/pubspec.yaml"; then
    command flutter $commandName "\$@"
  else
    command dart $commandName "\$@"
  fi
}''';

final bashScriptHeader = '''
#!/bin/bash
$createdWith

# Support built in commands on windows out of the box.
${_commandContent('pub')}
${_commandContent('format')}
${_commandContent('analyze')}''';

String generateTestScript(
  Map<String, String> commandsToKeys,
  bool prettyAnsi,
  String pubDependencyCommand,
) =>
    '''
$bashScriptHeader

if [[ -z \${PKGS} ]]; then
  ${safeEcho(prettyAnsi, red, "PKGS environment variable must be set! - TERMINATING JOB")}
  exit 64
fi

if [[ "\$#" == "0" ]]; then
  ${safeEcho(prettyAnsi, red, "At least one task argument must be provided! - TERMINATING JOB")}
  exit 64
fi

SUCCESS_COUNT=0
declare -a FAILURES

for PKG in \${PKGS}; do
  ${echoWithEvaluation(prettyAnsi, styleBold, r'PKG: ${PKG}')}
  EXIT_CODE=0
  pushd "\${PKG}" >/dev/null || EXIT_CODE=\$?

  if [[ \${EXIT_CODE} -ne 0 ]]; then
    ${echoWithEvaluation(prettyAnsi, red, "PKG: '\${PKG}' does not exist - TERMINATING JOB")}
    exit 64
  fi

  dart pub $pubDependencyCommand || EXIT_CODE=\$?

  if [[ \${EXIT_CODE} -ne 0 ]]; then
    ${echoWithEvaluation(prettyAnsi, red, "PKG: \${PKG}; 'dart pub $pubDependencyCommand' - FAILED  (\${EXIT_CODE})")}
    FAILURES+=("\${PKG}; 'dart pub $pubDependencyCommand'")
  else
    for TASK in "\$@"; do
      EXIT_CODE=0
      echo
      ${echoWithEvaluation(prettyAnsi, styleBold, r'PKG: ${PKG}; TASK: ${TASK}')}
${_shellCase('TASK', _calculateTaskEntries(commandsToKeys, prettyAnsi))}

      if [[ \${EXIT_CODE} -ne 0 ]]; then
        ${echoWithEvaluation(prettyAnsi, red, 'PKG: \${PKG}; TASK: \${TASK} - FAILED (\${EXIT_CODE})')}
        FAILURES+=("\${PKG}; TASK: \${TASK}")
      else
        ${echoWithEvaluation(prettyAnsi, green, 'PKG: \${PKG}; TASK: \${TASK} - SUCCEEDED')}
        SUCCESS_COUNT=\$((SUCCESS_COUNT + 1))
      fi

    done
  fi

  echo
  ${echoWithEvaluation(prettyAnsi, green, "SUCCESS COUNT: \${SUCCESS_COUNT}")}

  if [ \${#FAILURES[@]} -ne 0 ]; then
    ${echoWithEvaluation(prettyAnsi, red, 'FAILURES: \${#FAILURES[@]}')}
    for i in "\${FAILURES[@]}"; do
      ${echoWithEvaluation(prettyAnsi, red, "  \$i")}
    done
  fi

  popd >/dev/null || exit 70
  echo
done

if [ \${#FAILURES[@]} -ne 0 ]; then
  exit 1
fi
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

  for (var entry in commandsToKeys.entries) {
    addEntry(entry.value, [
      "echo '${entry.key}'",
      '${entry.key} || EXIT_CODE=\$?',
    ]);
  }

  if (taskEntries.isEmpty) {
    throw UserException(
      'No entries created. Check your nested `$monoPkgFileName` files.',
    );
  }

  taskEntries.sort();

  addEntry('*', [
    echoWithEvaluation(
      prettyAnsi,
      red,
      "Unknown TASK '\${TASK}' - TERMINATING JOB",
    ),
    'exit 64',
  ]);
  return taskEntries;
}

String _shellCase(String scriptVariable, List<String> entries) {
  if (entries.isEmpty) return '';

  return LineSplitter.split('''
case \${$scriptVariable} in
${entries.join('\n')}
esac
''').map((l) => '      $l').join('\n');
}

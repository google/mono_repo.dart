import 'package:io/ansi.dart';

/// Safely escape everything:
/// 1 - use single quotes.
/// 2 - if there is a single quote in the string
///     2.1 end the string before the single quote
///     2.2 echo the single quote escaped
///     2.3 continue the string
///
/// See https://stackoverflow.com/a/20053121/39827
String safeEcho(bool prettyAnsi, AnsiCode code, String value) {
  value = value.replaceAll("'", "'\\''");
  return "echo -e '${wrapAnsi(prettyAnsi, code, value)}'";
}

String wrapAnsi(bool doWrap, AnsiCode code, String value) =>
    doWrap ? code.wrap(value, forScript: true) : value;

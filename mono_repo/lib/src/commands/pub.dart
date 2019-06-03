// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../root_config.dart';
import 'mono_repo_command.dart';

class PubCommand extends MonoRepoCommand {
  @override
  ArgParser get argParser => _pubArgParser ??= _PubArgParser();
  _PubArgParser _pubArgParser;

  @override
  String get description => 'Run a `pub` command across all packages';

  @override
  String get name => 'pub';

  @override
  Future<void> run() => pub(rootConfig(), argResults.rest);
}

/// Implementation of [ArgParser] that delegates to an [allowAnything()] but
/// allows compatibility with [Command] and [CommandRunner].
///
/// Specifically, the follow issues are addressed:
/// - [Command]:
///   - Attempts to [addFlag] a 'help' option, which isn't allowed by
///   [allowAnything()] (ironically). We don't want that flag to be added
///   anyway; we want `pub` or `flutter` to handle printing their own usage.
///   [allowAnything()] throws an [UnsupportedError] so instead we just
///   ignore the call and don't pass it on to the delegate.
/// - [CommandRunner]:
///   - Attempts to check the value of the 'help' option, which doesn't exist
///   because we ignored [Command]'s adding it. This check isn't done via
///   [_PubArgParser]'s own [ArgResults] from [parse], as this isn't ever the
///   top-level [ArgParser]. Instead, as [CommandRunner] steps into the
///   arguments for [PubCommand], it ends up being the [options] getter here
///   which is checked for the 'help' option by an [ArgResults] created from
///   the top-level (which is out of our control). To trick [CommandRunner],
///   we return a [_PubOptions], itself a delegating class.
class _PubArgParser implements ArgParser {
  final ArgParser _delegate;

  _PubArgParser() : _delegate = ArgParser.allowAnything();

  /// [_PubArgParser] can't have commands added to it, so we do nothing.
  @override
  ArgParser addCommand(String name, [ArgParser parser]) => parser;

  /// [_PubArgParser] can't have flags added to it, so we do nothing.
  @override
  void addFlag(String name,
      {String abbr,
      String help,
      bool defaultsTo = false,
      bool negatable = true,
      void Function(bool value) callback,
      bool hide = false}) {}

  /// [_PubArgParser] can't have options added to it, so we do nothing.
  @override
  void addMultiOption(String name,
      {String abbr,
      String help,
      String valueHelp,
      Iterable<String> allowed,
      Map<String, String> allowedHelp,
      Iterable<String> defaultsTo,
      void Function(List<String> values) callback,
      bool splitCommas = true,
      bool hide = false}) {}

  /// [_PubArgParser] can't have options added to it, so we do nothing.
  @override
  void addOption(String name,
      {String abbr,
      String help,
      String valueHelp,
      Iterable<String> allowed,
      Map<String, String> allowedHelp,
      String defaultsTo,
      Function callback,
      bool allowMultiple = false,
      bool splitCommas,
      bool hide = false}) {}

  /// [_PubArgParser] can't have separators added to it, so we do nothing.
  @override
  void addSeparator(String text) {}

  @override
  bool get allowTrailingOptions => _delegate.allowTrailingOptions;

  @override
  bool get allowsAnything => _delegate.allowsAnything;

  @override
  Map<String, ArgParser> get commands => _delegate.commands;

  @override
  Option findByAbbreviation(String abbr) => _delegate.findByAbbreviation(abbr);

  /// [_PubArgParser] can't have options, so if asked about a default we return
  /// null.
  @override
  dynamic getDefault(String option) => null;

  @override
  String getUsage() => _delegate.usage;

  /// Return the options as a [_PubOptions] to trick [CommandRunner].
  @override
  Map<String, Option> get options => _PubOptions(_delegate.options);

  /// Wrap the normal output with a `PubArgResults` to fail quieter than normal.
  @override
  ArgResults parse(Iterable<String> args) => _delegate.parse(args);

  @override
  String get usage => '''Any arguments given are passed verbatim to `pub`\n
If a particular package uses Flutter, `flutter` is used rather than `pub`:
- If the arguments begin with `get` or `upgrade`, `flutter packages` is used
- Otherwise, `flutter` is used''';

  @override
  int get usageLineLength => _delegate.usageLineLength;
}

/// Implementation of [Map] designed to trick [CommandRunner] into believing
/// that any options it asks for did exist but were false.
///
/// This means that when [CommandRunner] checks the 'help' flag it assumes
/// was added, it is told that the option had the value of false. This is in
/// spite of the fact that an [allowAnything()] [ArgParser] can't have flags
/// added and we ignored the addition of 'help' earlier in [_PubArgParser].
/// [allowAnthing()] sets the options to be constantly empty, and for clarity
/// we delegate to that value here, given in the constructor.
///
/// Conceptually, this class is a map that behaves as though it has no
/// elements unless a specific one is requested: [containsKey] is always
/// true, and the `[]` operator always returns a stub [_FalseOption].
class _PubOptions implements Map<String, Option> {
  final Map<String, Option> _delegate;

  _PubOptions(Map<String, Option> delegate) : _delegate = delegate;

  /// Return a [_FalseOption], in-line with the class documentation.
  @override
  Option operator [](Object key) => _FalseOption();

  @override
  void operator []=(String key, Option value) => false;

  @override
  void addAll(Map<String, Option> other) => _delegate.addAll(other);

  @override
  void addEntries(Iterable<MapEntry<String, Option>> newEntries) =>
      _delegate.addEntries(newEntries);

  @override
  Map<RK, RV> cast<RK, RV>() => _delegate.cast();

  @override
  void clear() => _delegate.clear();

  /// Return `true`, in-line with the class documentation.
  @override
  bool containsKey(Object key) => true;

  @override
  bool containsValue(Object value) => _delegate.containsValue(value);

  @override
  Iterable<MapEntry<String, Option>> get entries => _delegate.entries;

  @override
  void forEach(void Function(String key, Option value) f) =>
      _delegate.forEach(f);

  @override
  bool get isEmpty => _delegate.isEmpty;

  @override
  bool get isNotEmpty => _delegate.isNotEmpty;

  @override
  Iterable<String> get keys => _delegate.keys;

  @override
  int get length => _delegate.length;

  @override
  Map<K2, V2> map<K2, V2>(
          MapEntry<K2, V2> Function(String key, Option value) f) =>
      _delegate.map(f);

  @override
  Option putIfAbsent(String key, Option Function() ifAbsent) =>
      _delegate.putIfAbsent(key, ifAbsent);

  @override
  Option remove(Object key) => _delegate.remove(key);

  @override
  void removeWhere(bool Function(String key, Option value) predicate) =>
      _delegate.removeWhere(predicate);

  @override
  Option update(String key, Option Function(Option value) update,
          {Option Function() ifAbsent}) =>
      _delegate.update(key, update);

  @override
  void updateAll(Option Function(String key, Option value) update) =>
      _delegate.updateAll(update);

  @override
  Iterable<Option> get values => _delegate.values;
}

/// A stub [Option] that only exists to have a [getOrDefault] method that
/// returns false.
///
/// Since [CommandRunner] only accesses the 'help' option by transitively
/// checking that the key exists (handled by [_PubOptions] and by calling
/// [getOrDefault] on the value, we can just implement that method and throw
/// a [UnsupportedError] if anything else is called.
class _FalseOption implements Option {
  @override
  dynamic getOrDefault(value) => false;

  @override
  void noSuchMethod(Invocation invocation) =>
      UnsupportedError('Unimplemented method was called on FalseOption');
}

Future<void> pub(RootConfig rootConfig, List<String> args) async {
  final pkgDirs = rootConfig.map((pc) => pc.relativePath).toList();

  print(lightBlue.wrap(
      'Running `pub ${args.join(' ')}` across ${pkgDirs.length} package(s).'));

  for (var config in rootConfig) {
    final dir = config.relativePath;
    final packageArgs = [
      if (config.hasFlutterDependency &&
          (args.first == 'get' || args.first == 'upgrade'))
        'packages',
      ...args
    ];
    final executable = config.hasFlutterDependency ? 'flutter' : pubPath;

    print('');
    print(wrapWith(
        'Starting `$executable ${packageArgs.join(' ')}` in `$dir`...',
        [styleBold, lightBlue]));
    final workingDir = p.join(rootConfig.rootDirectory, dir);

    final proc = await Process.start(executable, packageArgs,
        mode: ProcessStartMode.inheritStdio, workingDirectory: workingDir);

    final exit = await proc.exitCode;

    if (exit == 0) {
      print(wrapWith('`$dir`: success!', [styleBold, green]));
    } else {
      print(wrapWith('`$dir`: failed!', [styleBold, red]));
    }
  }
}

/// The path to the root directory of the SDK.
final String _sdkDir = (() {
  // The Dart executable is in "/path/to/sdk/bin/dart", so two levels up is
  // "/path/to/sdk".
  final aboveExecutable = p.dirname(p.dirname(Platform.resolvedExecutable));
  assert(FileSystemEntity.isFileSync(p.join(aboveExecutable, 'version')));
  return aboveExecutable;
})();

final String pubPath =
    p.join(_sdkDir, 'bin', Platform.isWindows ? 'pub.bat' : 'pub');

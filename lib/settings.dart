// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.settings;

import 'package:args/args.dart';

class UsageError {}

class UnknownOptionError extends FormatException {
  UnknownOptionError(String message) : super(message);
}

class UnrecognisedOptionValue extends FormatException {
  UnrecognisedOptionValue(String option, String value)
      : super(
            "Invalid value; the option `$option' does accept `$value' as a valid value.");
}

class NamedOptions {
  static String get dump_ast => "dump-ast";
  static String get dump_dast => "dump-dast";
  static String get help => "help";
  static String get output => "output";
  static String get trace => "trace";
  static String get type_check => "type-checking";
  static String get verbose => "verbose";
  static String get version => "version";
  static String get exit_after => "exit-after";
}

ArgParser _parser;

ArgParser _setupArgParser() {
  if (_parser != null) return _parser;

  ArgParser parser = new ArgParser();

  parser.addFlag(NamedOptions.dump_ast,
      negatable: false,
      defaultsTo: false,
      help: "Dump the syntax tree to stderr.");
  parser.addFlag(NamedOptions.dump_dast,
      negatable: false,
      defaultsTo: false,
      help: "Dump the elaborated syntax tree to stderr.");
  parser.addOption(NamedOptions.exit_after,
      defaultsTo: null,
      help: "Exit after running a particular component.",
      valueHelp: "elaborator,parser");
  parser.addFlag(NamedOptions.help,
      abbr: 'h',
      negatable: false,
      defaultsTo: false,
      help: "Display this list of options.");
  parser.addOption(NamedOptions.output,
      abbr: 'o',
      help: "Place the output into <file>.",
      valueHelp: "file",
      defaultsTo: "stdout");
  parser.addMultiOption(NamedOptions.trace,
      help: "Trace the operational behaviour of a component.",
      valueHelp: "elaborator,parser");
  parser.addFlag(NamedOptions.type_check,
      help: "Enable or disable type checking.", defaultsTo: true);
  parser.addFlag(NamedOptions.verbose,
      abbr: 'v',
      negatable: false,
      defaultsTo: false,
      help: "Enable verbose logging.");
  parser.addFlag(NamedOptions.version,
      negatable: false, defaultsTo: false, help: "Display the version.");

  return _parser = parser;
}

ArgResults _parse(args) {
  try {
    final ArgParser parser = _setupArgParser();
    return parser.parse(args);
  } on ArgParserException catch (err) {
    throw new UnknownOptionError(err.message);
  }
}

bool _validateExitAfter(String value, [bool allowNull = true]) {
  switch (value) {
    case "elaborator":
    case "parser":
      return true;
    default:
      return allowNull && value == null;
  }
}

class Settings {
  // Boolean flags.
  final bool dumpAst;
  final bool dumpDast;
  final String exitAfter;
  final bool showHelp;
  final bool showVersion;
  final MultiOption trace;
  final bool verbose;

  // Other settings.
  final String sourceFile;

  factory Settings.fromCLI(List<String> args) {
    ArgResults results = _parse(args);
    var dumpAst = results[NamedOptions.dump_ast];
    var dumpDast = results[NamedOptions.dump_dast];
    var exitAfter = results[NamedOptions.exit_after];
    var showHelp = results[NamedOptions.help];
    var showVersion = results[NamedOptions.version];
    var verbose = results[NamedOptions.verbose];
    var trace = new MultiOption(results[NamedOptions.trace], verbose ?? false);

    if (!_validateExitAfter(exitAfter)) {
      throw UnrecognisedOptionValue(NamedOptions.exit_after, exitAfter);
    }

    var sourceFile;
    if (results.rest.length == 1) {
      sourceFile = results.rest[0];
    } else if (!showHelp && !showVersion) {
      throw new UsageError();
    }
    return Settings._(dumpAst, dumpDast, exitAfter, showHelp, showVersion,
        sourceFile, trace, verbose);
  }

  const Settings._(this.dumpAst, this.dumpDast, this.exitAfter, this.showHelp,
      this.showVersion, this.sourceFile, this.trace, this.verbose);

  static String usage() {
    ArgParser parser = _setupArgParser();

    String header = "usage: t20 [OPTION]... <file.t20>";
    return "$header\n\nOptions are:\n${parser.usage}";
  }
}

class MultiOption {
  final List<String> values;
  final bool verbose;

  MultiOption(this.values, this.verbose);

  bool operator [](value) => verbose || values.contains(value);
}

// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.settings;

import 'package:args/args.dart';

class UsageError {}

class UnknownOptionError extends FormatException {
  UnknownOptionError(String message) : super(message);
}

class NamedOptions {
  static String get dump_ast => "dump-ast";
  static String get dump_dast => "dump-dast";
  static String get help => "help";
  static String get output => "output";
  static String get type_check => "type-checking";
  static String get verbose => "verbose";
  static String get version => "version";
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
  parser.addFlag(NamedOptions.type_check,
      help: "Enable or disable type checking.",
      defaultsTo: true);
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

class Settings {
  // Boolean flags.
  final bool dumpAst;
  final bool dumpDast;
  final bool showHelp;
  final bool showVersion;
  final bool verbose;

  // Other settings.
  final String sourceFile;

  factory Settings.fromCLI(List<String> args) {
    ArgResults results = _parse(args);
    var dumpAst = results[NamedOptions.dump_ast];
    var dumpDast = results[NamedOptions.dump_dast];
    var showHelp = results[NamedOptions.help];
    var showVersion = results[NamedOptions.version];
    var verbose = results[NamedOptions.verbose];

    var sourceFile;
    if (results.rest.length == 1) {
      sourceFile = results.rest[0];
    } else if (!showHelp && !showVersion) {
      throw new UsageError();
    }
    return Settings._(
        dumpAst, dumpDast, showHelp, showVersion, verbose, sourceFile);
  }

  const Settings._(this.dumpAst, this.dumpDast, this.showHelp, this.showVersion,
      this.verbose, this.sourceFile);

  static String usage() {
    ArgParser parser = _setupArgParser();

    String header = "usage: t20 [OPTION]... <file.t20>";
    return "$header\n\nOptions are:\n${parser.usage}";
  }
}

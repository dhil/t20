// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:t20/settings.dart';
import 'package:t20/t20_api.dart';

// This constant must be updated in tandem with the corresponding constant in
// the pubspec.yaml file.
const String _VERSION = "0.5.1-alpha.1";

class _SourceDoesNotExistsError {
  final String sourceFile;
  _SourceDoesNotExistsError(this.sourceFile);
}

void reportError(String errorMsg, {kind = null}) {
  String prefix = kind == null ? "error" : "$kind error";
  stderr.writeln("$prefix: $errorMsg");
}

void reportFatal(String errorMsg, StackTrace trace,
    {bool unexpected = false, String kind = null}) {
  kind = kind == null
      ? (unexpected ? "unexpected fatal" : "fatal")
      : (unexpected ? "unexpected fatal $kind" : "fatal $kind");
  reportError(errorMsg, kind: kind);
  stderr.writeln("$trace");
}

void main(List<String> args) async {
  int exitCode = 0;
  try {
    // Handle settings.
    Settings settings = Settings.fromCLI(args);
    if (settings.showHelp) throw new UsageError();
    if (settings.showVersion) {
      stdout.writeln("Triple 20 compiler, version $_VERSION");
      exit(0);
    }
    if (settings.sourceFiles == null) throw new UsageError();

    // Run compilation pipeline.
    bool result = await compile(settings.sourceFiles, settings);
    if (!result) exitCode = 10;
  } on UsageError {
    stdout.writeln(Settings.usage());
  } on UnknownOptionError catch (err) {
    reportError(err.message);
    stdout.writeln(Settings.usage());
    exitCode = 10;
  } on UnrecognisedOptionValue catch (err) {
    reportError(err.message);
    exitCode = 10;
  } on _SourceDoesNotExistsError catch (err) {
    reportError("no such file ${err.sourceFile}.", kind: "i/o");
    exitCode = 10;
  } on IOException catch (err, stacktrace) {
    reportFatal("i/o exception $err", stacktrace, kind: "i/o");
    exitCode = 10;
  } catch (err, stacktrace) {
    reportFatal("$err", stacktrace, unexpected: true);
    exitCode = 10;
  }
  exit(exitCode);
}

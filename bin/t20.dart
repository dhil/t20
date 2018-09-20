// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';

import 'package:t20/settings.dart';
import 'package:t20/t20_api.dart';

// This constant must be updated in tandem with the corresponding constant in
// the pubspec.yaml file.
const String _VERSION = "0.0.1-alpha.1";

class _SourceDoesNotExistsError {
  final String sourceFile;
  _SourceDoesNotExistsError(this.sourceFile);
}

void reportError(String errorMsg, {kind = null}) {
  String prefix = kind == null ? "error" : "$kind error";
  stderr.writeln("$prefix: $errorMsg");
}

void reportFatal(String errorMsg, StackTrace trace,
    {unexpected = false, kind = null}) {
  kind = kind == null
      ? (unexpected ? "unexpected fatal" : "fatal")
      : (unexpected ? "unexpected fatal $kind" : "fatal $kind");
  reportError(errorMsg, kind: kind);
  stderr.writeln("$trace");
}

void main(List<String> args) {
  int exitCode = 0;
  RandomAccessFile fileHandle;
  try {
    // Handle settings.
    Settings settings = Settings.fromCLI(args);
    if (settings.showHelp) throw new UsageError();
    if (settings.showVersion) {
      stdout.writeln("Triple 20 compiler, version $_VERSION");
      exit(0);
    }
    if (settings.sourceFile == null) throw new UsageError();

    // Parse source.
    File sourceFile = new File(settings.sourceFile);
    if (!sourceFile.existsSync())
      throw new _SourceDoesNotExistsError(settings.sourceFile);
    fileHandle = sourceFile.openSync(mode: FileMode.read);
    Source source = new FileSource(fileHandle);
    Parser parser = Parser.sexp();
    parser.parse(source, trace:settings.verbose);
  } on UsageError {
    stdout.writeln(Settings.usage());
  } on UnknownOptionError catch (err) {
    reportError(err.message);
    stdout.writeln(Settings.usage());
    exitCode = 1;
  } on _SourceDoesNotExistsError catch (err) {
    reportError("no such file ${err.sourceFile}.", kind: "i/o");
    exitCode = 1;
  } on EndOfStreamError catch (_, stacktrace) {
    reportFatal("end of stream.", stacktrace);
    exitCode = 1;
  } on IOException catch (err, stacktrace) {
    reportFatal("i/o exception $err", stacktrace, kind: "i/o");
    exitCode = 1;
  } catch (err, stacktrace) {
    reportFatal("$err", stacktrace, unexpected: true);
    exitCode = 1;
  } finally {
    if (fileHandle != null) fileHandle.closeSync();
  }

  exit(exitCode);
}

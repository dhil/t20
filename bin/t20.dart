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
    File source = new File(settings.sourceFile);
    if (!source.existsSync())
      throw new _SourceDoesNotExistsError(settings.sourceFile);
    fileHandle = source.openSync(mode: FileMode.read);
    // Stream s = new ByteStream.fromString("Hello");
    Stream s = new ByteStream.fromFile(fileHandle);
    PushbackStream<String> s0 =
        new PushbackStream<int>(new BufferedStream<int>(s))
            .map((e) => String.fromCharCode(e));
    int count = 0;
    while (!s0.endOfStream) {
      // if (count == 10) {
      //   print("peek: ${s0.peek().map((e) => e + 1)}");
      // }
      var byte = s0.next();
      print("$count: $byte");
      count++;
      if (count == 10) {
        s0.unread(byte);
      }
    }
    print("${s0.peek().map((e) => e.toString())}");
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

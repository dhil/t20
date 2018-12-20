// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This script builds a customised version of the Dart VM Platform for the T20
// DSL compiler.

import 'dart:io';

import 'package:args/args.dart';

class CompilerContext {
  final Uri sdkRoot;
  final Uri _target;

  String get source {
    StringBuffer buffer = StringBuffer();
    buffer.write(sdkRoot.toFilePath());
    buffer.write("pkg/kernel/lib/ast.dart");
    return buffer.toString();
  }

  String get builtTarget {
    StringBuffer buffer = StringBuffer();
    buffer.write(source);
    buffer.write(".dill");
    return buffer.toString();
  }

  String get fasta {
    StringBuffer buffer = StringBuffer();
    buffer.write(sdkRoot.toFilePath());
    buffer.write("pkg/front_end/tool/fasta");
    return buffer.toString();
  }

  String get target => _target.toFilePath();

  CompilerContext(this.sdkRoot, this._target);
}

class CannotLocateSDKException {}

class ShowUsageException {
  final String usage;
  ShowUsageException(this.usage);

  String toString() {
    return "usage: build_platform [OPTION]...\n\nOptions are:\n$usage";
  }
}

CompilerContext parseArguments(List<String> args) {
  ArgParser parser = new ArgParser();

  parser.addOption("sdk-root",
      help:
          "Specify where to locate the root of the Dart SDK source repository",
      defaultsTo: Platform.environment['DART_SDK'],
      valueHelp: "path");
  parser.addOption("output",
      abbr: "o",
      help: "Specify where to place the output.",
      defaultsTo: "./t20_custom_platform.dill",
      valueHelp: "file");
  parser.addFlag("help",
      abbr: "h",
      negatable: false,
      help: "Display this message.",
      defaultsTo: false);

  ArgResults results = parser.parse(args);

  if (results["help"]) throw ShowUsageException(parser.usage);
  String sdkRoot = results["sdk-root"];
  if (sdkRoot == null) {
    throw CannotLocateSDKException();
  }

  return CompilerContext(Uri.directory(sdkRoot), Uri.file(results["output"]));
}

class PlatformCompilationException {
  // TODO may be useful to include contents from std{out,err}.
  final int exitCode;
  PlatformCompilationException(this.exitCode);

  String toString() {
    return "Platform compilation failed with code $exitCode";
  }
}

void compilePlatform(String fasta, String source) {
  ProcessResult result = Process.runSync(fasta, <String>["compile", source]);
  if (exitCode != 0) {
    throw PlatformCompilationException(exitCode);
  }
}

class InvalidTargetException {
  final String target;
  InvalidTargetException(this.target);

  String toString() {
    return "Invalid target '$target' (the target must be an ordinary file)";
  }
}

void move(String source, String destination) {
  if (Directory(destination).existsSync()) {
    throw InvalidTargetException(destination);
  }
  File sourceFile = File(source);
  sourceFile.renameSync(destination);
}

void main(List<String> args) {
  try {
    CompilerContext context = parseArguments(args);
    // Invoke fasta to compile a version of the VM platform with kernel embedded
    // into it.
    compilePlatform(context.fasta, context.source);
    // Move the compiled platform.
    move(context.builtTarget, context.target);
  } on ArgParserException catch (err) {
    stderr.writeln("error: $err");
    exit(1);
  } on CannotLocateSDKException {
    stderr.writeln("error: cannot locate the Dart SDK.");
    stderr.writeln(
        "       Either specify the path to the SDK directly on the command line or via the environment variable DART_SDK.");
    exit(1);
  } on PlatformCompilationException catch (err) {
    stderr.writeln("error: $err.");
    exit(1);
  } on InvalidTargetException catch (err) {
    stderr.writeln("error: $err.");
    exit(1);
  } on ShowUsageException catch (err) {
    stdout.writeln(err);
    exit(0);
  }
}

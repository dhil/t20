// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.pipeline;

import 'dart:io';

import '../settings.dart';
import 'ast/ast.dart';
import 'compilation_unit.dart';
import 'errors/error_reporting.dart';
import 'errors/errors.dart';
import 'io/bytestream.dart';
import 'result.dart';
import 'syntax/elaborator.dart';
import 'syntax/parse_sexp.dart';

bool compile(List<String> filePaths, Settings settings) {
  RandomAccessFile currentFile;
  try {
    for (String path in filePaths) {
      File file = new File(path);
      currentFile = file.openSync(mode: FileMode.read);

      // Parse source.
      Result<Sexp, SyntaxError> parseResult = Parser.sexp()
          .parse(new FileSource(currentFile), trace: settings.trace["parser"]);

      // Close file.
      currentFile.closeSync();
      currentFile = null;

      // Report errors, if any.
      if (!parseResult.wasSuccessful) {
        report(parseResult.errors);
        return false;
      }

      // Exit now, if requested.
      if (settings.exitAfter == "parser") {
        return parseResult.wasSuccessful;
      }

      // Elaborate.
      Result<ModuleMember, T20Error> elabResult =
          new Elaborator().elaborate(parseResult.result);
      if (!elabResult.wasSuccessful) {
        report(elabResult.errors);
        return false;
      }

      // Exit now, if requested.
      if (settings.exitAfter == "elaborator") {
        return elabResult.wasSuccessful;
      }
    }
  } catch (err, stack) {
    if (currentFile != null) currentFile.closeSync();
    rethrow;
    // stderr.writeln("Fatal error: $err");
    // stderr.writeln("$stack");
    // rethrow;
  }
  // finally {
  //   if (currentFile != null) currentFile.closeSync();
  // }
  return true;
}

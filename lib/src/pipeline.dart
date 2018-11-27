// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.pipeline;

import 'dart:io';

import '../settings.dart';
import 'ast/ast_module.dart';
import 'ast/ast_builder.dart';
import 'compilation_unit.dart';
import 'errors/error_reporting.dart';
import 'errors/errors.dart';
import 'result.dart';
import 'syntax/parse_sexp.dart';

import 'typing/type_checker.dart';
import 'codegen/kernel_emitter.dart';

Future<bool> compile(List<String> filePaths, Settings settings) async {
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
      Result<ModuleMember, LocatedError> elabResult = new ASTBuilder()
          .build(parseResult.result, BuildContext.withBuiltins());

      // Report errors, if any.
      if (!elabResult.wasSuccessful) {
        report(elabResult.errors);
        return false;
      }

      // Exit now, if requested.
      if (settings.exitAfter == "elaborator") {
        return elabResult.wasSuccessful;
      }

      // Type check.
      Result<ModuleMember, TypeError> typeResult;
      if (settings.typeCheck) {
        typeResult = new TypeChecker(settings.trace["typechecker"])
            .typeCheck(elabResult.result);

        // Report errors, if any.
        if (!typeResult.wasSuccessful) {
          report(typeResult.errors);
          return false;
        }
      }

      // Exit now, if requested.
      if (settings.exitAfter == "typechecker") {
        return typeResult == null ? true : typeResult.wasSuccessful;
      }

      // Code generate.

      // Exit now, if requested.
      if (settings.exitAfter == "codegen") {
        return true;
      }

      // Emit DILL.
      KernelEmitter emitter = new KernelEmitter(settings.platformDill);
      await emitter.emit(emitter.helloWorld(), "hello.dill");
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

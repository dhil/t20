// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.pipeline;

import 'dart:io';

import '../settings.dart';
import 'builtins.dart' as builtins;
// import 'ast/algebra.dart';
// import 'ast/datatype.dart';
// import 'ast/name.dart';
// import 'ast/nullalgebras.dart';
// import 'ast/traversals.dart';
import 'ast/ast_module.dart';
import 'ast/datatype.dart';
import 'ast/binder.dart';
import 'ast/ast_builder.dart';
import 'compilation_unit.dart';
import 'errors/error_reporting.dart';
import 'errors/errors.dart';
import 'io/bytestream.dart';
import 'result.dart';
// import 'static_semantics/name_resolution.dart';
// import 'static_semantics/type_checking.dart';
import 'syntax/parse_sexp.dart';
import 'syntax/elaboration.dart';

import 'fp.dart';

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
      Result<ModuleMember, TypeError> typeResult =
          new TypeChecker(settings.trace["typechecker"]).typeCheck(elabResult.result);

      // Report errors, if any.
      if (!typeResult.wasSuccessful) {
        report(typeResult.errors);
        return false;
      }

      // Exit now, if requested.
      if (settings.exitAfter == "typechecker") {
        return typeResult.wasSuccessful;
      }

      // Emit DILL.
      KernelEmitter emitter = new KernelEmitter(settings.platformDill);
      await emitter.emit(emitter.helloWorld(), "hello.dill");

      // Elaborate.
      // if (settings.exitAfter == "elaborator") {
      //   Pair<Object, List<LocatedError>> errors = new ModuleElaborator(
      //           new NameResolver<
      //               List<LocatedError>,
      //               List<LocatedError>,
      //               List<LocatedError>,
      //               List<LocatedError>>(new ResolvedErrorCollector()))
      //       .elaborate(parseResult.result)(NameContext.withBuiltins());
      //   if (errors.snd.length > 0) {
      //     report(errors.snd);
      //     return false;
      //   }
      //   return true;
      // }

      // Pair<Object, List<LocatedError>> errors = new ModuleElaborator(
      //         new NameResolver<
      //             List<LocatedError>,
      //             List<LocatedError>,
      //             List<LocatedError>,
      //             List<LocatedError>>(new ResolvedErrorCollector()))
      //     .elaborate(parseResult.result)(NameContext.withBuiltins());
      // if (errors.snd.length > 0) {
      //   report(errors.snd);
      //   return false;
      // }

      // // Type check.
      // if (settings.exitAfter == "typechecker") {
      //   // Pair<Object, List<LocatedError>> errors =

      //   NameResolver<List<LocatedError>, List<LocatedError>, List<LocatedError>,
      //       Object> nameResolver;
      //   TypeChecker<List<LocatedError>, List<LocatedError>, List<LocatedError>>
      //       typeChecker;

      //   // nameResolver = new NameResolver<List<LocatedError>, List<LocatedError>,
      //   //     List<LocatedError>, Object>(typeChecker);

      //   // Test1<Null, Null, Null, Datatype>(new Test2<Null, Null, Null>(null));

      //   Object obj = new ModuleElaborator(nameResolver);
      //   // if (errors.snd.length > 0) {
      //   //   report(errors.snd);
      //   //   return false;
      //   // }
      // }
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

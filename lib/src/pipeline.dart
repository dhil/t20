// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.pipeline;

import 'dart:io';

import 'package:kernel/ast.dart' as kernel;

import '../settings.dart';
import 'ast/ast.dart';
import 'ast/ast_builder.dart';
import 'builtins.dart' as builtins;
import 'compilation_unit.dart';
import 'errors/error_reporting.dart';
import 'errors/errors.dart';
import 'module_environment.dart' show ModuleEnvironment;
import 'result.dart';
import 'syntax/parse_sexp.dart';

import 'typing/type_checker.dart';

import 'codegen/desugar.dart';
import 'codegen/ir.dart' as ir;
import 'codegen/kernel_emitter.dart';
import 'codegen/kernel_generator.dart';
import 'codegen/platform.dart';

Result<List<TopModule>, T20Error> frontendResult(
        Result<Object, T20Error> result, ModuleEnvironment moduleEnv) =>
    result == null
        ? Result<List<TopModule>, T20Error>.success(moduleEnv.modules)
        : result.map<List<TopModule>>((Object _) => moduleEnv.modules);

Result<List<TopModule>, T20Error> frontend(
    ModuleEnvironment moduleEnv, List<String> filePaths, Settings settings) {
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

      // Exit now, if requested or the input was erroneous.
      if (!parseResult.wasSuccessful || settings.exitAfter == "parser") {
        return frontendResult(parseResult, moduleEnv);
      }

      // Elaborate.
      Result<ModuleMember, LocatedError> elabResult =
          new ASTBuilder().build(parseResult.result, moduleEnv);

      // Exit now, if requested or the input was erroneous.
      if (!elabResult.wasSuccessful || settings.exitAfter == "elaborator") {
        return frontendResult(elabResult, moduleEnv);
      }

      // Type check.
      Result<ModuleMember, TypeError> typeResult;
      if (settings.typeCheck) {
        typeResult = new TypeChecker(settings.trace["typechecker"])
            .typeCheck(elabResult.result);
      }

      // Exit now, if requested or the input was erroneous.
      if (typeResult != null && !typeResult.wasSuccessful ||
          settings.exitAfter == "typechecker") {
        return frontendResult(typeResult, moduleEnv);
      }

      // Save the module.
      TopModule typedModule = typeResult.result;
      moduleEnv.store(typedModule);
    }
  } catch (err) {
    if (currentFile != null) currentFile.closeSync();
    rethrow;
  }

  return Result<List<TopModule>, T20Error>.success(moduleEnv.modules);
}

Future<Result<void, T20Error>> backend(
    List<TopModule> modules, Settings settings) async {
  TopModule module = modules.last; // TODO generalise.
  // Generate code.
  Result<ir.Module, T20Error> codeResult = new Desugarer(ir.IRAlgebra())
      .desugar(module, Map.of(builtins.getPrimitiveBinders()));

  if (!codeResult.wasSuccessful || settings.exitAfter == "desugar") {
    return codeResult;
  }

  kernel.Component kernelResult =
      new KernelGenerator(new Platform(settings.platformDill))
          .compile(codeResult.result);

  // Exit now, if requested.
  if (kernelResult == null || settings.exitAfter == "codegen") {
    return kernelResult == null
        ? Result<void, T20Error>.success(null)
        : Result<void, T20Error>.failure(<T20Error>[CodeGenerationError()]);
  }

  // Emit DILL.
  await KernelEmitter().emit(kernelResult, settings.outputFile);

  return Result<void, T20Error>.success(true);
}

Future<bool> compile(List<String> filePaths, Settings settings) async {
  // Prepare compilation.
  ModuleEnvironment moduleEnv = ModuleEnvironment();
  moduleEnv.builtins = builtins.module;

  // Run the frontend.
  Result<List<TopModule>, T20Error> frontResult =
      frontend(moduleEnv, filePaths, settings);

  // Report errors, if any.
  if (!frontResult.wasSuccessful) {
    report(frontResult.errors);
    return false;
  }

  // Exit now, if requested.
  if (settings.exitAfter == "parser" ||
      settings.exitAfter == "elaborator" ||
      settings.exitAfter == "typechecker") {
    return frontResult.wasSuccessful;
  }

  // Run the backend.
  List<TopModule> modules = frontResult.result;
  Result<void, T20Error> backResult = await backend(modules, settings);

  // Report errors, if any.
  if (!backResult.wasSuccessful) {
    report(backResult.errors);
    return false;
  }

  return true;
}

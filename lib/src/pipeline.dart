// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.pipeline;

import 'dart:io';

import 'package:kernel/ast.dart' as kernel;

import '../settings.dart';
import 'ast/ast.dart' show TopModule;
import 'bootstrap.dart';
import 'builtins.dart' as builtins;
import 'compilation_unit.dart' show FileSource;
import 'errors/error_reporting.dart';
import 'errors/errors.dart';
import 'module_environment.dart' show ModuleEnvironment;
import 'result.dart';

import 'frontend_compiler.dart';
import 'backend_compiler.dart';

Result<List<TopModule>, T20Error> frontend(
    ModuleEnvironment moduleEnv, List<String> filePaths, Settings settings) {
  RandomAccessFile currentFile;
  FrontendCompiler frontend = FrontendCompiler(moduleEnv, settings);
  try {
    for (String path in filePaths) {
      // Open the source file.
      File file = new File(path);
      currentFile = file.openSync(mode: FileMode.read);

      // Run the frontend compiler.
      List<T20Error> errors = frontend.compile(new FileSource(currentFile));

      // Close the file.
      currentFile.closeSync();
      currentFile = null;

      // Abort if there are any errors.
      if (errors != null) {
        return Result<List<TopModule>, T20Error>.failure(errors);
      }
    }
  } catch (err) {
    if (currentFile != null) currentFile.closeSync();
    rethrow;
  }

  return Result<List<TopModule>, T20Error>.success(frontend.modules);
}

Future<Result<void, T20Error>> backend(
    List<TopModule> modules, Settings settings) async {
  BackendCompiler compiler = BackendCompiler(settings);
  List<T20Error> errors = await compiler.compile(modules);
  return errors == null
      ? Result<void, T20Error>.success(null)
      : Result<void, T20Error>.failure(errors);
}

Future<bool> compile(List<String> filePaths, Settings settings) async {
  // Prepare compilation.
  Result<ModuleEnvironment, T20Error> bootstrapResult = bootstrap();
  if (!bootstrapResult.wasSuccessful) {
    bootstrapReport(bootstrapResult.errors);
    return false;
  }
  ModuleEnvironment moduleEnv = bootstrapResult.result;
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
  Result<void, T20Error> backResult =
      await backend(frontResult.result, settings);

  // Report errors, if any.
  if (!backResult.wasSuccessful) {
    report(backResult.errors);
    return false;
  }

  return true;
}

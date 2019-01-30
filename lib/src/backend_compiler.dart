// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart' show Component;

import '../settings.dart';

import 'ast/ast.dart' show TopModule;

import 'codegen/kernel_emitter.dart';
import 'codegen/kernel_generator.dart';
import 'codegen/platform.dart';

import 'errors/errors.dart' show T20Error, CodeGenerationError;
import 'errors/error_reporting.dart';

import 'module_environment.dart';

import 'result.dart';

class BackendCompiler {
  Settings settings;
  BackendCompiler(this.settings);

  Future<List<T20Error>> compile(
      ModuleEnvironment environment, List<TopModule> modules) async {
    // Generate code.
    Result<Component, CodeGenerationError> codegenResult = new KernelGenerator(
            new Platform(settings.platformDill), environment,
            demoMode: settings.demoMode, compilerVersion: settings.VERSION)
        .compile(modules);

    // Check whether there were any errors.
    if (!codegenResult.wasSuccessful) {
      return codegenResult.errors;
    }

    Component component = codegenResult.result;

    // Exit now, if requested.
    if (component == null || settings.exitAfter == "codegen") {
      return component == null ? <T20Error>[CodeGenerationError()] : null;
    }

    // Emit DILL.
    await KernelEmitter().emit(component, settings.outputFile);

    // Return [null] to signal success.
    return null;
  }
}

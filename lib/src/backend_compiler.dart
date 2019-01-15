// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart' show Component;

import 'ast/ast.dart' show TopModule;

import '../settings.dart';

import 'builtins.dart' as builtins;

import 'errors/errors.dart';

import 'module_environment.dart';

import 'result.dart';

// import 'codegen/desugar.dart';
// import 'codegen/ir.dart';
import 'codegen/kernel_emitter.dart';
import 'codegen/kernel_generator.dart';
import 'codegen/platform.dart';

class BackendCompiler {
  Settings settings;
  BackendCompiler(this.settings);

  Future<List<T20Error>> compile(
      ModuleEnvironment environment, List<TopModule> modules) async {
    // Generate code.
    Component component =
    new KernelGenerator(new Platform(settings.platformDill), environment)
            .compile(modules);

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

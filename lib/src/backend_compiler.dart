// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart' as kernel;

import 'ast/ast.dart' show TopModule;

import '../settings.dart';

import 'builtins.dart' as builtins;

import 'errors/errors.dart';

import 'result.dart';

import 'codegen/desugar.dart';
import 'codegen/ir.dart';
import 'codegen/kernel_emitter.dart';
import 'codegen/kernel_generator.dart';
import 'codegen/platform.dart';

class BackendCompiler {
  Settings settings;
  BackendCompiler(this.settings);

  Future<List<T20Error>> compile(List<TopModule> modules) async {
    TopModule module = modules.last; // TODO generalise.
    // Generate code.
    Result<Module, T20Error> codeResult = new Desugarer(IRAlgebra())
        .desugar(module, Map.of(builtins.getPrimitiveBinders()));

    if (!codeResult.wasSuccessful || settings.exitAfter == "desugar") {
      return codeResult.errors;
    }

    kernel.Component kernelResult =
        new KernelGenerator(new Platform(settings.platformDill))
            .compile(codeResult.result);

    // Exit now, if requested.
    if (kernelResult == null || settings.exitAfter == "codegen") {
      return kernelResult == null ? <T20Error>[CodeGenerationError()] : null;
    }

    // Emit DILL.
    await KernelEmitter().emit(kernelResult, settings.outputFile);

    // Return [null] to signal success.
    return null;
  }
}

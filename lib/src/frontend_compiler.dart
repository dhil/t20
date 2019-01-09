// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../settings.dart';

import 'ast/ast.dart' show ModuleMember, TopModule;
import 'ast/ast_builder.dart' show ASTBuilder;
import 'ast/desugar.dart' show ModuleDesugarer;

import 'compilation_unit.dart' show Source;

import 'errors/errors.dart' show LocatedError, SyntaxError, T20Error, TypeError;

import 'module_environment.dart' show ModuleEnvironment;

import 'result.dart';

import 'syntax/parse_sexp.dart' show Parser;
import 'syntax/sexp.dart' show Sexp;

import 'typing/type_checker.dart' show TypeChecker;

class FrontendCompiler {
  ModuleEnvironment moduleEnv;
  Settings settings;

  FrontendCompiler(ModuleEnvironment initialEnv, this.settings)
      : moduleEnv = initialEnv;

  List<T20Error> compile(Source source, {bool isVirtual = false}) {
    // Parse source.
    Result<Sexp, SyntaxError> parseResult =
        Parser.sexp().parse(source, trace: settings.trace["parser"]);

    // Exit now, if requested or the input was erroneous.
    if (!parseResult.wasSuccessful || settings.exitAfter == "parser") {
      return parseResult.errors;
    }

    // Elaborate.
    Result<ModuleMember, LocatedError> elabResult =
        new ASTBuilder().build(parseResult.result, moduleEnv, isVirtual);

    // Exit now, if requested or the input was erroneous.
    if (!elabResult.wasSuccessful || settings.exitAfter == "elaborator") {
      return elabResult.errors;
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
      return typeResult.errors;
    }

    // Save the module.
    TopModule module =
        typeResult.result == null ? elabResult.result : typeResult.result;
    moduleEnv.store(module);

    // Return [null] to signal successful compilation.
    return null;
  }

  List<TopModule> get modules => moduleEnv.modules;
  ModuleEnvironment get environment => moduleEnv;
}

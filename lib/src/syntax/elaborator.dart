// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.elaborator;

import '../ast/ast.dart';
import '../errors/errors.dart';
import '../location.dart';
import '../result.dart';
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;

import 'module_elaborator.dart';

class Elaborator {
  Result<ModuleMember, T20Error> elaborate(Sexp program) {
    ModuleElaborator elab = new ModuleElaborator();
    ModuleMember ast = program.visit<ModuleMember>(elab);
    List<T20Error> errors = elab.errors ?? [];
    Result<ModuleMember, T20Error> result =
        new Result<ModuleMember, T20Error>(ast, errors);
    return result;
  }
}

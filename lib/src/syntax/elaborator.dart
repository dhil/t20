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

import 'type_elaborator.dart';

export 'type_elaborator.dart';

class Elaborator {
  Result<Module, T20Error> elaborate(Sexp program) {
    //ModuleElaborator elab = new ModuleElaborator();
    Module ast = null; //program.visit<Module>(elab);
    List<T20Error> errors = []; //elab.errors ?? [];
    Result<Module, T20Error> result = new Result<Module, T20Error>(ast, errors);
    return result;
  }
}

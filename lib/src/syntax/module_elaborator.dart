// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart';
import '../errors/errors.dart';
import '../location.dart';
import '../unicode.dart' as unicode;
import 'sexp.dart'
    show Atom, Error, Sexp, SexpVisitor, SList, StringLiteral, Toplevel;

import 'syntax_elaborator.dart';
import 'type_elaborator.dart';

class ModuleElaborator extends BaseElaborator<Module> {
  ModuleElaborator() : super("ModuleElaborator");

  Module visitAtom(Atom atom) {
    
    return null;
  }

  Module visitError(Error error) {
    return null;
  }

  Module visitList(SList list) {
    // Function definitions.
    // Datatype definitions.
    // Inclusion.
    return null;
  }

  Module visitString(StringLiteral string) {
    return null;
  }

  Module visitToplevel(Toplevel toplevel) {
    return null;
  }
}

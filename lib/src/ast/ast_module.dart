// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show List, Map;

import '../location.dart';
import '../errors/errors.dart' show LocatedError;
import 'ast_common.dart';
import 'ast_declaration.dart';
import 'ast_expressions.dart';
import 'ast_patterns.dart';
import 'ast_types.dart';

//
// Module / top-level language.
//
abstract class ModuleVisitor<T> {
  T visitDatatype(DatatypeDeclaration decl);
  T visitError(ErrorModule err);
  T visitFunction(FunctionDeclaration decl);
  T visitInclude(Include include);
  // T visitSignature(Signature sig);
  T visitTopModule(TopModule mod);
  T visitTypename(TypenameDeclaration decl);
  T visitValue(ValueDeclaration decl);
}

abstract class ModuleMember {
  T visit<T>(ModuleVisitor<T> v);
}

class ValueDeclaration implements TermDeclaration, ModuleMember {
  Name name;
  Datatype type;
  Expression body;
  Location location;

  ValueDeclaration(this.name, this.body, this.location);
  T visit<T>(ModuleVisitor<T> v) {
    return v.visitValue(this);
  }
}

class FunctionDeclaration implements TermDeclaration, ModuleMember {
  Name name;
  Datatype type;
  List<Pattern> parameters;
  List<Expression> body;
  Location location;

  FunctionDeclaration(this.name, this.parameters, this.body, this.location);

  T visit<T>(ModuleVisitor<T> v) {
    return v.visitFunction(this);
  }
}

class DatatypeDeclaration implements TypeDeclaration, ModuleMember {
  Name name;
  List<TypeParameter> typeParameters;
  Map<Name, List<Datatype>> constructors;
  Location location;

  DatatypeDeclaration(
      this.name, this.typeParameters, this.constructors, this.location);

  T visit<T>(ModuleVisitor<T> v) {
    return v.visitDatatype(this);
  }
}

class Include implements ModuleMember {
  String module;
  Location location;

  Include(this.module, this.location);

  T visit<T>(ModuleVisitor<T> v) {
    return v.visitInclude(this);
  }
}

// class Signature implements ModuleMember {
//   Location location;
//   String name;
//   Datatype type;

//   Signature(this.name, this.type, this.location);

//   T visit<T>(ModuleVisitor<T> v) {
//     return v.visitSignature(this);
//   }
// }

class TopModule implements ModuleMember {
  Location location;
  List<ModuleMember> members;
  List<Map<Name, Map<Name, List<Datatype>>>> datatypes;

  TopModule(this.members, this.location);

  T visit<T>(ModuleVisitor<T> v) {
    return v.visitTopModule(this);
  }
}

class TypenameDeclaration implements TypeDeclaration, ModuleMember {
  Name name;
  List<TypeParameter> typeParameters;
  Datatype rhs;
  Location location;

  TypenameDeclaration(this.name, this.typeParameters, this.rhs, this.location);

  T visit<T>(ModuleVisitor<T> v) {
    return v.visitTypename(this);
  }
}

class ErrorModule implements ModuleMember {
  final LocatedError error;
  final Location _location;

  Location get location => _location ?? Location.dummy();

  ErrorModule(this.error, [Location location = null]) : _location = location;

  T visit<T>(ModuleVisitor<T> v) {
    return v.visitError(this);
  }
}

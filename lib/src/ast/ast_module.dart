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
  final ModuleTag tag;
  Location location;

  ModuleMember(this.tag, this.location);

  T accept<T>(ModuleVisitor<T> v);
}

enum ModuleTag { DATATYPE_DEF, ERROR, FUNC_DEF, OPEN, TOP, TYPENAME, VALUE_DEF }

class ValueDeclaration extends ModuleMember implements TermDeclaration {
  Name name;
  Datatype type;
  Expression body;

  ValueDeclaration(this.name, this.body, Location location)
      : super(ModuleTag.VALUE_DEF, location);
  T accept<T>(ModuleVisitor<T> v) {
    return v.visitValue(this);
  }
}

class FunctionDeclaration extends ModuleMember implements TermDeclaration {
  Name name;
  Datatype type;
  List<Pattern> parameters;
  List<Expression> body;

  FunctionDeclaration(this.name, this.parameters, this.body, Location location)
      : super(ModuleTag.FUNC_DEF, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitFunction(this);
  }
}

class DatatypeDeclaration extends ModuleMember implements TypeDeclaration {
  Name name;
  List<TypeParameter> typeParameters;
  Map<Name, List<Datatype>> constructors;
  List<Name> deriving;

  DatatypeDeclaration(this.name, this.typeParameters, this.constructors,
      this.deriving, Location location)
      : super(ModuleTag.DATATYPE_DEF, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitDatatype(this);
  }
}

class Include extends ModuleMember {
  String module;

  Include(this.module, Location location) : super(ModuleTag.OPEN, location);

  T accept<T>(ModuleVisitor<T> v) {
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

class TopModule extends ModuleMember {
  List<ModuleMember> members;
  List<Map<Name, Map<Name, List<Datatype>>>> datatypes;

  TopModule(this.members, Location location) : super(ModuleTag.TOP, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitTopModule(this);
  }
}

class TypenameDeclaration extends ModuleMember implements TypeDeclaration {
  Name name;
  List<TypeParameter> typeParameters;
  Datatype rhs;

  TypenameDeclaration(
      this.name, this.typeParameters, this.rhs, Location location)
      : super(ModuleTag.TYPENAME, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitTypename(this);
  }
}

class ErrorModule extends ModuleMember {
  final LocatedError error;

  ErrorModule(this.error, [Location location = null])
      : super(ModuleTag.ERROR, location == null ? Location.dummy() : location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitError(this);
  }
}

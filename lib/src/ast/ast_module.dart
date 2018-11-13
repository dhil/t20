// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show List, Map;

import '../location.dart';
import '../errors/errors.dart' show LocatedError;
import 'ast_declaration.dart';
import 'ast_expressions.dart';
import 'ast_patterns.dart';
// import 'ast_types.dart';

import 'binder.dart';
import 'datatype.dart';

//
// Module / top-level language.
//
abstract class ModuleVisitor<T> {
  T visitDataConstructor(DataConstructor constr);
  T visitDatatype(DatatypeDescriptor decl);
  T visitDatatypes(DatatypeDeclarations decls);
  T visitError(ErrorModule err);
  T visitFunction(FunctionDeclaration decl);
  T visitInclude(Include include);
  T visitSignature(Signature sig);
  T visitTopModule(TopModule mod);
  T visitTypename(TypeAliasDescriptor decl);
  T visitValue(ValueDeclaration decl);
}

enum ModuleTag {
  CONSTR,
  DATATYPE_DEF,
  DATATYPE_DEFS,
  ERROR,
  FUNC_DEF,
  OPEN,
  SIGNATURE,
  TOP,
  TYPENAME,
  VALUE_DEF
}

abstract class ModuleMember {
  final ModuleTag tag;
  Location location;

  ModuleMember(this.tag, this.location);

  T accept<T>(ModuleVisitor<T> v);
}

class Signature extends ModuleMember {
  Location location;
  Binder binder;
  Datatype type;
  List<Declaration> definitions;

  Signature(this.binder, this.type, Location location)
      : definitions = new List<Declaration>(),
        super(ModuleTag.SIGNATURE, location);


  void addDefinition(Declaration decl) {
    definitions.add(decl);
  }

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitSignature(this);
  }
}

class ValueDeclaration extends ModuleMember implements Declaration {
  Binder binder;
  Signature signature;
  Expression body;

  ValueDeclaration(this.signature, this.binder, this.body, Location location)
      : super(ModuleTag.VALUE_DEF, location);
  T accept<T>(ModuleVisitor<T> v) {
    return v.visitValue(this);
  }
}

class FunctionDeclaration extends ModuleMember implements Declaration {
  Binder binder;
  Signature signature;
  List<Pattern> parameters;
  Expression body;

  FunctionDeclaration(this.signature, this.binder, this.parameters, this.body,
      Location location)
      : super(ModuleTag.FUNC_DEF, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitFunction(this);
  }
}

class DataConstructor extends ModuleMember implements Declaration {
  DatatypeDescriptor declarator;
  Binder binder;
  List<Datatype> parameters;

  DataConstructor(this.binder, this.parameters, Location location)
      : super(ModuleTag.CONSTR, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitDataConstructor(this);
  }
}

class DatatypeDescriptor extends ModuleMember
    implements Declaration, TypeDescriptor {
  Binder binder;
  List<Quantifier> parameters;
  List<DataConstructor> constructors;
  List<int> deriving;

  int get arity => parameters.length;

  DatatypeDescriptor(this.binder, this.parameters, this.constructors,
      this.deriving, Location location)
      : super(ModuleTag.DATATYPE_DEF, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitDatatype(this);
  }
}

class DatatypeDeclarations extends ModuleMember {
  List<DatatypeDescriptor> declarations;

  DatatypeDeclarations(this.declarations, Location location)
      : super(ModuleTag.DATATYPE_DEFS, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitDatatypes(this);
  }
}

class Include extends ModuleMember {
  String module;

  Include(this.module, Location location) : super(ModuleTag.OPEN, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitInclude(this);
  }
}

class TopModule extends ModuleMember {
  List<ModuleMember> members;

  TopModule(this.members, Location location) : super(ModuleTag.TOP, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitTopModule(this);
  }
}

class TypeAliasDescriptor extends ModuleMember
    implements Declaration, TypeDescriptor {
  Binder binder;
  List<Quantifier> parameters;
  Datatype rhs;

  int get arity => parameters.length;

  TypeAliasDescriptor(this.binder, this.parameters, this.rhs, Location location)
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

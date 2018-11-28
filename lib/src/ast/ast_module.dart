// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';
import '../errors/errors.dart' show LocatedError;
import '../utils.dart' show ListUtils;

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

  bool get isVirtual => false;
  Datatype get type => signature.type;
  int get ident => binder.id;

  ValueDeclaration(this.signature, this.binder, this.body, Location location)
      : super(ModuleTag.VALUE_DEF, location);
  T accept<T>(ModuleVisitor<T> v) {
    return v.visitValue(this);
  }

  String toString() {
    return "(define $binder (...)))";
  }
}

class FunctionDeclaration extends ModuleMember implements Declaration {
  Binder binder;
  Signature signature;
  List<Pattern> parameters;
  Expression body;

  bool get isVirtual => false;
  Datatype get type => signature.type;
  int get ident => binder.id;

  FunctionDeclaration(this.signature, this.binder, this.parameters, this.body,
      Location location)
      : super(ModuleTag.FUNC_DEF, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitFunction(this);
  }

  String toString() {
    String parameters0 = ListUtils.stringify(" ", parameters);
    return "(define ($binder $parameters0) (...))";
  }
}

class VirtualFunctionDeclaration extends FunctionDeclaration {
  bool get isVirtual => true;

  VirtualFunctionDeclaration._(Signature signature, Binder binder)
      : super(signature, binder, null, null, signature.location);
  factory VirtualFunctionDeclaration(String name, Datatype type) {
    Location location = Location.dummy();
    Binder binder = Binder.primitive(name);
    Signature signature = new Signature(binder, type, location);
    VirtualFunctionDeclaration funDecl =
        new VirtualFunctionDeclaration._(signature, binder);
    signature.addDefinition(funDecl);
    return funDecl;
  }
}

class DataConstructor extends ModuleMember implements Declaration {
  DatatypeDescriptor declarator;
  Binder binder;
  List<Datatype> parameters;

  bool get isVirtual => false;
  int get ident => binder.id;

  Datatype _type;
  Datatype get type {
    if (_type == null) {
      List<Quantifier> quantifiers;
      if (declarator.parameters.length > 0) {
        // It's necessary to copy the quantifiers as the [ForallType] enforces
        // the invariant that the list is sorted.
        quantifiers = new List<Quantifier>(declarator.parameters.length);
        List.copyRange<Quantifier>(quantifiers, 0, declarator.parameters);
      }
      if (parameters.length > 0) {
        // Construct the induced function type.
        List<Datatype> domain = parameters;
        Datatype codomain = declarator.type;
        Datatype ft = ArrowType(domain, codomain);
        if (quantifiers != null) {
          ForallType forallType = new ForallType();
          forallType.quantifiers = quantifiers;
          forallType.body = ft;
          ft = forallType;
        }
        _type = ft;
      } else {
        if (quantifiers != null) {
          ForallType forallType = new ForallType();
          forallType.quantifiers = quantifiers;
          forallType.body = declarator.type;
          _type = forallType;
        } else {
          _type = declarator.type;
        }
      }
    }
    return _type;
  }

  DataConstructor(this.binder, this.parameters, Location location)
      : super(ModuleTag.CONSTR, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitDataConstructor(this);
  }
}

class ClassDescriptor {
  final Binder binder;
  final List<VirtualFunctionDeclaration> members;

  int get ident => binder.id;

  ClassDescriptor(this.binder, this.members);
}

class Derive {
  final ClassDescriptor classDescriptor;
  Derive(this.classDescriptor);
}

class DatatypeDescriptor extends ModuleMember
    implements Declaration, TypeDescriptor {
  Binder binder;
  List<Quantifier> parameters;
  List<DataConstructor> constructors;
  List<Derive> deriving;

  bool get isVirtual => false;
  int get ident => binder.id;

  TypeConstructor _type;
  TypeConstructor get type {
    if (_type == null) {
      List<Datatype> arguments = new List<Datatype>(parameters.length);
      for (int i = 0; i < parameters.length; i++) {
        arguments[i] = TypeVariable.bound(parameters[i]);
      }
      _type = TypeConstructor.from(this, arguments);
    }
    return _type;
  }

  int get arity => parameters.length;

  DatatypeDescriptor(this.binder, this.parameters, this.constructors,
      this.deriving, Location location)
      : super(ModuleTag.DATATYPE_DEF, location);
  DatatypeDescriptor.partial(
      Binder binder, List<Quantifier> parameters, Location location)
      : this(binder, parameters, null, null, location);
  T accept<T>(ModuleVisitor<T> v) {
    return v.visitDatatype(this);
  }

  String toString() {
    String parameterisedName;
    if (parameters.length == 0) {
      parameterisedName = binder.sourceName;
    } else {
      String parameters0 = ListUtils.stringify(" ", parameters);
      parameterisedName = "(${binder.sourceName} $parameters0)";
    }
    return "(define-datatype $parameterisedName ...)";
  }
}

class DatatypeDeclarations extends ModuleMember {
  List<DatatypeDescriptor> declarations;

  DatatypeDeclarations(this.declarations, Location location)
      : super(ModuleTag.DATATYPE_DEFS, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitDatatypes(this);
  }

  String toString() {
    return "(define-datatypes $declarations)";
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

  String toString() {
    String members0 = ListUtils.stringify(" ", members);
    return "(module ...)";
  }
}

class TypeAliasDescriptor extends ModuleMember
    implements Declaration, TypeDescriptor {
  Binder binder;
  List<Quantifier> parameters;
  Datatype rhs;

  bool get isVirtual => false;
  int get ident => binder.id;

  TypeConstructor _type;
  TypeConstructor get type {
    if (_type == null) {
      List<Datatype> arguments = new List<Datatype>(parameters.length);
      for (int i = 0; i < parameters.length; i++) {
        arguments[i] = TypeVariable.bound(parameters[i]);
      }
      _type = TypeConstructor.from(this, arguments);
    }
    return _type;
  }

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

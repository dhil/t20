// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show T20Error;
import '../location.dart';
import '../unionfind.dart' as unionfind;
import '../unionfind.dart' show Point;
import '../utils.dart' show Gensym;

import 'binder.dart';
import 'monoids.dart' show Monoid, StringMonoid;
// import 'name.dart';

abstract class TypeDescriptor {
  Binder binder;
  List<Quantifier> parameters;
  int get arity;
}

enum TypeTag {
  // Base types.
  BOOL,
  INT,
  STRING,

  // Higher order types.
  ARROW,
  CONSTR,
  FORALL,
  TUPLE,

  // Variables.
  VAR,

  // Misc.
  ERROR
}

abstract class TypeVisitor<T> {
  T visitBoolType(BoolType boolType);
  T visitIntType(IntType intType);
  T visitStringType(StringType stringType);

  T visitForallType(ForallType forallType);

  T visitArrowType(ArrowType arrowType);
  T visitTupleType(TupleType tupleType);
  T visitTypeConstructor(TypeConstructor constr);

  T visitTypeVariable(TypeVariable variable);
  T visitSkolem(Skolem skolem);

  T visitError(ErrorType error);
}

abstract class ReduceDatatype<T> extends TypeVisitor<T> {
  Monoid<T> get m;

  T visitList(List<Datatype> types) {
    return types.fold(
        m.empty, (T acc, Datatype type) => m.compose(acc, type.accept(this)));
  }

  T visitBoolType(BoolType _) => m.empty;
  T visitIntType(IntType _) => m.empty;
  T visitStringType(StringType _) => m.empty;

  T visitForallType(ForallType forallType) {
    return forallType.body.accept(this);
  }

  T visitArrowType(ArrowType arrowType) {
    T domain = visitList(arrowType.domain);
    T codomain = arrowType.codomain.accept(this);
    return m.compose(domain, codomain);
  }

  T visitTupleType(TupleType tupleType) {
    return visitList(tupleType.components);
  }

  T visitTypeConstructor(TypeConstructor constr) {
    return visitList(constr.arguments);
  }

  T visitTypeVariable(TypeVariable _) => m.empty;
  T visitSkolem(Skolem _) => m.empty;
  T visitError(ErrorType error) => m.empty;
}

class StringifyDatatype extends ReduceDatatype<String> {
  final StringMonoid _m = new StringMonoid();
  Monoid<String> get m => _m;

  String stringOfQuantifier(Quantifier q) => q.binder.toString();
  String visitQuantifiers(List<Quantifier> qs) {
    List<String> qs0 = new List<String>(qs.length);
    for (int i = 0; i < qs.length; i++) {
      qs0[i] = stringOfQuantifier(qs[i]);
    }
    return qs0.join(" ");
  }

  String visitBoolType(BoolType _) => "Bool";
  String visitIntType(IntType _) => "Int";
  String visitStringType(StringType _) => "String";

  String visitForallType(ForallType forallType) {
    String quantifiers = visitQuantifiers(forallType.quantifiers);
    String body = forallType.body.accept(this);
    if (forallType.quantifiers.length == 1) {
      return "(forall $quantifiers $body)";
    } else {
      return "(forall ($quantifiers) $body)";
    }
  }

  String visitArrowType(ArrowType arrowType) {
    if (arrowType.domain.length == 0) {
      String codomain = arrowType.codomain.accept(this);
      return "(-> $codomain)";
    } else {
      String domain = visitList(arrowType.domain);
      String codomain = arrowType.codomain.accept(this);
      return "(-> $domain $codomain)";
    }
  }

  String visitTupleType(TupleType tupleType) {
    if (tupleType.components.length == 0) {
      return "(*)";
    } else {
      String components = visitList(tupleType.components);
      return "(* $components)";
    }
  }

  String visitTypeConstructor(TypeConstructor constr) {
    String name = constr.declarator.binder.sourceName;
    if (constr.arguments.length == 0) {
      return "$name";
    } else {
      String typeArguments = visitList(constr.arguments);
      if (constr.arguments.length == 1) {
        return "($name $typeArguments)";
      } else {
        return "($name ($typeArguments)";
      }
    }
  }

  String visitTypeVariable(TypeVariable v) => v.declarator.binder.toString();
  String visitSkolem(Skolem s) {
    Datatype type = s.type;
    if (type == null || type == s) {
      return s.syntheticName;
    } else {
      return type.accept(this);
    }
  }
}

abstract class TransformDatatype extends TypeVisitor<Datatype> {
  List<Datatype> visitList(List<Datatype> types) {
    final List<Datatype> types0 = new List<Datatype>();
    for (int i = 0; i < types.length; i++) {
      types0.add(types[i].accept(this));
    }
    return types0;
  }

  Datatype visitBoolType(BoolType boolType) => boolType;
  Datatype visitIntType(IntType intType) => intType;
  Datatype visitStringType(StringType stringType) => stringType;

  Datatype visitForallType(ForallType forallType) {
    Datatype body0 = forallType.body.accept(this);
    ForallType forallType0 = new ForallType();
    forallType0._quantifiers = forallType._quantifiers;
    forallType0.body = body0;
    return forallType0;
  }

  Datatype visitArrowType(ArrowType arrowType) {
    List<Datatype> domain = visitList(arrowType.domain);
    Datatype codomain = arrowType.codomain.accept(this);
    return ArrowType(domain, codomain);
  }

  Datatype visitTupleType(TupleType tupleType) {
    return TupleType(visitList(tupleType.components));
  }

  Datatype visitTypeConstructor(TypeConstructor constr) {
    return TypeConstructor.from(constr.declarator, visitList(constr.arguments));
  }

  Datatype visitTypeVariable(TypeVariable variable) => variable;
  Datatype visitSkolem(Skolem skolem) => skolem;
  Datatype visitError(ErrorType error) => error;
}

abstract class Datatype {
  final TypeTag tag;
  const Datatype(this.tag);

  T accept<T>(TypeVisitor<T> v);

  String toString() {
    return accept<String>(StringifyDatatype());
  }
}

abstract class BaseType extends Datatype {
  const BaseType(TypeTag tag) : super(tag);
}

class BoolType extends BaseType {
  const BoolType() : super(TypeTag.BOOL);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitBoolType(this);
  }
}

class IntType extends BaseType {
  const IntType() : super(TypeTag.INT);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitIntType(this);
  }
}

class StringType extends BaseType {
  const StringType() : super(TypeTag.STRING);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitStringType(this);
  }
}

class ArrowType extends Datatype {
  final List<Datatype> domain;
  final Datatype codomain;

  ArrowType(this.domain, this.codomain) : super(TypeTag.ARROW);

  int get arity => domain.length;

  T accept<T>(TypeVisitor<T> v) {
    return v.visitArrowType(this);
  }
}

class TupleType extends Datatype {
  final List<Datatype> components;
  const TupleType(this.components) : super(TypeTag.TUPLE);

  int get arity => components.length;

  T accept<T>(TypeVisitor<T> v) {
    return v.visitTupleType(this);
  }
}

class Quantifier {
  final Kind kind = Kind.TYPE;
  final Binder binder;
  int get ident => binder.id;
  // final Set<Object> constraints;

  Quantifier.fresh()
      : binder = Binder.fresh(); // : constraints = new Set<Object>();
  Quantifier.of(Binder binder) : this.binder = binder;

  static int compare(Quantifier a, Quantifier b) {
    if (a.binder.id < b.binder.id)
      return -1;
    else if (a.binder.id == b.binder.id)
      return 0;
    else
      return 1;
  }

  String toString() {
    return "$binder";
  }
}

class TypeVariable extends Datatype {
  // May be null during construction. Otherwise it is intended to point to its
  // binder.
  Quantifier declarator;

  bool get isQuantified => declarator != null;

  TypeVariable() : super(TypeTag.VAR);
  TypeVariable.unbound() : this.bound(Quantifier.fresh());
  TypeVariable.bound(this.declarator) : super(TypeTag.VAR);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitTypeVariable(this);
  }

  int get ident => declarator.binder.id;
}

class Skolem extends Datatype {
  Point<Datatype> _point;
  final int _ident;
  int get ident => _ident;

  int level = 0; // TODO remove.

  String get syntheticName => "?$ident";

  Skolem()
      : _ident = Gensym.freshInt(),
        _point = unionfind.singleton(null),
        super(TypeTag.VAR);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitSkolem(this);
  }

  Datatype get type => unionfind.find(_point);

  void equate(Skolem other) {
    unionfind.union(_point, other._point);
  }

  void solve(Datatype type) {
    unionfind.change(_point, type);
  }

  bool get isSolved => unionfind.find(_point) != null;

  bool painted = false;
  void paint() => painted = true;
  void reset() => painted = false;
}

class ForallType extends Datatype {
  List<Quantifier> _quantifiers;
  List<Quantifier> get quantifiers => _quantifiers;
  void set quantifiers(List<Quantifier> quantifiers) {
    quantifiers.sort(Quantifier.compare);
    _quantifiers = quantifiers;
  }

  Datatype body;

  ForallType() : super(TypeTag.FORALL);
  factory ForallType.complete(List<Quantifier> quantifiers, Datatype body) {
    ForallType type = new ForallType();
    type.quantifiers = quantifiers;
    type.body = body;
    return body;
  }

  T accept<T>(TypeVisitor<T> v) {
    return v.visitForallType(this);
  }
}

class TypeConstructor extends Datatype {
  TypeDescriptor declarator;
  List<Datatype> arguments;

  int get ident => declarator.binder.id;

  TypeConstructor() : super(TypeTag.CONSTR);
  TypeConstructor.from(this.declarator, this.arguments) : super(TypeTag.CONSTR);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitTypeConstructor(this);
  }
}

class ErrorType extends Datatype {
  final T20Error error;

  ErrorType(this.error, Location location) : super(TypeTag.ERROR);

  T accept<T>(TypeVisitor<T> v) {
    return v.visitError(this);
  }
}

// Kinds
enum Kind { TYPE }

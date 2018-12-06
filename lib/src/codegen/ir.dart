// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/binder.dart';
import '../ast/datatype.dart';
import '../location.dart' show Location;
import '../typing/type_utils.dart' as typeUtils show arity;

/*
 * The intermediate representation (IR) is an ANF-ish representation of the
 * front-end AST. The IR distinguishes between computations and values (or
 * serious and trivial terms).
 */

abstract class IRVisitor<T> {
  // Modules.
  T visitModule(Module mod);

  // Computations.
  T visitComputation(Computation comp);

  // Values.
  T visitApplyPure(ApplyPure apply);
  T visitBoolLit(BoolLit lit);
  T visitIntLit(IntLit lit);
  T visitLambda(Lambda lambda);
  T visitRecord(Record record);
  T visitPrimitiveFunction(PrimitiveFunction primitive);
  T visitProjection(Projection proj);
  T visitStringLit(StringLit lit);
  T visitVariable(Variable v);

  // Bindings.
  T visitDataConstructor(DataConstructor constr);
  T visitDatatype(DatatypeDescriptor desc);
  T visitLetFun(LetFun f);
  T visitLetVal(LetVal let);

  // Tail computations.
  T visitIf(If ifthenelse);
  T visitApply(Apply apply);
  T visitReturn(Return ret);

  // Specials.
  /* Empty (for now) */
}

//===== Algebras.
class IRAlgebra {
  static IRAlgebra _instance;
  IRAlgebra._();
  factory IRAlgebra() {
    _instance ??= IRAlgebra._();
    return _instance;
  }

      // Values.
  ApplyPure applyPure(Value fn, List<Value> arguments, {Location location}) {
    return ApplyPure(apply(fn, arguments));
  }

  BoolLit boollit(bool lit, {Location location}) => BoolLit(lit);
  IntLit intlit(int lit, {Location location}) => IntLit(lit);

  Lambda lambda(List<TypedBinder> parameters, Computation body,
      {Location location}) {
    return Lambda(parameters, body);
  }

  Record record(Map<String, Value> members, {Location location}) {
    return Record(members);
  }

  Projection project(Value v, String label, {Location location}) {
    return Projection(v, label);
  }

  StringLit stringlit(String lit, {Location location}) => StringLit(lit);

  Variable variable(TypedBinder binder, {Location location}) {
    Variable v = Variable(binder);
    binder.addOccurrence(v);
    return v;
  }

  // Bindings.
  DataConstructor dataConstructor(
      TypedBinder binder, List<Datatype> memberTypes,
      {Location location}) {
    return null;
  }

  DatatypeDescriptor datatypeDescriptor(
      TypedBinder binder, List<DataConstructor> constructors,
      {Location location}) {
    return null;
  }

  LetFun letFunction(
      TypedBinder binder, List<TypedBinder> parameters, Computation body,
      {Location location}) {
    LetFun fun = LetFun(binder, parameters, body);
    binder.bindingSite = fun;
    for (int i = 0; i < parameters.length; i++) {
      parameters[i].bindingSite = fun;
    }
    return fun;
  }

  LetVal letValue(TypedBinder binder, TailComputation expr,
      {Location location}) {
    LetVal let = LetVal(binder, expr);
    binder.bindingSite = let;
    return let;
  }

  // Tail computations.
  Apply apply(Value fn, List<Value> arguments, {Location location}) {
    return Apply(fn, arguments);
  }

  If ifthenelse(Value condition, Computation thenBranch, Computation elseBranch,
      {Location location}) {
    return If(condition, thenBranch, elseBranch);
  }

  Return return$(Value v, {Location location}) => Return(v);

  // Computations.
  Computation computation(List<Binding> bindings, TailComputation tc,
          {Location location}) =>
      Computation(bindings, tc);

  // Modules.
  Module module(List<Binding> bindings, {Location location}) =>
      Module(bindings);

  // Utils.
  Computation withBindings(List<Binding> bindings, Computation comp) {
    if (bindings == null) return comp;

    if (comp.bindings != null) {
      bindings.addAll(comp.bindings);
    }

    comp.bindings = bindings;
    return comp;
  }
}

abstract class IRNode {
  T accept<T>(IRVisitor<T> v);
}

//===== Modules.
class Module implements IRNode {
  Map<int, Object> datatypes;
  List<Binding> bindings;

  Module(this.bindings);

  T accept<T>(IRVisitor<T> v) {
    return v.visitModule(this);
  }
}

//===== Binder.
class TypedBinder extends Binder {
  Binding bindingSite;
  Datatype type;
  Set<Variable> occurrences;

  TypedBinder.of(Binder b, Datatype type)
      : this.type = type,
        super.raw(b.ident, b.sourceName, b.location);

  TypedBinder.fresh(Datatype type)
      : this.type = type,
        super.fresh();

  bool get hasOccurrences => occurrences != null && occurrences.length > 0;
  void addOccurrence(Variable v) {
    if (occurrences == null) occurrences = new Set<Variable>();
    occurrences.add(v);
  }

  int get hashCode {
    int hash = super.hashCode * 13 + type.hashCode;
    return hash;
  }
}

//===== Bindings.
abstract class Binding implements IRNode {
  TypedBinder binder;

  Datatype get type => binder.type;
  int get ident => binder.ident;

  Binding(this.binder);

  // bool get hasOccurrences => binder.hasOccurrences;
  // void addOccurrence(Variable v) => binder.addOccurrence(v);
}

class LetVal extends Binding {
  TailComputation tailComputation;

  LetVal(TypedBinder binder, this.tailComputation) : super(binder);

  T accept<T>(IRVisitor<T> v) {
    return v.visitLetVal(this);
  }
}

class LetFun extends Binding {
  List<TypedBinder> parameters;
  Computation body;

  int get arity => parameters == null ? 0 : parameters.length;

  LetFun(TypedBinder binder, this.parameters, this.body) : super(binder);

  T accept<T>(IRVisitor<T> v) {
    return v.visitLetFun(this);
  }
}

class DatatypeDescriptor extends Binding {
  List<DataConstructor> constructors;

  DatatypeDescriptor(TypedBinder binder, this.constructors) : super(binder);

  T accept<T>(IRVisitor<T> v) {
    return v.visitDatatype(this);
  }
}

class DataConstructor extends Binding {
  List<Datatype> members;

  DataConstructor(TypedBinder binder, this.members) : super(binder);

  T accept<T>(IRVisitor<T> v) {
    return v.visitDataConstructor(this);
  }
}

//===== Computations.
class Computation implements IRNode {
  List<Binding> bindings;
  TailComputation tailComputation;

  Computation(this.bindings, this.tailComputation);

  bool get isSimple =>
      (bindings == null || bindings.length == 0) && tailComputation.isSimple;

  T accept<T>(IRVisitor<T> v) {
    return v.visitComputation(this);
  }
}

//===== Tail computations.
abstract class TailComputation implements IRNode {
  bool get isSimple;
}

class Apply extends TailComputation {
  Value abstractor;
  List<Value> arguments;

  Apply(this.abstractor, this.arguments);

  bool get isSimple => true;

  T accept<T>(IRVisitor<T> v) {
    return v.visitApply(this);
  }
}

class If extends TailComputation {
  Value condition;
  Computation thenBranch;
  Computation elseBranch;

  If(this.condition, this.thenBranch, this.elseBranch);

  bool get isSimple => thenBranch.isSimple && elseBranch.isSimple;

  T accept<T>(IRVisitor<T> v) {
    return v.visitIf(this);
  }
}

class Return extends TailComputation {
  Value value;

  Return(this.value);

  bool get isSimple => true;

  T accept<T>(IRVisitor<T> v) {
    return v.visitReturn(this);
  }
}

//===== Values.
abstract class Value implements IRNode {}

class ApplyPure extends Value {
  Apply apply;

  Value get abstractor => apply.abstractor;
  List<Value> get arguments => apply.arguments;

  ApplyPure(this.apply);

  T accept<T>(IRVisitor<T> v) {
    return v.visitApplyPure(this);
  }
}

abstract class Literal extends Value {
  Literal();
}

class BoolLit extends Literal {
  bool value;

  BoolLit(this.value) : super();

  T accept<T>(IRVisitor<T> v) => v.visitBoolLit(this);
}

class IntLit extends Literal {
  int value;

  IntLit(this.value) : super();

  T accept<T>(IRVisitor<T> v) => v.visitIntLit(this);
}

class StringLit extends Literal {
  String value;
  StringLit(this.value) : super();

  T accept<T>(IRVisitor<T> v) => v.visitStringLit(this);
}

class Lambda extends Value {
  List<TypedBinder> parameters;
  Computation body;

  Lambda(this.parameters, this.body);

  T accept<T>(IRVisitor<T> v) {
    return v.visitLambda(this);
  }
}

class Record extends Value {
  Map<String, Value> members;

  Record(this.members);

  T accept<T>(IRVisitor<T> v) {
    return v.visitRecord(this);
  }
}

class Projection extends Value {
  String label;
  Value receiver;

  Projection(this.receiver, this.label);

  T accept<T>(IRVisitor<T> v) => v.visitProjection(this);
}

class Variable extends Value {
  TypedBinder declarator;
  int get ident => declarator.ident;

  Variable(this.declarator);

  T accept<T>(IRVisitor<T> v) {
    return v.visitVariable(this);
  }

  bool operator ==(Object other) =>
      identical(this, other) || other is Variable && ident == other.ident;
  int get hashCode => ident;
}

//===== Primitives.
abstract class Primitive extends Value implements Binding {
  TypedBinder binder;

  Datatype get type => binder.type;
  int get ident => binder.ident;

  Primitive(this.binder);
}

class PrimitiveFunction extends Primitive {
  int get arity => typeUtils.arity(type);
  PrimitiveFunction(TypedBinder binder) : super(binder);

  T accept<T>(IRVisitor<T> v) => v.visitPrimitiveFunction(this);
}

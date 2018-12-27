// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart' hide Location;

import '../ast/binder.dart' show Binder;
import '../ast/datatype.dart';
import '../location.dart' show Location;
import '../typing/type_utils.dart' as typeUtils show arity;
import '../utils.dart' show Gensym;

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
  T visitFormal(FormalParameter formal);

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

  void _setUplinks(List<IRNode> nodes, IRNode parent) {
    if (nodes == null) return;

    for (int i = 0; i < nodes.length; i++) {
      nodes[i].parent = parent;
    }
  }

  // Values.
  ApplyPure applyPure(Value fn, List<Value> arguments, {Location location}) {
    ApplyPure appl = ApplyPure(apply(fn, arguments));
    // Set uplinks.
    fn.parent = appl;
    _setUplinks(arguments, appl);
    return appl;
  }

  BoolLit boollit(bool lit, {Location location}) => BoolLit(lit);
  IntLit intlit(int lit, {Location location}) => IntLit(lit);

  Lambda lambda(List<FormalParameter> parameters, Computation body,
      {Location location}) {
    Lambda lam = Lambda(parameters, body);
    // Set uplinks.
    body.parent = lam;
    _setUplinks(parameters, lam);
    return lam;
  }

  Record record(Map<String, Value> members, {Location location}) {
    Record record = Record(members);
    // Set uplink.
    members.forEach((String _, Value v) => v.parent = record);
    return record;
  }

  Projection project(Value v, String label, {Location location}) {
    Projection prj = Projection(v, label);
    // Set uplink.
    v.parent = prj;
    return prj;
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
      TypedBinder binder, List<FormalParameter> parameters, Computation body,
      {Location location}) {
    LetFun fun = LetFun(binder, parameters, body);
    binder.bindingSite = fun;
    _setUplinks(parameters, fun);
    body.parent = fun;
    return fun;
  }

  LetVal letValue(TypedBinder binder, TailComputation expr,
      {Location location}) {
    LetVal let = LetVal(binder, expr);
    binder.bindingSite = let;
    expr.parent = let;
    return let;
  }

  FormalParameter formal(TypedBinder binder) {
    FormalParameter param = FormalParameter(binder);
    binder.bindingSite = param;
    return param;
  }

  // Tail computations.
  Apply apply(Value fn, List<Value> arguments, {Location location}) {
    Apply appl = Apply(fn, arguments);
    // Set uplinks.
    fn.parent = appl;
    _setUplinks(arguments, appl);
    return appl;
  }

  If ifthenelse(Value condition, Computation thenBranch, Computation elseBranch,
      {Location location}) {
    If ifexpr = If(condition, thenBranch, elseBranch);
    // Set uplinks.
    condition.parent = ifexpr;
    thenBranch.parent = ifexpr;
    elseBranch.parent = ifexpr;
    return ifexpr;
  }

  Return return$(Value v, {Location location}) {
    Return ret = Return(v);
    v.parent = ret;
    return ret;
  }

  // Computations.
  Computation computation(List<Binding> bindings, TailComputation tc,
      {Location location}) {
    Computation comp = Computation(bindings, tc);
    tc.parent = comp;
    _setUplinks(bindings, comp);
    return comp;
  }

  // Modules.
  Module module(List<Binding> bindings, {Location location}) {
    Module mod = Module(bindings);
    _setUplinks(bindings, mod);
    return mod;
  }

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

//===== Tags.
// Modules.
const int MODULE = 0x00001;
// Computations.
const int COMPUTATION = 0x00010;
// Tail computations.
const int APPLY = 0x00100;
const int IF = 0x00200;
const int RETURN = 0x00300;
// Values.
const int BOOL = 0x01000;
const int INT = 0x02000;
const int STRING = 0x03000;
const int APPLY_PURE = 0x04000;
const int LAMBDA = 0x05000;
const int RECORD = 0x06000;
const int PROJECT = 0x07000;
const int PRIMITIVE = 0x08000;
const int VAR = 0x09000;
// Bindings.
const int LET_FUN = 0x10000;
const int LET_VAL = 0x20000;
const int CONSTR = 0x30000;
const int TYPE = 0x40000;
const int FORMAL = 0x50000;

abstract class IRNode {
  final int tag;

  IRNode _parent; // May be null.
  IRNode get parent => _parent;
  void set parent(IRNode parent) => _parent = parent;

  IRNode(this.tag);

  T accept<T>(IRVisitor<T> v);

  String toString() {
    _PrettyPrinter ppr = _PrettyPrinter();
    this.accept<void>(ppr);
    return ppr.result;
  }
}

//===== Modules.
class Module extends IRNode {
  final int tag = MODULE;
  Map<int, Object> datatypes;
  List<Binding> bindings;

  Module(this.bindings) : super(MODULE);

  T accept<T>(IRVisitor<T> v) {
    return v.visitModule(this);
  }
}

//===== Binder.
class TypedBinder {
  //Module origin;
  final String _sourceName;
  final Location _location;
  final int _ident;
  int get ident => _ident;

  Location get location => _location ?? Location.dummy();
  String get sourceName => _sourceName ?? "<synthetic>";

  IRNode bindingSite; // Binding | Value (specifically Lambda).
  Datatype type;
  Set<Variable> occurrences;

  TypedBinder.of(Binder b, Datatype type)
      : this._raw(b.ident, b.sourceName, b.location, type);

  TypedBinder.fresh(Datatype type)
      : this._raw(Gensym.freshInt(), null, null, type);

  TypedBinder._raw(this._ident, this._sourceName, this._location, this.type);

  bool get hasOccurrences => occurrences != null && occurrences.length > 0;
  void addOccurrence(Variable v) {
    if (occurrences == null) occurrences = new Set<Variable>();
    occurrences.add(v);
  }

  int get hashCode {
    int hash = 1;
    hash = hash * 13 + (_location == null ? 0 : _location.hashCode);
    hash = hash * 17 + ident;
    hash = hash * 31 + (_sourceName == null ? 0 : _sourceName.hashCode);
    hash = hash * 13 + type.hashCode;
    return hash;
  }

  String get uniqueName {
    if (_sourceName == null) {
      return "_${_ident}";
    } else {
      return "${_sourceName}_${_ident}";
    }
  }
}

//===== Bindings.
abstract class Binding extends IRNode {
  TypedBinder binder;

  Datatype get type => binder.type;
  int get ident => binder.ident;

  Binding(this.binder, int tag) : super(tag);

  // bool get hasOccurrences => binder.hasOccurrences;
  // void addOccurrence(Variable v) => binder.addOccurrence(v);
}

class LetVal extends Binding {
  TailComputation tailComputation;
  TreeNode kernelNode;

  LetVal(TypedBinder binder, this.tailComputation) : super(binder, LET_VAL);

  T accept<T>(IRVisitor<T> v) {
    return v.visitLetVal(this);
  }
}

class LetFun extends Binding {
  List<FormalParameter> parameters;
  Computation body;
  Procedure kernelNode;

  int get arity => parameters == null ? 0 : parameters.length;

  LetFun(TypedBinder binder, this.parameters, this.body)
      : super(binder, LET_FUN);

  T accept<T>(IRVisitor<T> v) {
    return v.visitLetFun(this);
  }
}

class FormalParameter extends Binding {
  VariableDeclaration kernelNode;

  FormalParameter(TypedBinder binder) : super(binder, FORMAL);

  T accept<T>(IRVisitor<T> v) => v.visitFormal(this);
}

class DatatypeDescriptor extends Binding {
  List<DataConstructor> constructors;

  DatatypeDescriptor(TypedBinder binder, this.constructors)
      : super(binder, TYPE);

  T accept<T>(IRVisitor<T> v) {
    return v.visitDatatype(this);
  }
}

class DataConstructor extends Binding {
  List<Datatype> members;

  DataConstructor(TypedBinder binder, this.members) : super(binder, CONSTR);

  T accept<T>(IRVisitor<T> v) {
    return v.visitDataConstructor(this);
  }
}

//===== Computations.
class Computation extends IRNode {
  List<Binding> bindings;
  TailComputation _tc;
  TailComputation get tailComputation => _tc;
  void set tailComputation(TailComputation tc) {
    _tc = tc;
    tc.parent = this;
  }

  Computation(this.bindings, this._tc) : super(COMPUTATION);

  bool get isSimple =>
      (bindings == null || bindings.length == 0) && tailComputation.isSimple;

  T accept<T>(IRVisitor<T> v) {
    return v.visitComputation(this);
  }
}

//===== Tail computations.
abstract class TailComputation extends IRNode {
  TailComputation(int tag) : super(tag);
  bool get isSimple;
}

class Apply extends TailComputation {
  Value abstractor;
  List<Value> arguments;

  Apply(this.abstractor, this.arguments) : super(APPLY);

  bool get isSimple => true;

  T accept<T>(IRVisitor<T> v) {
    return v.visitApply(this);
  }
}

class If extends TailComputation {
  Value condition;
  Computation thenBranch;
  Computation elseBranch;

  If(this.condition, this.thenBranch, this.elseBranch) : super(IF);

  bool get isSimple => thenBranch.isSimple && elseBranch.isSimple;

  T accept<T>(IRVisitor<T> v) {
    return v.visitIf(this);
  }
}

class Return extends TailComputation {
  Value value;

  Return(this.value) : super(RETURN);

  bool get isSimple => true;

  T accept<T>(IRVisitor<T> v) {
    return v.visitReturn(this);
  }
}

//===== Values.
abstract class Value extends IRNode {
  Value(int tag) : super(tag);
}

class ApplyPure extends Value {
  Apply apply;

  Value get abstractor => apply.abstractor;
  List<Value> get arguments => apply.arguments;

  ApplyPure(this.apply) : super(APPLY_PURE);

  T accept<T>(IRVisitor<T> v) {
    return v.visitApplyPure(this);
  }
}

abstract class Literal extends Value {
  Literal(int tag) : super(tag);
}

class BoolLit extends Literal {
  bool value;

  BoolLit(this.value) : super(BOOL);

  T accept<T>(IRVisitor<T> v) => v.visitBoolLit(this);
}

class IntLit extends Literal {
  int value;

  IntLit(this.value) : super(INT);

  T accept<T>(IRVisitor<T> v) => v.visitIntLit(this);
}

class StringLit extends Literal {
  String value;
  StringLit(this.value) : super(STRING);

  T accept<T>(IRVisitor<T> v) => v.visitStringLit(this);
}

class Lambda extends Value {
  List<FormalParameter> parameters;
  Computation body;

  Datatype get type => null; // TODO.

  Lambda(this.parameters, this.body) : super(LAMBDA);

  T accept<T>(IRVisitor<T> v) {
    return v.visitLambda(this);
  }
}

class Record extends Value {
  Map<String, Value> members;

  Record(this.members) : super(RECORD);

  T accept<T>(IRVisitor<T> v) {
    return v.visitRecord(this);
  }
}

class Projection extends Value {
  String label;
  Value receiver;

  Projection(this.receiver, this.label) : super(PROJECT);

  T accept<T>(IRVisitor<T> v) => v.visitProjection(this);
}

class Variable extends Value {
  TypedBinder declarator;
  int get ident => declarator.ident;

  Variable(this.declarator) : super(VAR);

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

  Primitive(this.binder) : super(PRIMITIVE);
}

class PrimitiveFunction extends Primitive {
  int get arity => typeUtils.arity(type);
  PrimitiveFunction(TypedBinder binder) : super(binder);

  T accept<T>(IRVisitor<T> v) => v.visitPrimitiveFunction(this);
}

//===== Pretty printer.

class _PrettyPrinter implements IRVisitor<void> {
  final StringBuffer _buffer;
  String get result => _buffer.toString();
  _PrettyPrinter() : _buffer = StringBuffer();

  void put(String contents) => _buffer.write(contents);
  void lparen() => put("(");
  void rparen() => put(")");
  void lsquare() => put("[");
  void rsquare() => put("]");
  void space() => put(" ");
  void binder(TypedBinder binder) => put("${binder.uniqueName}");

  void bindings(List<Binding> bs) {
    lsquare();
    if (bs != null && bs.length > 0) {
      for (int i = 0; i < bs.length; i++) {
        bs[i].accept<void>(this);
        if (i + 1 < bs.length) space();
      }
    }
    rsquare();
  }

  // Modules.
  void visitModule(Module mod) {
    lparen();
    bindings(mod.bindings);
    rparen();
  }

  // Computations.
  void visitComputation(Computation comp) {
    lparen();
    bindings(comp.bindings);

    comp.tailComputation.accept<void>(this);
    rparen();
  }

  // Values.
  void visitApplyPure(ApplyPure apply) => visitApply(apply.apply);
  void visitBoolLit(BoolLit lit) => put("${lit.value}");
  void visitIntLit(IntLit lit) => put("${lit.value}");

  void visitLambda(Lambda lambda) {
    lparen();
    put("lambda");

    space();
    lparen();
    if (lambda.parameters != null && lambda.parameters.length > 0) {
      for (int i = 0; i < lambda.parameters.length; i++) {
        lambda.parameters[i].accept<void>(this);
        if (i + 1 < lambda.parameters.length) space();
      }
    }
    rparen();

    lambda.body.accept<void>(this);
    rparen();
  }

  void visitRecord(Record record) {
    lparen();
    put("record");

    if (record.members != null && record.members.length > 0) {
      record.members.forEach((String key, Value value) {
        space();
        lsquare();
        put(key);

        space();
        value.accept<void>(this);
        rsquare();
      });
    }
    rparen();
  }

  void visitPrimitiveFunction(PrimitiveFunction primitive) {
    put("${primitive.binder.sourceName}");
  }

  void visitProjection(Projection proj) {
    lparen();
    put("project");

    space();
    put("${proj.label}");

    space();
    proj.receiver.accept<void>(this);
    rparen();
  }

  void visitStringLit(StringLit lit) => put('"${lit.value}"');
  void visitVariable(Variable v) => binder(v.declarator);

  // Bindings.
  void visitDataConstructor(DataConstructor constr) =>
      throw "Not yet implemented.";
  void visitDatatype(DatatypeDescriptor desc) => throw "Not yet implemented.";
  void visitLetFun(LetFun f) {
    lparen();
    put("let-fun");

    space();
    lparen();
    binder(f.binder);

    if (f.parameters != null && f.parameters.length > 0) {
      for (int i = 0; i < f.parameters.length; i++) {
        space();
        f.parameters[i].accept<void>(this);
      }
    }
    rparen();
    space();

    f.body.accept<void>(this);

    rparen();
  }

  void visitLetVal(LetVal let) {
    lparen();
    put("let-val");

    space();
    binder(let.binder);
    space();

    let.tailComputation.accept<void>(this);

    rparen();
  }

  void visitFormal(FormalParameter formal) {
    binder(formal.binder);
  }

  // Tail computations.
  void visitIf(If ifthenelse) {
    lparen();
    put("if");

    space();
    ifthenelse.condition.accept<void>(this);

    space();
    ifthenelse.thenBranch.accept<void>(this);

    space();
    ifthenelse.elseBranch.accept<void>(this);
    rparen();
  }

  void visitApply(Apply apply) {
    lparen();
    apply.abstractor.accept<void>(this);
    if (apply.arguments != null && apply.arguments.length > 0) {
      for (int i = 0; i < apply.arguments.length; i++) {
        space();
        apply.arguments[i].accept<void>(this);
      }
    }
    rparen();
  }

  void visitReturn(Return ret) {
    lparen();
    put("return");
    space();
    ret.value.accept<void>(this);
    rparen();
  }

  // Specials.
  /* Empty (for now) */
}

// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.ast;

// TODO: specify domain-specific constructs such as define-transform, etc.
// Abstract syntax (algebraic specification in EBNF notation).
//
// Module
// M ::= (include ...)                         (* module inclusion *)
//     | : x T                                 (* signatures *)
//     | define x P* E                         (* value definitions *)
//     | define-typename NAME t* T             (* type aliases *)
//     | define-datatype NAME t* (NAME T*)*    (* algebraic data type definitions *)
//       (derive! (fold | map)+)?
//
// Constants
// C ::= #t | #f          (* boolean literals *)
//     | [0-9]+           (* integer literals *)
//     | ".*"             (* string literals *)
//
// Expressions
// E ::= C                (* constants *)
//     | x                (* variables *)
//     | f E*             (* n-ary application *)
//     | lambda P* E+     (* lambda function *)
//     | let (P E)+ E+    (* parallel binding *)
//     | let∗ (P E)+ E+   (* sequential binding *)
//     | , E*             (* n-ary tuples *)
//     | if E E_tt E_ff   (* conditional evaluation *)
//     | match E [P E+]*  (* pattern matching *)
//
// Top-level patterns
// P ::= P' : T           (* has type pattern *)
//     | Q                (* constructor patterns *)
//
// Regular patterns
// Q ::= x                (* variables *)
//     | K x*             (* constructor matching *)
//     | , x*             (* tuple matching *)
//     | [0-9]+           (* integer literal matching *)
//     | ".*"             (* string literal matching *)
//     | #t | #f          (* boolean literal matching *)
//     | _                (* wildcard *)
//
// Types
// T ::= Int | Bool | String (* base types *)
//    | forall id+ T         (* quantification *)
//    | -> T* T              (* n-ary function types *)
//    | K T*                 (* type application *)
//    | ∗ T*                 (* n-ary tuple types *)

import '../deriving.dart';
import '../location.dart';
import '../errors/errors.dart' show LocatedError;
import '../utils.dart' show ListUtils;

import 'binder.dart';
export 'binder.dart';

import 'datatype.dart';
export 'datatype.dart';

import 'identifiable.dart';
export 'identifiable.dart';

//===== Declaration.
abstract class Declaration implements Identifiable {
  Datatype get type;
  Binder get binder;
  bool get isVirtual;
  int get ident => binder.ident;
}

//===== Module / top-level language.
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

class Signature extends ModuleMember implements Declaration {
  Binder binder;
  Datatype type;
  List<Declaration> definitions;
  bool get isVirtual => false;
  int get ident => binder.ident;

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
  int get ident => binder.ident;

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
  int get ident => binder.ident;

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
  factory VirtualFunctionDeclaration(
      TopModule origin, String name, Datatype type) {
    Location location = Location.primitive();
    Binder binder = Binder.primitive(origin, name);
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
  int get ident => binder.ident;

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

// class Derivable {
//   final String name;
//   Derivable(this.name);

//   Datatype type(String name, List<Quantifier> parameters) {
//     return null;
//   }
// }

// class ClassDescriptor {
//   final Binder binder;
//   final List<VirtualFunctionDeclaration> members;

//   int get ident => binder.ident;

//   ClassDescriptor(this.binder, this.members);
// }

// class Derive {
//   ClassDescriptor classDescriptor;
//   DatatypeDescriptor descriptor;
//   Derivable template;

//   Derive(this.classDescriptor);

//   Datatype _buildType() {
//     Datatype type = template.type(descriptor.binder.sourceName, descriptor.parameters);
//     return type;
//   }
// }

class DatatypeDescriptor extends ModuleMember
    implements Declaration, TypeDescriptor {
  Binder binder;
  List<Quantifier> parameters;
  List<DataConstructor> constructors;
  Set<Derivable> deriving;

  bool get isVirtual => false;
  int get ident => binder.ident;

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
  String name;

  TopModule(this.members, this.name, Location location)
      : super(ModuleTag.TOP, location);

  T accept<T>(ModuleVisitor<T> v) {
    return v.visitTopModule(this);
  }

  String toString() {
    //String members0 = ListUtils.stringify(" ", members);
    return "(module ...)";
  }

  bool get isVirtual => false;
}

class VirtualModule extends TopModule {
  VirtualModule(String name)
      : super(<ModuleMember>[], name, Location.primitive());
  bool get isVirtual => true;

  String toString() => "(virtual-module ...)";
}

class TypeAliasDescriptor extends ModuleMember
    implements Declaration, TypeDescriptor {
  Binder binder;
  List<Quantifier> parameters;
  Datatype rhs;

  bool get isVirtual => false;
  int get ident => binder.ident;

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

//===== Expression language.
abstract class ExpressionVisitor<T> {
  // Literals.
  T visitBool(BoolLit boolean);
  T visitInt(IntLit integer);
  T visitString(StringLit string);

  // Expressions.
  T visitApply(Apply apply);
  T visitIf(If ifthenelse);
  T visitLambda(Lambda lambda);
  T visitLet(Let binding);
  T visitMatch(Match match);
  // T visitProjection(Projection p);
  T visitTuple(Tuple tuple);
  T visitVariable(Variable v);
  T visitTypeAscription(TypeAscription ascription);

  T visitError(ErrorExpression e);
}

abstract class Expression {
  final ExpTag tag;
  Datatype type;
  Location location;

  Expression(this.tag, this.location);

  T accept<T>(ExpressionVisitor<T> v);
}

enum ExpTag {
  BOOL,
  ERROR,
  INT,
  STRING,
  APPLY,
  IF,
  LAMBDA,
  LET,
  MATCH,
  TUPLE,
  VAR,
  TYPE_ASCRIPTION
}

/** Constants. **/
abstract class Constant<T> extends Expression {
  T value;
  Constant(this.value, ExpTag tag, Location location) : super(tag, location);

  String toString() {
    return "$value";
  }
}

class BoolLit extends Constant<bool> {
  BoolLit(bool value, Location location) : super(value, ExpTag.BOOL, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitBool(this);
  }

  static const String T_LITERAL = "#t";
  static const String F_LITERAL = "#f";

  String toString() {
    if (value)
      return T_LITERAL;
    else
      return F_LITERAL;
  }
}

class IntLit extends Constant<int> {
  IntLit(int value, Location location) : super(value, ExpTag.INT, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitInt(this);
  }
}

class StringLit extends Constant<String> {
  StringLit(String value, Location location)
      : super(value, ExpTag.STRING, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitString(this);
  }

  String toString() {
    return "\"$value\"";
  }
}

class Apply extends Expression {
  Expression abstractor;
  List<Expression> arguments;

  Apply(this.abstractor, this.arguments, Location location)
      : super(ExpTag.APPLY, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitApply(this);
  }

  String toString() {
    if (arguments.length == 0) {
      return "($abstractor)";
    } else {
      String arguments0 = ListUtils.stringify(" ", arguments);
      return "($abstractor $arguments0)";
    }
  }
}

class Variable extends Expression {
  Declaration declarator;

  int get ident => declarator.binder.ident;

  Variable(this.declarator, Location location) : super(ExpTag.VAR, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitVariable(this);
  }

  String toString() {
    return "${declarator.binder}";
  }
}

class If extends Expression {
  Expression condition;
  Expression thenBranch;
  Expression elseBranch;

  If(this.condition, this.thenBranch, this.elseBranch, Location location)
      : super(ExpTag.IF, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitIf(this);
  }
}

class Binding {
  Pattern pattern;
  Expression expression;

  Binding(this.pattern, this.expression);

  String toString() {
    return "($pattern ...)";
  }
}

class Let extends Expression {
  List<Binding> valueBindings;
  Expression body;

  Let(this.valueBindings, this.body, Location location)
      : super(ExpTag.LET, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitLet(this);
  }

  String toString() {
    String valueBindings0 = ListUtils.stringify(" ", valueBindings);
    return "(let ($valueBindings0) $body)";
  }
}

class Lambda extends Expression {
  List<Pattern> parameters;
  Expression body;

  int get arity => parameters.length;

  Lambda(this.parameters, this.body, Location location)
      : super(ExpTag.LAMBDA, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitLambda(this);
  }

  String toString() {
    String parameters0 = ListUtils.stringify(" ", parameters);
    return "(lambda ($parameters0) (...))";
  }
}

class Case {
  Pattern pattern;
  Expression expression;

  Case(this.pattern, this.expression);

  String toString() {
    return "[$pattern $expression]";
  }
}

class Match extends Expression {
  Expression scrutinee;
  List<Case> cases;

  Match(this.scrutinee, this.cases, Location location)
      : super(ExpTag.MATCH, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitMatch(this);
  }

  String toString() {
    String cases0 = ListUtils.stringify(" ", cases);
    return "(match $scrutinee $cases0)";
  }
}

class Tuple extends Expression {
  List<Expression> components;

  Tuple(this.components, Location location) : super(ExpTag.TUPLE, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitTuple(this);
  }

  bool get isUnit => components.length == 0;

  String toString() {
    if (isUnit) {
      return "(,)";
    } else {
      String components0 = ListUtils.stringify(" ", components);
      return "(, $components0)";
    }
  }
}

class TypeAscription extends Expression {
  Expression exp;

  TypeAscription._(this.exp, Location location)
      : super(ExpTag.TYPE_ASCRIPTION, location);

  factory TypeAscription(Expression exp, Datatype type, Location location) {
    TypeAscription typeAs = new TypeAscription._(exp, location);
    typeAs.type = type;
    return typeAs;
  }

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitTypeAscription(this);
  }
}

class ErrorExpression extends Expression {
  final LocatedError error;

  ErrorExpression(this.error, Location location)
      : super(ExpTag.ERROR, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitError(this);
  }
}

//===== Pattern language.
abstract class PatternVisitor<T> {
  T visitBool(BoolPattern b);
  T visitConstructor(ConstructorPattern constr);
  T visitError(ErrorPattern e);
  T visitHasType(HasTypePattern t);
  T visitInt(IntPattern i);
  T visitString(StringPattern s);
  T visitTuple(TuplePattern t);
  T visitVariable(VariablePattern v);
  T visitWildcard(WildcardPattern w);
}

abstract class Pattern {
  Datatype type;
  Location location;
  final PatternTag tag;
  Pattern(this.tag, this.location);

  T accept<T>(PatternVisitor<T> v);
}

enum PatternTag {
  BOOL,
  CONSTR,
  ERROR,
  HAS_TYPE,
  INT,
  STRING,
  TUPLE,
  VAR,
  WILDCARD
}

abstract class BaseValuePattern extends Pattern {
  BaseValuePattern(PatternTag tag, Location location) : super(tag, location);
}

class BoolPattern extends BaseValuePattern {
  final bool value;

  BoolPattern(this.value, Location location) : super(PatternTag.BOOL, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitBool(this);
  }

  String toString() {
    return "$value";
  }
}

class ConstructorPattern extends Pattern {
  DataConstructor declarator;
  List<Pattern> components;
  Datatype get type => declarator.type;
  int get arity => components == null ? 0 : components.length;

  ConstructorPattern(this.declarator, this.components, Location location)
      : super(PatternTag.CONSTR, location);
  ConstructorPattern.nullary(DataConstructor declarator, Location location)
      : this(declarator, const <VariablePattern>[], location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitConstructor(this);
  }

  String toString() {
    String subpatterns = ListUtils.stringify(" ", components);
    return "[${declarator.binder.sourceName} $subpatterns]";
  }
}

class ErrorPattern extends Pattern {
  final LocatedError error;
  ErrorPattern(this.error, Location location)
      : super(PatternTag.ERROR, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitError(this);
  }
}

class HasTypePattern extends Pattern {
  Pattern pattern;
  Datatype type;

  HasTypePattern(this.pattern, this.type, Location location)
      : super(PatternTag.HAS_TYPE, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitHasType(this);
  }

  String toString() {
    return "[$pattern : $type]";
  }
}

class IntPattern extends BaseValuePattern {
  final int value;

  IntPattern(this.value, Location location) : super(PatternTag.INT, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitInt(this);
  }

  String toString() {
    return "$value";
  }
}

class StringPattern extends BaseValuePattern {
  final String value;

  StringPattern(this.value, Location location)
      : super(PatternTag.STRING, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitString(this);
  }

  String toString() {
    return "$value";
  }
}

class TuplePattern extends Pattern {
  List<Pattern> components;

  TuplePattern(this.components, Location location)
      : super(PatternTag.TUPLE, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitTuple(this);
  }

  String toString() {
    if (components.length == 0) {
      return "(*)";
    } else {
      return "(* $components)";
    }
  }
}

class VariablePattern extends Pattern implements Declaration {
  Binder binder;
  bool get isVirtual => false;

  int get ident => binder.ident;

  VariablePattern(this.binder, Location location)
      : super(PatternTag.VAR, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitVariable(this);
  }

  String toString() {
    return "${binder}";
  }
}

class WildcardPattern extends Pattern {
  WildcardPattern(Location location) : super(PatternTag.WILDCARD, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitWildcard(this);
  }

  String toString() {
    return "_";
  }
}

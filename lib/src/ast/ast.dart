// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.ast;

import 'dart:collection' show Map;

import 'package:kernel/ast.dart'
    show Member, Procedure, TreeNode, VariableDeclaration;

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

import '../deriving.dart' show Derivable;
import '../location.dart' show Location;
import '../errors/errors.dart' show LocatedError;
import '../utils.dart' show ListUtils;

import 'binder.dart';
export 'binder.dart';

import 'datatype.dart';
export 'datatype.dart';

import 'identifiable.dart';
export 'identifiable.dart';

//===== Common super node.
abstract class T20Node {
  T20Node _parent;
  T20Node get parent => _parent;
  void set parent(T20Node node) => _parent = node;

  TopModule get origin => this is TopModule ? this : parent?.origin;
}

void _setParent(T20Node node, T20Node parent) => node?.parent = parent;
void _setParentMany(List<T20Node> nodes, T20Node parent) {
  if (nodes == null) return;

  for (int i = 0; i < nodes.length; i++) {
    nodes[i].parent = parent;
  }
}

//===== Declaration.
abstract class Declaration implements Identifiable {
  Datatype get type;
  Binder get binder;
  void set binder(Binder _);
  bool get isVirtual;
  int get ident;

  List<Variable> get uses;
  void use(Variable reference);
}

abstract class DeclarationMixin implements Declaration {
  Datatype get type;
  int get ident => binder.ident;

  List<Variable> _uses;
  List<Variable> get uses {
    _uses ??= new List<Variable>();
    return _uses;
  }

  void use(Variable reference) {
    _uses ??= new List<Variable>();
    uses.add(reference);
  }

  void mergeUses(List<Variable> references) {
    if (_uses == null) {
      _uses = references;
    } else {
      uses.addAll(references);
    }
  }
}

//===== Module / top-level language.
abstract class ModuleVisitor<T> {
  T visitDataConstructor(DataConstructor constr);
  T visitDatatype(DatatypeDescriptor decl);
  T visitDatatypes(DatatypeDeclarations decls);
  T visitError(ErrorModule err);
  T visitFunction(FunctionDeclaration decl);
  T visitLetFunction(LetFunction fun);
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

abstract class ModuleMember extends T20Node {
  final ModuleTag tag;
  Location location;

  ModuleMember(this.tag, this.location);

  T accept<T>(ModuleVisitor<T> v);
}

class Signature extends ModuleMember
    with DeclarationMixin
    implements Declaration {
  Binder binder;
  Datatype type;

  List<Declaration> definitions;
  bool get isVirtual => false;
  int get ident => binder.ident;

  Signature(Binder binder, this.type, Location location)
      : this.binder = binder,
        definitions = new List<Declaration>(),
        super(ModuleTag.SIGNATURE, location) {
    binder.bindingOccurrence = this;
  }

  void addDefinition(Declaration decl) {
    definitions.add(decl);
  }

  T accept<T>(ModuleVisitor<T> v) => v.visitSignature(this);
}

class ValueDeclaration extends ModuleMember
    with DeclarationMixin
implements Declaration, KernelNode {
  Binder binder;
  Signature signature;
  Expression body;

  bool get isVirtual => false;
  Datatype get type => signature.type;
  int get ident => binder.ident;

  ValueDeclaration(
      this.signature, Binder binder, Expression body, Location location)
      : this.binder = binder,
        this.body = body,
        super(ModuleTag.VALUE_DEF, location) {
    binder.bindingOccurrence = this;
    _setParent(body, this);
  }
  T accept<T>(ModuleVisitor<T> v) => v.visitValue(this);

  String toString() {
    return "(define $binder (...)))";
  }

  Member asKernelNode;
}

class VirtualValueDeclaration extends ValueDeclaration {
  bool get isVirtual => true;

  VirtualValueDeclaration.stub(Signature signature, Binder binder)
      : super(signature, binder, null, signature.location);
  factory VirtualValueDeclaration(
      TopModule origin, String name, Datatype type) {
    Location location = Location.primitive();
    Binder binder = Binder.primitive(origin, name);
    Signature signature = new Signature(binder, type, location);
    VirtualValueDeclaration valDecl =
        new VirtualValueDeclaration.stub(signature, binder);
    signature.addDefinition(valDecl);
    return valDecl;
  }

  String toString() => "(define-stub $binder)";
}

abstract class AbstractFunctionDeclaration<Param extends T20Node,
        Body extends T20Node> extends ModuleMember
    with DeclarationMixin
    implements Declaration {
  Binder binder;
  Signature signature;
  List<Param> parameters;
  Body body;

  bool get isVirtual => false;
  Datatype get type => signature.type;
  int get ident => binder.ident;

  AbstractFunctionDeclaration(this.signature, Binder binder,
      List<Param> parameters, Body body, Location location)
      : this.binder = binder,
        this.body = body,
        this.parameters = parameters,
        super(ModuleTag.FUNC_DEF, location) {
    binder.bindingOccurrence = this;
    _setParent(body, this);
    _setParentMany(parameters, this);
  }

  String toString() {
    String parameters0 = ListUtils.stringify(" ", parameters);
    return "(define ($binder $parameters0) (...))";
  }
}

class FunctionDeclaration
    extends AbstractFunctionDeclaration<Pattern, Expression> {
  FunctionDeclaration(Signature signature, Binder binder,
      List<Pattern> parameters, Expression body, Location location)
      : super(signature, binder, parameters, body, location);

  T accept<T>(ModuleVisitor<T> v) => v.visitFunction(this);
}

class VirtualFunctionDeclaration extends FunctionDeclaration {
  bool get isVirtual => true;

  VirtualFunctionDeclaration.stub(Signature signature, Binder binder)
      : super(signature, binder, null, null, signature.location);
  factory VirtualFunctionDeclaration(
      TopModule origin, String name, Datatype type) {
    Location location = Location.primitive();
    Binder binder = Binder.primitive(origin, name);
    Signature signature = new Signature(binder, type, location);
    VirtualFunctionDeclaration funDecl =
        new VirtualFunctionDeclaration.stub(signature, binder);
    signature.addDefinition(funDecl);
    return funDecl;
  }

  String toString() {
    String parameters0 = ListUtils.stringify(" ", parameters);
    return "(define-stub ($binder $parameters0))";
  }
}

class DataConstructor extends ModuleMember
    with DeclarationMixin
    implements Declaration {
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

  DataConstructor(Binder binder, this.parameters, Location location)
      : this.binder = binder,
        super(ModuleTag.CONSTR, location) {
    binder.bindingOccurrence = this;
  }

  T accept<T>(ModuleVisitor<T> v) => v.visitDataConstructor(this);
}

class DatatypeDescriptor extends ModuleMember
    with DeclarationMixin
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

  DatatypeDescriptor(Binder binder, this.parameters,
      List<DataConstructor> constructors, this.deriving, Location location)
      : this.binder = binder,
        this.constructors = constructors,
        super(ModuleTag.DATATYPE_DEF, location) {
    binder.bindingOccurrence = this;
    _setParentMany(constructors, this);
  }
  DatatypeDescriptor.partial(
      Binder binder, List<Quantifier> parameters, Location location)
      : this(binder, parameters, null, null, location);

  T accept<T>(ModuleVisitor<T> v) => v.visitDatatype(this);

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

  DatatypeDeclarations(List<DatatypeDescriptor> declarations, Location location)
      : this.declarations = declarations,
        super(ModuleTag.DATATYPE_DEFS, location) {
    _setParentMany(declarations, this);
  }

  T accept<T>(ModuleVisitor<T> v) => v.visitDatatypes(this);

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

class Summary {
  final TopModule module;
  Map<int, Declaration> _valueBindings;
  Map<int, TypeDescriptor> _typeDescriptors;

  Summary(this.module);

  Map<int, Declaration> get valueBindings {
    if (_valueBindings == null) compute();
    return _valueBindings;
  }

  Map<int, TypeDescriptor> get typeDescriptors {
    if (_typeDescriptors == null) compute();
    return _typeDescriptors;
  }

  void compute() {
    _valueBindings = new Map<int, Declaration>();
    _typeDescriptors = new Map<int, TypeDescriptor>();
    for (int i = 0; i < module.members.length; i++) {
      ModuleMember member = module.members[i];
      switch (member.tag) {
        case ModuleTag.DATATYPE_DEFS:
          DatatypeDeclarations datatypes = member as DatatypeDeclarations;
          for (int j = 0; j < datatypes.declarations.length; j++) {
            TypeDescriptor descriptor = datatypes.declarations[j];
            _typeDescriptors[descriptor.binder.intern] = descriptor;
          }
          break;
        case ModuleTag.TYPENAME:
          TypeDescriptor descriptor = member as TypeDescriptor;
          _typeDescriptors[descriptor.binder.intern] = descriptor;
          break;
        case ModuleTag.CONSTR:
        case ModuleTag.FUNC_DEF:
        case ModuleTag.VALUE_DEF:
          Declaration decl = member as Declaration;
          _valueBindings[decl.binder.intern] = decl;
          break;
        default:
        // Ignored.
      }
    }
  }
}

class Manifest {
  final TopModule module;

  Map<String, Declaration> _index;

  Manifest(this.module);

  Declaration findByName(String name) {
    if (_index == null) compute();
    return _index[name];
  }

  void compute() => _index = Map.fromIterable(
      module.members.where((ModuleMember member) => member is Declaration),
      key: (dynamic decl) => (decl as Declaration).binder.sourceName,
      value: (dynamic decl) => decl as Declaration);

  Summary get summary => Summary(module);
}

class TopModule extends ModuleMember {
  Manifest manifest;
  List<ModuleMember> members;
  String name;

  TopModule(List<ModuleMember> members, this.name, Location location)
      : this.members = members,
        super(ModuleTag.TOP, location) {
    _setParentMany(members, this);
    manifest = Manifest(this);
  }

  Declaration main;
  bool get hasMain => main != null;

  T accept<T>(ModuleVisitor<T> v) => v.visitTopModule(this);

  String toString() {
    //String members0 = ListUtils.stringify(" ", members);
    return "(module $name ...)";
  }

  bool get isVirtual => false;
}

class VirtualModule extends TopModule {
  VirtualModule(String name, {List<ModuleMember> members, Location location})
      : super(members == null ? new List<ModuleMember>() : members, name,
            location == null ? Location.primitive() : location);
  bool get isVirtual => true;

  String toString() => "(virtual-module $name ...)";
}

class TypeAliasDescriptor extends ModuleMember
    with DeclarationMixin
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

  TypeAliasDescriptor(
      Binder binder, this.parameters, this.rhs, Location location)
      : this.binder = binder,
        super(ModuleTag.TYPENAME, location) {
    binder.bindingOccurrence = this;
  }

  T accept<T>(ModuleVisitor<T> v) => v.visitTypename(this);
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
  T visitTuple(Tuple tuple);
  T visitVariable(Variable v);
  T visitTypeAscription(TypeAscription ascription);

  T visitError(ErrorExpression e);

  // Desugared nodes.
  // T visitSetVariable(SetVariable v);
  T visitDLambda(DLambda lambda);
  T visitDLet(DLet let);
  T visitProject(Project project);
  // T visitBlock(Block block);
}

abstract class Expression extends T20Node {
  final ExpTag tag;
  Datatype type;
  Location location;

  Expression(this.tag, [Location location])
      : this.location = location == null ? Location.dummy() : location;

  T accept<T>(ExpressionVisitor<T> v);

  bool isPure = false;
}

enum ExpTag {
  // BLOCK,
  BOOL,
  ERROR,
  // GET,
  INT,
  STRING,
  APPLY,
  IF,
  LAMBDA,
  LET,
  MATCH,
  PROJECT,
  // SET,
  TUPLE,
  VAR,
  TYPE_ASCRIPTION
}

/** Constants. **/
abstract class Constant<T> extends Expression {
  T value;
  Constant(this.value, ExpTag tag, [Location location]) : super(tag, location);

  String toString() {
    return "$value";
  }

  bool isPure = true;
}

class BoolLit extends Constant<bool> {
  BoolLit(bool value, [Location location])
      : super(value, ExpTag.BOOL, location);

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
  IntLit(int value, [Location location]) : super(value, ExpTag.INT, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitInt(this);
  }
}

class StringLit extends Constant<String> {
  StringLit(String value, [Location location])
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

  Apply(Expression abstractor, List<Expression> arguments, [Location location])
      : this.abstractor = abstractor,
        this.arguments = arguments,
        super(ExpTag.APPLY, location) {
    _setParent(abstractor, this);
    _setParentMany(arguments, this);
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitApply(this);

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
  Binder binder;
  Declaration get declarator => binder.bindingOccurrence;

  int get ident => declarator.ident;

  Variable(this.binder, [Location location]) : super(ExpTag.VAR, location);

  T accept<T>(ExpressionVisitor<T> v) => v.visitVariable(this);

  String toString() => "${declarator.binder}";

  bool isPure = true;
}

class If extends Expression {
  Expression condition;
  Expression thenBranch;
  Expression elseBranch;

  If(Expression condition, Expression thenBranch, Expression elseBranch,
      [Location location])
      : this.condition = condition,
        this.thenBranch = thenBranch,
        this.elseBranch = elseBranch,
        super(ExpTag.IF, location) {
    _setParent(condition, this);
    _setParent(thenBranch, this);
    _setParent(elseBranch, this);
  }

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitIf(this);
  }

  String toString() => "(if $condition (...) (...))";
}

class Binding extends T20Node {
  Pattern pattern;
  Expression expression;

  Binding(Pattern pattern, Expression expression)
      : this.pattern = pattern,
        this.expression = expression {
    _setParent(pattern, this);
    _setParent(expression, this);
  }

  String toString() {
    return "($pattern ...)";
  }
}

class Let extends Expression {
  List<Binding> valueBindings;
  Expression body;

  Let(List<Binding> valueBindings, Expression body, Location location)
      : this.valueBindings = valueBindings,
        this.body = body,
        super(ExpTag.LET, location) {
    _setParentMany(valueBindings, this);
    _setParent(body, this);
  }

  String toString() {
    String valueBindings0 = ListUtils.stringify(" ", valueBindings);
    return "(let ($valueBindings0) $body)";
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitLet(this);
}

abstract class LambdaAbstraction<Param extends T20Node, Body extends T20Node>
    extends Expression {
  List<Param> parameters;
  Body body;

  int get arity => parameters.length;

  LambdaAbstraction(List<Param> parameters, Body body, Location location)
      : this.body = body,
        this.parameters = parameters,
        super(ExpTag.LAMBDA, location) {
    _setParentMany(parameters, this);
    _setParent(body, this);
  }

  String toString() {
    String parameters0 = ListUtils.stringify(" ", parameters);
    return "(lambda ($parameters0) (...))";
  }
}

class Lambda extends LambdaAbstraction<Pattern, Expression> {
  Lambda(List<Pattern> parameters, Expression body, Location location)
      : super(parameters, body, location);

  T accept<T>(ExpressionVisitor<T> v) {
    return v.visitLambda(this);
  }
}

class Case extends T20Node {
  Pattern pattern;
  Expression expression;

  Case(Pattern pattern, Expression expression)
      : this.pattern = pattern,
        this.expression = expression {
    _setParent(pattern, this);
    _setParent(expression, this);
  }

  Match get enclosingMatch => parent as Match;

  String toString() {
    return "[$pattern $expression]";
  }
}

class Match extends Expression {
  Expression scrutinee;
  List<Case> cases;

  Match(Expression scrutinee, List<Case> cases, Location location)
      : this.scrutinee = scrutinee,
        this.cases = cases,
        super(ExpTag.MATCH, location) {
    _setParent(scrutinee, this);
    _setParentMany(cases, this);
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitMatch(this);

  String toString() {
    String cases0 = ListUtils.stringify(" ", cases);
    return "(match $scrutinee $cases0)";
  }
}

class Tuple extends Expression {
  List<Expression> components;

  Tuple(List<Expression> components, Location location)
      : this.components = components,
        super(ExpTag.TUPLE, location) {
    _setParentMany(components, this);
  }

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

  TypeAscription(Expression exp, Datatype type, Location location)
      : this.exp = exp,
        super(ExpTag.TYPE_ASCRIPTION, location) {
    _setParent(exp, this);
    this.type = type;
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitTypeAscription(this);
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

abstract class Pattern extends T20Node {
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

abstract class BaseValuePattern<T> extends Pattern {
  T get value;
  BaseValuePattern(PatternTag tag, Location location) : super(tag, location);
}

class BoolPattern extends BaseValuePattern<bool> {
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
  Datatype get type => declarator.type; // TODO: this is not correct...
  int get arity => components == null ? 0 : components.length;

  ConstructorPattern(
      this.declarator, List<Pattern> components, Location location)
      : this.components = components,
        super(PatternTag.CONSTR, location) {
    _setParentMany(components, this);
  }
  ConstructorPattern.nullary(DataConstructor declarator, Location location)
      : this(declarator, const <VariablePattern>[], location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitConstructor(this);
  }

  String toString() {
    if (arity == 0) {
      return "[${declarator.binder.sourceName}]";
    } else {
      String subpatterns = ListUtils.stringify(" ", components);
      return "[${declarator.binder.sourceName} $subpatterns]";
    }
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

  HasTypePattern(Pattern pattern, this.type, Location location)
      : this.pattern = pattern,
        super(PatternTag.HAS_TYPE, location) {
    _setParent(pattern, this);
  }

  T accept<T>(PatternVisitor<T> v) {
    return v.visitHasType(this);
  }

  String toString() {
    return "[$pattern : $type]";
  }
}

class IntPattern extends BaseValuePattern<int> {
  final int value;

  IntPattern(this.value, Location location) : super(PatternTag.INT, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitInt(this);
  }

  String toString() {
    return "$value";
  }
}

class StringPattern extends BaseValuePattern<String> {
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

  TuplePattern(List<Pattern> components, Location location)
      : this.components = components,
        super(PatternTag.TUPLE, location) {
    _setParentMany(components, this);
  }

  T accept<T>(PatternVisitor<T> v) {
    return v.visitTuple(this);
  }

  String toString() {
    if (components.length == 0) {
      return "(,)";
    } else {
      String components0 = ListUtils.stringify(" ", components);
      return "(, $components0)";
    }
  }
}

class VariablePattern extends Pattern
    with DeclarationMixin
    implements Declaration {
  Binder binder;
  bool get isVirtual => false;

  int get ident => binder.ident;

  VariablePattern(Binder binder, Location location)
      : this.binder = binder,
        super(PatternTag.VAR, location) {
    binder.bindingOccurrence = this;
  }

  T accept<T>(PatternVisitor<T> v) {
    return v.visitVariable(this);
  }

  String toString() {
    return "${binder}";
  }
}

class WildcardPattern extends Pattern {
  WildcardPattern(Location location) : super(PatternTag.WILDCARD, location);

  T accept<T>(PatternVisitor<T> v) => v.visitWildcard(this);

  String toString() {
    return "_";
  }
}

//===== Desugared AST nodes.
abstract class KernelNode {
  TreeNode get asKernelNode;
}

class FormalParameter extends T20Node
    with DeclarationMixin
    implements Declaration, KernelNode {
  Binder binder;
  int get ident => binder.ident;
  Datatype get type => binder.type;
  bool get isVirtual => false;

  FormalParameter(Binder binder) {
    this.binder = binder;
    binder.bindingOccurrence = this;
  }

  VariableDeclaration asKernelNode;
}

class DLambda extends LambdaAbstraction<FormalParameter, Expression> {
  DLambda(List<FormalParameter> parameters, Expression body,
      [Location location])
      : super(parameters, body, location) {
    // Set parent pointers.
    body.parent = this;
    _setParentMany(parameters, this);
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitDLambda(this);
}

// class SimpleBinding extends T20Node
//     with DeclarationMixin
//     implements Declaration {
//   Binder binder;

//   int get ident => binder.ident;
//   Datatype get type => binder.type;
//   bool get isVirtual => false;

//   Expression expression;

//   SimpleBinding(Binder binder, Expression expression)
//       : this.binder = binder,
//         this.expression = expression {
//     binder.bindingOccurrence = this;
//     _setParent(expression, this);
//   }

//   String toString() => "[$binder $expression]";
// }

class DLet extends Expression with DeclarationMixin implements Declaration {
  Binder binder;
  Expression body;
  Expression continuation;

  bool get isVirtual => false;

  DLet(Binder binder, Expression body, Expression continuation,
      [Location location])
      : this.binder = binder,
        this.body = body,
        this.continuation = continuation,
        super(ExpTag.LET, location) {
    binder.bindingOccurrence = this;
    _setParent(body, this);
    _setParent(continuation, this);
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitDLet(this);
}

class LetFunction
    extends AbstractFunctionDeclaration<FormalParameter, Expression>
    implements KernelNode {
  Procedure asKernelNode;

  LetFunction(Signature signature, Binder binder,
      List<FormalParameter> parameters, Expression body, Location location)
      : super(signature, binder, parameters, body, location) {
    binder.bindingOccurrence = this;
    _setParent(body, this);
    _setParentMany(parameters, this);
  }

  T accept<T>(ModuleVisitor<T> v) => v.visitLetFunction(this);
}

class LetVirtualFunction extends LetFunction {
  bool get isVirtual => true;

  LetVirtualFunction(Signature signature, Binder binder, Location location)
      : super(signature, binder, null, null, location);
}

// abstract class LetValue extends ModuleMember
//     implements Declaration, KernelNode {
//   LetValue() : super(null, null);
// }

// class Register extends T20Node
//     with DeclarationMixin
//     implements Declaration, KernelNode {
//   Binder binder;

//   bool get isVirtual => false;
//   int get ident => binder.ident;
//   Datatype get type => const DynamicType(); // TODO.

//   Expression initialiser; // May be null.

//   Register(Binder binder, [Expression initialiser])
//       : this.binder = binder,
//         this.initialiser = initialiser {
//     binder.bindingOccurrence = this;
//   }

//   VariableDeclaration get asKernelNode => null;

//   Block _residence;
//   Block get residence => _residence;
//   void set residence(Block block) => _residence = block;

//   String toString() => "(var $binder)";

//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other != null && other is Register && hashCode == other.hashCode;

//   int get hashCode {
//     int hash = super.hashCode;
//     hash = hash * 13 + binder.hashCode;
//     hash = initialiser == null ? hash : hash * 17 + initialiser.hashCode;
//   }
// }

// class SetVariable extends Expression {
//   Variable variable;
//   Expression expression;

//   SetVariable(Variable variable, Expression expression)
//       : this.variable = variable,
//         this.expression = expression,
//         super(ExpTag.SET) {
//     _setParent(variable, this);
//     _setParent(expression, this);
//   }

//   T accept<T>(ExpressionVisitor<T> v) => v.visitSetVariable(this);

//   String toString() => "(set! $variable $expression)";
// }

// abstract class GetRegister extends Expression {
//   Register variable;

//   GetRegister(this.variable) : super(ExpTag.GET);

//   T accept<T>(ExpressionVisitor<T> v) => v.visitGetVariable(this);

//   String toString() => "(get! ${variable.binder})";
// }

// abstract class ScratchSpace extends T20Node {
//   // Local heap.
//   List<Register> _memory;
//   List<Register> get memory => _memory;
//   void set memory(List<Register> decls) {
//     _setParentMany(decls, this);
//     _memory = decls;
//   }

//   void allocate(Register variable) {
//     _setParent(variable, this);
//     _memory ??= new List<Register>();
//     memory.add(variable);
//   }

//   // The [preamble] contains side-effecting expressions, those expressions may
//   // contain references to the block-local heap.
//   List<Expression> _preamble;
//   List<Expression> get preamble => _preamble;
//   void set preamble(List<Expression> expressions) {
//     _setParentMany(expressions, this);
//     _preamble = expressions;
//   }

//   void addStatement(Expression expression) {
//     _setParent(expression, this);
//     _preamble ??= new List<Expression>();
//     _preamble.add(expression);
//   }

//   bool get isGlobal;
//   bool get isLocal => !isGlobal;

//   ScratchSpace();
// }

// Module-global heap-space.
// class GlobalSpace extends ScratchSpace {
//   GlobalSpace() : super();

//   String toString() {
//     String heap0 = ListUtils.stringify(" ", memory);
//     String preamble0 = ListUtils.stringify(" ", preamble);
//     return "(global-space [$heap0] [$preamble0])";
//   }

//   bool get isGlobal => true;
// }

// class Block extends Expression {
//   // Track usage of mutable variables (indicatively named "registers"). A
//   // subsequent optimisation pass can use this information to minimise the
//   // number of live stack variables.
//   List<Register> _registers;
//   List<Register> get registers => _registers;
//   void set registers(List<Register> decls) {
//     if (_registers != null) {
//       _setResidenceMany(_registers, null);
//     }
//     _setResidenceMany(decls, this);
//     _registers = decls;
//   }

//   Register allocate(Binder binder) {
//     Register register = Register(binder);
//     _setResidence(register, this);
//     _registers ??= new List<Register>();
//     registers.add(register);
//     return register;
//   }

//   void allocateMany(List<Register> variables) {
//     _setResidenceMany(variables, this);
//     if (_registers == null) {
//       _registers ??= new List<Register>();
//     } else {
//       registers.addAll(variables);
//     }
//   }

//   void _setResidence(Register variable, Block block) {
//     variable.residence = block;
//   }

//   void _setResidenceMany(List<Register> variables, Block block) {
//     if (variables == null) return;
//     for (int i = 0; i < variables.length; i++) {
//       variables[i].residence = block;
//     }
//   }

//   // The [preamble] contains side-effecting expressions, those expressions may
//   // reference registers.
//   List<Expression> _preamble;
//   List<Expression> get preamble => _preamble;
//   void set preamble(List<Expression> expressions) {
//     _setParentMany(expressions, this);
//     _preamble = expressions;
//   }

//   void addStatement(Expression expression) {
//     _setParent(expression, this);
//     _preamble ??= new List<Expression>();
//     _preamble.add(expression);
//   }

//   // The [expression] may not contain any unguarded blocks. A block is guarded
//   // if and only if it is the body of a function definition or lambda expression.
//   Expression _expression;
//   Expression get expression => _expression;
//   void set expression(Expression exp) {
//     _setParent(exp, this);
//     _expression = exp;
//   }

//   bool get isGuarded =>
//       parent != null && (parent is DLambda || parent is LetFunction);

//   // void merge(Block other) {
//   //   assert(other != null);
//   //   if (other.registers != null) {
//   //     if (registers == null) {
//   //       registers = other.registers;
//   //     } else {
//   //       _setResidenceMany(other.registers, this);
//   //       registers.addAll(other.registers);
//   //     }
//   //     other.registers = null;
//   //   }

//   //   if (other.preamble != null) {
//   //     if (preamble == null) {
//   //       preamble = other.preamble;
//   //     } else {
//   //       _setParentMany(other.preamble, this);
//   //       preamble.addAll(other.preamble);
//   //     }
//   //     other.preamble = null;
//   //   }

//   //   if (other.expression != null) {
//   //     addStatement(other.expression);
//   //   }
//   // }

//   Block([Expression expression, Location location])
//       : super(ExpTag.BLOCK, location) {
//     this.expression = expression;
//   }

//   Block.empty([Location location]) : this(null, location);

//   T accept<T>(ExpressionVisitor<T> v) => v.visitBlock(this);

//   String toString() => "(block [...] [...] $expression)";
// }

class Project extends Expression {
  Expression receiver;
  int label; // Should be generalised whenever I get around to implement support
  // for records.

  Project(Expression receiver, this.label)
      : this.receiver = receiver,
        super(ExpTag.PROJECT) {
    _setParent(receiver, this);
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitProject(this);

  String toString() => "(\$$label $receiver)";
}

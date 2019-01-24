// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.ast;

import 'package:kernel/ast.dart'
    show Class, Field, Member, Procedure, TreeNode, VariableDeclaration;

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
import '../typing/type_utils.dart' as typeUtils;
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

  TopModule get origin => parent?.origin;
}

void _setParent(T20Node node, T20Node parent) => node?.parent = parent;
void _setParentMany(List<T20Node> nodes, T20Node parent) {
  if (nodes == null) return;

  for (int i = 0; i < nodes.length; i++) {
    nodes[i].parent = parent;
  }
}

void _setBindingOccurrence(Binder binder, Declaration decl) =>
    binder.bindingOccurrence = decl;
void _setBindingOccurrenceMany(List<Binder> binders, Declaration decl) {
  if (binders == null) return;

  for (int i = 0; i < binders.length; i++) {
    binders[i].bindingOccurrence = decl;
  }
}

//===== Declaration.
abstract class Declaration implements Identifiable {
  Datatype get type;
  Binder get binder;
  void set binder(Binder _);
  bool get isVirtual;
  int get ident;

  // List<Variable> get uses;
  // void use(Variable reference);
}

abstract class DeclarationMixin implements Declaration {
  Binder binder;
  int get ident => binder.ident;
  bool get isVirtual => false;
  Datatype get type => binder.type;

  // List<Variable> _uses;
  // List<Variable> get uses {
  //   _uses ??= new List<Variable>();
  //   return _uses;
  // }

  // void use(Variable reference) {
  //   _uses ??= new List<Variable>();
  //   uses.add(reference);
  // }

  // void mergeUses(List<Variable> references) {
  //   if (_uses == null) {
  //     _uses = references;
  //   } else {
  //     uses.addAll(references);
  //   }
  // }
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

  Signature(Binder binder, this.type, Location location)
      : this.binder = binder,
        definitions = new List<Declaration>(),
        super(ModuleTag.SIGNATURE, location) {
    _setBindingOccurrence(binder, this);
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

  ValueDeclaration(
      Signature signature, Binder binder, Expression body, Location location)
      : this.binder = binder,
        this.body = body,
        this.signature = signature,
        super(ModuleTag.VALUE_DEF, location) {
    _setBindingOccurrence(binder, this);
    binder.type = signature.type;
    _setParent(body, this);
  }
  T accept<T>(ModuleVisitor<T> v) => v.visitValue(this);

  String toString() => "(define $binder (...)))";

  Member asKernelNode;
}

class VirtualValueDeclaration extends ValueDeclaration {
  bool get isVirtual => true;

  VirtualValueDeclaration.stub(Signature signature, Binder binder)
      : super(signature, binder, null, signature.location);
  factory VirtualValueDeclaration(String name, Datatype type) {
    Location location = Location.primitive();
    Binder binder = Binder.primitive(name);
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
  Binder _binder;
  Binder get binder => _binder;
  void set binder(Binder binder) {
    _setBindingOccurrence(binder, this);
    _binder = binder;
  }

  Signature signature;

  List<Param> _parameters;
  List<Param> get parameters => _parameters;
  void set parameters(List<Param> parameters) {
    _setParentMany(parameters, this);
    _parameters = parameters;
  }

  Body _body;
  Body get body => _body;
  void set body(Body body) {
    _setParent(body, this);
    _body = body;
  }

  AbstractFunctionDeclaration(Signature signature, Binder binder,
      List<Param> parameters, Body body, Location location)
      : this.signature = signature,
        super(ModuleTag.FUNC_DEF, location) {
    this.binder = binder;
    this.binder.type = signature.type;
    this.body = body;
    this.parameters = parameters;
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
  factory VirtualFunctionDeclaration(String name, Datatype type) {
    Location location = Location.primitive();
    Binder binder = Binder.primitive(name);
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
    implements Declaration, KernelNode {
  DatatypeDescriptor declarator;
  Binder binder;
  List<Datatype> parameters;

  Datatype get type {
    if (binder.type == null) {
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
        binder.type = ft;
      } else {
        if (quantifiers != null) {
          ForallType forallType = new ForallType();
          forallType.quantifiers = quantifiers;
          forallType.body = declarator.type;
          binder.type = forallType;
        } else {
          binder.type = declarator.type;
        }
      }
    }
    return binder.type;
  }

  DataConstructor(Binder binder, this.parameters, Location location)
      : this.binder = binder,
        super(ModuleTag.CONSTR, location) {
    _setBindingOccurrence(binder, this);
  }

  T accept<T>(ModuleVisitor<T> v) => v.visitDataConstructor(this);

  bool get isNullary => parameters.length == 0;

  Class asKernelNode;
}

class DatatypeDescriptor extends ModuleMember
    with DeclarationMixin
    implements Declaration, TypeDescriptor, KernelNode {
  Binder binder;
  List<Quantifier> parameters;

  List<DataConstructor> _constructors;
  List<DataConstructor> get constructors => _constructors;
  void set constructors(List<DataConstructor> constructors) {
    _setParentMany(constructors, this);
    _constructors = constructors;
  }

  Set<Derivable> deriving;

  TypeConstructor get type {
    if (binder.type == null) {
      List<Datatype> arguments = new List<Datatype>(parameters.length);
      for (int i = 0; i < parameters.length; i++) {
        arguments[i] = TypeVariable.bound(parameters[i]);
      }
      binder.type = TypeConstructor.from(this, arguments);
    }
    return binder.type as TypeConstructor;
  }

  int get arity => parameters.length;

  DatatypeDescriptor(Binder binder, this.parameters,
      List<DataConstructor> constructors, this.deriving, Location location)
      : this.binder = binder,
        super(ModuleTag.DATATYPE_DEF, location) {
    _setBindingOccurrence(binder, this);
    this.constructors = constructors;
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

  Class asKernelNode;
  Class eliminatorClass;
  Class matchClosureClass;
  Class visitorClass;
}

class DatatypeDeclarations extends ModuleMember {
  List<DatatypeDescriptor> _declarations;
  List<DatatypeDescriptor> get declarations => _declarations;
  void set declarations(List<DatatypeDescriptor> declarations) {
    _setParentMany(declarations, this);
    _declarations = declarations;
  }

  DatatypeDeclarations(List<DatatypeDescriptor> declarations, Location location)
      : super(ModuleTag.DATATYPE_DEFS, location) {
    this.declarations = declarations;
  }

  T accept<T>(ModuleVisitor<T> v) => v.visitDatatypes(this);

  String toString() => "(define-datatypes $declarations)";
}

class Include extends ModuleMember {
  String module;

  Include(this.module, Location location) : super(ModuleTag.OPEN, location);

  T accept<T>(ModuleVisitor<T> v) => v.visitInclude(this);
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

  void compute() {
    Map<String, Declaration> index = new Map<String, Declaration>();
    for (int i = 0; i < module.members.length; i++) {
      ModuleMember member = module.members[i];
      if (member is Declaration) {
        Declaration decl = member as Declaration;
        index[decl.binder.sourceName] = decl;
      } else if (member is DatatypeDeclarations) {
        DatatypeDeclarations decls = member;
        for (int i = 0; i < decls.declarations.length; i++) {
          DatatypeDescriptor descriptor = decls.declarations[i];
          index[descriptor.binder.sourceName] = descriptor;
        }
      } // else ignore.
    }
    _index = index;
  }

  Summary get summary => Summary(module);
}

class TopModule extends ModuleMember {
  Manifest manifest;
  String name;
  TopModule get origin => this;

  TopModule(List<ModuleMember> members, this.name, Location location)
      : super(ModuleTag.TOP, location) {
    this.members = members;
    manifest = Manifest(this);
  }

  // Members.
  List<ModuleMember> _members;
  List<ModuleMember> get members => _members;
  void set members(List<ModuleMember> members) {
    _setParentMany(members, this);
    _members = members;
  }

  // Main function.
  Declaration main;
  bool get hasMain => main != null;

  T accept<T>(ModuleVisitor<T> v) => v.visitTopModule(this);

  String toString() {
    //String members0 = ListUtils.stringify(" ", members);
    return "(module $name ...)";
  }

  bool get isVirtual => false;

  // Module-local boilerplate arising from the user's program.
  List<BoilerplateTemplate> get templates =>
      _templates ?? List<BoilerplateTemplate>();
  List<BoilerplateTemplate> _templates;
  void addTemplate(BoilerplateTemplate t) {
    _templates ??= new List<BoilerplateTemplate>();
    templates.add(t);
  }
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

  TypeConstructor get type {
    if (binder.type == null) {
      List<Datatype> arguments = new List<Datatype>(parameters.length);
      for (int i = 0; i < parameters.length; i++) {
        arguments[i] = TypeVariable.bound(parameters[i]);
      }
      binder.type = TypeConstructor.from(this, arguments);
    }
    return binder.type as TypeConstructor;
  }

  int get arity => parameters.length;

  TypeAliasDescriptor(
      Binder binder, this.parameters, this.rhs, Location location)
      : this.binder = binder,
        super(ModuleTag.TYPENAME, location) {
    _setBindingOccurrence(binder, this);
  }

  T accept<T>(ModuleVisitor<T> v) => v.visitTypename(this);
}

class ErrorModule extends ModuleMember {
  final LocatedError error;

  ErrorModule(this.error, [Location location = null])
      : super(ModuleTag.ERROR, location == null ? Location.dummy() : location);

  T accept<T>(ModuleVisitor<T> v) => v.visitError(this);
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
  T visitMatchClosure(MatchClosure clo);
  T visitEliminate(Eliminate elim);
  // T visitBlock(Block block);
}

abstract class Expression extends T20Node {
  final ExpTag tag;
  Location location;

  Expression(this.tag, [Location location])
      : this.location = location == null ? Location.dummy() : location;

  T accept<T>(ExpressionVisitor<T> v);

  Datatype get type => typeUtils.dynamicType;
}

enum ExpTag {
  // BLOCK,
  BOOL,
  ELIM,
  ERROR,
  // GET,
  INT,
  IS,
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

  String toString() => "$value";
}

class BoolLit extends Constant<bool> {
  BoolLit(bool value, [Location location])
      : super(value, ExpTag.BOOL, location);

  T accept<T>(ExpressionVisitor<T> v) => v.visitBool(this);

  static const String T_LITERAL = "#t";
  static const String F_LITERAL = "#f";

  String toString() => value ? T_LITERAL : F_LITERAL;

  BoolType get type => typeUtils.boolType;
}

class IntLit extends Constant<int> {
  IntLit(int value, [Location location]) : super(value, ExpTag.INT, location);

  T accept<T>(ExpressionVisitor<T> v) => v.visitInt(this);

  IntType get type => typeUtils.intType;
}

class StringLit extends Constant<String> {
  StringLit(String value, [Location location])
      : super(value, ExpTag.STRING, location);

  T accept<T>(ExpressionVisitor<T> v) => v.visitString(this);

  String toString() => "\"$value\"";

  StringType get type => typeUtils.stringType;
}

class Apply extends Expression {
  Expression _abstractor;
  Expression get abstractor => _abstractor;
  void set abstractor(Expression abstractor) {
    _setParent(abstractor, this);
    _abstractor = abstractor;
  }

  List<Expression> _arguments;
  List<Expression> get arguments => _arguments;
  void set arguments(List<Expression> arguments) {
    _setParentMany(arguments, this);
    _arguments = arguments;
  }

  Apply(Expression abstractor, List<Expression> arguments, [Location location])
      : super(ExpTag.APPLY, location) {
    this.abstractor = abstractor;
    this.arguments = arguments;
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

  // bool operator ==(dynamic other) =>
  //     other != null && other is Variable && identical(other.binder, binder);

  // int get hashCode => 13 * binder.hashCode;

  Datatype get type => binder.type;
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

  T accept<T>(ExpressionVisitor<T> v) => v.visitIf(this);

  String toString() => "(if $condition (...) (...))";

  Datatype type;
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

  String toString() => "($pattern ...)";
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

  Datatype get type => body.type;
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

  Datatype _type;
  void set type(Datatype type) => _type = type;
  Datatype get type => _type;
}

class Lambda extends LambdaAbstraction<Pattern, Expression> {
  Lambda(List<Pattern> parameters, Expression body, Location location)
      : super(parameters, body, location);

  T accept<T>(ExpressionVisitor<T> v) => v.visitLambda(this);

  String toString() {
    String parameters0 = ListUtils.stringify(" ", parameters);
    return "(lambda ($parameters0) (...))";
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

  Datatype _type;
  void set type(Datatype type) => _type = type;
  Datatype get type => _type;
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

  TupleType get type {
    List<Datatype> componentTypes =
        components.map((Expression e) => e.type).toList();
    return TupleType(componentTypes);
  }
}

class TypeAscription extends Expression {
  Datatype type;
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

  T accept<T>(ExpressionVisitor<T> v) => v.visitError(this);

  Datatype get type => typeUtils.dynamicType;
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
  T visitObvious(ObviousPattern o);
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
  OBVIOUS,
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

  Datatype get type => typeUtils.boolType;

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
  int get arity => components == null ? 0 : components.length;

  ConstructorPattern(
      this.declarator, List<Pattern> components, Location location)
      : this.components = components,
        super(PatternTag.CONSTR, location) {
    _setParentMany(components, this);
  }
  ConstructorPattern.nullary(DataConstructor declarator, Location location)
      : this(declarator, const <VariablePattern>[], location);

  T accept<T>(PatternVisitor<T> v) => v.visitConstructor(this);

  String toString() {
    if (arity == 0) {
      return "[${declarator.binder.sourceName}]";
    } else {
      String subpatterns = ListUtils.stringify(" ", components);
      return "[${declarator.binder.sourceName} $subpatterns]";
    }
  }

  Datatype _type;
  Datatype get type => _type ?? declarator.type;
  void set type(Datatype type) => _type = type;
}

class ErrorPattern extends Pattern {
  final LocatedError error;
  ErrorPattern(this.error, Location location)
      : super(PatternTag.ERROR, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitError(this);
  }

  Datatype get type => const DynamicType();
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

  Datatype get type => typeUtils.intType;

  IntPattern(this.value, Location location) : super(PatternTag.INT, location);

  T accept<T>(PatternVisitor<T> v) {
    return v.visitInt(this);
  }

  String toString() => "$value";
}

class StringPattern extends BaseValuePattern<String> {
  final String value;

  Datatype get type => typeUtils.stringType;

  StringPattern(this.value, Location location)
      : super(PatternTag.STRING, location);

  T accept<T>(PatternVisitor<T> v) => v.visitString(this);

  String toString() => '"$value"';
}

class TuplePattern extends Pattern {
  List<Pattern> components;

  TuplePattern(List<Pattern> components, Location location)
      : this.components = components,
        super(PatternTag.TUPLE, location) {
    _setParentMany(components, this);
  }

  T accept<T>(PatternVisitor<T> v) => v.visitTuple(this);

  String toString() {
    if (components.length == 0) {
      return "(,)";
    } else {
      String components0 = ListUtils.stringify(" ", components);
      return "(, $components0)";
    }
  }

  bool get isUnit => components.length == 0;

  Datatype get type {
    if (isUnit) return typeUtils.unitType;

    List<Datatype> componentTypes = List<Datatype>();
    for (int i = 0; i < components.length; i++) {
      componentTypes.add(components[i].type);
    }
    return TupleType(componentTypes);
  }
}

class VariablePattern extends Pattern
    with DeclarationMixin
    implements Declaration {
  Binder binder;

  VariablePattern(Binder binder, Location location)
      : this.binder = binder,
        super(PatternTag.VAR, location) {
    _setBindingOccurrence(binder, this);
  }

  T accept<T>(PatternVisitor<T> v) => v.visitVariable(this);

  String toString() => binder.toString();

  Datatype get type => binder.type ?? const DynamicType();
  void set type(Datatype type) => binder.type = type;
}

class WildcardPattern extends Pattern {
  WildcardPattern([Location location]) : super(PatternTag.WILDCARD, location);

  T accept<T>(PatternVisitor<T> v) => v.visitWildcard(this);

  String toString() => "_";

  Datatype _type = const DynamicType();
  Datatype get type => _type;
  void set type(Datatype type) => _type = type;
}

class ObviousPattern extends Pattern {
  ObviousPattern([Location location]) : super(PatternTag.OBVIOUS, location);

  T accept<T>(PatternVisitor<T> v) => v.visitObvious(this);

  String toString() => "#obvious!";

  Datatype _type = const DynamicType();
  Datatype get type => _type;
  void set type(Datatype type) => _type = type;
}

//===== Desugared AST nodes.
abstract class KernelNode {
  TreeNode get asKernelNode;
}

class FormalParameter extends T20Node
    with DeclarationMixin
    implements Declaration, KernelNode {
  Binder binder;

  FormalParameter(Binder binder) : this.binder = binder {
    _setBindingOccurrence(binder, this);
  }

  String toString() => binder.toString();

  VariableDeclaration asKernelNode;
}

class DLambda extends LambdaAbstraction<FormalParameter, Expression> {
  DLambda(List<FormalParameter> parameters, Expression body,
      [Location location])
      : super(parameters, body, location);

  T accept<T>(ExpressionVisitor<T> v) => v.visitDLambda(this);

  ArrowType get type {
    List<Datatype> domain =
        parameters.map((FormalParameter p) => p.type).toList();
    Datatype codomain = body.type;
    return ArrowType(domain, codomain);
  }

  String toString() {
    String parameters0 = ListUtils.stringify(" ", parameters);
    return "(dlambda ($parameters0) (...))";
  }
}

class DLet extends Expression with DeclarationMixin implements Declaration {
  Binder binder;

  Expression _body;
  Expression get body => _body;
  void set body(Expression body) {
    _setParent(body, this);
    _body = body;
  }

  Expression _continuation;
  Expression get continuation => _continuation;
  void set continuation(Expression cont) {
    _setParent(cont, this);
    _continuation = cont;
  }

  DLet(Binder binder, Expression body, Expression continuation,
      [Location location])
      : this.binder = binder,
        super(ExpTag.LET, location) {
    _setBindingOccurrence(binder, this);
    this.body = body;
    this.continuation = continuation;
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitDLet(this);

  Datatype get type => continuation.type;
}

class LetFunction
    extends AbstractFunctionDeclaration<FormalParameter, Expression>
    implements KernelNode {
  Procedure asKernelNode;

  LetFunction(Signature signature, Binder binder,
      List<FormalParameter> parameters, Expression body, Location location)
      : super(signature, binder, parameters, body, location) {
    _setBindingOccurrence(binder, this);
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

class Project extends Expression {
  Expression receiver;
  int label;

  Project(Expression receiver, this.label)
      : this.receiver = receiver,
        super(ExpTag.PROJECT) {
    _setParent(receiver, this);
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitProject(this);

  String toString() => "(\$$label $receiver)";

  Datatype get type {
    if (label < 1) return super.type;
    Datatype receiverType = receiver.type;

    if (receiverType is TupleType) {
      return receiverType.components[label - 1];
    }

    return super.type;
  }
}

class DataConstructorProject extends Project {
  DataConstructor constructor;

  DataConstructorProject(Expression receiver, int label, this.constructor)
      : super(receiver, label);

  Datatype get type {
    if (label < 1) return super.type;

    Datatype receiverType = receiver.type;
    if (receiverType is TypeConstructor) {
      if (typeUtils.isTypeAlias(receiverType)) return super.type;
      if (!identical(receiverType.declarator, constructor.declarator)) {
        return super.type;
      }

      // Construct the nth component type.
      Datatype componentType = constructor.parameters[label - 1];
      // The component type might be incomplete, i.e. an uninstantiated rigid
      // type variable. Therefore we need to check whether we need to perform an
      // instantiation.
      List<Datatype> typeArguments = receiverType.arguments;
      if (typeArguments.length == 0) return componentType;

      // At first one may think that it suffices to look at the head of the nth
      // component type to decide whether to perform an instantiation. However,
      // a type variable may be sitting arbitrarily deep inside a component
      // type. Therefore we eagerly choose to perform an instantiation, even if
      // it is unnecessary (to decide whether it was necessary, we would have to
      // traverse the entire type anyways).
      List<Quantifier> quantifiers =
          typeUtils.extractQuantifiers(constructor.type);
      return typeUtils.instantiate(quantifiers, typeArguments, componentType);
    }
    return super.type;
  }
}

abstract class BoilerplateTemplate {}

class MatchClosureCase extends T20Node
    with DeclarationMixin
    implements Declaration {
  Binder binder;
  DataConstructor constructor;
  Expression body;

  MatchClosureCase(Binder binder, this.constructor, Expression body)
      : this.binder = binder,
        this.body = body {
    _setParent(body, this);
    _setBindingOccurrence(binder, this);
  }
}

class MatchClosureDefaultCase extends T20Node
    with DeclarationMixin
    implements Declaration {
  Binder binder;
  Expression body;

  MatchClosureDefaultCase(Binder binder, Expression body)
      : this.binder = binder,
        this.body = body {
    _setBindingOccurrence(binder, this);
    _setParent(body, this);
  }
}

class MatchClosure extends Expression
    implements BoilerplateTemplate, KernelNode {
  TypeConstructor typeConstructor;

  // Binders for free variables.
  List<ClosureVariable> _context;
  List<ClosureVariable> get context => _context;
  void set context(List<ClosureVariable> context) {
    _setParentMany(context, this);
    _context = context;
  }

  List<MatchClosureCase> _cases;
  List<MatchClosureCase> get cases => _cases;
  void set cases(List<MatchClosureCase> cases) {
    _setParentMany(cases, this);
    _cases = cases;
  }

  MatchClosureDefaultCase _defaultCase;
  MatchClosureDefaultCase get defaultCase => _defaultCase;
  void set defaultCase(MatchClosureDefaultCase defaultCase) {
    _setParent(defaultCase, this);
    _defaultCase = defaultCase;
  }

  MatchClosure(
      this.type,
      this.typeConstructor,
      List<MatchClosureCase> cases,
      MatchClosureDefaultCase defaultCase,
      List<ClosureVariable> context,
      Location location)
      : super(ExpTag.MATCH, location) {
    this.context = context;
    this.cases = cases;
    this.defaultCase = defaultCase;
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitMatchClosure(this);

  Datatype type;

  Class asKernelNode;
}

class ClosureVariable extends T20Node
    with DeclarationMixin
    implements Declaration, KernelNode {
  Binder binder;

  ClosureVariable(Binder binder) {
    binder.bindingOccurrence = this;
    this.binder = binder;
  }

  String toString() => "ClosureVariable($binder)";

  Field asKernelNode;
}

class Eliminate extends Expression {
  TypeConstructor constructor;

  Variable _scrutinee;
  Variable get scrutinee => _scrutinee;
  void set scrutinee(Variable v) {
    _setParent(v, this);
    _scrutinee = v;
  }

  MatchClosure _closure;
  MatchClosure get closure => _closure;
  void set closure(MatchClosure clo) {
    _setParent(clo, this);
    _closure = clo;
  }

  List<Variable> _capturedVariables;
  List<Variable> get capturedVariables => _capturedVariables;
  void set capturedVariables(List<Variable> vs) {
    _setParentMany(vs, this);
    _capturedVariables = vs;
  }

  Eliminate(Variable scrutinee, MatchClosure closure,
      List<Variable> capturedVariables, this.constructor)
      : super(ExpTag.ELIM, null) {
    this.scrutinee = scrutinee;
    this.closure = closure;
    this.capturedVariables = capturedVariables;
  }

  T accept<T>(ExpressionVisitor<T> v) => v.visitEliminate(this);

  Datatype get type => closure.type;
}

class Is extends Expression {
  Expression operand;
  // The code generator is responsible for interpreting the [constructor] as a
  // [DartType].
  DataConstructor constructor;

  Is(Expression operand, this.constructor)
      : this.operand = operand,
        super(ExpTag.IS) {
    _setParent(operand, this);
  }

  T accept<T>(ExpressionVisitor<T> v) => null; // TODO.

  Datatype get type => typeUtils.boolType;
}

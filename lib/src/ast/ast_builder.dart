// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart';
import '../errors/errors.dart';
import '../fp.dart';
import '../immutable_collections.dart';

import '../static_semantics/type_utils.dart' as typeUtils
    show boolType, intType, stringType;

import 'algebra.dart';
import 'ast_module.dart';
import 'ast_expressions.dart';
import 'ast_declaration.dart';
import 'ast_patterns.dart';
import 'binder.dart';
import 'datatype.dart';

class Name {
  final Location location;
  final int intern;
  final String sourceName;

  Name(this.sourceName, this.location) : intern = sourceName.hashCode;

  String toString() {
    return "$sourceName:$location";
  }
}

class BuildContext {
  final ImmutableMap<int, Declaration> declarations;
  final ImmutableMap<int, Quantifier> quantifiers;
  final ImmutableMap<int, Signature> signatures;
  final ImmutableMap<int, TypeDescriptor> typenames;

  BuildContext(
      this.declarations, this.quantifiers, this.signatures, this.typenames);
  BuildContext.empty()
      : this(
            ImmutableMap<int, Declaration>.empty(),
            ImmutableMap<int, Quantifier>.empty(),
            ImmutableMap<int, Signature>.empty(),
            ImmutableMap<int, TypeDescriptor>.empty());

  Declaration getDeclaration(Name name) {
    return declarations.lookup(name.intern);
  }

  BuildContext putDeclaration(Name name, Declaration declaration) {
    return BuildContext(declarations.put(name.intern, declaration), quantifiers,
        signatures, typenames);
  }

  Signature getSignature(Name name) {
    return signatures.lookup(name.intern);
  }

  BuildContext putSignature(Name name, Signature signature) {
    return BuildContext(declarations, quantifiers,
        signatures.put(name.intern, signature), typenames);
  }

  TypeDescriptor getTypeDescriptor(Name name) {
    return typenames.lookup(name.intern);
  }

  BuildContext putTypeDescriptor(Name name, TypeDescriptor desc) {
    return BuildContext(declarations, quantifiers, signatures,
        typenames.put(name.intern, desc));
  }

  Quantifier getQuantifier(Name name) {
    return quantifiers.lookup(name.intern);
  }

  BuildContext putQuantifier(Name name, Quantifier quantifier) {
    return BuildContext(declarations, quantifiers.put(name.intern, quantifier),
        signatures, typenames);
  }

  BuildContext union(BuildContext other) {
    return BuildContext(
        declarations.union(other.declarations),
        quantifiers.union(other.quantifiers),
        signatures.union(other.signatures),
        typenames.union(other.typenames));
  }
}

class OutputBuildContext extends BuildContext {
  final List<Name> declaredNames;

  OutputBuildContext(this.declaredNames, BuildContext ctxt)
      : super(ctxt.declarations, ctxt.quantifiers, ctxt.signatures,
            ctxt.typenames);
}

typedef Build<T> = Pair<BuildContext, T> Function(BuildContext);

// builder : (BuildContext) -> (BuildContext * node)
// forall ctxt \in BuildContext. builder(ctxt) = (ctxt',_) such that |ctxt'| >= |ctxt|.
class ASTBuilder extends TAlgebra<Name, Build<ModuleMember>, Build<Expression>,
    Build<Pattern>, Build<Datatype>> {
  final BuildContext emptyContext = new BuildContext.empty();

  Pair<BuildContext, T> trivial<T>(Build<T> builder) {
    return builder(emptyContext);
  }

  Pair<BuildContext, T> build<T>(Build<T> builder, BuildContext context) {
    return builder(context);
  }

  T forgetfulBuild<T>(Build<T> builder, BuildContext context) {
    Pair<BuildContext, T> result = builder(context);
    return result.snd;
  }

  Triple<BuildContext, List<Name>, Pattern> buildPattern(
      Build<Pattern> builder, BuildContext context) {
    Pair<BuildContext, Pattern> result = builder(context);
    if (result.fst is OutputBuildContext) {
      OutputBuildContext ctxt0 = result.fst;
      return Triple<BuildContext, List<Name>, Pattern>(
          ctxt0, ctxt0.declaredNames, result.snd);
    } else {
      throw "Logical error. Expected an 'OutputBuildContext'.";
    }
  }

  Triple<BuildContext, List<Name>, List<Pattern>> buildParameters(
      List<Build<Pattern>> parameters, BuildContext context) {
    BuildContext ctxt0 = context; // Output context.
    List<Pattern> parameters0 = new List<Pattern>();
    List<Name> declaredNames = new List<Name>();
    for (int i = 0; i < parameters.length; i++) {
      Triple<BuildContext, List<Name>, Pattern> result =
          buildPattern(parameters[i], context);
      ctxt0 = ctxt0.union(result.fst);
      declaredNames.addAll(result.snd);
      parameters0[i] = result.thd;
    }
    return Triple<BuildContext, List<Name>, List<Pattern>>(
        ctxt0, declaredNames, parameters0);
  }

  List<Name> checkDuplicates(List<Name> names) {
    Set<int> uniqueNames = new Set<int>();
    List<Name> dups = new List<Name>();
    for (int i = 0; i < names.length; i++) {
      if (uniqueNames.contains(names[i].intern)) {
        dups.add(names[i]);
      }
    }
    return dups;
  }

  Pair<BuildContext, T> reportDuplicates<T>(List<Name> duplicates,
      Pair<BuildContext, T> Function(LocatedError, Location location) error) {
    Name first = duplicates[0];
    return error(MultipleDeclarationsError(first.sourceName, first.location),
        first.location);
  }

  BuildContext exposeQuantifiers(Signature sig, BuildContext context) {
    return context; // TODO.
  }

  Binder binderOf(Name name) {
    return Binder.fromSource(name.sourceName, name.location);
  }

  Pair<BuildContext, ModuleMember> moduleError(
      LocatedError error, Location location) {
    return Pair<BuildContext, ModuleMember>(
        emptyContext, ErrorModule(error, location));
  }

  Pair<BuildContext, Expression> expressionError(
      LocatedError error, Location location) {
    return Pair<BuildContext, Expression>(
        emptyContext, new ErrorExpression(error, location));
  }

  Build<ModuleMember> datatypes(
          List<
                  Triple<Name, List<Name>,
                      List<Pair<Name, List<Build<Datatype>>>>>>
              defs,
          List<Name> deriving,
          {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<ModuleMember> valueDef(Name name, Build<Expression> body,
          {Location location}) =>
      (BuildContext ctxt) {
        // Lookup the signature.
        Signature sig = ctxt.getSignature(name);
        if (sig == null) {
          // Signal an error.
          LocatedError err =
              MissingAccompanyingSignatureError(name.sourceName, location);
          return moduleError(err, location);
        }
        // Expose quantifiers.
        BuildContext ctxt0 = exposeQuantifiers(sig, ctxt);

        // Build the body.
        Expression body0 = forgetfulBuild<Expression>(body, ctxt0);

        // Create the declaration.
        ValueDeclaration member =
            new ValueDeclaration(sig, binderOf(name), body0, location);

        // Create the output context.
        ctxt = ctxt.putDeclaration(name, member);

        return Pair<BuildContext, ModuleMember>(ctxt, member);
      };

  Build<ModuleMember> functionDef(
          Name name, List<Build<Pattern>> parameters, Build<Expression> body,
          {Location location}) =>
      (BuildContext ctxt) {
        // Lookup the signature.
        Signature sig = ctxt.getSignature(name);
        if (sig == null) {
          // Signal an error.
          LocatedError err =
              MissingAccompanyingSignatureError(name.sourceName, location);
          return moduleError(err, location);
        }
        // Expose quantifiers.
        BuildContext ctxt0 = exposeQuantifiers(sig, ctxt);

        // Build parameters.
        Triple<BuildContext, List<Name>, List<Pattern>> result =
            buildParameters(parameters, ctxt0);
        List<Pattern> parameters0 = result.thd;
        // Check for duplicate parameter names.
        List<Name> dups = checkDuplicates(result.snd);
        if (dups.length > 0) {
          return reportDuplicates(dups, moduleError);
        }

        // Expose parameters.
        ctxt0 = result.fst;

        // Build the body.
        Expression body0 = forgetfulBuild<Expression>(body, ctxt0);

        // Create the declaration.
        FunctionDeclaration member = new FunctionDeclaration(
            sig, binderOf(name), parameters0, body0, location);

        // Create the output context.
        ctxt = ctxt.putDeclaration(name, member);

        return Pair<BuildContext, ModuleMember>(ctxt, member);
      };

  Build<ModuleMember> module(List<Build<ModuleMember>> members,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build each member.
        List<ModuleMember> members0 = new List<ModuleMember>();
        for (int i = 0; i < members0.length; i++) {
          Pair<BuildContext, ModuleMember> result =
              build<ModuleMember>(members[i], ctxt);
          // Update the context.
          ctxt = result.fst;
          // Only include non-null members. Members like signatures become null.
          if (result.snd != null) {
            members0[i] = result.snd;
          }
        }

        // Construct the module.
        TopModule module = new TopModule(members0, location);

        return Pair<BuildContext, ModuleMember>(ctxt, module);
      };

  Build<ModuleMember> typename(
          Name name, List<Name> typeParameters, Build<Datatype> type,
          {Location location}) =>
      (BuildContext ctxt) {
        // Create a fresh binder for [name].
        Binder binder = binderOf(name);
        // Check for duplicate type parameter names.
        List<Name> dups = checkDuplicates(typeParameters);
        if (dups.length > 0) {
          return reportDuplicates(dups, moduleError);
        }
        // Copy the original context.
        BuildContext ctxt0 = ctxt;
        // Transform the [typeParameters] into a list of quantifiers.
        List<Quantifier> quantifiers = new List<Quantifier>();
        for (int i = 0; i < typeParameters.length; i++) {
          Name typeParam = typeParameters[i];
          // Create a fresh binder.
          Binder typeBinder = binderOf(typeParam);
          // Construct a quantifier.
          Quantifier quantifier = Quantifier.of(typeBinder);
          quantifiers.add(quantifier);

          // Expose the quantifier.
          ctxt0.putQuantifier(typeParam, quantifier);
        }

        // Build the body.
        Datatype body0 = forgetfulBuild<Datatype>(type, ctxt0);

        // Construct the type descriptor.
        TypeAliasDescriptor desc =
            new TypeAliasDescriptor(binder, quantifiers, body0, location);

        // Construct the output context.
        ctxt = ctxt.putTypeDescriptor(name, desc);

        return Pair<BuildContext, ModuleMember>(ctxt, null);
      };

  Build<ModuleMember> signature(Name name, Build<Datatype> type,
          {Location location}) =>
      (BuildContext ctxt) {
        // Create a binder for [name].
        Binder binder = binderOf(name);

        // Build [type].
        Datatype type0 = forgetfulBuild<Datatype>(type, ctxt);

        // Construct the signature.
        Signature sig = new Signature(binder, type0, location);

        // Construct the output context.
        ctxt = ctxt.putSignature(name, sig);

        return Pair<BuildContext, ModuleMember>(ctxt, null);
      };

  Build<ModuleMember> errorModule(LocatedError error, {Location location}) =>
      (BuildContext ctxt) {
        return Pair<BuildContext, ModuleMember>(
            ctxt, new ErrorModule(error, location));
      };

  Build<Expression> boolLit(bool b, {Location location}) =>
      (BuildContext ctxt) {
        // Construct a boolean literal node.
        BoolLit lit = new BoolLit(b, location);
        lit.type = typeUtils.boolType;
        return Pair<BuildContext, Expression>(ctxt, lit);
      };

  Build<Expression> intLit(int n, {Location location}) => (BuildContext ctxt) {
        // Construct a boolean literal node.
        IntLit lit = new IntLit(n, location);
        lit.type = typeUtils.intType;
        return Pair<BuildContext, Expression>(ctxt, lit);
      };

  Build<Expression> stringLit(String s, {Location location}) =>
      (BuildContext ctxt) {
        // Construct a boolean literal node.
        StringLit lit = new StringLit(s, location);
        lit.type = typeUtils.stringType;
        return Pair<BuildContext, Expression>(ctxt, lit);
      };

  Build<Expression> varExp(Name name, {Location location}) =>
      (BuildContext ctxt) {
        // Lookup the declaration.
        Declaration declarator = ctxt.getDeclaration(name);
        if (declarator == null) {
          // Signal error.
          LocatedError err = UnboundNameError(name.sourceName, location);
          return expressionError(err, location);
        }

        // Construct a variable node.
        Variable v = new Variable(declarator, location);

        return Pair<BuildContext, Expression>(ctxt, v);
      };

  Build<Expression> apply(
          Build<Expression> fn, List<Build<Expression>> arguments,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build the function expression.
        Expression fn0 = forgetfulBuild<Expression>(fn, ctxt);

        // Build the arguments.
        List<Expression> arguments0 = new List<Expression>();
        for (int i = 0; i < arguments.length; i++) {
          Expression exp = forgetfulBuild(arguments[i], ctxt);
          arguments0[i] = exp;
        }

        // Construct the application node.
        Apply apply = new Apply(fn0, arguments0, location);
        return Pair<BuildContext, Expression>(ctxt, apply);
      };

  Build<Expression> lambda(
          List<Build<Pattern>> parameters, Build<Expression> body,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build the [parameters].
        Triple<BuildContext, List<Name>, List<Pattern>> result =
            buildParameters(parameters, ctxt);
        // Check for duplicate parameter names.
        List<Name> dups = checkDuplicates(result.snd);
        if (dups.length > 0) {
          return reportDuplicates(dups, expressionError);
        }

        // Build the [body].
        BuildContext ctxt0 = result.fst;
        Expression body0 = forgetfulBuild<Expression>(body, ctxt0);

        // Construct the lambda node.
        Lambda lambda = new Lambda(result.thd, body0, location);

        return Pair<BuildContext, Expression>(ctxt, lambda);
      };

  Build<Expression> let(List<Pair<Build<Pattern>, Build<Expression>>> bindings,
          Build<Expression> body,
          {BindingMethod bindingMethod = BindingMethod.Parallel,
          Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Expression> tuple(List<Build<Expression>> components,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build each component.
        List<Expression> components0 = new List<Expression>();
        for (int i = 0; i < components.length; i++) {
          components0[i] = forgetfulBuild<Expression>(components[i], ctxt);
        }

        // Construct the tuple node.
        Tuple tuple = new Tuple(components0, location);

        return Pair<BuildContext, Expression>(ctxt, tuple);
      };

  Build<Expression> ifthenelse(Build<Expression> condition,
          Build<Expression> thenBranch, Build<Expression> elseBranch,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build the [condition].
        Expression condition0 = forgetfulBuild<Expression>(condition, ctxt);
        // Build the branches.
        Expression thenBranch0 = forgetfulBuild<Expression>(thenBranch, ctxt);
        Expression elseBranch0 = forgetfulBuild<Expression>(elseBranch, ctxt);

        // Construct the if node.
        If ifthenelse = new If(condition0, thenBranch0, elseBranch0, location);
        return Pair<BuildContext, Expression>(ctxt, ifthenelse);
      };

  Build<Expression> match(Build<Expression> scrutinee,
          List<Pair<Build<Pattern>, Build<Expression>>> cases,
          {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Expression> typeAscription(Build<Expression> exp, Build<Datatype> type,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build the [type].
        Datatype type0 = forgetfulBuild<Datatype>(type, ctxt);

        // Build the expression.
        Expression exp0 = forgetfulBuild<Expression>(exp, ctxt);

        // Construct the type ascription node.
        TypeAscription typeAscription =
            new TypeAscription(exp0, type0, location);

        return Pair<BuildContext, Expression>(ctxt, typeAscription);
      };

  Build<Expression> errorExp(LocatedError error, {Location location}) =>
      (BuildContext ctxt) {
        return Pair<BuildContext, Expression>(
            ctxt, new ErrorExpression(error, location));
      };

  Build<Pattern> hasTypePattern(Build<Pattern> pattern, Build<Datatype> type,
          {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Pattern> boolPattern(bool b, {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Pattern> intPattern(int n, {Location location}) => (BuildContext ctxt) {
        return null;
      };

  Build<Pattern> stringPattern(String s, {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Pattern> wildcard({Location location}) => (BuildContext ctxt) {
        return null;
      };

  Build<Pattern> varPattern(Name name, {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Pattern> constrPattern(Name name, List<Build<Pattern>> parameters,
          {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Pattern> tuplePattern(List<Build<Pattern>> components,
          {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Pattern> errorPattern(LocatedError error, {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Datatype> intType({Location location}) => (BuildContext ctxt) {
        return null;
      };

  Build<Datatype> boolType({Location location}) => (BuildContext ctxt) {
        return null;
      };

  Build<Datatype> stringType({Location location}) => (BuildContext ctxt) {
        return null;
      };

  Build<Datatype> typeVar(Name name, {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Datatype> forallType(List<Name> quantifiers, Build<Datatype> type,
          {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Datatype> arrowType(
          List<Build<Datatype>> domain, Build<Datatype> codomain,
          {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Datatype> typeConstr(Name name, List<Build<Datatype>> arguments,
          {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Datatype> tupleType(List<Build<Datatype>> components,
          {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Build<Datatype> errorType(LocatedError error, {Location location}) =>
      (BuildContext ctxt) {
        return null;
      };

  Name termName(String name, {Location location}) {
    return Name(name, location);
  }

  Name typeName(String name, {Location location}) {
    return Name(name, location);
  }

  Name errorName(LocatedError error, {Location location}) {
    return null;
  }
}

// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../builtins.dart' as builtins;
import '../deriving.dart';
import '../errors/errors.dart';
import '../fp.dart';
import '../location.dart';
import '../immutable_collections.dart';
import '../module_environment.dart';
import '../result.dart';

import '../syntax/elaboration.dart' show ModuleElaborator, TypeElaborator;
import '../syntax/sexp.dart';
import '../typing/type_utils.dart' as typeUtils
    show boolType, intType, stringType, extractQuantifiers;

import '../unicode.dart' as unicode;

import 'algebra.dart';
import 'ast.dart';

class Name {
  final Location location;
  final int intern;
  final String sourceName;
  String get fullName => sourceName;

  Name(this.sourceName, this.location) : intern = computeIntern(sourceName);
  Name.synthesise(Binder binder)
      : intern = computeIntern(binder.sourceName),
        location = binder.location,
        sourceName = binder.sourceName;

  String toString() {
    return "$fullName"; //:$location";
  }

  static int computeIntern(String name) {
    if (name != null)
      return name.hashCode;
    else
      return 0;
  }
}

class QualifiedName extends Name {
  final String module;
  String get fullName => "$module.$sourceName";

  QualifiedName(this.module, String sourceName, Location location)
      : super(sourceName, location);
}

class BuildContext {
  final ImmutableMap<int, Declaration> declarations;
  final ImmutableMap<int, Quantifier> quantifiers;
  final ImmutableMap<int, Signature> signatures;
  final ImmutableMap<int, TypeDescriptor> typenames;
  // final Map<int, ClassDescriptor> classes;

  BuildContext(
      this.declarations, this.quantifiers, this.signatures, this.typenames);
  BuildContext.empty()
      : this(
            ImmutableMap<int, Declaration>.empty(),
            ImmutableMap<int, Quantifier>.empty(),
            ImmutableMap<int, Signature>.empty(),
            ImmutableMap<int, TypeDescriptor>.empty());

  factory BuildContext.fromSummary(Summary summary) {
    ImmutableMap<int, Declaration> decls =
        ImmutableMap<int, Declaration>.of(summary.valueBindings);
    ImmutableMap<int, TypeDescriptor> descriptors =
        ImmutableMap<int, TypeDescriptor>.of(summary.typeDescriptors);
    return BuildContext(decls, ImmutableMap<int, Quantifier>.empty(),
        ImmutableMap<int, Signature>.empty(), descriptors);
  }

  // ClassDescriptor getClass(Name name) {
  //   return classes[name.intern];
  // }

  Declaration getDeclaration(Name name) {
    return declarations.lookup(name.intern);
  }

  BuildContext putDeclaration(Name name, Declaration declaration) {
    return BuildContext(declarations.put(name.intern, declaration), quantifiers,
        signatures, typenames);
  }

  Signature getSignature(Name name) {
    if (name == null) return null;
    return signatures.lookup(name.intern);
  }

  BuildContext putSignature(Name name, Signature signature) {
    if (name == null) return this;
    return BuildContext(declarations, quantifiers,
        signatures.put(name.intern, signature), typenames);
  }

  TypeDescriptor getTypeDescriptor(Name name) {
    if (name == null) return null;
    return typenames.lookup(name.intern);
  }

  BuildContext putTypeDescriptor(Name name, TypeDescriptor desc) {
    if (name == null) return this;
    return BuildContext(declarations, quantifiers, signatures,
        typenames.put(name.intern, desc));
  }

  Quantifier getQuantifier(Name name) {
    if (name == null) return null;
    return quantifiers.lookup(name.intern);
  }

  BuildContext putQuantifier(Name name, Quantifier quantifier) {
    if (name == null) return this;
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

  BuildContext include(Manifest manifest) {
    BuildContext other = BuildContext.fromSummary(manifest.summary);
    return this.union(other);
  }
}

class OutputBuildContext extends BuildContext {
  final List<Name> declaredNames;

  OutputBuildContext(this.declaredNames, BuildContext ctxt)
      : super(ctxt.declarations, ctxt.quantifiers, ctxt.signatures,
            ctxt.typenames);
}

class ASTBuilder {
  Result<ModuleMember, LocatedError> build(
      Sexp program, ModuleEnvironment moduleEnv, bool isVirtual,
      [BuildContext context]) {
    if (context == null) {
      context = BuildContext.empty();
    }
    if (moduleEnv.prelude != null) {
      context = context.include(moduleEnv.prelude.manifest);
    }

    _ASTBuilder builder =
        new _ASTBuilder(initialEnv: moduleEnv, isVirtual: isVirtual);

    ModuleMember module =
        new ModuleElaborator(builder).elaborate(program)(context).snd;

    Result<ModuleMember, LocatedError> result;
    if (builder.errors.length > 0) {
      result = Result<ModuleMember, LocatedError>.failure(builder.errors);
    } else {
      result = Result<ModuleMember, LocatedError>.success(module);
    }
    return result;
  }

  Result<Datatype, LocatedError> buildDatatype(Sexp type,
      {ModuleEnvironment moduleEnv,
      TopModule origin,
      bool isVirtual = false,
      BuildContext context}) {
    if (context == null) {
      context = BuildContext.empty();
    }
    if (origin == null) {
      throw ArgumentError.notNull("origin");
    }
    _ASTBuilder builder = new _ASTBuilder(
        initialEnv: moduleEnv, origin: origin, isVirtual: isVirtual);
    Datatype datatype =
        new TypeElaborator(builder).elaborate(type)(context).snd;
    Result<Datatype, LocatedError> result;
    if (builder.errors.length > 0) {
      result = Result<Datatype, LocatedError>.failure(builder.errors);
    } else {
      result = Result<Datatype, LocatedError>.success(datatype);
    }
    return result;
  }
}

typedef Build<T> = Pair<BuildContext, T> Function(BuildContext);

// builder : (BuildContext) -> (BuildContext * node)
// forall ctxt \in BuildContext. builder(ctxt) = (ctxt',_) such that |ctxt'| >= |ctxt|.
class _ASTBuilder extends TAlgebra<Name, Build<ModuleMember>, Build<Expression>,
    Build<Pattern>, Build<Datatype>> {
  final List<LocatedError> errors = new List<LocatedError>();
  final List<Signature> lacksAccompanyingDefinition = new List<Signature>();
  final BuildContext emptyContext = new BuildContext.empty();
  final bool _isVirtual;
  TopModule _thisModule;
  ModuleEnvironment _moduleEnv;
  FunctionDeclaration mainCandidate;

  _ASTBuilder(
      {ModuleEnvironment initialEnv, TopModule origin, bool isVirtual = false})
      : _moduleEnv = initialEnv,
        _thisModule = origin,
        _isVirtual = isVirtual;

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
    context = result.fst;
    if (context is OutputBuildContext) {
      OutputBuildContext ctxt0 = context;
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
          buildPattern(parameters[i], context) as Triple<
              BuildContext,
              List<Name>,
              Pattern>; // This cast seems to be necessary to silence the
      // analyzer. It claims that [buildPattern] returns a
      // value of type [Triple<BuildContext, List<Name>,
      // dynamic>].
      ctxt0 = ctxt0.union(result.fst);
      declaredNames.addAll(result.snd);
      parameters0.add(result.thd);
    }
    return Triple<BuildContext, List<Name>, List<Pattern>>(
        ctxt0, declaredNames, parameters0);
  }

  List<Name> checkDuplicates(List<Name> names) {
    if (names == null) return const <Name>[];
    Set<int> uniqueNames = new Set<int>();
    List<Name> dups = new List<Name>();
    for (int i = 0; i < names.length; i++) {
      Name name = names[i];
      if (uniqueNames.contains(name.intern)) {
        dups.add(names[i]);
      } else {
        uniqueNames.add(name.intern);
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
    List<Quantifier> quantifiers = typeUtils.extractQuantifiers(sig.type);
    for (int i = 0; i < quantifiers.length; i++) {
      context = context.putQuantifier(
          Name.synthesise(quantifiers[i].binder), quantifiers[i]);
    }
    return context;
  }

  Binder binderOf(Name name) {
    if (name == null) {
      return Binder.fresh(_thisModule);
    } else {
      return Binder.fromSource(_thisModule, name.sourceName, name.location);
    }
  }

  Pair<BuildContext, T> addError<T>(LocatedError error, T node) {
    errors.add(error);
    return Pair<BuildContext, T>(emptyContext, node);
  }

  Pair<BuildContext, ModuleMember> moduleError(
      LocatedError error, Location location) {
    return addError<ModuleMember>(error, ErrorModule(error, location));
  }

  Pair<BuildContext, Expression> expressionError(
      LocatedError error, Location location) {
    return addError<Expression>(error, ErrorExpression(error, location));
  }

  Pair<BuildContext, Pattern> patternError(
      LocatedError error, Location location) {
    errors.add(error);
    return Pair<BuildContext, Pattern>(
        OutputBuildContext(const <Name>[], emptyContext),
        new ErrorPattern(error, location));
  }

  Pair<BuildContext, Datatype> typeError(
      LocatedError error, Location location) {
    return addError<Datatype>(error, new ErrorType(error, location));
  }

  Build<ModuleMember> datatypes(
          List<
                  Quadruple<Name, List<Name>,
                      List<Pair<Name, List<Build<Datatype>>>>, List<Name>>>
              defs,
          {Location location}) =>
      (BuildContext ctxt) {
        // Two pass algorithm:
        // 1) construct a partial data type descriptor for each data type in the
        // binding group.
        // 2) construct the data constructors and attach them to their type
        // descriptors.

        // Context shared amongst definitions
        BuildContext sharedContext = ctxt;
        // Declared type names.
        List<Name> declaredTypes = new List<Name>();
        // First pass.
        // Build each datatype definition.
        List<DatatypeDescriptor> descs = new List<DatatypeDescriptor>();
        for (int i = 0; i < defs.length; i++) {
          Quadruple<Name, List<Name>, List<Pair<Name, List<Build<Datatype>>>>,
              List<Name>> def = defs[i];
          // Create a binder for name.
          Name name = def.fst;
          Binder binder = binderOf(name);
          // Check for duplicate parameters.
          List<Name> typeParameters = def.snd;
          List<Name> dups = checkDuplicates(typeParameters);
          if (dups.length > 0) {
            return reportDuplicates(dups, moduleError);
          }
          // Transform the parameters.
          List<Quantifier> quantifiers = new List<Quantifier>();
          for (int i = 0; i < typeParameters.length; i++) {
            Quantifier q = Quantifier.of(binderOf(typeParameters[i]));
            quantifiers.add(q);
          }
          // Create a partial type descriptor.
          DatatypeDescriptor desc =
              DatatypeDescriptor.partial(binder, quantifiers, location);
          // Bind the (partial) descriptor in the context.
          sharedContext = sharedContext.putTypeDescriptor(name, desc);
          // Remember the type descriptor.
          descs.add(desc);
          declaredTypes.add(name);
        }

        // Check for duplicate names.
        List<Name> dups = checkDuplicates(declaredTypes);
        if (dups.length > 0) {
          return reportDuplicates(dups, moduleError);
        }

        // Second pass.
        // Declared constructor names.
        List<Name> declaredNames = new List<Name>();
        // Construct the data constructors.
        for (int i = 0; i < descs.length; i++) {
          Quadruple<Name, List<Name>, List<Pair<Name, List<Build<Datatype>>>>,
              List<Name>> def = defs[i];
          List<Name> typeParameters = def.snd;
          DatatypeDescriptor desc = descs[i];
          // Expose the quantifiers.
          List<Quantifier> quantifiers = desc.parameters;
          BuildContext ctxt0 = sharedContext;
          for (int j = 0; j < quantifiers.length; j++) {
            ctxt0 = ctxt0.putQuantifier(typeParameters[j], quantifiers[j]);
          }
          // Build the data constructors.
          List<Pair<Name, List<Build<Datatype>>>> constructors = def.thd;
          List<DataConstructor> dataConstructors = new List<DataConstructor>();
          for (int j = 0; j < constructors.length; j++) {
            Pair<Name, List<Build<Datatype>>> constr = constructors[j];
            // Create a binder for the name.
            Name constrName = constr.fst;
            Binder constrBinder = binderOf(constrName);
            declaredNames.add(constrName);
            // Build each datatype
            List<Build<Datatype>> types = constr.snd;
            List<Datatype> types0 = new List<Datatype>();
            for (int k = 0; k < types.length; k++) {
              types0.add(forgetfulBuild<Datatype>(types[k], ctxt0));
            }
            // Construct the data constructor node.
            DataConstructor dataConstructor =
                DataConstructor(constrBinder, types0, constrName.location);
            dataConstructor.declarator = desc;
            dataConstructors.add(dataConstructor);
            // Add the constructor to the shared context.
            sharedContext =
                sharedContext.putDeclaration(constrName, dataConstructor);
          }
          // Attach the data constructors to the descriptor.
          desc.constructors = dataConstructors;

          // Build the deriving clause.
          List<Name> deriving = def.fourth;
          Set<Derivable> deriving0 = new Set<Derivable>();
          for (int i = 0; i < deriving.length; i++) {
            Derivable derivable = Derivable.fromString(deriving[i].sourceName);
            if (derivable == null) {
              LocatedError err = UnsupportedDerivableError(
                  deriving[i].sourceName, deriving[i].location);
              return moduleError(err, deriving[i].location);
            } else {
              // Construct a virtual declaration corresponding to the derived
              // operator.
              String surfaceName =
                  derivable.surfaceName(desc.binder.sourceName);
              Datatype type = derivable.computeType(desc);
              VirtualFunctionDeclaration decl =
                  VirtualFunctionDeclaration(_thisModule, surfaceName, type);

              deriving0.add(derivable);
              sharedContext = sharedContext.putDeclaration(
                  Name(surfaceName, decl.binder.location), decl);
            }
          }
          // Attach derivables to the descriptor.
          desc.deriving = deriving0;
        }

        // Check for duplicate data constructors names.
        dups = checkDuplicates(declaredNames);
        if (dups.length > 0) {
          return reportDuplicates(dups, moduleError);
        }

        // Construct the datatypes node.
        DatatypeDeclarations datatypeDeclarations =
            DatatypeDeclarations(descs, location);

        return Pair<BuildContext, ModuleMember>(
            sharedContext, datatypeDeclarations);
      };

  Build<ModuleMember> stub(Name name, List<Build<Pattern>> parameters,
          {Location location}) =>
      (BuildContext ctxt) {
        if (!_isVirtual) {
          // Stub definitions are only allowed in virtual modules.
          LocatedError err =
              StubInNonVirtualModuleError(name.sourceName, name.location);
          return moduleError(err, location);
        }

        // Lookup the signature.
        Signature sig = ctxt.getSignature(name);
        if (sig == null) {
          // Signal an error.
          LocatedError err =
              MissingAccompanyingSignatureError(name.sourceName, name.location);
          return moduleError(err, location);
        }

        ModuleMember member;
        if (parameters == null) {
          // Value stub.
          member = VirtualValueDeclaration.stub(sig, binderOf(name));
        } else {
          // Function stub.
          member = VirtualFunctionDeclaration.stub(sig, binderOf(name));
        }

        // Register [member] as a consumer of [sig].
        sig.addDefinition(member as Declaration);

        return Pair<BuildContext, ModuleMember>(ctxt, member);
      };

  Build<ModuleMember> valueDef(Name name, Build<Expression> body,
          {Location location}) =>
      (BuildContext ctxt) {
        // Lookup the signature.
        Signature sig = ctxt.getSignature(name);
        if (sig == null) {
          // Signal an error.
          LocatedError err =
              MissingAccompanyingSignatureError(name.sourceName, name.location);
          return moduleError(err, location);
        }
        // Expose quantifiers.
        BuildContext ctxt0 = exposeQuantifiers(sig, ctxt);

        // Build the body.
        Expression body0 = forgetfulBuild<Expression>(body, ctxt0);

        // Create the declaration.
        ValueDeclaration member =
            new ValueDeclaration(sig, binderOf(name), body0, location);

        // Register [member] as a consumer of [sig].
        sig.addDefinition(member);

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
              MissingAccompanyingSignatureError(name.sourceName, name.location);
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

        // Register [member] as a consumer of [sig].
        sig.addDefinition(member);

        // Create the output context.
        ctxt = ctxt.putDeclaration(name, member);

        // Determine whether this function is a main function.
        if (member.binder.sourceName == "transform") {
          mainCandidate = member;
        }
        return Pair<BuildContext, ModuleMember>(ctxt, member);
      };

  Build<ModuleMember> module(List<Build<ModuleMember>> members, String name,
          {Location location}) =>
      (BuildContext ctxt) {
        assert(_thisModule == null);
        // Construct the module.
        List<ModuleMember> members0 = new List<ModuleMember>();
        _thisModule = _isVirtual
            ? VirtualModule(name, members: members0, location: location)
            : TopModule(members0, name, location);

        // Build each member.
        for (int i = 0; i < members.length; i++) {
          Pair<BuildContext, ModuleMember> result =
              build<ModuleMember>(members[i], ctxt);
          // Update the context.
          if (result.fst != emptyContext) ctxt = result.fst;
          // Only include non-null members. Members like signatures and open become null.
          if (result.snd != null) {
            members0.add(result.snd);
          }
        }

        // Signal an error for every signature without an accompanying
        // definition.
        for (int i = 0; i < lacksAccompanyingDefinition.length; i++) {
          Signature sig = lacksAccompanyingDefinition[i];
          LocatedError err = MissingAccompanyingDefinitionError(
              sig.binder.sourceName, sig.binder.location);
          errors.add(err);
          members0.add(ErrorModule(err, sig.location));
        }
        List<Signature> sigs = ctxt.signatures.entries
            .map((MapEntry<int, Signature> e) => e.value)
            .toList();
        for (int i = 0; i < sigs.length; i++) {
          Signature sig = sigs[i];
          if (sig.definitions.length == 0) {
            LocatedError err = MissingAccompanyingDefinitionError(
                sig.binder.sourceName, sig.binder.location);
            errors.add(err);
            members0.add(ErrorModule(err, sig.location));
          }
        }

        _thisModule.main = mainCandidate;
        return Pair<BuildContext, ModuleMember>(ctxt, _thisModule);
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
        // Check whether there already exists a signature with [name], and whether
        // it has any associated definitions.
        if (ctxt.getSignature(name) != null) {
          Signature sig = ctxt.getSignature(name);
          if (sig.definitions.length == 0) {
            lacksAccompanyingDefinition.add(sig);
          }
        }
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

  Build<ModuleMember> open(String moduleName, {Location location}) =>
      (BuildContext ctxt) {
        // Lookup [moduleName].
        TopModule module = _moduleEnv.find(moduleName);
        if (module != null) {
          ctxt = ctxt.include(module.manifest);
        } else {
          moduleError(UnboundModuleError(moduleName, location), location);
          return Pair<BuildContext, ModuleMember>(ctxt, null);
        }
        return Pair<BuildContext, ModuleMember>(ctxt, null);
      };

  Build<ModuleMember> errorModule(LocatedError error, {Location location}) =>
      (BuildContext ctxt) {
        return moduleError(error, location);
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

  Declaration findDeclaration(Name name, BuildContext ctxt) {
    if (name is QualifiedName) {
      QualifiedName qname = name;
      TopModule module = _moduleEnv.find(qname.module);
      if (module == null) return null;
      return module.manifest.findByName(name.sourceName);
    } else {
      return ctxt.getDeclaration(name);
    }
  }

  Build<Expression> varExp(Name name, {Location location}) =>
      (BuildContext ctxt) {
        // Lookup the declaration.
        Declaration declarator = findDeclaration(name, ctxt);
        if (declarator == null) {
          // Signal error.
          LocatedError err = UnboundNameError(name.fullName, location);
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
          arguments0.add(exp);
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
        // Copy the context.
        BuildContext ctxt0 = ctxt;
        List<Binding> bindings0 = new List<Binding>();
        List<Name> declaredNames;
        switch (bindingMethod) {
          case BindingMethod.Parallel:
            {
              // Build the patterns and their bodies in parallel, i.e. under the original context.
              List<BuildContext> contexts;
              for (int i = 0; i < bindings.length; i++) {
                // Build the body under the original context.
                Expression body =
                    forgetfulBuild<Expression>(bindings[i].snd, ctxt);

                // Build the pattern.
                Triple<BuildContext, List<Name>, Pattern> result =
                    buildPattern(bindings[i].fst, ctxt);
                ctxt0 = result.fst;
                if (declaredNames == null) {
                  declaredNames = result.snd;
                  contexts = <BuildContext>[ctxt0];
                } else {
                  declaredNames.addAll(result.snd);
                  contexts.add(ctxt0);
                }

                // Construct the binding node.
                bindings0.add(new Binding(result.thd, body));
              }
              // Merge the declaration contexts.
              ImmutableMap<int, Declaration> decls = ctxt.declarations;
              for (int i = 0; i < contexts.length; i++) {
                decls = decls.union(contexts[i].declarations);
              }
              ctxt0 = BuildContext(
                  decls, ctxt.quantifiers, ctxt.signatures, ctxt.typenames);
              break;
            }
          case BindingMethod.Sequential:
            {
              // Build the patterns and their bodies sequentially, i.e. increase the
              // context monotonically.
              for (int i = 0; i < bindings.length; i++) {
                // Build the body under the current (declaration) context.
                Expression body =
                    forgetfulBuild<Expression>(bindings[i].snd, ctxt0);
                // Build the pattern under the current (declaration) context.
                Triple<BuildContext, List<Name>, Pattern> result =
                    buildPattern(bindings[i].fst, ctxt0);
                // TODO allow shadowing of sequential names.
                if (declaredNames == null) {
                  declaredNames = result.snd;
                } else {
                  declaredNames.addAll(result.snd);
                }

                // Update the declaration context.
                ctxt0 = BuildContext(
                    ctxt0.declarations.union(result.fst.declarations),
                    ctxt0.quantifiers,
                    ctxt0.signatures,
                    ctxt0.typenames);

                // Construct the binding node.
                bindings0.add(new Binding(result.thd, body));
              }
              break;
            }
        }

        // Check for duplicate declarations.
        if (declaredNames != null) {
          List<Name> dups = checkDuplicates(declaredNames);
          if (dups.length > 0) {
            return reportDuplicates(dups, expressionError);
          }
        }

        // Build the continuation (body).
        Expression body0 = forgetfulBuild<Expression>(body, ctxt0);

        // Construct the let node.
        Let let = new Let(bindings0, body0, location);

        return new Pair<BuildContext, Expression>(ctxt, let);
      };

  Build<Expression> tuple(List<Build<Expression>> components,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build each component.
        List<Expression> components0 = new List<Expression>();
        for (int i = 0; i < components.length; i++) {
          components0.add(forgetfulBuild<Expression>(components[i], ctxt));
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
        // Build the [scrutinee].
        Expression scrutinee0 = forgetfulBuild<Expression>(scrutinee, ctxt);

        // Build the [cases].
        List<Case> cases0 = new List<Case>();
        for (int i = 0; i < cases.length; i++) {
          // Build the pattern first.
          Triple<BuildContext, List<Name>, Pattern> result =
              buildPattern(cases[i].fst, ctxt);
          BuildContext ctxt0 = result.fst;
          // Check for duplicates.
          List<Name> dups = checkDuplicates(result.snd);
          if (dups.length > 0) {
            return reportDuplicates(dups, expressionError);
          }
          // Build the right hand side.
          Expression rhs = forgetfulBuild<Expression>(cases[i].snd, ctxt0);

          // Construct the case.
          cases0.add(new Case(result.thd, rhs));
        }

        // Construct the match node.
        Match match = new Match(scrutinee0, cases0, location);
        return Pair<BuildContext, Expression>(ctxt, match);
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
      (BuildContext ctxt) => expressionError(error, location);

  Build<Pattern> hasTypePattern(Build<Pattern> pattern, Build<Datatype> type,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build the [type].
        Datatype type0 = forgetfulBuild<Datatype>(type, ctxt);
        // Build the [pattern].
        Triple<BuildContext, List<Name>, Pattern> result =
            buildPattern(pattern, ctxt);

        // Construct the has type node.
        HasTypePattern hasType =
            new HasTypePattern(result.thd, type0, location);
        return Pair<BuildContext, Pattern>(result.fst, hasType);
      };

  Build<Pattern> boolPattern(bool b, {Location location}) =>
      (BuildContext ctxt) {
        // Construct the output context.
        BuildContext ctxt0 = new OutputBuildContext(const <Name>[], ctxt);
        // Construct the bool pattern node.
        BoolPattern pattern = new BoolPattern(b, location);
        return Pair<BuildContext, Pattern>(ctxt0, pattern);
      };

  Build<Pattern> intPattern(int n, {Location location}) => (BuildContext ctxt) {
        // Construct the output context.
        BuildContext ctxt0 = new OutputBuildContext(const <Name>[], ctxt);
        // Construct the int pattern node.
        IntPattern pattern = new IntPattern(n, location);
        return Pair<BuildContext, Pattern>(ctxt0, pattern);
      };

  Build<Pattern> stringPattern(String s, {Location location}) =>
      (BuildContext ctxt) {
        // Construct the output context.
        BuildContext ctxt0 = new OutputBuildContext(const <Name>[], ctxt);
        // Construct the string pattern node.
        StringPattern pattern = new StringPattern(s, location);
        return Pair<BuildContext, Pattern>(ctxt0, pattern);
      };

  Build<Pattern> wildcard({Location location}) => (BuildContext ctxt) {
        // Construct the output context.
        BuildContext ctxt0 = new OutputBuildContext(const <Name>[], ctxt);
        // Construct the wild card pattern node.
        WildcardPattern pattern = new WildcardPattern(location);
        return Pair<BuildContext, Pattern>(ctxt0, pattern);
      };

  Build<Pattern> varPattern(Name name, {Location location}) =>
      (BuildContext ctxt) {
        // Construct the var pattern node.
        VariablePattern pattern = new VariablePattern(binderOf(name), location);

        // Construct the output context.
        ctxt = ctxt.putDeclaration(name, pattern);
        BuildContext ctxt0 = new OutputBuildContext(<Name>[name], ctxt);
        return Pair<BuildContext, Pattern>(ctxt0, pattern);
      };

  Build<Pattern> constrPattern(Name name, List<Build<Pattern>> parameters,
          {Location location}) =>
      (BuildContext ctxt) {
        // Check that the [name] refers to data constructor in the current scope.
        Declaration decl = findDeclaration(name, ctxt);
        if (decl is! DataConstructor) {
          LocatedError err =
              UnboundConstructorError(name.sourceName, name.location);
          return patternError(err, location);
        }
        // Copy the original context.
        BuildContext ctxt0 = ctxt;
        // Build each subpattern.
        List<Pattern> parameters0 = new List<Pattern>();
        List<Name> declaredNames = new List<Name>();
        for (int i = 0; i < parameters.length; i++) {
          Triple<BuildContext, List<Name>, Pattern> result =
              buildPattern(parameters[i], ctxt);
          parameters0.add(result.thd);
          declaredNames.addAll(result.snd);
          // Update the context.
          ctxt0 = ctxt0.union(result.fst);
        }
        // Check duplicates.
        List<Name> dups = checkDuplicates(declaredNames);
        if (dups.length > 0) {
          return reportDuplicates(dups, patternError);
        }

        // Construct the constructor node.
        ConstructorPattern constr = new ConstructorPattern(
            decl as DataConstructor, parameters0, location);

        // Construct the output context.
        OutputBuildContext ctxt1 = new OutputBuildContext(declaredNames, ctxt0);

        return Pair<BuildContext, Pattern>(ctxt1, constr);
      };

  Build<Pattern> tuplePattern(List<Build<Pattern>> components,
          {Location location}) =>
      (BuildContext ctxt) {
        // Copy the original context.
        BuildContext ctxt0 = ctxt;
        // Build each subpattern.
        List<Pattern> components0 = new List<Pattern>();
        List<Name> declaredNames = new List<Name>();
        for (int i = 0; i < components.length; i++) {
          Triple<BuildContext, List<Name>, Pattern> result =
              buildPattern(components[i], ctxt)
                  as Triple<BuildContext, List<Name>, Pattern>;
          components0.add(result.thd);
          declaredNames.addAll(result.snd);
          // Update the context.
          ctxt0 = ctxt0.union(result.fst);
        }
        // Check duplicates.
        List<Name> dups = checkDuplicates(declaredNames);
        if (dups.length > 0) {
          return reportDuplicates(dups, patternError);
        }

        // Construct the tuple node.
        TuplePattern tuple = new TuplePattern(components0, location);

        // Construct the output context.
        OutputBuildContext ctxt1 = new OutputBuildContext(declaredNames, ctxt0);

        return Pair<BuildContext, Pattern>(ctxt1, tuple);
      };

  Build<Pattern> errorPattern(LocatedError error, {Location location}) =>
      (BuildContext ctxt) {
        return patternError(error, location);
      };

  Build<Datatype> intType({Location location}) => (BuildContext ctxt) {
        return Pair<BuildContext, Datatype>(ctxt, typeUtils.intType);
      };

  Build<Datatype> boolType({Location location}) => (BuildContext ctxt) {
        return Pair<BuildContext, Datatype>(ctxt, typeUtils.boolType);
      };

  Build<Datatype> stringType({Location location}) => (BuildContext ctxt) {
        return Pair<BuildContext, Datatype>(ctxt, typeUtils.stringType);
      };

  Build<Datatype> typeVar(Name name, {Location location}) =>
      (BuildContext ctxt) {
        // Look up the declarator.
        Quantifier quantifier = ctxt.getQuantifier(name);
        TypeVariable v;
        // Construct the type variable node.
        if (quantifier == null) {
          //v = new TypeVariable();
          // TODO do not eagerly throw an error.
          LocatedError err = UnboundNameError(name.sourceName, location);
          return typeError(err, location);
        } else {
          v = new TypeVariable.bound(quantifier);
        }

        return Pair<BuildContext, Datatype>(ctxt, v);
      };

  Build<Datatype> forallType(List<Name> quantifiers, Build<Datatype> type,
          {Location location}) =>
      (BuildContext ctxt) {
        // Copy the original context.
        BuildContext ctxt0 = ctxt;
        // Transform [quantifiers].
        List<Quantifier> quantifiers0 = new List<Quantifier>();
        for (int i = 0; i < quantifiers.length; i++) {
          Name name = quantifiers[i];
          Quantifier q = Quantifier.of(binderOf(name));
          quantifiers0.add(q);
          ctxt0 = ctxt0.putQuantifier(name, q);
        }
        // Build the [type].
        Datatype type0 = forgetfulBuild<Datatype>(type, ctxt0);

        // Construct the forall type node.
        ForallType forallType = ForallType();
        forallType.quantifiers = quantifiers0;
        forallType.body = type0;

        return Pair<BuildContext, Datatype>(ctxt, forallType);
      };

  Build<Datatype> arrowType(
          List<Build<Datatype>> domain, Build<Datatype> codomain,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build the [domain].
        List<Datatype> domain0 = new List<Datatype>();
        for (int i = 0; i < domain.length; i++) {
          domain0.add(forgetfulBuild<Datatype>(domain[i], ctxt));
        }
        // Build the [codomain].
        Datatype codomain0 = forgetfulBuild<Datatype>(codomain, ctxt);

        // Construct the arrow type node.
        Datatype arrowType = ArrowType(domain0, codomain0);

        return Pair<BuildContext, Datatype>(ctxt, arrowType);
      };

  Build<Datatype> typeConstr(Name name, List<Build<Datatype>> arguments,
          {Location location}) =>
      (BuildContext ctxt) {
        // Check whether the constructor name is defined.
        TypeDescriptor desc = ctxt.getTypeDescriptor(name);
        if (desc == null) {
          LocatedError err = UnboundNameError(name.sourceName, name.location);
          return typeError(err, location);
        }
        // Build each argument.
        List<Datatype> arguments0 = new List<Datatype>();
        for (int i = 0; i < arguments.length; i++) {
          arguments0.add(forgetfulBuild<Datatype>(arguments[i], ctxt));
        }
        // Construct the constructor type node.
        TypeConstructor constr = new TypeConstructor.from(desc, arguments0);
        return Pair<BuildContext, Datatype>(ctxt, constr);
      };

  Build<Datatype> tupleType(List<Build<Datatype>> components,
          {Location location}) =>
      (BuildContext ctxt) {
        // Build each component.
        List<Datatype> components0 = new List<Datatype>();
        for (int i = 0; i < components.length; i++) {
          components0.add(forgetfulBuild<Datatype>(components[i], ctxt));
        }
        // Construct the tuple type node.
        TupleType tupleType = new TupleType(components0);
        return Pair<BuildContext, Datatype>(ctxt, tupleType);
      };

  Build<Datatype> constraintType(
          List<Pair<Name, Build<Datatype>>> constraints, Build<Datatype> body,
          {Location location}) =>
      (BuildContext ctxt) {
        return null; // TODO.
      };

  Build<Datatype> errorType(LocatedError error, {Location location}) =>
      (BuildContext ctxt) {
        return typeError(error, location);
      };

  Name termName(String name, {Location location}) {
    // Might be a qualified name.
    if (isQualifiedName(name)) {
      Pair<String, String> result = splitQualifiedName(name);
      return QualifiedName(result.fst, result.snd, location);
    } else {
      return Name(name, location);
    }
  }

  Name typeName(String name, {Location location}) {
    // Might be a qualified name.
    if (isQualifiedName(name)) {
      Pair<String, String> result = splitQualifiedName(name);
      return QualifiedName(result.fst, result.snd, location);
    } else {
      return Name(name, location);
    }
  }

  Name errorName(LocatedError error, {Location location}) {
    errors.add(error);
    return null;
  }

  bool isQualifiedName(String name) {
    assert(name != null && name.length > 0);
    int c = name.codeUnitAt(0);
    if (!unicode.isAsciiUpper(c)) return false;

    bool hasDot = false;
    for (int i = 1; i < name.length; i++) {
      c = name.codeUnitAt(i);
      if (c == unicode.DOT) {
        if (hasDot) return false;
        hasDot = true;
      }
    }
    return hasDot;
  }

  Pair<String, String> splitQualifiedName(String name) {
    StringBuffer modulePrefix = StringBuffer();
    StringBuffer identSuffix = StringBuffer();

    int i = 0;
    for (i = 0; i < name.length; i++) {
      int c = name.codeUnitAt(i);
      if (c == unicode.DOT) {
        ++i;
        break;
      }
      modulePrefix.writeCharCode(c);
    }

    for (i; i < name.length; i++) {
      identSuffix.writeCharCode(name.codeUnitAt(i));
    }

    return Pair<String, String>(
        modulePrefix.toString(), identSuffix.toString());
  }
}

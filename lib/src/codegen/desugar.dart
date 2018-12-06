// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart' as ast;
import '../ast/datatype.dart';
import '../builtins.dart' show getPrimitive;
import '../errors/errors.dart' show T20Error, unhandled;
import '../result.dart';

import '../typing/type_utils.dart' as typeUtils;

import 'ir.dart';

TypedBinder translateBinder(
    ast.Binder binder, Datatype type, Map<int, TypedBinder> binderContext) {
  TypedBinder result = TypedBinder.of(binder, type);
  binderContext[binder.ident] = result;
  return result;
}

class Desugarer {
  final IRAlgebra alg;
  final PatternCompiler patternCompiler;

  Desugarer(IRAlgebra alg)
      : patternCompiler = new PatternCompiler(alg),
        this.alg = alg;

  Result<IRNode, T20Error> desugar(
      ast.TopModule mod, Map<int, TypedBinder> binderContext) {
    List<Binding> bindings = new List<Binding>();
    for (int i = 0; i < mod.members.length; i++) {
      bindings = module(bindings, mod.members[i], binderContext);
    }
    return Result<IRNode, T20Error>.success(null);
  }

  // TypedBinder freshBinder(Datatype type, Map<int, TypedBinder> binderContext) {
  //   TypedBinder binder = TypedBinder.fresh(type);
  //   binderContext[binder.ident] = binder; // Possibly unnecessary.
  //   return binder;
  // }

  List<Binding> module(List<Binding> bindings, ast.ModuleMember mod,
      Map<int, TypedBinder> binderContext) {
    switch (mod.tag) {
      case ast.ModuleTag.FUNC_DEF:
        return translateFunDecl(
            bindings, mod as ast.FunctionDeclaration, binderContext);
        break;
      case ast.ModuleTag.VALUE_DEF:
        return translateValueDecl(
            bindings, mod as ast.ValueDeclaration, binderContext);
        break;
      case ast.ModuleTag.CONSTR:
        unhandled("Not yet implemented", mod.tag);
        break;
      case ast.ModuleTag.DATATYPE_DEFS:
        unhandled("Not yet implemented", mod.tag);
        break;
      case ast.ModuleTag.TYPENAME:
        unhandled("Not yet implemented", mod.tag);
        break;
      default:
        unhandled("Desugarer.module", mod.tag);
    }

    return null; // Impossible!
  }

  List<Binding> translateFunDecl(List<Binding> bindings,
      ast.FunctionDeclaration fun, Map<int, TypedBinder> binderContext) {
    // Translate the binder.
    TypedBinder binder = translateBinder(fun.binder, fun.type, binderContext);
    // Desugar each parameter.
    List<TypedBinder> parameters = new List<TypedBinder>();
    for (int i = 0; i < fun.parameters.length; i++) {
      ast.Pattern param = fun.parameters[i];
      // Create a fresh binder.
      TypedBinder binder = TypedBinder.fresh(param.type);
      parameters.add(binder);
      // Desugar the pattern and append any new bindings onto [bindings].
      bindings = append(
          patternCompiler.desugar(binder, param, binderContext), bindings);
    }
    // Desugar the body.
    Computation body = expression(fun.body, binderContext);

    // Construct the IR node.
    LetFun letfun = alg.letFunction(binder, parameters, body);

    // Register [letfun] as a global binding.
    bindings = augment(letfun, bindings);
    return bindings;
  }

  List<Binding> translateValueDecl(List<Binding> bindings,
      ast.ValueDeclaration val, Map<int, TypedBinder> binderContext) {
    // Translate the binder.
    TypedBinder binder = translateBinder(val.binder, val.type, binderContext);
    // Translate the body.
    Computation comp = expression(val.body, binderContext);
    // Add new bindings to [bindings].
    bindings = append(comp.bindings, bindings);
    bindings = augment(alg.letValue(binder, comp.tailComputation), bindings);
    return bindings;
  }

  Computation expression(
      ast.Expression expr, Map<int, TypedBinder> binderContext) {
    switch (expr.tag) {
      case ast.ExpTag.BOOL:
        return alg.computation(
            null, alg.return$(alg.boollit((expr as ast.BoolLit).value)));
        break;
      case ast.ExpTag.INT:
        return alg.computation(
            null, alg.return$(alg.intlit((expr as ast.IntLit).value)));
        break;
      case ast.ExpTag.STRING:
        return alg.computation(
            null, alg.return$(alg.stringlit((expr as ast.StringLit).value)));
        break;
      case ast.ExpTag.APPLY:
        return translateApply(expr as ast.Apply, binderContext);
        break;
      case ast.ExpTag.IF:
        return translateIf(expr as ast.If, binderContext);
        break;
      case ast.ExpTag.LAMBDA:
        return translateLambda(expr as ast.Lambda, binderContext);
        break;
      case ast.ExpTag.LET:
        return translateLet(expr as ast.Let, binderContext);
        break;
      case ast.ExpTag.MATCH:
        break;
      case ast.ExpTag.TUPLE:
        return translateTuple(expr as ast.Tuple, binderContext);
        break;
      case ast.ExpTag.VAR:
        int ident = (expr as ast.Variable).ident;
        TypedBinder binder = binderContext[ident];
        if (ident == null) {
          throw "unbound $expr";
        }
        return alg.computation(null, alg.return$(alg.variable(binder)));
        break;
      case ast.ExpTag.TYPE_ASCRIPTION:
        unhandled("Not yet implemented", expr.tag);
        break;
      default:
        unhandled("Desugarer.expression", expr.tag);
    }
    return null; // Impossible.
  }

  Computation translateLambda(
      ast.Lambda lambda, Map<int, TypedBinder> binderContext) {
    // Translate each parameter.
    List<TypedBinder> parameters = new List<TypedBinder>();
    List<Datatype> domain = typeUtils.domain(lambda.type);
    List<Binding> bindings;
    for (int i = 0; i < lambda.parameters.length; i++) {
      // Create a fresh binder.
      TypedBinder binder = TypedBinder.fresh(domain[i]);
      bindings = append(
          patternCompiler.desugar(binder, lambda.parameters[i], binderContext),
          bindings);
      parameters.add(binder);
    }
    // Translate the body.
    Computation body = expression(lambda.body, binderContext);

    return alg.computation(bindings, alg.return$(alg.lambda(parameters, body)));
  }

  Computation translateLet(ast.Let let, Map<int, TypedBinder> binderContext) {
    // Translate value binding.
    List<Binding> bindings = new List<Binding>();
    for (int i = 0; i < let.valueBindings.length; i++) {
      ast.Binding b = let.valueBindings[i];
      // Translate the expression.
      Computation comp = expression(b.expression, binderContext);
      // Append any new bindings.
      bindings = append(comp.bindings, bindings);
      // Generate a fresh binder.
      TypedBinder binder = TypedBinder.fresh(null /* TODO */);
      // Bind the tail computation.
      bindings = augment(alg.letValue(binder, comp.tailComputation), bindings);
      // Translate the pattern.
      bindings = append(
          patternCompiler.desugar(binder, b.pattern, binderContext), bindings);
    }

    // Translate the continuation.
    Computation comp = expression(let.body, binderContext);
    comp.bindings = append(comp.bindings, bindings);
    return comp;
  }

  String tupleLabel(int i) => "\$${i + 1}";

  Computation translateTuple(
      ast.Tuple tuple, Map<int, TypedBinder> binderContext) {
    // Translate each component.
    List<Binding> bindings;
    Map<String, Value> members = new Map<String, Value>();
    for (int i = 0; i < tuple.components.length; i++) {
      Computation comp = expression(tuple.components[i], binderContext);
      bindings = append(comp.bindings, bindings) ?? new List<Binding>();
      members ??= new Map<String, Value>();
      members[tupleLabel(i)] =
          extractValue(bindings, comp.tailComputation, null /* TODO */);
    }
    return alg.computation(bindings, alg.return$(alg.record(members)));
  }

  Computation translateApply(
      ast.Apply apply, Map<int, TypedBinder> binderContext) {
    // First translate the abstractor.
    Computation comp = expression(apply.abstractor, binderContext);
    // Grab the translated abstractor.
    List<Binding> bindings = comp.bindings ?? new List<Binding>();
    Value abstractor =
        extractValue(bindings, comp.tailComputation, null /* TODO */);

    // Translate each argument.
    List<Value> arguments = new List<Value>();
    for (int i = 0; i < apply.arguments.length; i++) {
      comp = expression(apply.arguments[i], binderContext);
      bindings = append(comp.bindings, bindings);
      Value argument =
          extractValue(bindings, comp.tailComputation, null /* TODO */);
      arguments.add(argument);
    }

    // Construct the apply node. Reuse the [comp] object.
    comp.bindings = bindings;
    comp.tailComputation = alg.apply(abstractor, arguments);
    return comp;
  }

  Value extractValue(
      List<Binding> bindings, TailComputation tailComputation, Datatype type) {
    Value v;
    // Micro-optimisation: If the translated condition has the form `Return w'
    // for some value w, then use w directly rather than introducing a new
    // binding.
    if (tailComputation is Return) {
      Return ret = tailComputation;
      v = ret.value;
    } else {
      TypedBinder binder = TypedBinder.fresh(type);
      augment(alg.letValue(binder, tailComputation), bindings);
      v = alg.variable(binder);
    }
    return v;
  }

  Computation translateIf(
      ast.If ifthenelse, Map<int, TypedBinder> binderContext) {
    // Translate the condition.
    Computation comp = expression(ifthenelse.condition, binderContext);
    // Subsequently we need to normalise the translated condition, i.e. extract
    // a value from the tail computation by let binding it.
    Value condition;
    condition =
        extractValue(comp.bindings, comp.tailComputation, typeUtils.boolType);
    // Reuse the computation object.
    comp.tailComputation = alg.ifthenelse(
        condition,
        expression(ifthenelse.thenBranch, binderContext),
        expression(ifthenelse.elseBranch, binderContext));
    return comp;
  }

  List<Binding> augment(Binding binding, List<Binding> bindings) {
    bindings ??= new List<Binding>();
    bindings.add(binding);
    return bindings;
  }

  List<Binding> append(List<Binding> source, List<Binding> destination) {
    if (source == null) return destination;
    if (destination == null) return source;

    destination.addAll(source);
    return destination;
  }
}

class PatternCompiler {
  TailComputation matchFailure;
  IRAlgebra alg;

  PatternCompiler._(this.alg, this.matchFailure);
  factory PatternCompiler(IRAlgebra alg) {
    TailComputation matchFailure = alg.apply(getPrimitive("error"),
        <Value>[alg.stringlit("Pattern match failure.")]);
    return PatternCompiler._(alg, matchFailure);
  }

  List<Binding> desugar(TypedBinder binder, ast.Pattern pattern,
      Map<int, TypedBinder> binderContext) {
    switch (pattern.tag) {
      case ast.PatternTag.BOOL:
      case ast.PatternTag.INT:
      case ast.PatternTag.STRING:
        return basePattern(binder, pattern);
        break;
      case ast.PatternTag.TUPLE:
        break;
      case ast.PatternTag.CONSTR:
        break;
      case ast.PatternTag.HAS_TYPE:
        return desugar(
            binder, (pattern as ast.HasTypePattern).pattern, binderContext);
        break;
      case ast.PatternTag.VAR:
        ast.VariablePattern v = pattern as ast.VariablePattern;
        TypedBinder vb = translateBinder(v.binder, v.type, binderContext);
        return <Binding>[alg.letValue(vb, alg.return$(alg.variable(binder)))];
        break;
      case ast.PatternTag.WILDCARD:
        return const <Binding>[];
        break;
      default:
        unhandled("desugarPattern", pattern.tag);
    }
    return null;
  }

  List<Binding> basePattern(TypedBinder binder, ast.Pattern pattern) {
    Value w;
    Value eq;
    Datatype type;
    if (pattern is ast.BoolPattern) {
      w = alg.boollit(pattern.value);
      type = typeUtils.boolType;
      eq = getPrimitive("bool-eq?");
    } else if (pattern is ast.IntPattern) {
      w = alg.intlit(pattern.value);
      type = typeUtils.intType;
      eq = getPrimitive("int-eq?");
    } else if (pattern is ast.StringPattern) {
      w = alg.stringlit(pattern.value);
      type = typeUtils.stringType;
      eq = getPrimitive("string-eq?");
    } else {
      unhandled("PatternCompiler.basePattern", pattern);
    }

    // Fresh dummy name for the let binding.
    TypedBinder dummy = TypedBinder.fresh(type);

    // [|pat|] = let x = if (eq? y [|pat.value|]) y else error "pattern match failure.".
    LetVal testExp = alg.letValue(
        dummy,
        alg.ifthenelse(
            alg.applyPure(eq, <Value>[alg.variable(binder), w]),
            alg.computation(null, alg.return$(w)),
            alg.computation(null, matchFailure)));

    return <Binding>[testExp];
  }
}

class DecisionTreeCompiler {
  Desugarer desugarer;
  IRAlgebra get alg => desugarer.alg;

  // Compiles a sorted list of base patterns into a well-balanced binary search
  // tree.
  Computation compile(Variable scrutinee, List<ast.Case> cases, int start,
      int end, Computation continuation, Map<int, TypedBinder> binderContext) {
    final int length = end - start + 1;
    // Two base cases:
    // 1) compile _ [] continuation = continuation.
    if (length == 0) return continuation;
    // 2) compile scrutinee [case] continuation = if (eq? scrutinee w) desugar case.body else continuation.
    //                                          where w = [|case.pattern.value|].
    if (length == 1) {
      final int mid = length ~/ 2;
      final ast.Case c = cases[mid];
      final ast.Pattern pat = c.pattern;

      // Immediate match.
      if (pat is ast.VariablePattern) {
        // Bind the scrutinee.
        TypedBinder binder =
            translateBinder(pat.binder, pat.type, binderContext);
        return alg.withBindings(
            <Binding>[alg.letValue(binder, alg.return$(scrutinee))],
            desugarer.expression(c.expression, binderContext));
      } else if (pat is ast.WildcardPattern) {
        return desugarer.expression(c.expression, binderContext);
      }

      // Potential match.
      Value w;
      Value eq;
      if (pat is ast.IntPattern) {
        w = alg.intlit(pat.value);
        eq = getPrimitive("int-eq?");
      } else if (pat is ast.StringPattern) {
        w = alg.stringlit(pat.value);
        eq = getPrimitive("string-eq?");
      } else {
        unhandled("DecisionTreeCompiler.compile", pat);
      }
      Value condition = alg.applyPure(eq, <Value>[scrutinee, w]);

      If testExp = alg.ifthenelse(condition,
          desugarer.expression(c.expression, binderContext), continuation);
      return alg.computation(null, testExp);
    }

    // Inductive case:
    // compile scrutinee cases = (if (= scrutinee w) (compile scrutinee [cmid]) else (if (< scrutinee w) (compile scrutinee left(cases)) else (compile scrutinee right(cases)))).
    //                         where  cmid = cases[cases.length / 2]
    //                                  w = [|cmid.pattern.value|];
    //                         left cases = [ c | c <- cases, c.pattern.value < cmid.pattern.value ]
    //                        right cases = [ c | c <- cases, c.pattern.value > cmid.pattern.value ]
    final int mid = length ~/ 2;
    final ast.Case c = cases[mid];
    final ast.Pattern pat = c.pattern;

    // Immediate match.
    if (pat is ast.VariablePattern || pat is ast.WildcardPattern) {
      // Delegate to the base case.
      return compile(scrutinee, cases, mid, mid, continuation, binderContext);
    }

    // Potential match.
    Value w;
    Value less;
    Value eq;

    if (pat is ast.IntPattern) {
      w = alg.intlit(pat.value);
      less = getPrimitive("int-less?");
      eq = getPrimitive("int-eq?");
    } else if (pat is ast.StringPattern) {
      w = alg.stringlit(pat.value);
      less = getPrimitive("string-less?");
      eq = getPrimitive("string-eq?");
    } else {
      unhandled("DecisionTreeCompiler.compile", pat);
    }

    List<Value> arguments = <Value>[scrutinee, w];
    final If testExp = alg.ifthenelse(
        alg.applyPure(eq, arguments),
        desugarer.expression(c.expression, binderContext),
        alg.computation(
            null,
            alg.ifthenelse(
                alg.applyPure(less, arguments),
                compile(scrutinee, cases, start, mid - 1, continuation,
                    binderContext),
                compile(scrutinee, cases, mid + 1, end, continuation,
                    binderContext))));

    return alg.computation(null, testExp);
  }
}

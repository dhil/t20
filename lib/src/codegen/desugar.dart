// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart' as ast;
import '../ast/datatype.dart';
import '../errors/errors.dart' show T20Error, unhandled;
import '../fp.dart' show Pair;
import '../result.dart';

import '../typing/type_utils.dart' as typeUtils;

import 'ir.dart';

TailComputation matchFailure = Apply(
    null /* TODO look up name for fail/error */,
    <Value>[StringLit("Pattern match failure.")]);

Computation comp(TailComputation tc) => Computation(null, tc);

class Desugarer {
  final IRAlgebra alg;

  Desugarer(this.alg);

  Result<IRNode, T20Error> desugar(ast.TopModule mod) {
    return Result<IRNode, T20Error>.success(null);
  }

  Binding module(ast.ModuleMember mod) {
    switch (mod.tag) {
      case ast.ModuleTag.FUNC_DEF:
        break;
      case ast.ModuleTag.VALUE_DEF:
        break;
      case ast.ModuleTag.CONSTR:
        break;
      case ast.ModuleTag.DATATYPE_DEFS:
        break;
      case ast.ModuleTag.TYPENAME:
        return null;
        break;

      default:
        unhandled("Desugarer.module", mod.tag);
    }

    return null; // Impossible!
  }

  Computation expression(ast.Expression expr) {
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
        return translateApply(expr as ast.Apply);
        break;
      case ast.ExpTag.IF:
        return translateIf(expr as ast.If);
        break;
      case ast.ExpTag.LAMBDA:
        break;
      case ast.ExpTag.LET:
        break;
      case ast.ExpTag.MATCH:
        break;
      case ast.ExpTag.TUPLE:
        return translateTuple(expr as ast.Tuple);
        break;
      case ast.ExpTag.VAR:
        // TODO pass in a context which binds idents to their TypedBinder object.
        break;
      case ast.ExpTag.TYPE_ASCRIPTION:
        break;
      default:
        unhandled("Desugarer.expression", expr.tag);
    }
    return null; // Impossible.
  }

  String tupleLabel(int i) => "\$${i + 1}";

  Computation translateTuple(ast.Tuple tuple) {
    // Translate each component.
    List<Binding> bindings;
    Map<String, Value> members = new Map<String, Value>();
    for (int i = 0; i < tuple.components.length; i++) {
      Computation comp = expression(tuple.components[i]);
      bindings = append(comp.bindings, bindings) ?? new List<Binding>();
      members ??= new Map<String, Value>();
      members[tupleLabel(i)] =
          extractValue(bindings, comp.tailComputation, null /* TODO */);
    }
    return alg.computation(bindings, alg.return$(alg.record(members)));
  }

  Computation translateApply(ast.Apply apply) {
    // First translate the abstractor.
    Computation comp = expression(apply.abstractor);
    // Grab the translated abstractor.
    List<Binding> bindings = comp.bindings ?? new List<Binding>();
    Value abstractor =
        extractValue(bindings, comp.tailComputation, null /* TODO */);

    // Translate each argument.
    List<Value> arguments = new List<Value>();
    for (int i = 0; i < apply.arguments.length; i++) {
      comp = expression(apply.arguments[i]);
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

  Computation translateIf(ast.If ifthenelse) {
    // Translate the condition.
    Computation comp = expression(ifthenelse.condition);
    // Subsequently we need to normalise the translated condition, i.e. extract
    // a value from the tail computation by let binding it.
    Value condition;
    condition =
        extractValue(comp.bindings, comp.tailComputation, typeUtils.boolType);
    // Reuse the computation object.
    comp.tailComputation = alg.ifthenelse(condition,
        expression(ifthenelse.thenBranch), expression(ifthenelse.elseBranch));
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

class SingleBindingDesugarer {
  IRAlgebra alg;

  Pair<TypedBinder, List<Binding>> desugar(ast.Pattern pattern) {
    switch (pattern.tag) {
      case ast.PatternTag.BOOL:
      case ast.PatternTag.INT:
      case ast.PatternTag.STRING:
        return basePattern(pattern);
        break;
      case ast.PatternTag.TUPLE:
        break;
      case ast.PatternTag.CONSTR:
        break;
      case ast.PatternTag.HAS_TYPE:
        return desugar((pattern as ast.HasTypePattern).pattern);
        break;
      case ast.PatternTag.VAR:
        ast.VariablePattern v = pattern as ast.VariablePattern;
        return Pair<TypedBinder, List<Binding>>(
            TypedBinder.of(v.binder, v.type), const <Binding>[]);
        break;
      case ast.PatternTag.WILDCARD:
        return Pair<TypedBinder, List<Binding>>(
            TypedBinder.fresh(pattern.type), const <Binding>[]);
        break;
      default:
        unhandled("desugarPattern", pattern.tag);
    }
    return null;
  }

  Pair<TypedBinder, List<Binding>> basePattern(ast.Pattern pattern) {
    Value w;
    Value eq;
    Datatype type;
    if (pattern is ast.BoolPattern) {
      w = alg.boollit(pattern.value);
      type = typeUtils.boolType;
      eq = null; // TODO lookup.
    } else if (pattern is ast.IntPattern) {
      w = alg.intlit(pattern.value);
      type = typeUtils.intType;
      eq = null;
    } else if (pattern is ast.StringPattern) {
      w = alg.stringlit(pattern.value);
      type = typeUtils.stringType;
      eq = null;
    } else {
      unhandled("SingleBindingDesugarer.basePattern", pattern);
    }

    // Fresh name for the parameter.
    TypedBinder binder = TypedBinder.fresh(type);
    // Fresh dummy name for the let binding.
    TypedBinder dummy = TypedBinder.fresh(type);

    // [|pat|] = let x = if (eq? y [|pat.value|]) y else error "pattern match failure.".
    LetVal testExp = alg.letValue(
        dummy,
        alg.ifthenelse(alg.applyPure(eq, <Value>[alg.variable(binder), w]),
            comp(alg.return$(w)), comp(matchFailure)));

    return Pair<TypedBinder, List<Binding>>(binder, <Binding>[testExp]);
  }
}

class DecisionTreeCompiler {
  Desugarer desugarer;
  IRAlgebra get alg => desugarer.alg;

  // Compiles a sorted list of base patterns into a well-balanced binary search
  // tree.
  Computation compile(Variable scrutinee, List<ast.Case> cases, int start,
      int end, Computation continuation) {
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
        TypedBinder binder = TypedBinder.of(pat.binder, pat.type);
        return alg.withBindings(
            <Binding>[alg.letValue(binder, alg.return$(scrutinee))],
            desugarer.expression(c.expression));
      } else if (pat is ast.WildcardPattern) {
        return desugarer.expression(c.expression);
      }

      // Potential match.
      Value w;
      Value eq;
      if (pat is ast.IntPattern) {
        w = alg.intlit(pat.value);
        eq = null; // TODO lookup.
      } else if (pat is ast.StringPattern) {
        w = alg.stringlit(pat.value);
        eq = null;
      } else {
        unhandled("DecisionTreeCompiler.compile", pat);
      }
      Value condition = alg.applyPure(eq, <Value>[scrutinee, w]);

      If testExp = alg.ifthenelse(
          condition, desugarer.expression(c.expression), continuation);
      return comp(testExp);
    }

    // Inductive case:
    // compile scrutinee cases = (if (< scrutinee w) (compile scrutinee left(cases)) else (if (> scrutinee w) (compile scrutinee right(cases)) else (compile scrutinee [cmid]))).
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
      return compile(scrutinee, cases, mid, mid, continuation);
    }

    // Potential match.
    Value w;
    Value less;
    Value greater;

    if (pat is ast.IntPattern) {
      w = alg.intlit(pat.value);
      less = null; // TODO lookup.
      greater = null;
    } else if (pat is ast.StringPattern) {
      w = alg.stringlit(pat.value);
      less = null;
      greater = null;
    } else {
      unhandled("DecisionTreeCompiler.compile", pat);
    }

    List<Value> arguments = <Value>[scrutinee, w];
    final If testExp = alg.ifthenelse(
        alg.applyPure(less, arguments),
        desugarer.expression(c.expression),
        comp(alg.ifthenelse(
            alg.applyPure(greater, arguments),
            compile(scrutinee, cases, mid + 1, end, continuation),
            compile(scrutinee, cases, mid, mid, continuation))));

    return comp(testExp);
  }
}

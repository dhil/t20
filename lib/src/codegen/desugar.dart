// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ast/ast.dart';
import '../errors/errors.dart' show T20Error, unhandled;
import '../fp.dart' show Pair;
import '../result.dart';

import '../typing/type_utils.dart' as typeUtils;

import 'ir.dart' as ir;

ir.Value applyPure(ir.Value f, List<ir.Value> args) {
  ir.Apply apply = ir.Apply(f, args);
  return ir.ApplyPure(apply);
}

ir.Value equals(ir.Value a, ir.Value b) {
  ir.Value eq = null; // TODO lookup built-in equals;
  return applyPure(eq, <ir.Value>[a, b]);
}

ir.TailComputation matchFailure = ir.Apply(
    null /* TODO look up name for fail/error */,
    <ir.Value>[ir.StringLit("Pattern match failure.")]);

ir.Computation lift(ir.TailComputation tc) => ir.Computation(null, tc);

class Desugarer {
  Result<ir.IRNode, T20Error> desugar(ModuleMember mod) {
    return Result<ir.IRNode, T20Error>.success(null);
  }

  ir.Binding module(ModuleMember mod) {
    return null;
  }

  ir.Computation expression(Expression expr) {
    return null;
  }
}

class SingleBindingDesugarer {
  Pair<ir.TypedBinder, List<ir.Binding>> desugar(Pattern pattern) {
    switch (pattern.tag) {
      case PatternTag.BOOL:
      case PatternTag.INT:
      case PatternTag.STRING:
        return basePattern(pattern);
        break;
      case PatternTag.TUPLE:
        break;
      case PatternTag.CONSTR:
        break;
      case PatternTag.HAS_TYPE:
        return desugar((pattern as HasTypePattern).pattern);
        break;
      case PatternTag.VAR:
        VariablePattern v = pattern as VariablePattern;
        break;
      case PatternTag.WILDCARD:
        return null;
        break;
      default:
        unhandled("desugarPattern", pattern.tag);
    }
    return null;
  }

  Pair<ir.TypedBinder, List<ir.Binding>> basePattern(Pattern pattern) {
    ir.Value value;
    Datatype type;
    if (pattern is BoolPattern) {
      value = ir.BoolLit(pattern.value);
      type = typeUtils.boolType;
    } else if (pattern is IntPattern) {
      value = ir.IntLit(pattern.value);
      type = typeUtils.intType;
    } else if (pattern is StringPattern) {
      value = ir.StringLit(pattern.value);
      type = typeUtils.stringType;
    } else {
      unhandled("ParameterDesugarer.basePattern", pattern);
    }

    // Fresh name for the parameter.
    ir.TypedBinder binder = ir.TypedBinder.fresh(type);
    // Fresh dummy name for the let binding.
    ir.TypedBinder dummy = ir.TypedBinder.fresh(type);

    // Occurrence of [binder].
    ir.Variable y = ir.Variable(binder);
    binder.addOccurrence(y);

    // [|pat|] = let x = if (eq? y [|pat.value|]) y else error "pattern match failure.".
    ir.If ifexp =
        ir.If(equals(y, value), lift(ir.Return(value)), lift(matchFailure));

    ir.Let testExp = ir.Let(dummy, ifexp);
    dummy.bindingSite = testExp;

    return Pair<ir.TypedBinder, List<ir.Binding>>(
        binder, <ir.Binding>[testExp]);
  }

  ir.Literal literal(Object value) {
    if (value is bool) {
      return ir.BoolLit(value);
    } else if (value is int) {
      return ir.IntLit(value);
    } else if (value is String) {
      return ir.StringLit(value);
    } else {
      unhandled("literal", value);
    }

    return null; // Impossible!
  }
}

class DecisionTreeCompiler {
  Desugarer desugarer;
  // Compiles a sorted list of base patterns into a well-balanced binary search
  // tree.
  ir.Computation compile(ir.Variable scrutinee, List<Case> cases, int start,
      int end, ir.Computation continuation) {
    final int length = end - start + 1;
    // Two base cases:
    // 1) compile _ [] continuation = continuation.
    if (length == 0) return continuation;
    // 2) compile scrutinee [case] continuation = if (eq? scrutinee w) desugar case.body else continuation.
    //                                          where w = [|case.pattern.value|].
    if (length == 1) {
      final int mid = length ~/ 2;
      final Case c = cases[mid];
      final Pattern pat = c.pattern;

      // Immediate match.
      if (pat is VariablePattern) {
        // Bind the scrutinee.
        ir.TypedBinder binder = ir.TypedBinder.of(pat.binder, pat.type);
        ir.Let let = ir.Let(binder, ir.Return(scrutinee));
        binder.bindingSite = let;
        ir.Computation comp = desugarer.expression(c.expression);
        return ir.withBindings(<ir.Binding>[let], comp);
      } else if (pat is WildcardPattern) {
        return desugarer.expression(c.expression);
      }

      // Potential match.
      ir.Value value;
      if (pat is IntPattern) {
        value = ir.IntLit(pat.value);
      } else if (pat is StringPattern) {
        value = ir.StringLit(pat.value);
      } else {
        unhandled("DecisionTreeCompiler.compile", pat);
      }
      ir.Value condition = equals(scrutinee, value);

      ir.If testExp = ir.If(
          condition, desugarer.expression(cases[mid].expression), continuation);
      return lift(testExp);
    }

    // Inductive case:
    // compile scrutinee cases = (if (< scrutinee w) (compile scrutinee left(cases)) else (if (> scrutinee w) (compile scrutinee right(cases)) else (compile scrutinee [cmid]))).
    //                         where  cmid = cases[cases.length / 2]
    //                                  w = [|cmid.pattern.value|];
    //                         left cases = [ c | c <- cases, c.pattern.value < cmid.pattern.value ]
    //                        right cases = [ c | c <- cases, c.pattern.value > cmid.pattern.value ]
    final int mid = length ~/ 2;
    final Case c = cases[mid];
    final Pattern pat = c.pattern;

    // Immediate match.
    if (pat is VariablePattern || pat is WildcardPattern) {
      return compile(scrutinee, cases, mid, mid, continuation);
    }

    // Potential match.
    ir.Value w;
    ir.Value less;
    ir.Value greater;

    if (pat is IntPattern) {
      w = ir.IntLit(pat.value);
      less = null; // TODO lookup.
      greater = null;
    } else if (pat is StringPattern) {
      w = ir.StringLit(pat.value);
      less = null;
      greater = null;
    } else {
      unhandled("DecisionTreeCompiler.compile", pat);
    }

    List<ir.Value> arguments = <ir.Value>[scrutinee, w];
    final ir.If testExp = ir.If(
        applyPure(less, arguments),
        desugarer.expression(c.expression),
        lift(ir.If(
            applyPure(greater, arguments),
            compile(scrutinee, cases, mid + 1, end, continuation),
            compile(scrutinee, cases, mid, mid, continuation))));

    return lift(testExp);
  }
}

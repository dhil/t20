// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../errors/errors.dart' show unhandled;
import 'ast.dart';
import 'monoids.dart' show Monoid, SetMonoid;

List<Variable> freeVariables(T20Node node) {
  return ComputeExpressionFreeVariables().compute(node);
}

class ComputePatternBoundNames extends PatternVisitor<void> {
  List<Binder> result;
  ComputePatternBoundNames();

  List<Binder> compute(Pattern pattern) {
    result = new List<Binder>();
    pattern.accept<void>(this);
    return result;
  }

  List<Binder> computeMany(List<Pattern> patterns) {
    result = new List<Binder>();
    many(patterns);
    return result;
  }

  void many(List<Pattern> patterns) {
    for (int i = 0; i < patterns.length; i++) {
      patterns[i].accept<void>(this);
    }
  }

  void visitBool(BoolPattern _) => null;
  void visitInt(IntPattern _) => null;
  void visitString(StringPattern _) => null;
  void visitError(ErrorPattern _) => null;

  void visitHasType(HasTypePattern t) => t.pattern.accept<void>(this);
  void visitConstructor(ConstructorPattern constr) => many(constr.components);
  void visitTuple(TuplePattern t) => many(t.components);

  void visitVariable(VariablePattern v) => result.add(v.binder);
  void visitWildcard(WildcardPattern _) => null;
  void visitObvious(ObviousPattern _) => null;
}

class ComputeExpressionFreeVariables extends ExpressionVisitor<void> {
  Map<int, List<Variable>> freeVariables;

  ComputePatternBoundNames pattern;
  ComputeExpressionFreeVariables() : this.pattern = ComputePatternBoundNames();

  List<Variable> compute(T20Node node) {
    freeVariables = new Map<int, List<Variable>>();
    // TODO this is rather hacky and needs to be cleaned up (and generalised).
    if (node is Expression) {
      node.accept<void>(this);
    } else if (node is Case) {
      visitCase(node);
    } else if (node is MatchClosureCase) {
      visitMatchClosureCase(node);
    } else if (node is MatchClosureDefaultCase) {
      visitMatchClosureDefaultCase(node);
    } else {
      unhandled("ComputeExpressionFreeVariables.compute", node);
    }

    return freeVariables.values
        .fold(Iterable<Variable>.empty(),
              (Iterable<Variable> xs, Iterable<Variable> ys) => xs.followedBy(ys))
        .toList();
  }

  void many(List<Expression> exps) {
    for (int i = 0; i < exps.length; i++) {
      exps[i].accept<void>(this);
    }
  }

  void subtract(List<Binder> binders) {
    for (int i = 0; i < binders.length; i++) {
      subtract1(binders[i]);
    }
  }

  void subtract1(Binder binder) => freeVariables.remove(binder.ident);

  // Literals.
  void visitBool(BoolLit boolean) => null;
  void visitInt(IntLit integer) => null;
  void visitString(StringLit string) => null;

  // Expressions.
  void visitApply(Apply apply) {
    apply.abstractor.accept<void>(this);
    many(apply.arguments);
  }

  void visitIf(If ifthenelse) {
    ifthenelse.condition.accept<void>(this);
    ifthenelse.thenBranch.accept<void>(this);
    ifthenelse.elseBranch.accept<void>(this);
  }

  void visitLambda(Lambda lambda) {
    lambda.body.accept<void>(this);
    List<Binder> boundNames = pattern.computeMany(lambda.parameters);
    subtract(boundNames);
  }

  void visitLet(Let binding) {
    binding.body.accept<void>(this);
    for (int i = binding.valueBindings.length; 0 <= i; i--) {
      Binding b = binding.valueBindings[i];
      b.expression.accept<void>(this);
      List<Binder> boundNames = pattern.compute(b.pattern);
      subtract(boundNames);
    }
  }

  void visitMatch(Match match) {
    for (int i = 0; i < match.cases.length; i++) {
      Case case0 = match.cases[i];
      case0.expression.accept<void>(this);
      List<Binder> boundNames = pattern.compute(case0.pattern);
      subtract(boundNames);
    }
    match.scrutinee.accept<void>(this);
  }

  void visitTuple(Tuple tuple) => many(tuple.components);

  void visitVariable(Variable v) {
    List<Variable> fvs = freeVariables[v.ident];
    if (fvs == null) {
      fvs = <Variable>[v];
      freeVariables[v.ident] = fvs;
    } else {
      fvs.add(v);
    }
  }

  void visitTypeAscription(TypeAscription ascription) =>
      ascription.exp.accept<void>(this);

  void visitError(ErrorExpression e) => null;

  // Desugared nodes.
  void visitDLambda(DLambda lambda) {
    lambda.body.accept<void>(this);
    subtract(lambda.parameters.map((FormalParameter p) => p.binder).toList());
  }

  void visitDLet(DLet let) {
    let.continuation.accept<void>(this);
    let.body.accept<void>(this);
    subtract1(let.binder);
  }

  void visitProject(Project project) => project.receiver.accept<void>(this);

  void visitMatchClosure(MatchClosure clo) => null; // Already a closed value.
  void visitEliminate(Eliminate elim) {
    elim.scrutinee.accept<void>(this);
    elim.closure.accept<void>(this);
  }

  void visitCase(Case case0) {
    case0.expression.accept<void>(this);
    subtract(pattern.compute(case0.pattern));
  }

  void visitMatchClosureCase(MatchClosureCase case0) {
    case0.body.accept<void>(this);
    subtract1(case0.binder);
  }

  void visitMatchClosureDefaultCase(MatchClosureDefaultCase case0) {
    if (case0.isObvious) return;
    case0.body.accept<void>(this);
    subtract1(case0.binder);
  }
}

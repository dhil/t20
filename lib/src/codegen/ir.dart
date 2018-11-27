// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/*
 * The intermediate representation (IR) is an ANF representation of the
 * front-end AST. The IR distinguishes between computations and values (or
 * serious and trivial terms).
 */

abstract class IRVisitor<T> {
  // Computations.
  T visitComputation(Computation comp);

  // Bindings.
  T visitFun(Fun f);
  T visitLet(Let let);

  // Tail computations.
  T visitIf(If ifthenelse);
  T visitApply(Apply apply);
  T visitReturn(Return ret);
}

//===== Computations.

class Computation {
  List<Binding> bindings;
  TailComputation tailComputation;

  Computation(this.bindings, this.tailComputation);

  T accept<T>(IRVisitor<T> v) {
    return v.visitComputation(this);
  }
}

//===== Bindings.
abstract class Binding {}

class Let extends Binding {
  Object binder;
  TailComputation tailComputation;

  Let(this.binder, this.tailComputation);

  T accept<T>(IRVisitor<T> v) {
    return v.visitLet(this);
  }
}

class Fun extends Binding {
  Object type;
  Object binder;
  List<Object> parameters;
  Computation body;

  Fun(this.type, this.binder, this.parameters, this.body);

  T accept<T>(IRVisitor<T> v) {
    return v.visitFun(this);
  }
}

//===== Tail computations.
abstract class TailComputation {}

class Apply extends TailComputation {
  Object abstractor;
  List<Object> arguments;

  Apply(this.abstractor, this.arguments);

  T accept<T>(IRVisitor<T> v) {
    return v.visitApply(this);
  }
}

class If extends TailComputation {
  Object scrutinee;

  T accept<T>(IRVisitor<T> v) {
    return v.visitIf(this);
  }
}

class Return extends TailComputation {
  Object value;

  T accept<T>(IRVisitor<T> v) {
    return v.visitReturn(this);
  }
}

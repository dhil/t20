// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show Map, LinkedList, LinkedListEntry;

import '../ast/datatype.dart';
import '../ast/ast_declaration.dart';
import '../ast/ast_patterns.dart' show VariablePattern;
import '../ast/monoids.dart' show Monoid, LAndMonoid;
import '../utils.dart' show Gensym;

class DatatypeVerifier extends ReduceDatatype<bool> {
  Monoid<bool> get m => LAndMonoid();
  final Set<int> scope;
  DatatypeVerifier(this.scope);

  bool verify(Datatype type) {
    return type.accept<bool>(this);
  }

  bool visitTypeVariable(TypeVariable typeVariable) {
    return scope.contains(typeVariable.ident);
  }

  bool visitSkolem(Skolem skolem) {
    if (skolem.painted) {
      return false;
    }

    skolem.paint();
    bool checkSolution = m.empty;
    if (skolem.isSolved) {
      checkSolution = skolem.type.accept<bool>(this);
    }

    bool inScope =
        scope.contains(skolem.ident) || scope.contains(-skolem.ident);
    skolem.reset();
    return inScope && checkSolution;
  }
}

abstract class ScopedEntry {
  ScopedEntry predecessor;
  ScopedEntry successor;

  int get ident;

  void insertBefore(ScopedEntry entry) {
    // entry' = pred(entry)
    ScopedEntry entry0 = entry.predecessor;

    // succ(this) = entry
    this.successor = entry;
    // pred(entry) = this
    entry.predecessor = this;
    // succ(entry0) = this
    if (entry0 != null) {
      entry0.successor = this;
    }
    // pred(this) = entry'
    this.predecessor = entry0;
  }

  void insertAfter(ScopedEntry entry) {
    // entry' = succ(entry)
    // print("${entry.successor} = succ($entry)");
    ScopedEntry entry0 = entry.successor;

    // pred(this) = entry
    // print("pred($this) = $entry");
    this.predecessor = entry;
    // succ(entry) = this
    // print("succ($entry) = $this");
    entry.successor = this;
    // pred(entry') = this
    // print("pred($entry0) = $this");
    if (entry0 != null) {
      entry0.predecessor = this;
    }
    // succ(this) = entry0
    // print("succ($this) = $entry0");
    this.successor = entry0;
  }

  // Detaches [this] and the subsequent entries from [predecessor].
  void detach() {
    // entry' = pred(this)
    ScopedEntry entry0 = this.predecessor;
    // succ(entry') = null
    if (entry0 != null) {
      entry0.successor = null;
    }
    // pred(this) = null
    this.predecessor = null;
  }

  bool verify(Set<int> scope) => !scope.contains(ident);
}

class Marker extends ScopedEntry {
  final Skolem skolem;
  Marker(this.skolem);

  int get ident => -skolem.ident;

  String toString() {
    return ">$skolem";
  }
}

class Ascription extends ScopedEntry {
  Declaration decl;
  Datatype type;
  int get ident => decl.binder.id;
  Ascription(this.decl, this.type);

  String toString() {
    return "$decl : $type";
  }

  bool verify(Set<int> scope) {
    return !scope.contains(ident) &&
        DatatypeVerifier(scope).verify(type);
  }
}

class QuantifiedVariable extends ScopedEntry {
  Quantifier quantifier;
  int get ident => quantifier.ident;
  QuantifiedVariable(Quantifier quantifier);
}

class Existential extends ScopedEntry {
  final Skolem skolem;
  Datatype solution;
  // Datatype get solution => skolem.type;
  Existential(this.skolem, [Datatype solution]) {
    // if (solution != null) {
    //   skolem.solve(solution);
    // }
    this.solution = solution;
  }

  int get ident => skolem.ident;
  bool get isSolved => solution != null;
  // void solve(Datatype solution) => skolem.solve(solution);
  void solve(Datatype solution) => this.solution = solution;
  // void equate(Existential ex) => skolem.equate(ex.skolem);

  String toString() {
    if (isSolved) {
      return "$skolem = $solution";
    } else {
      return "$skolem";
    }
  }

  bool verify(Set<int> scope) {
    if (!scope.contains(ident)) {
      bool checkSolution =
          isSolved ? DatatypeVerifier(scope).verify(solution) : true;
      return checkSolution;
    } else {
      return false;
    }
  }
}

class OrderedContext extends TransformDatatype {
  ScopedEntry _last;
  Map<int, ScopedEntry> _table;

  int get size => _table.length;

  ScopedEntry get first {
    if (_last == null) return null;

    // Roll back.
    ScopedEntry entry = _last;
    while (entry.predecessor != null) {
      entry = entry.predecessor;
    }
    return entry;
  }

  OrderedContext.empty()
      : _last = null,
        _table = new Map<int, ScopedEntry>();

  void insertLast(ScopedEntry entry) {
    if (_last == null) {
      _last = entry;
    } else {
      entry.insertAfter(_last);
      _last = entry;
    }

    _table[entry.ident] = entry;
  }

  void insertBefore(ScopedEntry entry, ScopedEntry successor) {
    assert(entry != _last);
    if (entry == _last) {
      // I think moving the [_last] entry should be an error.
      _last = successor;
    }
    entry.insertBefore(successor);
    _table[entry.ident] = entry;
  }

  ScopedEntry lookup(int identifier) {
    ScopedEntry entry = _table[identifier];
    assert(entry != null);
    return entry;
  }

  // TODO there might be a clever way to lower the asympotic complexity of this
  // operation.
  ScopedEntry lookupAfter(int identifier, ScopedEntry entry) {
    while (entry != null) {
      if (entry.ident == identifier) break;
      entry = entry.successor;
    }
    return entry;
  }

  // Drops [entry] and everything succeeding it from the context.
  void drop(ScopedEntry entry) {
    ScopedEntry parent = entry;
    assert(_table[parent.ident] != null);
    _last = entry.predecessor;
    entry.detach();
    while (entry != null) {
      _table.remove(entry.ident);
      entry = entry.successor;
    }
    assert(_table[parent.ident] == null);
  }

  // Verifies whether the context is well-founded.
  bool verify() {
    ScopedEntry entry = first;
    Set<int> scope = new Set<int>();
    while (entry != null) {
      if (entry.verify(scope)) {
        scope.add(entry.ident);
        entry = entry.successor;
      } else {
        return false;
      }
    }
    return true;
  }

  // Apply this context as a substitution.
  Datatype apply(Datatype type) {
    return type.accept<Datatype>(this);
  }

  Datatype visitSkolem(Skolem skolem) {
    if (skolem.painted) return skolem;

    ScopedEntry entry = lookup(skolem.ident);
    if (entry == null) {
      return skolem;
    }

    skolem.paint();
    if (entry is Existential) {
      Existential ex = entry;
      Datatype result;
      if (ex.isSolved) {
        result = ex.solution.accept(this);
      } else {
        result = skolem;
      }
      skolem.reset();
      return result;
    } else {
      throw "Logical error: ScopedEntry instance for Skolem $skolem is not an instance of Existential.";
    }
  }

  // Datatype visitTypeVariable(TypeVariable typeVariable) {
  //   ScopedEntry entry = lookup(typeVariable.ident);
  //   if (entry == null) return typeVariable;

  //   if (entry is QuantifiedVariable) {
  //     // No-op.
  //   } else if (entry is TypeAscription) {
  //     TypeAscription ascription = entry;

  //   } else {
  //     throw "Logical error: ScopedEntry instance for TypeVariable $typeVariable is not an instance of either QuantifiedVariable or TypeAscription.";
  //   }
  // }-

  String toString() {
    if (_last == null) {
      return "{}";
    }

    // Roll back to the first entry.
    ScopedEntry entry = first;

    // Build the string
    StringBuffer buf = new StringBuffer();
    buf.write("{");
    while (entry.successor != null) {
      buf.write(entry.toString());
      buf.write(", ");
      entry = entry.successor;
    }
    buf.write(entry.toString());
    buf.write("}");
    return buf.toString();
  }
}

// void main() {
//   // OrderedContext ctxt = OrderedContext.empty();
//   // print("$ctxt [size = ${ctxt.size}]");

//   // Existential exvar = Existential(new Skolem(1));
//   // ctxt.insertLast(exvar);
//   // print("$ctxt [size = ${ctxt.size}]");

//   // Existential exvar2 = Existential(new Skolem(2));
//   // ctxt.insertLast(exvar2);
//   // print("$ctxt [size = ${ctxt.size}]");

//   // ctxt.drop(exvar2);
//   // print("$ctxt [size = ${ctxt.size}]");

//   // Existential exvar3 = Existential(new Skolem(3));
//   // ctxt.insertLast(exvar3);
//   // print("$ctxt [size = ${ctxt.size}]");

//   // ctxt.insertBefore(exvar2, exvar3);
//   // print("$ctxt [size = ${ctxt.size}]");

//   // print("${ctxt.lookup(exvar3.ident)}");

//   // ctxt.drop(exvar3);
//   // exvar2.solve(IntType());
//   // print("$ctxt [size = ${ctxt.size}]");

//   // ctxt.insertBefore(exvar3, exvar);
//   // print("$ctxt [size = ${ctxt.size}]");

//   // exvar.solve(ArrowType([Skolem(5)], Skolem(4)));
//   // print("$ctxt [size = ${ctxt.size}]");

//   // print("lookup $exvar3 $exvar2 ~=~ ${ctxt.lookupAfter(exvar2.ident, exvar3)}");

//   Existential ex0 = Existential(new Skolem());
//   Existential ex1 = Existential(new Skolem());
//   Existential ex2 = Existential(new Skolem());

//   OrderedContext ctxt = OrderedContext.empty();
//   ctxt.insertLast(ex0);
//   ctxt.insertBefore(ex1, ex0);
//   ctxt.insertBefore(ex2, ex1);

//   print("$ctxt");

//   ex0.solve(ArrowType([ex1.skolem], ex2.skolem));
//   print("$ctxt");

//   Datatype ty = ex0.skolem;
//   print("$ty[$ctxt] = ${ctxt.apply(ty)} [${ctxt.verify()}]");

//   Marker m = Marker(ex0.skolem);
//   m.insertBefore(ex1);
//   ex0.solve(ArrowType([ex1.skolem], ex2.skolem));
//   // ex2.solve(ex1.skolem); // Potentially bad.
//   print("$ty[$ctxt] = ${ctxt.apply(ty)} [${ctxt.verify()}]");

//   ex1.solve(ex2.skolem);
//   print("$ty[$ctxt] = ${ctxt.apply(ty)} [${ctxt.verify()}]");

//   // ctxt.drop(ex2);
//   print("$ty[$ctxt] = ${ctxt.apply(ty)} [${ctxt.verify()}]");
//   ex2.solve(TupleType([IntType(), BoolType()]));
//   print("$ty[$ctxt] = ${ctxt.apply(ty)} [${ctxt.verify()}]");
// }

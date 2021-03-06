// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Monoids.
abstract class Magma<R> {
  R compose(R x, R y);
}

abstract class Monoid<R> implements Magma<R> {
  R get empty;
}

class NullMonoid<T> implements Monoid<T> {
  T get empty => null;
  T compose(T x, T y) => null;
}

class LAndMonoid implements Monoid<bool> {
  static LAndMonoid _instance;

  LAndMonoid._();
  factory LAndMonoid() {
    if (_instance == null) {
      _instance = LAndMonoid._();
    }
    return _instance;
  }

  bool get empty => true;
  bool compose(bool x, bool y) => x && y;
}

class SetMonoid<T> implements Monoid<Set<T>> {
  Set<T> get empty => new Set<T>();
  Set<T> compose(Set<T> x, Set<T> y) => x.union(y);
}

class ListMonoid<T> implements Monoid<List<T>> {
  List<T> get empty => new List<T>();
  List<T> compose(List<T> x, List<T> y) {
    assert(x != null && y != null);
    x.addAll(y); // TODO: use an immutable list.
    return x;
  }
}

class StringMonoid implements Monoid<String> {
  String get empty => "";
  String compose(String x, String y) {
    if (x == empty) return y;
    else if (y == empty) return x;
    else return "$x $y";
  }
}

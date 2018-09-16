// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.option;

class OptionValueFromNoneError {}

abstract class Option<E> {
  final E value;

  const factory Option.some(E x) = _Some<E>;
  const factory Option.none() = _None<E>;

  bool get isSome;
  bool get isNone;

  Option<T> map<T>(T Function(E));
}

class _Some<E> implements Option<E> {
  final E value;
  const _Some(E x) : value = x;

  bool get isSome => true;
  bool get isNone => false;

  Option<T> map<T>(T Function(E) f) {
    return _Some(f(value));
  }

  String toString() {
    return "Some($value)";
  }
}

class _None<E> implements Option<E> {
  const _None();

  E get value => throw new OptionValueFromNoneError();

  bool get isSome => false;
  bool get isNone => true;

  Option<T> map<T>(T Function(E)) {
    return _None<T>();
  }

  String toString() {
    return "None";
  }
}

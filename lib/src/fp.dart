// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// A collection of some basic functional programming structures or idioms.

// Sum types.
abstract class Sum<L,R> {
  final dynamic _value;
  dynamic get value;

  const Sum._(this._value);
  const factory Sum.inl(L data) = _Inl<L,R>;
  const factory Sum.inr(R data) = _Inr<L,R>;

  bool get isLeft => false;
  bool get isRight => false;
}

class _Inl<L,R> extends Sum<L,R> {
  const _Inl(L value) : super._(value);

  L get value => value as L;

  bool get isLeft => true;

  String toString() {
    return "Inl($value)";
  }
}

class _Inr<L,R> extends Sum<L,R> {
  const _Inr(R value) : super._(value);

  R get value => _value as R;

  bool get isRight => true;

  String toString() {
    return "Inr($value)";
  }
}

// Option types.
class OptionValueFromNoneError {}

class Option<E> {
  final Sum<Null, E> _sum;

  const Option._(this._sum);
  factory Option.some(E x) {
    return Option<E>._(Sum.inr(x));
  }
  factory Option.none() {
    return Option<E>._(Sum.inl(null));
  }

  bool get isSome => _sum.isRight;
  bool get isNone => _sum.isLeft;

  E get value {
    if (isNone) throw OptionValueFromNoneError();
    return (_sum.value as E);
  }

  Option<T> map<T>(T Function(E) f) {
    if (isNone) return Option<T>.none();
    return Option<T>.some(f(value));
  }
}

// Product types.
class Pair<A, B> {
  final A fst;
  final B snd;

  const Pair(this.fst, this.snd);

  A get $1 => fst;
  B get $2 => snd;
}

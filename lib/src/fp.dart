// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// A collection of some basic functional programming structures or idioms.

// Sum types.
abstract class Sum<L, R> {
  final dynamic _value;
  dynamic get value;

  const Sum._(this._value);
  const factory Sum.inl(L data) = _Inl<L, R>;
  const factory Sum.inr(R data) = _Inr<L, R>;

  bool get isLeft => false;
  bool get isRight => false;
}

class _Inl<L, R> extends Sum<L, R> {
  const _Inl(L value) : super._(value);

  L get value => _value as L;

  bool get isLeft => true;

  String toString() {
    return "Inl($value)";
  }
}

class _Inr<L, R> extends Sum<L, R> {
  const _Inr(R value) : super._(value);

  R get value => _value as R;

  bool get isRight => true;

  String toString() {
    return "Inr($value)";
  }
}

// The familiar 'either' formulation of the binary sum type.
abstract class Either<L, R> {
  const Either._();
  const factory Either.left(L data) = Left<L, R>;
  const factory Either.right(R data) = Right<L, R>;

  bool get isLeft => false;
  bool get isRight => false;

  dynamic get value => (this as dynamic).value;

  // This is a somewhat "ad-hoc generalised" version of the standard definition
  // of [bind] operation on the either monad.
  Either<L0, R0> bind2<L0, R0>(
      Either<L0, R0> Function(L) lfn, Either<L0, R0> Function(R) rfn);

  Either<L, R0> bind<R0>(Either<L, R0> Function(R) fn);
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value) : super._();

  bool get isLeft => true;

  Either<L0, R0> bind2<L0, R0>(
          Either<L0, R0> Function(L) fn, Either<L0, R0> Function(R) _) =>
      fn(value);

  Either<L, R0> bind<R0>(Either<L, R0> Function(R) fn) =>
      (this as Either<L, Null>);
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value) : super._();

  bool get isRight => true;

  Either<L0, R0> bind2<L0, R0>(
          Either<L0, R0> Function(L) _, Either<L0, R0> Function(R) fn) =>
      fn(value);

  Either<L, R0> bind<R0>(Either<L, R0> Function(R) fn) => fn(value);
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

class Triple<A, B, C> extends Pair<A, B> {
  final C thd;

  const Triple(A fst, B snd, this.thd) : super(fst, snd);

  C get $3 => thd;
}

class Quadruple<A, B, C, D> extends Triple<A, B, C> {
  final D fourth;

  const Quadruple(A fst, B snd, C thd, this.fourth) : super(fst, snd, thd);

  D get $4 => fourth;
}

// Reference types.
class Ref<A> {
  A _value;
  A get value => _value;
  void set value(A v) => _value = v;

  Ref(this._value);
}

// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

typedef Bind<L,R,T> = Either<L,T> Function(R);

abstract class Either<L,R> {
  const Either._();
  const factory Either.left(L data) = _Left<L,R>;
  const factory Either.right(R data) = _Right<L,R>;

  bool get isLeft => false;
  bool get isRight => false;

  dynamic get value;

  Either<L, T> bind<T>(Bind<L,R,T> bind) {
    if (isLeft) return Either<L, T>.left(value);
    return bind((this as _Right<L,R>).value);
  }
}

class _Left<L,R> extends Either<L,R> {
  final L _value;
  const _Left(this._value) : super._();

  bool get isLeft => true;
  L get value => _value;
}

class _Right<L,R> extends Either<L,R> {
  final R _value;
  const _Right(this._value) : super._();

  bool get isRight => true;
  R get value => _value;
}

// void main() {
//   Either<String, bool> e = Either.right(true);
//   e = e.bind((b) => Either.right(!b));
//   if (e.isRight) {
//     print("${e.value}");
//   }
// }

// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.errors;

import '../location.dart';

abstract class T20Error {}

abstract class LocatedError implements T20Error {
  final Location location;

  LocatedError(this.location);
}

// Syntax errors.
abstract class SyntaxError implements LocatedError, T20Error {}

class UnmatchedBracketError extends LocatedError implements SyntaxError {
  final int _unmatched;

  UnmatchedBracketError(this._unmatched, Location location) : super(location);

  String get unmatchedBracket => String.fromCharCode(_unmatched);
}

// Lexical errors.
abstract class LexicalError implements SyntaxError {}

class InvalidCharacterError extends LocatedError implements LexicalError {
  final int char;
  InvalidCharacterError(this.char, Location location) : super(location);

  String get character => String.fromCharCode(char);
}

class UnterminatedStringError extends LocatedError implements LexicalError {
  final List<int> _partialString;

  UnterminatedStringError(this._partialString, Location location)
      : super(location);

  String get unterminatedString => String.fromCharCodes(_partialString);
}

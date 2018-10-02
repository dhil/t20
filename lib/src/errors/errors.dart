// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.errors;

import '../location.dart';
import '../unicode.dart' as unicode;

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

  String toString() {
    switch (_unmatched) {
      case unicode.LPAREN:
        return "Unmatched parenthesis";
      case unicode.LBRACE:
        return "Unmatched curly brace";
      case unicode.LBRACKET:
        return "Unmatched square bracket";
      default:
        throw ArgumentError(_unmatched.toString());
    }
  }
}

// Lexical errors.
abstract class LexicalError implements SyntaxError {}

class InvalidCharacterError extends LocatedError implements LexicalError {
  final int char;
  InvalidCharacterError(this.char, Location location) : super(location);

  String get character => String.fromCharCode(char);

  String toString() {
    return "Invalid character";
  }
}

class UnterminatedStringError extends LocatedError implements LexicalError {
  final List<int> _partialString;

  UnterminatedStringError(this._partialString, Location location)
      : super(location);

  String get unterminatedString => String.fromCharCodes(_partialString);

  String toString() {
    return "Unterminated string";
  }
}

class BadCharacterEscapeError extends LocatedError implements LexicalError {
  final List<int> _badEscape;

  BadCharacterEscapeError(this._badEscape, Location location) : super(location);

  String get badEscape => String.fromCharCodes(_badEscape);

  String toString() {
    return "Bad character escape";
  }
}

class InvalidUTF16SequenceError extends LocatedError implements LexicalError {
  final List<int> _invalid;

  InvalidUTF16SequenceError(this._invalid, Location location) : super(location);

  String get invalidSequence => String.fromCharCodes(_invalid);

  String toString() {
    return "Invalid UTF-16 character";
  }
}

// Elaboration errors.
abstract class ElaborationError implements T20Error {}

// This error is *never* suppose to occur.
class UnsupportedTypeElaborationMethodError implements ElaborationError {
  final String elaboratorName;
  final String methodName;
  UnsupportedTypeElaborationMethodError(this.elaboratorName, this.methodName);

  String toString() {
    return "Unsupported invocation of method '$methodName' elaborator '$elaboratorName'.";
  }
}

class InvalidTypeError extends LocatedError implements ElaborationError {
  final String typeName;

  InvalidTypeError(this.typeName, Location location) : super(location);

  String toString() {
    return "Invalid type";
  }
}

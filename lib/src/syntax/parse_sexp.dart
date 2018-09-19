// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.parser;

import 'dart:collections;';

import '../compilation_unit.dart';
import '../io/stream_io.dart';
import '../location.dart';
import '../option.dart';
import '../unicode.dart';


class Result<TAst, TErr> {
  final List<TErr> errors;
  int get errorCount => errors.length;
  bool get wasSuccessful => errorCount == 0;
  final TAst result;

  const Result(this.result, [errors = null])
      : this.errors = errors == null ? [] : errors;
}

abstract class Parser {
  const factory Parser.sexp() = SexpParser;
  Result<Object, Object> parse(Source source);
}

class SexpParser implements Parser {
  const SexpParser();

  Result<Object, Object> parse(Source source) {
    var parser = new _StatefulSexpParser(source);
    return parser.parse();
  }
}

class _StatefulSexpParser {
  final Source _src;
  PushbackStream<int> _stream;

  // Book keeping.
  int _col = 0;
  int _line = 1;
  int _start = 0;
  Queue<int> _brackets;

  // Constructs an object that represents the current source location.
  Location get _location => new Location(_src.sourceName, _line, _start);

  _StatefulSexpParser(this._src) {
    _stream = new PushbackStream(_src.openInputStream());
    _brackets = new Queue<int>();
  }

  Result<Object, Object> parse() {
    List<Object> sexps = new List<Object>();
    Object sexp;
    while (!_stream.endOfStream) {
      sexp = _expression();
      if (sexp != null)
        sexps.add(sexp);
    }
    return null;
  }


  Object _expression() {
    int c = _peek();
    switch (c) {
      case Unicode.SEMI_COLON: // Consume comment.
        while (!endOfStream && _peek() != Unicode.NL);
      case Unicode.NL:
        break;
      case Unicode.LBRACE:
        case Unicode.LBRACKET:
      case Unicode.LPAREN: // Generate LBRACKET.
          return _list();
          break;
      case Unicode.QUOTE: // String literal.
        return _string();
        break;
      case Unicode.SPACE:
      case Unicode.HT:
          break;
      default: // Atom or int literal.
        if (Unicode.isLetter(c)) {
          return _atom();
        } else if (Unicode.isDigit(c)) {
          return _integer();
        } else {
          // error
        }
    }
  }

  Object _atom() {
  }

  Object _list() {
    int beginBracket = _advance();
    if (!_expectOpeningBracket(beginBracket)) return null; // error, expected opening bracket.

    List<Object> sexps = new List<Object>();
    while (!_stream.endOfStream && !isClosingBracket(_peek())) {
      sexps.add(_expression());
    }

    if (_stream.endOfStream) return null; // error, unmatched bracket.
    int endBracket = _advance();
    if (_expectMatchingClosingBracket(endBracket)) return null; // error, unmatched bracket.

    return null;
  }

  int _peek() {
    return _stream.unsafePeek();
  }

  int _advance() {
    int c = _stream.next();
    if (c == Unicode.NL) {
      _line++;
      _col = 0;
    } else {
      col++;
    }
    return c;
  }

  bool _expectOpeningBracket(int c) {
    if (_isBracket(c) && !_isClosingBracket(c)) {
      _brackets.add(c);
      return true;
    } else {
      return false;
    }
  }

  bool _expectMatchingClosingBracket(int c) {
    if (brackets.isEmpty) return false;
    return brackets.removeLast() == c;
  }

  bool _isClosingBracket(int c) {
    switch (c) {
      case Unicode.RBRACE:
      case Unicode.RBRACKET:
      case Unicode.RPAREN:
        return true;
      default:
        return false;
    }
  }

  bool _isBracket(int c) {
    switch (c) {
      case Unicode.LBRACE:
      case Unicode.RBRACE:
      case Unicode.LBRACKET:
      case Unicode.RBRACKET:
      case Unicode.LPAREN:
      case Unicode.RPAREN:
        return true;
      default:
        return false;
    }
  }
}

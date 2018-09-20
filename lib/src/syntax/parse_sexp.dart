// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.parser;

import 'dart:collection';

import '../compilation_unit.dart';
import '../io/stream_io.dart';
import '../location.dart';
import '../unicode.dart' as Unicode;

class ExpectationError {
  final String actual;
  final String expected;
  ExpectationError(this.expected, this.actual);
}

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
  Result<Object, Object> parse(Source source, {bool trace = false});
}

class SexpParser implements Parser {
  const SexpParser();

  Result<Object, Object> parse(Source source, {bool trace = false}) {
    _StatefulSexpParser parser;
    if (trace) {
      parser = new _TracingSexpParser(source);
    } else {
      parser = new _StatefulSexpParserImpl(source);
    }
    return parser.parse();
  }
}

abstract class _StatefulSexpParser {
  Result<Object, Object> parse();

  Object atom();
  Object expression();
  Object integer();
  Object list();
  Object string();
}

class _StatefulSexpParserImpl implements _StatefulSexpParser {
  final Source _src;
  PushbackStream<int> _stream;

  // Book keeping.
  int _col = 0;
  int _line = 1;
  Queue<int> _brackets;

  // Constructs an object that represents the current source location.
  Location _location(int start) {
    return new Location(_src.sourceName, _line, start);
  }

  bool get _atEnd => _stream.endOfStream;

  _StatefulSexpParserImpl(this._src) {
    _stream = new PushbackStream(_src.openInputStream());
    _brackets = new Queue<int>();
  }

  Result<Object, Object> parse() {
    List<Object> sexps = new List<Object>();
    Object sexp;
    while (!_atEnd) {
      sexp = expression();
      if (sexp != null) sexps.add(sexp);
    }
    return null;
  }

  bool _match(int c) {
    return !_atEnd && _peek() == c;
  }

  void _expect(int c) {
    int k = _advance();
    if (c != k)
      throw new ExpectationError(
          String.fromCharCode(c), String.fromCharCode(k));
  }

  Object expression() {
    while (!_atEnd) {
      int c = _peek();
      switch (c) {
        case Unicode.SEMICOLON: // Consume comment.
          while (!_atEnd && !_match(Unicode.NL)) {
            _advance();
          }
          break;
        case Unicode.LBRACE:
        case Unicode.LBRACKET:
        case Unicode.LPAREN: // Generate LBRACKET.
          return list();
          break;
        case Unicode.QUOTE: // String literal.
          return string();
          break;
        case Unicode.HT:
        case Unicode.NL:
        case Unicode.SPACE:
          _advance();
          break;
        default: // Atom or int literal.
          if (Unicode.isLetter(c)) {
            return atom();
          } else if (Unicode.isDigit(c)) {
            return integer();
          } else {
            // error
          }
      }
    }
    return null;
  }

  Object string() {
    final List<int> bytes = new List<int>();
    while (!_match(Unicode.QUOTE)) {
      bytes.add(_advance());
    }
    if (_atEnd) return null; // unterminated string.
    _expect(Unicode.QUOTE);
    return null;
  }

  Object integer() {
    assert(Unicode.isDigit(_peek()));
    final int start = _col + 1;
    final List<int> bytes = new List<int>();
    while (!_atEnd && Unicode.isDigit(_peek())) {
      bytes.add(_advance());
    }
    // construct integer node.
    return null;
  }

  Object atom() {
    assert(Unicode.isLetter(_peek()));
    final int start = _col + 1;
    final List<int> bytes = new List<int>();
    while (!_atEnd && !Unicode.isSpace(_peek())) {
      bytes.add(_advance());
    }
    // construct new atom
    return null;
  }

  Object list() {
    int beginBracket = _advance();
    final int start = _col;
    if (!_expectOpeningBracket(beginBracket))
      return null; // error, expected opening bracket.

    List<Object> sexps = new List<Object>();
    while (!_atEnd && !_isClosingBracket(_peek())) {
      Object sexp = expression();
      if (sexp != null) sexps.add(sexp);
    }

    if (_atEnd) return null; // error, unmatched bracket.
    int endBracket = _advance();
    if (_expectMatchingClosingBracket(endBracket))
      return null; // error, unmatched bracket.

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
      _col++;
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
    if (_brackets.isEmpty) return false;
    return _brackets.removeLast() == c;
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

class _Symbols {
  static final String branch = String.fromCharCode(0x251C);
  static final String finalBranch = String.fromCharCode(0x2514);
  static final String verticalLine = String.fromCharCode(0x2502);
  static final String horizontalLine = String.fromCharCode(0x2500);
  static final String tDown = String.fromCharCode(0x252C);
  static final String end = String.fromCharCode(0x25B8);
  static final String ePrint = String.fromCharCode(0x2639);
}

class _TracingSexpParser extends _StatefulSexpParserImpl {
  final StringBuffer _sb;
  final StringBuffer _pb;
  int _indent = 0;

  _TracingSexpParser(Source src)
      : _pb = new StringBuffer(),
        _sb = new StringBuffer(),
        super(src);

  Result<Object, Object> parse() {
    print("parse");
    return super.parse();
  }

  Object atom() {
    _finalDive();
    var node = super.atom();
    _sb.write("${_Symbols.end} atom [$node]");
    print("$_sb");
    _surface();
    return node;
  }

  Object expression() {
    _dive();
    _sb.write("${_Symbols.tDown} expression");
    print("$_sb");
    var node = super.expression();
    _surface();
    return node;
  }

  Object integer() {
    var node = super.integer();
    return node;
  }

  Object string() {
    _finalDive();
    var node = super.string();
    _sb.write("${_Symbols.end} string [$node]");
    print("$_sb");
    _surface();
    return node;
  }

  void _finalDive() {
     _sb.clear();
     _sb.write("$_pb${_Symbols.finalBranch}${_Symbols.horizontalLine}${_Symbols.horizontalLine}");
     _pb.write("   ");
  }

  void _dive() {
    _sb.clear();
    _sb.write("$_pb${_Symbols.branch}${_Symbols.horizontalLine}${_Symbols.horizontalLine}");
    _pb.write("${_Symbols.verticalLine}  ");
  }

  void _surface() {
    String prefix = _pb.toString();
    _pb.clear();
    //    print("$prefix ${prefix.length}");
    if (prefix.length > 3)
      _pb.write(prefix.substring(prefix.length - 4, prefix.length - 1));
  }
}

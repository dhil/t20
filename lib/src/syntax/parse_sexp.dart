// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.parser;

import 'dart:collection';
import 'dart:io';

import '../compilation_unit.dart';
import '../io/stream_io.dart';
import '../unicode.dart' as Unicode;

import 'sexp.dart';
import 'tokens.dart';

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
  Result<Sexp, Object> parse(TokenStream stream, {bool trace = false});
}

class SexpParser implements Parser {
  const SexpParser();

  Result<Sexp, Object> parse(TokenStream stream, {bool trace = false}) {
    _StatefulSexpParser parser;
    if (trace) {
      parser = new _TracingSexpParser(stream);
    } else {
      parser = new _StatefulSexpParserImpl(stream);
    }
    return parser.parse();
  }
}

abstract class _StatefulSexpParser {
  Result<Sexp, Object> parse();

  Sexp atom();
  Sexp expression();
  Sexp integer();
  Sexp list();
  Sexp string();
}

class _StatefulSexpParserImpl implements _StatefulSexpParser {
  PushbackStream<Token> _stream;

  // Book keeping.
  int _col = 0;
  int _line = 1;
  Queue<int> _brackets;

  _StatefulSexpParserImpl(TokenStream stream) {
    _stream = new PushbackStream(stream);
    _brackets = new Queue<int>();
  }

  Result<Sexp, Object> parse() {
    List<Sexp> sexps = new List<Sexp>();
    Object sexp;
    while (!_match(TokenKind.EOF)) {
      sexps.add(expression());
    }
    return null;
  }

  bool _match(TokenKind kind) {
    return _peek().kind == kind;
  }

  bool _matchEither(List<TokenKind> kinds) {
    for (TokenKind kind in kinds) {
      if (_peek().kind == kind) return true;
    }
    return false;
  }

  Sexp expression() {
    Token token = _peek();
    switch (token.kind) {
      case TokenKind.ATOM:
        return atom();
      case TokenKind.INT:
        return integer();
      case TokenKind.STRING:
        return string();
      case TokenKind.LBRACE:
      case TokenKind.LBRACKET:
      case TokenKind.LPAREN:
        return list();
      default:
        // error
        print("Unexpected token error");
    }
    return null;
  }

  StringLiteral string() {
    assert(_match(TokenKind.STRING));
    Token token = _advance();
    return StringLiteral(token.value, token.location);
  }

  IntLiteral integer() {
    assert(_match(TokenKind.INT));
    Token token = _advance();
    return IntLiteral(token.value, token.location);
  }

  Atom atom() {
    assert(_match(TokenKind.ATOM));
    Token token = _advance();
    return Atom(token.lexeme, token.location);
  }

  SList list() {
    assert(_matchEither(<TokenKind>[TokenKind.LBRACE, TokenKind.LBRACKET, TokenKind.LPAREN]));
    Token beginBracket = _advance();
    TokenKind endBracketKind = _correspondingClosingBracket(beginBracket.kind);

    List<Sexp> sexps = new List<Sexp>();
    while (!_match(endBracketKind) && !_match(TokenKind.EOF)) {
      sexps.add(expression());
    }

    // Unterminated list.
    if (!_match(endBracketKind)) {
      print("error unterminated list");
    }
    Token endBracket = _advance();

    return SList(sexps, beginBracket.location);
  }

  Token _peek() {
    return _stream.unsafePeek();
  }

  Token _advance() {
    return _stream.next();
  }

  TokenKind _correspondingClosingBracket(TokenKind bracket) {
    switch (bracket) {
      case TokenKind.LBRACE:
        return TokenKind.RBRACE;
      case TokenKind.LBRACKET:
        return TokenKind.RBRACKET;
      case TokenKind.LPAREN:
        return TokenKind.RPAREN;
      default:
        throw new ArgumentError();
    }
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

  _TracingSexpParser(TokenStream stream)
      : _pb = new StringBuffer(),
        _sb = new StringBuffer(),
        super(stream);

  Result<Sexp, Object> parse() {
    stderr.writeln("parse");
    return super.parse();
  }

  Atom atom() {
    _finalDive();
    var node = super.atom();
    _sb.write("${_Symbols.end} atom [$node]");
    stderr.writeln(_sb.toString());
    return node;
  }

  Sexp expression() {
    _dive();
    _sb.write("${_Symbols.tDown} expression");
    stderr.writeln(_sb.toString());
    var node = super.expression();
    _surface();
    return node;
  }

  IntLiteral integer() {
    _finalDive();
    var node = super.integer();
    _sb.write("${_Symbols.end} int [$node]");
    stderr.writeln(_sb.toString());
    return node;
  }

  SList list() {
    _dive();
    _sb.write("${_Symbols.tDown} list");
    stderr.writeln(_sb.toString());
    var node = super.list();
    _surface();
    return node;
  }

  StringLiteral string() {
    _finalDive();
    var node = super.string();
    _sb.write("${_Symbols.end} string [$node]");
    stderr.writeln(_sb.toString());
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
    _pb.write(prefix.substring(prefix.length - 6));
  }
}

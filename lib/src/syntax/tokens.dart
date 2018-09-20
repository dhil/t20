// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.tokens;

import 'dart:io';

import '../compilation_unit.dart';
import '../io/stream_io.dart';
import '../location.dart';
import '../unicode.dart' as Unicode;

enum TokenKind {
  // Atoms.
  ATOM,
  // Curly braces, parentheses, and square brackets.
  LBRACE,
  RBRACE,
  LBRACKET,
  RBRACKET,
  LPAREN,
  RPAREN,
  // Literals.
  INT,
  STRING,
  // End of file marker.
  EOF
}

class Token {
  final Location location;
  final TokenKind kind;
  final String lexeme;
  final Object value;

  const Token(this.kind, this.lexeme, this.location, [this.value = null]);

  const Token.EOF(this.location)
      : kind = TokenKind.EOF,
        lexeme = null,
        value = null;

  String toString() {
    return "Token($kind, $lexeme, $location, $value)";
  }
}

// An infinite stream of tokens.
class TokenStream implements Stream<Token> {
  Source _src;
  PushbackStream<int> _stream;

  // For book keeping.
  int _col = 0;
  int _line = 1;

  factory TokenStream(Source source, {bool trace = false}) {
    if (trace) return new _TracingTokenStream(source);
    else return new TokenStream._(source);
  }

  TokenStream._(Source source) {
    if (source == null) throw new ArgumentError.notNull("source");
    _src = source;
    _stream = new PushbackStream<int>(source.openInputStream());
  }

  bool get endOfStream => _stream.endOfStream;

  Token next() {
    while (!endOfStream) {
      int c = _peek();
      switch (c) {
        case Unicode.SEMICOLON: // Consume comment.
          _comment();
          break;
        case Unicode.NL:
          _advance();
          _col = 0;
          _line++;
          break;
        case Unicode.LBRACE:
          return _bracket(TokenKind.LBRACE, _advance());
        case Unicode.LBRACKET:
          return _bracket(TokenKind.LBRACKET, _advance());
        case Unicode.LPAREN:
          return _bracket(TokenKind.LPAREN, _advance());
        case Unicode.RBRACE:
          return _bracket(TokenKind.RBRACE, _advance());
        case Unicode.RBRACKET:
          return _bracket(TokenKind.RBRACKET, _advance());
        case Unicode.RPAREN:
          return _bracket(TokenKind.RPAREN, _advance());
        case Unicode.QUOTE: // String literal.
          return _string();
          break;
        case Unicode.SPACE:
        case Unicode.HT:
          _advance();
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

    return Token.EOF(_location(_line, _col));
  }

  bool _match(int c) {
    if (endOfStream) return false;
    return !endOfStream && _peek() == c;
  }

  int _peek() {
    return _stream.unsafePeek();
  }

  int _advance() {
    _col++;
    return _stream.next();
  }

  void _comment() {
    assert(_match(Unicode.SEMICOLON));
    while (!endOfStream && !_match(Unicode.NL)) _advance();
  }

  Token _string() {
    assert(_match(Unicode.QUOTE));
    int _startCol = _col;
    List<int> bytes = new List<int>();
    bytes.add(_advance()); // Consume the beginning quotation mark.
    while (!endOfStream && !_match(Unicode.QUOTE)) {
      bytes.add(_advance());
    }
    // Check whether the string is unterminated.
    if (endOfStream) {
      print("error unterminated string.");
      return null;
    }
    bytes.add(_advance()); // Consume the ending quotation mark.

    String lexeme = String.fromCharCodes(bytes);
    String interpretation = lexeme.substring(1, lexeme.length - 1);
    return _token(TokenKind.STRING, lexeme, value: interpretation);
  }

  Token _integer() {
    assert(Unicode.isDigit(_peek()));

    List<int> bytes = new List<int>();
    while (!endOfStream && Unicode.isDigit(_peek())) {
      bytes.add(_advance());
    }

    String lexeme = String.fromCharCodes(bytes);
    int interpretation = int.parse(lexeme);
    return _token(TokenKind.INT, lexeme, value: interpretation);
  }

  Token _atom() {
    assert(Unicode.isLetter(_peek()));

    List<int> bytes = new List<int>();
    while (!endOfStream && !Unicode.isSpace(_peek())) {
      bytes.add(_advance());
    }

    String lexeme = String.fromCharCodes(bytes);
    return _token(TokenKind.ATOM, lexeme);
  }

  Token _bracket(TokenKind kind, int c) {
    return _token(kind, String.fromCharCode(c));
  }

  Location _location(int startLine, int startColumn) {
    return new Location(_src.sourceName, startLine, startColumn);
  }

  Token _token(TokenKind kind, String lexeme, {Object value = null}) {
    Token token = new Token(kind, lexeme, _location(_line, _col), value);
    return token;
  }
}

class _TracingTokenStream extends TokenStream {
  _TracingTokenStream(Source source) : super._(source);

  Token next() {
    Token token = super.next();
    stderr.writeln("$token");
    return token;
  }
}

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
  EOF,
  // Special error token.
  ERROR
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
    String lexeme;
    String value;
    if (this.lexeme == null)
      lexeme = String.fromCharCode(0x03B5); // epsilon.
    else
      lexeme = this.lexeme;

    if (this.value == null)
      value = String.fromCharCode(0x22A5); // bottom.
    else
      value = this.value.toString();

    return "Token($location, ${stringOfTokenKind(kind)}, $lexeme, $value)";
  }

  String stringOfTokenKind(TokenKind kind) {
    switch (kind) {
      case TokenKind.ATOM:
        return "ATOM";
      case TokenKind.LBRACE:
        return "LBRACE";
      case TokenKind.RBRACE:
        return "RBRACE";
      case TokenKind.LBRACKET:
        return "LBRACKET";
      case TokenKind.RBRACKET:
        return "RBRACKET";
      case TokenKind.LPAREN:
        return "LPAREN";
      case TokenKind.RPAREN:
        return "RPAREN";
      case TokenKind.INT:
        return "INT";
      case TokenKind.STRING:
        return "STRING";
      case TokenKind.EOF:
        return "EOF";
      case TokenKind.ERROR:
        return "ERROR";
    }
  }
}

abstract class ErrorCause {}

class InvalidCharacterError implements ErrorCause {
  final String char;
  const InvalidCharacterError(this.char);

  String toString() {
    return "InvalidCharacterError($char)";
  }
}

class UnterminatedStringError implements ErrorCause {
  String toString() {
    return "UnterminatedStringError";
  }
}

class ErrorToken extends Token {
  final ErrorCause errorCause;

  const ErrorToken(
      this.errorCause, TokenKind kind, String lexeme, Location location,
      [Object value = null])
      : super(kind, lexeme, location, value);
}

// An infinite stream of tokens.
class TokenStream implements Stream<Token> {
  Source _src;
  PushbackStream<int> _stream;

  // For book keeping.
  int _start = 0;
  int _col = 0;
  int _line = 1;

  factory TokenStream(Source source, {bool trace = false}) {
    if (trace)
      return new _TracingTokenStream(source);
    else
      return new TokenStream._(source);
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
      _start = _col;
      switch (c) {
        case Unicode.SEMICOLON: // Consume comment.
          _comment();
          break;
        case Unicode.NL:
          _advance();
          _col = _start = 0;
          _line++;
          break;
        case Unicode.LBRACE:
          return _bracket(TokenKind.LBRACE);
        case Unicode.LBRACKET:
          return _bracket(TokenKind.LBRACKET);
        case Unicode.LPAREN:
          return _bracket(TokenKind.LPAREN);
        case Unicode.RBRACE:
          return _bracket(TokenKind.RBRACE);
        case Unicode.RBRACKET:
          return _bracket(TokenKind.RBRACKET);
        case Unicode.RPAREN:
          return _bracket(TokenKind.RPAREN);
        case Unicode.QUOTE: // String literal.
          return _string();
          break;
        case Unicode.SPACE:
        case Unicode.HT:
          _advance();
          break;
        default: // Atom or int literal.
          if (Unicode.isLetter(c) || isSymbol(c)) {
            return _atom();
          } else if (Unicode.isDigit(c)) {
            return _integer();
          } else {
            // Error.
            return _invalidCharacter(_advance());
          }
      }
    }

    return Token.EOF(_location(_line, _col));
  }

  bool _match(int c) {
    return !endOfStream && _peek() == c;
  }

  bool _matchEither(List<int> cs) {
    if (endOfStream) return false;
    for (int c in cs) {
      if (c == _peek()) return true;
    }

    return false;
  }

  int _peek() {
    return _stream.unsafePeek();
  }

  int _advance() {
    _col++;
    return _stream.next();
  }

  Token _invalidCharacter(int c) {
    String lexeme = String.fromCharCode(c);
    return ErrorToken(InvalidCharacterError(lexeme), TokenKind.ERROR, lexeme,
        _location(_line, _col));
  }

  Token _unterminatedString(List<int> bytes) {
    String lexeme = String.fromCharCodes(bytes);
    return ErrorToken(UnterminatedStringError(), TokenKind.ERROR, lexeme, _location(_line, _start));
  }

  void _comment() {
    assert(_match(Unicode.SEMICOLON));
    while (!endOfStream && !_match(Unicode.NL)) _advance();
  }

  Token _string() {
    assert(_match(Unicode.QUOTE));
    List<int> bytes = new List<int>();
    bytes.add(_advance()); // Consume the beginning quotation mark.
    final List<int> terminators = <int>[Unicode.QUOTE, Unicode.NL];
    while (!endOfStream && !_matchEither(terminators)) {
      bytes.add(_advance());
    }
    // Check whether the string is unterminated.
    if (endOfStream) {
      return _unterminatedString(bytes);
    }
    if (_match(Unicode.NL)) {
      return _unterminatedString(bytes);
    }
    bytes.add(_advance()); // Consume the ending quotation mark.

    String lexeme = String.fromCharCodes(bytes);
    String denotation = lexeme.substring(1, lexeme.length - 1);
    return _token(TokenKind.STRING, lexeme, value: denotation);
  }

  Token _integer() {
    assert(Unicode.isDigit(_peek()));
    List<int> bytes = new List<int>();
    while (!endOfStream && Unicode.isDigit(_peek())) {
      bytes.add(_advance());
    }

    String lexeme = String.fromCharCodes(bytes);
    int denotation = int.parse(lexeme);
    return _token(TokenKind.INT, lexeme, value: denotation);
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

  Token _bracket(TokenKind kind) {
    assert(_isBracket(_peek()));
    int c = _advance();
    return _token(kind, String.fromCharCode(c));
  }

  Location _location(int startLine, int startColumn) {
    return new Location(_src.sourceName, startLine, startColumn);
  }

  Token _token(TokenKind kind, String lexeme, {Object value = null}) {
    Token token = new Token(kind, lexeme, _location(_line, _start), value);
    return token;
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

  bool isSymbol(int c) {
    return 0x0021 <= c && c <= 0x002F ||
        0x003A <= c && c <= 0x0040 ||
        c == 0x005C ||
        c == 0x005E ||
        c == 0x005F ||
        c == 0x0060 ||
        c == 0x007E;
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

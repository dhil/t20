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
  int _errors = 0;

  _StatefulSexpParserImpl(TokenStream stream) {
    _stream = new PushbackStream(stream);
    _brackets = new Queue<int>();
  }

  Result<Sexp, Object> parse() {
    final List<Sexp> sexps = new List<Sexp>();
    while (!_match(TokenKind.EOF)) {
      sexps.add(expression());
    }
    return new Result<Sexp, Object>(new Toplevel(sexps), null);
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
        _advance();
        _errors++;
        print("Unexpected token error $token");
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
    assert(_matchEither(
        <TokenKind>[TokenKind.LBRACE, TokenKind.LBRACKET, TokenKind.LPAREN]));
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

class _TracingSexpParser extends _StatefulSexpParserImpl {
  ParseTreeInteriorNode tree;
  _TracingSexpParser(TokenStream stream) : super(stream);

  Result<Sexp, Object> parse() {
    tree = new ParseTreeInteriorNode("parse");
    var result = super.parse();
    tree.visit(new PrintParseTree());
    return result;
  }

  Atom atom() {
    var node = super.atom();
    tree.add(new ParseTreeLeaf("atom", node.value));
    return node;
  }

  Sexp expression() {
    var parent = tree;
    tree = new ParseTreeInteriorNode("expression");
    parent.add(tree);
    var node = super.expression();
    tree = parent;
    return node;
  }

  IntLiteral integer() {
    var node = super.integer();
    tree.add(new ParseTreeLeaf("integer", node.value.toString()));
    return node;
  }

  SList list() {
    var parent = tree;
    tree = new ParseTreeInteriorNode("list");
    parent.add(tree);
    var node = super.list();
    tree = parent;
    return node;
  }

  StringLiteral string() {
    var node = super.string();
    tree.add(new ParseTreeLeaf("string", node.value));
    return node;
  }
}

abstract class ParseTreeNode {
  String name;

  void visit(ParseTreeVisitor visitor);
}

class ParseTreeInteriorNode implements ParseTreeNode {
  String name;
  List<ParseTreeNode> children;

  ParseTreeInteriorNode(this.name) : children = new List<ParseTreeNode>();

  void visit(ParseTreeVisitor visitor) {
    visitor.visitInteriorNode(this);
  }

  String toString() {
    return "$name [children: ${children.length}]";
  }

  void add(ParseTreeNode node) {
    children.add(node);
  }
}

class ParseTreeLeaf implements ParseTreeNode {
  String name;
  String value;

  ParseTreeLeaf(this.name, this.value);

  void visit(ParseTreeVisitor visitor) {
    visitor.visitLeaf(this);
  }

  String toString() {
    return "$name [$value]";
  }
}

abstract class ParseTreeVisitor {
  void visitInteriorNode(ParseTreeInteriorNode node);
  void visitLeaf(ParseTreeLeaf leaf);
}

class PrintParseTree implements ParseTreeVisitor {
  // Symbols used to depict the tree.
  final String BRANCH = String.fromCharCode(0x251C);
  final String FINAL_BRANCH = String.fromCharCode(0x2514);
  final String VL = String.fromCharCode(0x2502);
  final String HL = String.fromCharCode(0x2500);
  final String T_DOWN = String.fromCharCode(0x252C);
  final String END = String.fromCharCode(0x25B8);
  final StringBuffer _sb;
  final StringBuffer _pb;
  bool _toplevel = true;

  PrintParseTree()
      : _sb = new StringBuffer(),
        _pb = new StringBuffer();

  void visitInteriorNode(ParseTreeInteriorNode node) {
    if (_toplevel) {
      _toplevel = false;
      _sb.write("$node");
    } else {
      _sb.write("$T_DOWN $node");
    }

    stderr.writeln(_sb.toString());

    for (int i = 0; i < node.children.length; i++) {
      if (i + 1 == node.children.length)
        _finalDive();
      else
        _dive();
      node.children[i].visit(this);
      _surface();
    }
  }

  void visitLeaf(ParseTreeLeaf leaf) {
    _sb.write("$END $leaf");
    stderr.writeln(_sb.toString());
  }

  void _finalDive() {
    _sb.clear();
    _sb.write("$_pb$FINAL_BRANCH$HL$HL");
    _pb.write("   ");
  }

  void _dive() {
    _sb.clear();
    _sb.write("$_pb$BRANCH$HL$HL");
    _pb.write("$VL  ");
  }

  void _surface() {
    String prefix = _pb.toString();
    _pb.clear();
    _pb.write(delete(prefix, prefix.length - 3, prefix.length - 1));
  }

  String delete(String s, int start, int end) {
    StringBuffer buf = new StringBuffer();
    if (start > 0)
      buf.write(s.substring(0, start));
    if (end - s.length > 0)
      buf.write(s.substring(end, s.length - 1));
    return buf.toString();
  }
}

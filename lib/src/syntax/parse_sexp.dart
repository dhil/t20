// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.parser;

import 'dart:collection';
import 'dart:io';

import '../compilation_unit.dart';
import '../errors/errors.dart';
import '../io/bytestream.dart';
import '../location.dart';
import '../result.dart';
import '../unicode.dart' as unicode;

import 'sexp.dart';
export 'sexp.dart';

abstract class Parser {
  const factory Parser.sexp() = SexpParser;
  Result<Sexp, SyntaxError> parse(Source source, {bool trace = false});
}

class SexpParser implements Parser {
  const SexpParser();

  Result<Sexp, SyntaxError> parse(Source source, {bool trace = false}) {
    if (source == null) throw new ArgumentError.notNull("source");
    if (trace) {
      return new _TracingSexpParser(source.uri, source.openStream()).parse();
    } else {
      return new _StatefulSexpParser(source.uri, source.openStream()).parse();
    }
  }
}

// Grammar
//
// P ::= E*                               (* toplevel program *)
// E ::= atom                             (* indivisible expressions *)
//    | E . E                             (* pairs *)
//    | '(' E ')' | '[' E ']' | '{' E '}' (* lists *)
//
// After left recursion elimination:
//
// P  ::= E*
// E  ::= atom E'
//     | '(' E ')' E' | '[' E ']' E' | '{' E '}' E'
// E' ::=  . E E'
//     | epsilon
//
class _StatefulSexpParser {
  final Set<int> _validAtomSymbols = Set.of(<int>[
    unicode.AT,
    unicode.LOW_LINE,
    unicode.HYPHEN_MINUS,
    unicode.PLUS_SIGN,
    unicode.ASTERISK,
    unicode.SLASH,
    unicode.DOLLAR_SIGN,
    unicode.BANG,
    unicode.QUESTION_MARK,
    unicode.EQUALS_SIGN,
    unicode.LESS_THAN_SIGN,
    unicode.GREATER_THAN_SIGN,
    unicode.COLON,
    unicode.HASH,
    unicode.APOSTROPHE,
    unicode.QUOTE
  ]);
  final List<int> _whitespaces = const <int>[
    // Sorted after "likelihood".
    unicode.SPACE,
    unicode.NL,
    unicode.SEMICOLON,
    unicode.HT,
    unicode.CR,
    unicode.FF
  ];
  final List<int> _closingBrackets = const <int>[
    unicode.RPAREN,
    unicode.RBRACKET,
    unicode.RBRACE
  ];

  // The input stream.
  ByteStream _stream;
  Uri _uri;

  // Book keeping.
  int _offset = 0;
  List<SyntaxError> _errors;

  _StatefulSexpParser(this._uri, this._stream);

  Result<Sexp, SyntaxError> parse() {
    spaces(); // Consume any initial white space.
    List<Sexp> sexps = new List<Sexp>();
    while (!_atEnd) {
      sexps.add(expression());
    }

    return new Result<Sexp, SyntaxError>(
        new Toplevel(sexps, _spanLocation(0, _offset)), _errors);
  }

  bool _match(int c) {
    return c == _peek();
  }

  bool _matchEither(List<int> cs) {
    int c = _peek();
    for (int i = 0; i < cs.length; i++) {
      if (c == cs[i]) return true;
    }
    return false;
  }

  bool get _atEnd {
    return _match(ByteStream.END_OF_STREAM);
  }

  void spaces() {
    // Consume white space.
    while (_matchEither(_whitespaces)) {
      if (_match(unicode.SEMICOLON)) {
        // Consume comment.
        while (!_match(unicode.NL) && !_atEnd) _advance();
      }
      _advance();
    }
  }

  Sexp atom() {
    int offset = _offset;
    int c = _advance();
    assert(isValidAtomStart(c));

    // It might be a negative number.
    // if (c == unicode.HYPHEN_MINUS && unicode.isDigit(_peek())) {
    //   return number(sign: unicode.HYPHEN_MINUS);
    // } else {
    List<int> bytes = new List<int>()..add(c);
    while (!_atEnd && isValidAtomContinuation(_peek())) {
      bytes.add(_advance());
    }
    String value = String.fromCharCodes(bytes);
    return new Atom(value, _location(_offset));
    // }
  }

  // Sexp number({int sign = unicode.PLUS_SIGN}) {
  //   int offset = _offset;
  //   assert(unicode.isDigit(_peek()));
  //   List<int> bytes = new List<int>()..add(_advance());
  //   while (!_atEnd && unicode.isDigit(_peek())) {
  //     bytes.add(_advance());
  //   }
  //   int denotation = int.parse(String.fromCharCodes(bytes));
  //   if (sign == unicode.HYPHEN_MINUS) {
  //     offset -= 1; // Decrement by one to include the position of the minus
  //     // sign.
  //     denotation *= -1;
  //   }
  //   return new IntLiteral(denotation, _location(offset));
  // }

  Sexp expression() {
    Sexp sexp;
    int c = _peek();
    switch (c) {
      case unicode.LPAREN:
      case unicode.LBRACKET:
      case unicode.LBRACE:
        sexp = list();
        break;
      // case unicode.ZERO:
      // case unicode.ONE:
      // case unicode.TWO:
      // case unicode.THREE:
      // case unicode.FOUR:
      // case unicode.FIVE:
      // case unicode.SIX:
      // case unicode.SEVEN:
      // case unicode.EIGHT:
      // case unicode.NINE:
      //   sexp = number();
      //   break;
      case unicode.QUOTE:
        sexp = string();
        break;
      default:
        if (isValidAtomStart(c)) {
          sexp = atom();
        } else {
          // Error: Invalid character.
          Location location = _location(_offset);
          sexp = error(InvalidCharacterError(_advance(), location));
        }
    }
    spaces(); // Consume trailing white space.
    return sexp;
    // if (_match(unicode.DOT))
    //   return pair(sexp);
    // else
    //   return sexp;
  }

  Sexp list() {
    assert(_matchEither(
        const <int>[unicode.LPAREN, unicode.LBRACKET, unicode.LBRACE]));
    int startOffset = _offset;
    int beginBracket = _advance();
    spaces(); // Consume any white space after the bracket.
    List<Sexp> sexps = new List<Sexp>();
    while (!_atEnd && !_matchEither(_closingBrackets)) {
      sexps.add(expression());
    }
    Sexp sexp;
    int endOffset = _offset;
    if (_peek() != getMatchingBracket(beginBracket)) {
      // Error: Unmatched bracket.
      sexp = error(UnmatchedBracketError(
          beginBracket, _spanLocation(startOffset, endOffset)));
    } else {
      _advance(); // Consume end bracket.
      sexp = new SList(sexps, _bracketsKind(beginBracket),
          _spanLocation(startOffset, endOffset));
    }
    return sexp;
  }

  // Sexp pair(Sexp first) {
  //   assert(_match(unicode.DOT));
  //   int offset = _offset;
  //   _advance(); // Consume the full stop.
  //   spaces(); // Consume any white space after the dot.
  //   Sexp second = expression(); // As a side-effect [expression] consumes
  //   // trailing white space.
  //   return new Pair(first, second, _location(offset));
  // }

  Sexp string() {
    assert(_match(unicode.QUOTE));
    int offset = _offset;
    List<int> bytes = new List<int>();
    _advance(); // Consume the initial quotation mark.
    Sexp stringLit;
    while (!_atEnd && !_match(unicode.QUOTE) && !_match(unicode.NL)) {
      int c = _advance();
      // if (c == unicode.BACKSLASH) {
      //   // Escape the next character.
      //   LexicalError err = _escape(bytes);
      //   if (err != null) error(err);
      // } else {
      bytes.add(c);
      // }
    }
    if (!_match(unicode.QUOTE)) {
      // Error: Unterminated string.
      stringLit = error(UnterminatedStringError(bytes, _location(offset)));
    } else {
      _advance(); // Consume the final quotation mark.
      String denotation = String.fromCharCodes(bytes);
      stringLit = new StringLiteral(denotation, _location(offset));
    }
    return stringLit;
  }

  // LexicalError _escape(List<int> bytes) {
  //   int offset = _offset;
  //   if (_atEnd) {
  //     // Error: bad escape.
  //     return BadCharacterEscapeError(<int>[], _location(offset));
  //   }
  //   int c = _peek();
  //   switch (c) {
  //     case unicode.b:
  //       _advance();
  //       bytes.add(unicode.BACKSPACE);
  //       break;
  //     case unicode.n:
  //       _advance();
  //       bytes.add(unicode.NL);
  //       break;
  //     case unicode.r:
  //       _advance();
  //       bytes.add(unicode.CR);
  //       break;
  //     case unicode.t:
  //       _advance();
  //       bytes.add(unicode.HT);
  //       break;
  //     case unicode.BACKSLASH:
  //       _advance();
  //       bytes.add(unicode.BACKSLASH);
  //       break;
  //     case unicode.u: // Unicode character.
  //       _advance();
  //       int i;
  //       for (i = 0; i < 4 && !_atEnd; i++) {
  //         if (isHex(_peek()))
  //           bytes.add(_advance());
  //         else
  //           break;
  //       }
  //       if (i != 4) {
  //         // Error: bad UTF-16 sequence.
  //         return InvalidUTF16SequenceError(
  //             bytes.sublist(bytes.length - i, bytes.length), _location(offset));
  //       }
  //       break;
  //     case unicode.QUOTE:
  //       bytes.add(_advance());
  //       break;
  //     default:
  //       c = _advance();
  //       return BadCharacterEscapeError(<int>[c], _location(offset));
  //   }
  //   return null;
  // }

  Sexp error(SyntaxError error) {
    _errors ??= new List<SyntaxError>();
    _errors.add(error);
    return Error(error, error.location);
  }

  int _peek() {
    return _stream.peek();
  }

  int _advance() {
    ++_offset;
    return _stream.read();
  }

  int getMatchingBracket(int beginBracket) {
    switch (beginBracket) {
      case unicode.LPAREN:
        return unicode.RPAREN;
      case unicode.LBRACKET:
        return unicode.RBRACKET;
      case unicode.LBRACE:
        return unicode.RBRACE;
      default:
        throw new ArgumentError(beginBracket);
    }
  }

  ListBrackets _bracketsKind(int kind) {
    switch (kind) {
      case unicode.LBRACE:
      case unicode.RBRACE:
        return ListBrackets.BRACES;
      case unicode.LBRACKET:
      case unicode.RBRACKET:
        return ListBrackets.BRACKETS;
      case unicode.LPAREN:
      case unicode.RPAREN:
        return ListBrackets.PARENS;
      default:
        throw new ArgumentError(kind);
    }
  }

  bool isValidAtomStart(int c) {
    return unicode.isAsciiLetter(c) ||
        unicode.isDigit(c) ||
        _validAtomSymbols.contains(c);
  }

  bool isValidAtomContinuation(int c) {
    return isValidAtomStart(c) || unicode.isDigit(c);
  }

  bool isHex(int c) {
    return unicode.a <= c && c <= unicode.f ||
        unicode.A <= c && c <= unicode.F ||
        unicode.isDigit(c);
  }

  Location _location(int offset) {
    return new Location(_uri, offset);
  }

  SpanLocation _spanLocation(int startOffset, int endOffset) {
    return new SpanLocation(_uri, startOffset, endOffset);
  }
}

class _TracingSexpParser extends _StatefulSexpParser {
  ParseTreeInteriorNode tree;
  _TracingSexpParser(Uri uri, ByteStream stream) : super(uri, stream);

  Result<Sexp, SyntaxError> parse() {
    tree = new ParseTreeInteriorNode("parse");
    var result = super.parse();
    tree.visit(new PrintParseTree());
    return result;
  }

  Sexp atom() {
    var parent = tree;
    tree = new ParseTreeInteriorNode("atom");
    var node = super.atom();
    if (node is Atom) {
      parent.add(new ParseTreeLeaf("atom", node.toString()));
    } else {
      parent.add(tree);
    }
    tree = parent;
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

  // Sexp number({int sign = unicode.PLUS_SIGN}) {
  //   var parent = tree;
  //   tree = new ParseTreeInteriorNode("number");
  //   var node = super.number(sign: sign);
  //   if (node is IntLiteral) {
  //     parent.add(new ParseTreeLeaf("number", node.toString()));
  //   } else {
  //     parent.add(tree);
  //   }
  //   tree = parent;
  //   return node;
  // }

  Sexp list() {
    var parent = tree;
    tree = new ParseTreeInteriorNode("list");
    parent.add(tree);
    var node = super.list();
    if (node is SList && node.sexps.length == 0) {
      parent.remove(tree);
      parent.add(new ParseTreeLeaf("list", "(nil)"));
    }
    tree = parent;
    return node;
  }

  // Sexp pair(Sexp first) {
  //   var parent = tree;
  //   tree = new ParseTreeInteriorNode("pair");
  //   parent.add(tree);
  //   var node = super.pair(first);
  //   if (node == first) parent.remove(tree);
  //   tree = parent;
  //   return node;
  // }

  Sexp error(SyntaxError err) {
    var node = super.error(err);
    tree.add(new ParseTreeLeaf("error", err.toString()));
    return node;
  }

  Sexp string() {
    var parent = tree;
    tree = new ParseTreeInteriorNode("string");
    var node = super.string();
    if (node is StringLiteral) {
      parent.add(new ParseTreeLeaf("string", node.toString()));
    } else {
      parent.add(tree);
    }
    tree = parent;
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

  void remove(ParseTreeNode node) {
    children.remove(node);
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
    return "$name: $value";
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
    _pb.write(_delete(prefix, prefix.length - 3, prefix.length - 1));
  }

  String _delete(String s, int start, int end) {
    StringBuffer buf = new StringBuffer();
    if (start > 0) buf.write(s.substring(0, start));
    if (end - s.length > 0) buf.write(s.substring(end, s.length - 1));
    return buf.toString();
  }
}

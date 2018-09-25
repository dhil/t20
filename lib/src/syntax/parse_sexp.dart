// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.syntax.parser;

import 'dart:collection';
import 'dart:io';

//import '../compilation_unit.dart';
import '../errors/errors.dart';
import '../io/bytestream.dart';
import '../unicode.dart' as Unicode;

import 'sexp.dart';
//import 'tokens.dart';
export 'sexp.dart';

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

// abstract class Parser {
//   const factory Parser.sexp() = SexpParser;
//   Result<Sexp, Object> parse(TokenStream stream, {bool trace = false});
// }

// class SexpParser implements Parser {
//   const SexpParser();

//   Result<Sexp, Object> parse(TokenStream stream, {bool trace = false}) {
//     _StatefulSexpParser parser;
//     if (trace) {
//       parser = new _TracingSexpParser(stream);
//     } else {
//       parser = new _StatefulSexpParserImpl(stream);
//     }
//     return parser.parse();
//   }
// }

// abstract class _StatefulSexpParser {
//   Result<Sexp, Object> parse();

//   Sexp atom();
//   Sexp expression();
//   Sexp integer();
//   Sexp list();
//   Sexp string();
//   //Sexp error();
// }

// class _StatefulSexpParserImpl implements _StatefulSexpParser {
//   PushbackStream<Token> _stream;

//   // Book keeping.
//   int _col = 0;
//   int _line = 1;
//   Queue<int> _brackets;
//   int _errors = 0;

//   _StatefulSexpParserImpl(TokenStream stream) {
//     _stream = new PushbackStream(stream);
//     _brackets = new Queue<int>();
//   }

//   Result<Sexp, Object> parse() {
//     final List<Sexp> sexps = new List<Sexp>();
//     while (!_match(TokenKind.EOF)) {
//       sexps.add(expression());
//     }
//     return new Result<Sexp, Object>(new Toplevel(sexps), null);
//   }

//   bool _match(TokenKind kind) {
//     return _peek().kind == kind;
//   }

//   bool _matchEither(List<TokenKind> kinds) {
//     for (TokenKind kind in kinds) {
//       if (_peek().kind == kind) return true;
//     }
//     return false;
//   }

//   Sexp expression() {
//     Token token = _peek();
//     switch (token.kind) {
//       case TokenKind.ATOM:
//         return atom();
//       case TokenKind.INT:
//         return integer();
//       case TokenKind.STRING:
//         return string();
//       case TokenKind.LBRACE:
//       case TokenKind.LBRACKET:
//       case TokenKind.LPAREN:
//         return list();
//       default:
//         // error
//         _advance();
//         _errors++;
//         print("Unexpected token error $token");
//     }
//     return null;
//   }

//   StringLiteral string() {
//     assert(_match(TokenKind.STRING));
//     Token token = _advance();
//     return StringLiteral(token.value, token.location);
//   }

//   IntLiteral integer() {
//     assert(_match(TokenKind.INT));
//     Token token = _advance();
//     return IntLiteral(token.value, token.location);
//   }

//   Atom atom() {
//     assert(_match(TokenKind.ATOM));
//     Token token = _advance();
//     return Atom(token.lexeme, token.location);
//   }

//   SList list() {
//     assert(_matchEither(
//         <TokenKind>[TokenKind.LBRACE, TokenKind.LBRACKET, TokenKind.LPAREN]));
//     Token beginBracket = _advance();
//     TokenKind endBracketKind = _correspondingClosingBracket(beginBracket.kind);

//     List<Sexp> sexps = new List<Sexp>();
//     while (!_match(endBracketKind) && !_match(TokenKind.EOF)) {
//       sexps.add(expression());
//     }

//     // Unterminated list.
//     if (!_match(endBracketKind)) {
//       print("error unterminated list");
//     }
//     Token endBracket = _advance();

//     return SList(sexps, _bracketsKind(endBracketKind), beginBracket.location);
//   }

//   Token _peek() {
//     return _stream.unsafePeek();
//   }

//   Token _advance() {
//     return _stream.next();
//   }

//   TokenKind _correspondingClosingBracket(TokenKind bracket) {
//     switch (bracket) {
//       case TokenKind.LBRACE:
//         return TokenKind.RBRACE;
//       case TokenKind.LBRACKET:
//         return TokenKind.RBRACKET;
//       case TokenKind.LPAREN:
//         return TokenKind.RPAREN;
//       default:
//         throw new ArgumentError();
//     }
//   }

//   bool _expectOpeningBracket(int c) {
//     if (_isBracket(c) && !_isClosingBracket(c)) {
//       _brackets.add(c);
//       return true;
//     } else {
//       return false;
//     }
//   }

//   bool _expectMatchingClosingBracket(int c) {
//     if (_brackets.isEmpty) return false;
//     return _brackets.removeLast() == c;
//   }

//   bool _isClosingBracket(int c) {
//     switch (c) {
//       case Unicode.RBRACE:
//       case Unicode.RBRACKET:
//       case Unicode.RPAREN:
//         return true;
//       default:
//         return false;
//     }
//   }

//   bool _isBracket(int c) {
//     switch (c) {
//       case Unicode.LBRACE:
//       case Unicode.RBRACE:
//       case Unicode.LBRACKET:
//       case Unicode.RBRACKET:
//       case Unicode.LPAREN:
//       case Unicode.RPAREN:
//         return true;
//       default:
//         return false;
//     }
//   }

//   ListBrackets _bracketsKind(TokenKind kind) {
//     switch (kind) {
//       case TokenKind.LBRACE:
//       case TokenKind.RBRACE:
//         return ListBrackets.BRACES;
//       case TokenKind.LBRACKET:
//       case TokenKind.RBRACKET:
//         return ListBrackets.BRACKETS;
//       case TokenKind.LPAREN:
//       case TokenKind.RPAREN:
//         return ListBrackets.PARENS;
//       default:
//         throw new ArgumentError(kind);
//     }
//   }
// }

abstract class Parser {
  const factory Parser.sexp() = SexpParser;
  Result<Sexp, SyntaxError> parse(ByteStream source, {bool trace = false});
}

class SexpParser implements Parser {
  const SexpParser();

  Result<Sexp, SyntaxError> parse(ByteStream source, {bool trace = false}) {
    if (source == null) throw new ArgumentError.notNull("source");
    if (trace)
      return new _TracingSexpParser(source).parse();
    else
      return new _StatefulSexpParser(source).parse();
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
    Unicode.AT,
    Unicode.LOW_LINE,
    Unicode.HYPHEN_MINUS,
    Unicode.PLUS_SIGN,
    Unicode.ASTERISK,
    Unicode.SLASH,
    Unicode.DOLLAR_SIGN,
    Unicode.BANG,
    Unicode.QUESTION_MARK,
    Unicode.EQUALS_SIGN,
    Unicode.LESS_THAN_SIGN,
    Unicode.GREATER_THAN_SIGN
  ]);
  final List<int> _whitespaces = const <int>[
    // Sorted after "likelihood".
    Unicode.SPACE,
    Unicode.NL,
    Unicode.SEMICOLON,
    Unicode.HT,
    Unicode.CR,
    Unicode.FF
  ];
  final List<int> _closingBrackets = const <int>[
    Unicode.RPAREN,
    Unicode.RBRACKET,
    Unicode.RBRACE
  ];
  // The input stream.
  ByteStream _stream;

  // Book keeping.
  int _offset = 0;
  List<SyntaxError> _errors;

  _StatefulSexpParser(this._stream);

  Result<Sexp, SyntaxError> parse() {
    spaces(); // Consume any initial white space.
    List<Sexp> sexps = new List<Sexp>();
    while (!_atEnd) {
      sexps.add(expression());
    }

    return new Result<Sexp, SyntaxError>(new Toplevel(sexps), _errors);
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
      if (_match(Unicode.SEMICOLON)) {
        // Consume comment.
        while (!_match(Unicode.NL)) _advance();
      }
      _advance();
    }
  }

  Sexp atom() {
    int c = _advance();
    assert(isValidAtomStart(c));
    if (c == Unicode.HYPHEN_MINUS && Unicode.isDigit(_peek())) {
      return number(sign: Unicode.HYPHEN_MINUS);
    } else {
      List<int> bytes = new List<int>()..add(c);
      while (!_atEnd && isValidAtomContinuation(_peek())) {
        bytes.add(_advance());
      }
      String value = String.fromCharCodes(bytes);
      return new Atom(value, null);
    }
  }

  Sexp number({int sign = Unicode.PLUS_SIGN}) {
    assert(Unicode.isDigit(_peek()));
    List<int> bytes = new List<int>()..add(_advance());
    while (!_atEnd && Unicode.isDigit(_peek())) {
      bytes.add(_advance());
    }
    int denotation = int.parse(String.fromCharCodes(bytes));
    if (sign == Unicode.HYPHEN_MINUS) denotation *= -1;
    return new IntLiteral(denotation, null);
  }

  Sexp expression() {
    Sexp sexp;
    int c = _peek();
    switch (c) {
      case Unicode.LPAREN:
      case Unicode.LBRACKET:
      case Unicode.LBRACE:
        sexp = list();
        break;
      case Unicode.ONE:
      case Unicode.TWO:
      case Unicode.THREE:
      case Unicode.FOUR:
      case Unicode.FIVE:
      case Unicode.SIX:
      case Unicode.SEVEN:
      case Unicode.EIGHT:
      case Unicode.NINE:
        sexp = number();
        break;
      case Unicode.QUOTE:
        sexp = string();
        break;
      default:
        if (isValidAtomStart(c)) {
          sexp = atom();
        } else {
          // Error: Invalid character.
          sexp = error(InvalidCharacterError(_advance(), null));
        }
    }
    spaces(); // Consume trailing white space.
    if (_match(Unicode.DOT))
      return pair(sexp);
    else
      return sexp;
  }

  Sexp list() {
    assert(_matchEither(const <int>[0x0028, 0x005b, 0x007b]));
    int beginBracket = _advance();
    spaces(); // Consume any white space after the bracket.
    List<Sexp> sexps = new List<Sexp>();
    while (!_atEnd && !_matchEither(_closingBrackets)) {
      sexps.add(expression());
    }
    Sexp sexp;
    if (_peek() != getMatchingBracket(beginBracket)) {
      // Error: Unmatched bracket.
      sexp = error(UnmatchedBracketError(beginBracket, null));
    } else {
      _advance(); // Consume end bracket.
      sexp = new SList(sexps, _bracketsKind(beginBracket), null);
    }
    return sexp;
  }

  Sexp pair(Sexp first) {
    assert(_match(Unicode.DOT));
    _advance();
    spaces(); // Consume any white space after the dot.
    Sexp second = expression(); // As a side-effect [expression] consumes
    // trailing white space.
    return new Pair(first, second, null);
  }

  Sexp string() {
    assert(_match(Unicode.QUOTE));
    List<int> bytes = new List<int>();
    _advance(); // Consume the initial quotation mark.
    while (!_atEnd && !_match(Unicode.QUOTE)) {
      bytes.add(_advance());
    }
    Sexp stringLit;
    if (!_match(Unicode.QUOTE)) {
      // Error: Unterminated string.
      stringLit = error(UnterminatedStringError(bytes, null));
    } else {
      _advance(); // Consume the final quotation mark.
      String denotation = String.fromCharCodes(bytes);
      stringLit = new StringLiteral(denotation, null);
    }
    return stringLit;
  }

  Sexp error(SyntaxError error) {
    _errors ??= new List<SyntaxError>();
    _errors.add(error);
    return Error(error);
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
      case Unicode.LPAREN:
        return Unicode.RPAREN;
      case Unicode.LBRACKET:
        return Unicode.RBRACKET;
      case Unicode.LBRACE:
        return Unicode.RBRACE;
      default:
        throw new ArgumentError(beginBracket);
    }
  }

  ListBrackets _bracketsKind(int kind) {
    switch (kind) {
      case Unicode.LBRACE:
      case Unicode.RBRACE:
        return ListBrackets.BRACES;
      case Unicode.LBRACKET:
      case Unicode.RBRACKET:
        return ListBrackets.BRACKETS;
      case Unicode.LPAREN:
      case Unicode.RPAREN:
        return ListBrackets.PARENS;
      default:
        throw new ArgumentError(kind);
    }
  }

  bool isValidAtomStart(int c) {
    return Unicode.isAsciiLetter(c) || _validAtomSymbols.contains(c);
  }

  bool isValidAtomContinuation(int c) {
    return isValidAtomStart(c) || Unicode.isDigit(c);
  }
}

class _TracingSexpParser extends _StatefulSexpParser {
  ParseTreeInteriorNode tree;
  _TracingSexpParser(ByteStream stream) : super(stream);

  Result<Sexp, SyntaxError> parse() {
    tree = new ParseTreeInteriorNode("parse");
    var result = super.parse();
    tree.visit(new PrintParseTree());
    return result;
  }

  Sexp atom() {
    var node = super.atom();
    if (node is Atom)
      tree.add(new ParseTreeLeaf("atom", node.toString()));
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

  Sexp number({int sign = Unicode.PLUS_SIGN}) {
    var node = super.number(sign: sign);
    tree.add(new ParseTreeLeaf("number", node.toString()));
    return node;
  }

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

  Sexp pair(Sexp first) {
    var parent = tree;
    tree = new ParseTreeInteriorNode("pair");
    parent.add(tree);
    var node = super.pair(first);
    if (node == first) parent.remove(tree);
    tree = parent;
    return node;
  }

  Sexp error(SyntaxError err) {
    var node = super.error(err);
    tree.add(new ParseTreeLeaf("error", err.toString()));
    return node;
  }

  Sexp string() {
    var node = super.string();
    tree.add(new ParseTreeLeaf("string", node.toString()));
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
    _pb.write(delete(prefix, prefix.length - 3, prefix.length - 1));
  }

  String delete(String s, int start, int end) {
    StringBuffer buf = new StringBuffer();
    if (start > 0) buf.write(s.substring(0, start));
    if (end - s.length > 0) buf.write(s.substring(end, s.length - 1));
    return buf.toString();
  }
}

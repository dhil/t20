// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart' show Location;
import '../unicode.dart' as unicode;

// TODO clean up the whole naming business.
class Name {
  final String text; // TODO: intern strings.
  final Location _location;

  Location get location => _location ?? Location.dummy();

  const Name(this.text, [Location location = null]) : this._location = location;

  String toString() {
    return text;
  }

  bool operator== (dynamic other) {
    if (other == null) return false;
    if (other is Name) return other.text.compareTo(text) == 0;
    if (other is String) return other.compareTo(text) == 0;
  }

  static bool equals(Name name, Name other) {
    if (name == null || other == null) return name == other;
    return name.text.compareTo(other.text) == 0;
  }

  int get hashCode {
    int result = 17;
    result = 37 * result + text.hashCode;
    return result;
  }
}

class DummyName extends Name {
  const DummyName([Location location = null]) : super("<dummy>", location);
}

final Set<int> allowedIdentSymbols = Set.of(const <int>[
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
  unicode.COLON
]);

bool isValidIdentifier(String name) {
  assert(name != null);
  if (name.length == 0) return false;

  // An identifier is not allowed to start with an underscore (_) or colon (:).
  int c = name.codeUnitAt(0);
  if (!unicode.isAsciiLetter(c) &&
      !(allowedIdentSymbols.contains(c) && c != unicode.LOW_LINE && c != unicode.COLON)) {
    return false;
  }

  for (int i = 1; i < name.length; i++) {
    c = name.codeUnitAt(i);
    if (!unicode.isAsciiLetter(c) &&
        !unicode.isDigit(c) &&
        !allowedIdentSymbols.contains(c)) {
      return false;
    }
  }
  return true;
}

bool isValidTypeVariableName(String name) {
  assert(name != null);

  if (name.length < 2) return false;
  int c = name.codeUnitAt(0);
  int k = name.codeUnitAt(1);
  if (c != unicode.APOSTROPHE) return false;
  if (!unicode.isAsciiLetter(k)) return false;

  for (int i = 1; i < name.length; i++) {
    c = name.codeUnitAt(i);
    if (!unicode.isAsciiLetter(c) && !unicode.isDigit(c)) return false;
  }

  return true;
}

bool isValidTypeName(String name) {
  assert(name != null);
  if (name.length == 0) return false;
  int c = name.codeUnitAt(0);
  if (!unicode.isAsciiUpper(c)) return false;

  for (int i = 1; i < name.length; i++) {
    c = name.codeUnitAt(i);
    if (!unicode.isAsciiLetter(c)) return false;
  }
  return true;
}

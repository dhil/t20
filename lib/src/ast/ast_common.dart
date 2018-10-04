// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../location.dart' show Location;
import '../unicode.dart' as unicode;

class Name {
  final String text; // TODO: intern strings.
  final Location _location;

  Location get location => _location ?? Location.dummy();

  const Name(this.text, [Location location = null]) : this._location = location;

  String toString() {
    return text;
  }
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

  // An identifier is not allowed to start with an underscore (_).
  int c = name.codeUnitAt(0);
  if (!unicode.isAsciiLetter(c) &&
      !(allowedIdentSymbols.contains(c) && c != unicode.LOW_LINE)) {
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

bool isValidQuantifier(String name) {
  assert(name != null);
  if (name.length < 2) return false;

  int c = name.codeUnitAt(0);
  int k = name.codeUnitAt(1);
  if (c != unicode.APOSTROPHE && !unicode.isAsciiLetter(k)) return false;

  for (int i = 1; i < name.length; i++) {
    c = name.codeUnitAt(i);
    if (!unicode.isAsciiLetter(i) && !unicode.isDigit(c)) return false;
  }

  return true;
}

// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.location;

class Location {
  final Uri uri;
  final int startOffset;

  static Location _primInstance;

  const Location(this.uri, this.startOffset);
  const factory Location.span(Uri uri, int startOffset, int endOffset) =
      SpanLocation;
  factory Location.dummy([String sourceName]) = DummyLocation;
  factory Location.primitive() {
    _primInstance ??= PrimitiveLocation();
    return _primInstance;
  }


  String toString() {
    return "<$uri:$startOffset>";
  }

  bool get isSynthetic => false;
}

class SpanLocation extends Location {
  final int endOffset;

  const SpanLocation(Uri uri, int startOffset, this.endOffset)
      : super(uri, startOffset);

  String toString() {
    return "<$uri:$startOffset:$endOffset>";
  }

  Location get end => Location(super.uri, endOffset);
}

class DummyLocation extends Location {
  final String sourceName;

  DummyLocation([this.sourceName = "dummy"])
      : super(Uri.dataFromString(""), -1);

  String toString() {
    return "<$sourceName:$startOffset>";
  }

  bool get isSynthetic => true;
}

class PrimitiveLocation extends Location {
  PrimitiveLocation() : super(Uri.dataFromString(""), -1);

  String toString() {
    return "<primitive>";
  }

  bool get isSynthetic => true;
}

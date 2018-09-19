// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library t20.io;

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import '../option.dart';

class EndOfStreamError {}

/// A stream of data E.
abstract class Stream<E> {
  factory Stream.empty() = _EmptyStream<E>;
  bool get endOfStream;
  E next();

  // Stream<T> map<T>(T Function(E));
}

/// An infinite stream.
class InfiniteStream<E> implements Stream<E> {
  final E lastElement;
  final Stream<E> _stream;

  InfiniteStream.fromFinite(Stream<E> input, this.lastElement)
      : _stream = input == null ? new _EmptyStream<E>() : input;

  bool get endOfStream => false;

  E next() {
    if (_stream.endOfStream) return lastElement;
    return _stream.next();
  }

  InfiniteStream<T> map<T>(T Function(E) fn) {
    return new InfiniteStream<T>.fromFinite(
        new _MappedStream<E, T>(fn, this), fn(lastElement));
  }
}

class _MappedStream<S, T> implements Stream<T> {
  final Stream<S> _stream;
  final T Function(S) _fn;

  _MappedStream(this._fn, this._stream);

  bool get endOfStream => _stream.endOfStream;
  T next() {
    if (_stream.endOfStream) throw new EndOfStreamError();
    return _fn(_stream.next());
  }

  Stream<U> map<U>(U Function(T) fn) {
    return new _MappedStream<T, U>(fn, this);
  }
}

class _EmptyStream<E> implements Stream<E> {
  bool get endOfStream => true;
  E next() {
    throw new EndOfStreamError();
  }

  _EmptyStream<T> map<T>(T Function(E) _) {
    return new _EmptyStream<T>();
  }
}

class _FileIterator implements Iterator<int> {
  final RandomAccessFile _file;
  int _current;
  _FileIterator(this._file) : _current = -1;

  bool moveNext() {
    _current = _file.readByteSync();
    return _current != -1;
  }

  int get current => _current;
}

// class _MappedIterator<S, T> implements Iterator<T> {
//   final Iterator<S> _source;
//   final T Function(S) _fn;

//   class _MappedIterator(this._fn, this._source);

//   bool moveNext() {
//     return _source.moveNext();
//   }

//   T get current => _fn(_source.current);
// }

/// A stream of bytes.
class ByteStream implements Stream<int> {
  Iterator<int> _stream;
  int _next;

  ByteStream.fromString(String source) {
    if (source == null)
      _stream = const <int>[].iterator;
    else
      _stream = source.codeUnits.iterator;

    if (_stream.moveNext()) _next = _stream.current;
  }

  ByteStream.fromBytes(List<int> codeUnits) {
    if (codeUnits == null)
      _stream = const <int>[].iterator;
    else
      _stream = codeUnits.iterator;

    if (_stream.moveNext()) _next = _stream.current;
  }

  ByteStream.fromFile(RandomAccessFile handle) {
    if (handle == null)
      _stream = const <int>[].iterator;
    else
      _stream = new _FileIterator(handle);

    if (_stream.moveNext()) _next = _stream.current;
  }

  bool get endOfStream => _next == null;

  int next() {
    if (endOfStream) throw new EndOfStreamError();

    final int byte = _next;
    if (!_stream.moveNext())
      _next = null;
    else
      _next = _stream.current;
    return byte;
  }

  Stream<T> map<T>(T Function(int) fn) {
    return new _MappedStream<int, T>(fn, this);
  }
}

/// A stream that allows read elements to be pushed back onto the stream. Note
/// that a pushed element need not originate from the stream.
class PushbackStream<E> implements Stream<E> {
  Stream<E> _stream;
  Queue<E> _pushbackBuffer;

  PushbackStream(Stream<E> input)
      : _stream = input == null ? Stream.empty() : input,
        _pushbackBuffer = new Queue<E>();

  void unread(E e) {
    _pushbackBuffer.add(e);
  }

  E unsafePeek([int lookAhead = 1]) {
    if (lookAhead < 1) return null;

    if (lookAhead < _pushbackBuffer.length) {
      return _pushbackBuffer.elementAt(lookAhead);
    }

    int limit = lookAhead - _pushbackBuffer.length;
    while (!_stream.endOfStream && limit > 0) {
      limit--;
      _pushbackBuffer.add(_stream.next());
    }
    if (limit == 0) {
      E elem = _pushbackBuffer.removeLast();
      _pushbackBuffer.addLast(elem);
      return elem;
    } else {
      return null;
    }
  }

  Option<E> peek([int lookAhead = 1]) {
    E e = unsafePeek(lookAhead);
    if (e == null) return Option.none();
    else return Option<E>.some(e);
  }

  bool get endOfStream => _stream.endOfStream && _pushbackBuffer.isEmpty;

  E next() {
    if (_pushbackBuffer.length > 0) {
      return _pushbackBuffer.removeFirst();
    } else if (!_stream.endOfStream) {
      return _stream.next();
    } else {
      throw new EndOfStreamError();
    }
  }

  PushbackStream<T> map<T>(T Function(E) fn) {
    return new PushbackStream<T>(new _MappedStream<E, T>(fn, this));
  }
}

/// A stream that buffers the contents of its underlying stream.
class BufferedStream<E> implements Stream<E> {
  Stream<E> _stream;
  List<E> _buffer;
  int _ptr = 0;
  int _length = 0;

  BufferedStream(Stream<E> input, {int size = 1024})
      : _stream = input == null ? new _EmptyStream() : input {
    _buffer = BufferedStream._makeBuffer<E>(size);
  }

  static List<E> _makeBuffer<E>(int size) {
    if (size < 0) size = 1024;
    return new List<E>(size);
  }

  bool get endOfStream => _stream.endOfStream && _ptr == _length;

  E next() {
    if (endOfStream) throw new EndOfStreamError();

    if (_ptr == _length) _fillBuffer();
    return _buffer[_ptr++];
  }

  void _fillBuffer() {
    int max = _buffer.length;
    int ptr = 0;
    while (!_stream.endOfStream && ptr < max) {
      _buffer[ptr++] = _stream.next();
    }
    _length = ptr;
    _ptr = 0;
  }

  BufferedStream<T> map<T>(T Function(E) fn) {
    final Stream<T> input = new _MappedStream<E, T>(fn, this);
    return new BufferedStream<T>(input, size: 1);
  }
}

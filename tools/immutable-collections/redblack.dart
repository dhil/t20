// Immutable Red Black tree.

import 'dart:collection' show Queue;

class Pair<A, B> {
  final A fst;
  final B snd;

  Pair(this.fst, this.snd);

  A get $1 => fst;
  B get $2 => snd;
}

class Colour {
  static const int RED = 0;
  static const int BLACK = 1;
}

abstract class ImmSet<T extends Comparable<T>> {
  //int get size;

  bool contains(T x);
  ImmSet<T> add(T x);
  ImmSet<T> union(RedBlackSet<T> y);
  //ImmSet<T> intersect(RedBlackSet<T> y);
  //ImmSet<T> diff(RedBlackSet<T> y);
}

class RedBlackSet<T extends Comparable<T>> implements ImmSet<T> {
  final RBNode<T> _tree;
  final int size;

  RedBlackSet.empty() : this._(RBNode<T>.nil(), 0);
  RedBlackSet._(this._tree, this.size);

  bool contains(T x) => _tree.contains(x);
  RedBlackSet<T> add(T x) {
    return RedBlackSet._(_tree.add(x), size + 1);
  }

  RedBlackSet<T> union(RedBlackSet<T> other) {
    // TODO this an näive implementation whose complexity is O(m log(m + n -
    // 1)), where m is the number of elements in [_tree]. There is a more
    // efficient algorithm which has only O(m + n) complexity.
    Iterator<T> it = _tree.iterator;
    List<T> xs = new List<T>();
    while (it.moveNext()) {
      xs.add(it.current);
    }
    RedBlackSet<T> u = other;
    for (T x in xs) {
      u.add(x);
    }
    return u;
  }
}

abstract class RBNode<T extends Comparable<T>> {
  int get colour;
  bool get isNil;
  Iterator<T> get iterator;
  bool contains(T obj);
  RBNode<T> add(T obj);

  const factory RBNode.nil() = Nil<T>;
}

class _NilIterator<T> implements Iterator<T> {
  bool moveNext() => false;
  T current;
}

class Nil<T extends Comparable<T>> implements RBNode<T> {
  const Nil();

  int get colour => Colour.BLACK;
  bool get isNil => true;
  bool contains(T _) => false;
  RBNode<T> add(T x) {
    return Node<T>(this, x, this, Colour.RED);
  }

  Iterator<T> get iterator => _NilIterator<T>();
}

class _NodeIterator<T extends Comparable<T>> implements Iterator<T> {
  T current;
  Queue<Node<T>> stk;

  _NodeIterator(Node<T> node) {
    stk = new Queue<Node<T>>()..add(node);
  }

  bool moveNext() {
    if (stk.isEmpty) return false;

    Node<T> node = stk.removeLast();
    if (node.right is Node) {
      stk.add(node.right);
    }

    if (node.left is Node) {
      stk.add(node.left);
    }

    current = node.element;
    return true;
  }
}

class Node<T extends Comparable<T>> implements RBNode<T> {
  int colour;
  bool get isNil => false;

  T elem;

  T get element => elem;

  RBNode<T> left;
  RBNode<T> right;

  Node(this.left, this.elem, this.right, this.colour);

  bool contains(T x) {
    RBNode<T> tree = this;
    while (tree is Node) {
      Node<T> node = tree;
      int result = x.compareTo(node.element);
      if (result == 0) {
        return true;
      } else if (result < 0) {
        tree = node.left;
      } else {
        tree = node.right;
      }
    }
    return false;
  }

  static Node<T> _insert<T extends Comparable<T>>(T x, RBNode<T> tree) {
    if (!tree.isNil) {
      Node<T> node = tree as Node<T>;
      int result = x.compareTo(node.element);
      if (result == 0) {
        return tree;
      } else if (result < 0) {
        return _balance<T>(
            node.colour, _insert<T>(x, node.left), node.element, node.right);
      } else {
        return _balance<T>(
            node.colour, node.left, node.element, _insert<T>(x, node.right));
      }
    } else {
      RBNode<T> nil = RBNode<T>.nil();
      return Node<T>(nil, x, nil, Colour.RED);
    }
  }

  RBNode<T> add(T x) {
    if (contains(x)) return this;

    Node<T> node = _insert(x, this);
    node.colour = Colour.BLACK;
    return node;
  }

  static Node<T> _balance<T extends Comparable<T>>(
      int colour, RBNode<T> left, T elem, RBNode<T> right) {
    if (colour == Colour.BLACK) {
      if (left is Node && left.colour == Colour.RED) {
        Node<T> lchild = left as Node<T>;
        if (lchild.left.colour == Colour.RED && lchild.left is Node) {
          // B (Node R (Node R a x b) y c) z d = Node R (Node B a x b) y (Node B c z d).
          Node<T> lgrandchild = lchild.left as Node<T>;

          RBNode<T> a = lgrandchild.left;
          T x = lgrandchild.element;
          RBNode<T> b = lgrandchild.right;

          T y = lchild.element;
          RBNode<T> c = lchild.right;

          T z = elem;
          RBNode<T> d = right;

          Node<T> left0 = Node<T>(a, x, b, Colour.BLACK);
          Node<T> right0 = Node<T>(c, z, d, Colour.BLACK);
          return Node<T>(left0, y, right0, Colour.RED);
        } else if (lchild.right.colour == Colour.RED && lchild.right is Node) {
          // B (Node R a x (Node R b y c)) z d = Node R (Node B a x b) y (Node B c z d).
          Node<T> rgrandchild = lchild.right as Node<T>;

          RBNode<T> a = lchild.left;
          T x = lchild.element;

          RBNode<T> b = rgrandchild.left;
          T y = rgrandchild.element;
          RBNode<T> c = rgrandchild.right;

          T z = elem;
          RBNode<T> d = right;

          RBNode<T> left0 = Node<T>(a, x, b, Colour.BLACK);
          RBNode<T> right0 = Node<T>(c, z, d, Colour.BLACK);
          return Node<T>(left0, y, right0, Colour.RED);
        }
      } else if (right is Node && right.colour == Colour.RED) {
        Node<T> rchild = right as Node<T>;
        if (rchild.left.colour == Colour.RED && rchild.left is Node) {
          // B a x (Node R (Node R b y c) z d) = Node R (Node B a x b) y (Node B c z d).
          Node<T> lgrandchild = rchild.left as Node<T>;

          RBNode<T> a = left;
          T x = elem;

          RBNode<T> b = lgrandchild.left;
          T y = lgrandchild.element;
          RBNode<T> c = lgrandchild.right;

          T z = rchild.element;
          RBNode<T> d = rchild.right;

          RBNode<T> left0 = Node<T>(a, x, b, Colour.BLACK);
          RBNode<T> right0 = Node<T>(c, z, d, Colour.BLACK);
          return Node<T>(left0, y, right0, Colour.RED);
        } else if (rchild.right.colour == Colour.RED && rchild.right is Node) {
          // B a x (Node R b y (Node R c z d)) = Node R (Node B a x b) y (Node B c z d).
          Node<T> rgrandchild = rchild.right as Node<T>;

          RBNode<T> a = left;
          T x = elem;

          RBNode<T> b = rchild.left;
          T y = rchild.element;

          RBNode<T> c = rgrandchild.left;
          T z = rgrandchild.element;
          RBNode<T> d = rgrandchild.right;

          RBNode<T> left0 = Node<T>(a, x, b, Colour.BLACK);
          RBNode<T> right0 = Node<T>(c, z, d, Colour.BLACK);
          return Node<T>(left0, y, right0, Colour.RED);
        }
      }
    }
    return Node(left, elem, right, colour);
  }

  Iterator<T> get iterator => _NodeIterator<T>(this);
}

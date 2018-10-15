// Immutable Red Black tree.

class Colour {
  static const int RED = 0;
  static const int BLACK = 1;
}

abstract class RBNode<T extends Comparable<T>> {
  int get colour;
  T get element;
  bool get isNil;
  bool contains(T obj);
  RBNode<T> add(T obj);
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
    RBNode<T> node = this;
    while (node is Node) {
      RBNode node0 = node;
      int result = x.compareTo(node0.element);
      if (result == 0) {
        return true;
      } else if (result < 0) {
        node = left;
      } else {
        node = right;
      }
    }
    return false;
  }

  RBNode<T> add(T x) {
    RBNode<T> ins(RBNode<T> tree) {
      if (!tree.isNil) {
        int result = x.compareTo(tree.elem);
        if (result == 0) {
          return this;
        } else if (result < 0) {
          return balance(colour, ins(left), elem, right);
        } else {
          return balance(colour, left, elem, ins(right));
        }
      } else {
        return Node<T>(RBNode<T>.nil(), x, RBNode<T>.nil(), Colour.RED);
      }
    }

    RBNode<T> node = ins(this);
    node.colour = Colour.BLACK;
    return node;
  }

  RBNode<T> balance(int colour, RBNode<T> left, T elem, RBNode<T> right) {
    switch (colour) {
      if (colour == Colour.BLACK) {
        if (left is Node && left.colour == Colour.RED) {
          Node<T> lchild = left as Node<T>;
          // B (Node R (Node R a x b) y c) z d = Node R (Node B a x b) y (Node B c z d)
          if (lchild.left.colour == Colour.RED && lchild.left is Node) {
            Node<T> lgrandchild = lchild.left as Node<T>;
            Node<T> l = Node<T>(lgrandchild.left, lgrandchild.element,
                lgrandchild.right, Colour.BLACK);
            Node<T> r = Node<T>(lchild.right, elem, right, Colour.BLACK);
            return Node<T>(l, lchild.element, r, Colour.RED);
            // B (Node R a x (Node R b y c)) z d = Node R (Node B a x b) y (Node B c z d)
          } else if (lchild.right.colour == Colour.RED &&
              lchild.left.right is Node) {
            Node<T> rgrandchild = lchild.right as Node<T>;
            Node<T> l = Node<T>(
                lchild.left, lchild.element, rgrandchild.left, Colour.BLACK);
            Node<T> r = Node<T>(
                rgrandchild.right, left.element, left.right, Colour.BLACK);
            return Node<T>(l, rgrandchild.element, r, Colour.RED);
          }
        } else if (right is Node && right.colour == Colour.RED) {
          Node<T> rchild = right as Node<T>;
          // B a x (Node R (Node R b y c) z d) = Node R (Node B a x b) y (Node B c z d)
          // B a x (Node R b y (Node R c z d)) = Node R (Node B a x b) y (Node B c z d)
        }
      }
      return Node(left, elem, right, colour);
    }
  }
}

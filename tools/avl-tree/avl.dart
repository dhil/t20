class NotFound {}

class AVLNode<K extends Comparable<K>, V> {
  final K key;
  final V value;
  final int height;

  final AVLNode<K, V> left;
  final AVLNode<K, V> right;

  AVLNode(this.key, this.value, AVLNode<K, V> left, AVLNode<K, V> right)
      : this.left = left,
        this.right = right,
        this.height = 1 + max(getHeight(left), getHeight(right));

  static int getHeight<K extends Comparable<K>, V>(AVLNode<K, V> tree) {
    if (tree == null) {
      return 0;
    } else {
      return tree.height;
    }
  }

  static AVLNode<K, V> rotateLeft<K extends Comparable<K>, V>(
      AVLNode<K, V> node) {
    // Node (k, x, l, Node (rk, rx, rl, rr)) = Node (rk, rx, Node (k, x, l, rl), rr).
    assert(node.right != null);
    AVLNode<K, V> rnode = node.right;
    return AVLNode<K, V>(
        rnode.key,
        rnode.value,
        AVLNode<K, V>(node.key, node.value, node.left, rnode.left),
        rnode.right);
  }

  static AVLNode<K, V> rotateRight<K extends Comparable<K>, V>(
      AVLNode<K, V> node) {
    // Node (k, x, Node (lk, lx, ll, lr), r) = Node (lk, lx, ll, Node (k, x, lr, r)).
    assert(node.left != null);
    AVLNode<K, V> lnode = node.left;
    return AVLNode<K, V>(lnode.key, lnode.value, lnode.left,
        AVLNode<K, V>(node.key, node.value, lnode.right, node.right));
  }

  static AVLNode<K, V> insert<K extends Comparable<K>, V>(
      K key, V value, AVLNode<K, V> node) {
    if (node == null) {
      return AVLNode<K, V>(key, value, null, null);
    }

    int result = key.compareTo(node.key);
    if (result == 0) {
      return AVLNode<K, V>(key, value, node.left, node.right);
    } else if (result < 0) {
      AVLNode<K, V> ltree = insert<K, V>(key, value, node.left);
      if (getHeight<K, V>(ltree) - getHeight<K, V>(node.right) <= 1) {
        return AVLNode<K, V>(node.key, node.value, ltree, node.right);
      } else {
        ltree = getHeight<K, V>(ltree.left) < getHeight<K, V>(ltree.right)
            ? rotateLeft<K, V>(ltree)
            : ltree;
        return rotateRight<K, V>(
            AVLNode<K, V>(node.key, node.value, ltree, node.right));
      }
    } else {
      AVLNode<K, V> rtree = insert<K, V>(key, value, node.right);
      if (getHeight<K, V>(rtree) - getHeight<K, V>(node.left) <= 1) {
        return AVLNode<K, V>(node.key, node.value, node.left, rtree);
      } else {
        rtree = getHeight<K, V>(rtree.left) > getHeight<K, V>(rtree.right)
            ? rotateRight<K, V>(rtree)
            : rtree;
        return rotateLeft<K, V>(
            AVLNode<K, V>(node.key, node.value, node.left, rtree));
      }
    }
  }

  static AVLNode<K, V> delete<K extends Comparable<K>, V>(
      K key, AVLNode<K, V> node) {
    try {
      return _delete<K, V>(key, node);
    } on NotFound {
      return node;
    }
  }

  static AVLNode<K, V> _delete<K extends Comparable<K>, V>(K key, AVLNode<K, V> node) {
    return null;
  }

  static int max(int a, int b) => a >= b ? a : b;

  static V lookup<K extends Comparable<K>, V>(K key, AVLNode<K, V> node) {
    V value;
    while (node != null) {
      int result = key.compareTo(node.key);
      if (result == 0) {
        value = node.value;
        break;
      } else if (result < 0) {
        node = node.left;
      } else {
        node = node.right;
      }
    }
    return value;
  }
}

class AVLTree<K extends Comparable<K>, V> {
  final AVLNode<K, V> root;
  AVLTree.empty() : root = null;
  AVLTree._(this.root);

  int get height => AVLNode.getHeight<K, V>(root);

  bool containsKey(K key) =>
      AVLNode.lookup<K, V>(key, root) != null ? true : false;

  V lookup(K key) => AVLNode.lookup<K, V>(key, root);

  AVLTree<K, V> put(K key, V value) {
    AVLNode<K, V> tree = AVLNode.insert<K, V>(key, value, root);
    return AVLTree<K, V>._(tree);
  }

  AVLTree<K, V> remove(K key) {
    AVLNode<K, V> tree = AVLNode.delete<K, V>(key, root);
    return identical(tree, root) ? this : AVLTree<K, V>._(tree);
  }
}

void main() {}

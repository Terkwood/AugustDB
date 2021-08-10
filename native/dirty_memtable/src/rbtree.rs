#![allow(dead_code)]
use rand::Rng;
use std::cmp::Ord;
use std::cmp::Ordering;
use std::fmt::Debug;
use std::iter::IntoIterator;
use std::iter::Iterator;

pub struct Node<K, V> {
    value: V,
    key: K,
    left: Option<usize>,
    right: Option<usize>,
    size: usize,
    color: Color,
    parent: Option<usize>,
}

#[derive(Copy, Clone)]
struct Color {
    color: bool,
}

impl Color {
    const RED: bool = true;
    const BLACK: bool = false;
    fn red() -> Color {
        Color { color: Color::RED }
    }
    fn black() -> Color {
        Color {
            color: Color::BLACK,
        }
    }
    fn is_red(self) -> bool {
        self.color == Color::RED
    }
    fn flip(&mut self) {
        self.color = !self.color;
    }
}

impl<K, V> Debug for Node<K, V>
where
    K: Debug,
    V: Debug,
{
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        let left = if self.left.is_some() {
            format!("{}", self.left.unwrap())
        } else {
            "_".to_string()
        };
        let right = if self.right.is_some() {
            format!("{}", self.right.unwrap())
        } else {
            "_".to_string()
        };
        let paren = if self.parent.is_some() {
            format!("{}", self.parent.unwrap())
        } else {
            "_".to_string()
        };
        write!(
            f,
            "Node {:?} parent {} left: {} right: {} k: {:?} v: {:?}, s: {}",
            self.color, paren, left, right, self.key, self.value, self.size
        )
    }
}

impl Debug for Color {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        if self.is_red() {
            write!(f, "RED")
        } else {
            write!(f, "BLACK")
        }
    }
}

pub struct RBTree<K, V>
where
    K: Ord + Sync,
    V: Sync,
{
    root: Option<usize>,
    nodes: Vec<Node<K, V>>,
}

struct DeleteResult {
    child: Option<usize>,
    moved_node: usize,
    moved_node_new_id: usize,
}

impl DeleteResult {
    fn translate(&self, id: usize) -> usize {
        if self.moved_node == id {
            self.moved_node_new_id
        } else {
            id
        }
    }

    fn set_child(mut self, id: usize) -> DeleteResult {
        self.child = Some(self.translate(id));
        self
    }
}

///
/// A Red-Black BST Implementation, using a Vec for storing the actual node data.
/// Rather than linking directly from one node to another, each node's `left` and `right`
/// fields contain an `Option<usize>`, where `Some(id)` refers to an index within the `nodes` Vec.
///
/// Inspiration for this approach taken from various examples using a vector-based _arena_.
///
/// The design goals here were to keep the tree data exclusively inside of the vector in order to
/// take advantage of performance optimizations resulting from use of contiguous blocks of memory.
///
/// It remains to be seen if this actually speeds things up, pending some benchmarking.
///
/// The trick with all recursive data structures I've seen so far, is in satisfying the borrow checker.
/// This was solved by making it so that all node manipulations are done by moving only `Copy` values,
/// so as to circumvent the _cannot move from borrowed value_ error.
///
/// The algorithm itself is Robert Sedgewick's algorithm as [written in java](https://algs4.cs.princeton.edu/33balanced/RedBlackBST.java.html).
/// While I found some discussion online describing O(1) fixups, the implementations seem
/// overly complex, and I'm satisfied with O(log(N)) fixups.
///
impl<K, V> RBTree<K, V>
where
    K: Ord + Debug + Sync,
    V: Debug + Sync,
{
    pub fn new() -> RBTree<K, V> {
        Self::default()
    }

    pub fn random(&self) -> Option<(&K, &V)> {
        if self.is_empty() {
            None
        } else {
            let rank = rand::thread_rng().gen_range(0..self.len());
            let node = &self.nodes[self.select_from_node(rank, self.root.unwrap())];
            Some((&node.key, &node.value))
        }
    }

    pub fn get(&self, key: &K) -> Option<&V> {
        let mut maybe_id = self.root;
        while let Some(id) = maybe_id {
            let node = &self.nodes[id];
            match key.cmp(&node.key) {
                Ordering::Equal => return Some(&node.value),
                Ordering::Less => maybe_id = node.left,
                Ordering::Greater => maybe_id = node.right,
            }
        }

        None
    }

    pub fn insert(&mut self, key: K, value: V) {
        self.root = Self::put(self.root, None, key, value, &mut self.nodes);
        self.nodes[self.root.unwrap()].color = Color::black();
        // assert!(self.check());
    }

    pub fn len(&self) -> usize {
        Self::size(self.root, &self.nodes)
    }

    pub fn is_empty(&self) -> bool {
        self.root.is_none()
    }

    /**
     * It returns true if the left and right heights differ by one or zero.
     */
    pub fn is_balanced(&self) -> bool {
        let mut black = 0;
        let mut node = self.root;
        while node.is_some() {
            if !Self::is_red(node, &self.nodes) {
                black += 1;
            }
            node = self.nodes[node.unwrap()].left;
        }
        self.node_balanced(self.root, black)
    }

    fn node_balanced(&self, maybe_id: Option<usize>, black: i32) -> bool {
        if let Some(id) = maybe_id {
            let diff = if self.nodes[id].color.is_red() { 0 } else { -1 };
            self.node_balanced(self.nodes[id].left, black + diff)
                && self.node_balanced(self.nodes[id].right, black + diff)
        } else {
            black == 0
        }
    }

    pub fn contains(&self, key: &K) -> bool {
        self.get(key).is_some()
    }

    pub fn delete(&mut self, key: &K) {
        if !self.contains(key) {
            return;
        }

        // if both children of root are black, set root to red
        {
            let root = self.root.unwrap();
            if Self::is_red(self.nodes[root].left, &self.nodes)
                && Self::is_red(self.nodes[root].right, &self.nodes)
            {
                self.nodes[root].color = Color::red();
            }
        }
        let DeleteResult { child: root, .. } =
            Self::delete_node(self.root.unwrap(), key, &mut self.nodes);
        self.root = root;

        if !self.is_empty() {
            self.nodes[self.root.unwrap()].color = Color::black();
        }
        // assert!(self.check());
    }

    pub fn print(&self) {
        Self::print_node(self.root, 0, &self.nodes);
    }

    fn print_node(maybe_id: Option<usize>, depth: usize, nodes: &[Node<K, V>]) {
        let indent = "     ".repeat(depth);
        if let Some(id) = maybe_id {
            println!("{} {:?}", indent, nodes[id]);
            Self::print_node(nodes[id].left, depth + 1, nodes);
            Self::print_node(nodes[id].right, depth + 1, nodes);
        } else {
            println!("{} None", indent);
        }
    }

    fn swap_delete_min(
        mut child: usize,
        parent: usize,
        nodes: &mut Vec<Node<K, V>>,
    ) -> DeleteResult {
        if let Some(left) = nodes[child].left {
            if Self::two_left_black(child, nodes) {
                child = Self::move_red_left(child, nodes);
            }
            let result = Self::swap_delete_min(left, parent, nodes);
            child = result.translate(child);
            nodes[child].left = result.child;
            child = Self::balance(child, nodes);
            result.set_child(child)
        } else {
            nodes[child].parent = nodes[parent].parent;
            nodes[child].color = nodes[parent].color;
            nodes[child].left = nodes[parent].left;
            nodes[child].right = nodes[parent].right;
            nodes[child].size = nodes[parent].size;
            nodes.swap(child, parent);
            Self::remove(parent, nodes)
        }
    }

    fn two_left_black(id: usize, nodes: &[Node<K, V>]) -> bool {
        let left = nodes[id].left;
        !Self::is_red(left, nodes) && !Self::is_red(nodes[left.unwrap()].left, nodes)
    }

    fn delete_node(mut id: usize, key: &K, nodes: &mut Vec<Node<K, V>>) -> DeleteResult {
        let result: DeleteResult;

        if key < &nodes[id].key {
            if Self::two_left_black(id, nodes) {
                id = Self::move_red_left(id, nodes);
            }
            result = Self::delete_node(nodes[id].left.unwrap(), key, nodes);
            id = result.translate(id);
            nodes[id].left = result.child;
        } else {
            if Self::is_red(nodes[id].left, nodes) {
                id = Self::rotate_right(id, nodes);
            }
            if key.cmp(&nodes[id].key) == Ordering::Equal && nodes[id].right.is_none() {
                // TODO: Remove from vector!
                // nodes.remove(id);
                return Self::remove(id, nodes);
            }
            // By now we've already proven that Node(id).right is Some.
            // Therefore we are safe to unwrap Node(id).right.
            let right = nodes[id].right;
            if !Self::is_red(right, nodes) && !Self::is_red(nodes[right.unwrap()].left, nodes) {
                id = Self::move_red_right(id, nodes);
            }
            // This is the node to remove.
            // We'll replace its values with those from the minimum
            // key to the right (the next greatest key from this one).
            if key.cmp(&nodes[id].key) == Ordering::Equal {
                result = Self::swap_delete_min(nodes[id].right.unwrap(), id, nodes);
            } else {
                result = Self::delete_node(nodes[id].right.unwrap(), key, nodes);
            }
            id = result.translate(id);
            nodes[id].right = result.child;
        }
        result.set_child(Self::balance(id, nodes))
    }

    fn balance(mut id: usize, nodes: &mut Vec<Node<K, V>>) -> usize {
        if Self::is_red(nodes[id].right, nodes) {
            id = Self::rotate_left(id, nodes);
        }
        let left = nodes[id].left;
        if Self::is_red(left, nodes) && Self::is_red(nodes[left.unwrap()].left, nodes) {
            id = Self::rotate_right(id, nodes);
        }
        nodes[id].size = 1 + Self::size(nodes[id].left, nodes) + Self::size(nodes[id].right, nodes);
        Self::maybe_flip(id, nodes);
        id
    }

    fn maybe_flip(id: usize, nodes: &mut Vec<Node<K, V>>) {
        if let Some(left) = nodes[id].left {
            if let Some(right) = nodes[id].right {
                if nodes[left].color.is_red() && nodes[right].color.is_red() {
                    Self::flip_colors(id, left, right, nodes);
                }
            }
        }
    }

    /// This only happens when node `id` has two consecutive black left children.
    /// Black color only happens on the left when the right is present.
    /// I don't quite understand why we can assume that node `id` is red.
    fn move_red_left(mut id: usize, nodes: &mut Vec<Node<K, V>>) -> usize {
        Self::flip_colors(id, nodes[id].left.unwrap(), nodes[id].right.unwrap(), nodes);
        if Self::is_red(nodes[nodes[id].right.unwrap()].left, nodes) {
            nodes[id].right = Some(Self::rotate_right(nodes[id].right.unwrap(), nodes));
            id = Self::rotate_left(id, nodes);
            Self::flip_colors(id, nodes[id].left.unwrap(), nodes[id].right.unwrap(), nodes);
        }
        id
    }

    fn move_red_right(mut id: usize, nodes: &mut Vec<Node<K, V>>) -> usize {
        let left = nodes[id].left.unwrap();
        Self::flip_colors(id, left, nodes[id].right.unwrap(), nodes);
        if Self::is_red(nodes[left].left, nodes) {
            id = Self::rotate_right(id, nodes);
            Self::flip_colors(id, nodes[id].left.unwrap(), nodes[id].right.unwrap(), nodes);
        }
        id
    }

    fn is_red(maybe_id: Option<usize>, nodes: &[Node<K, V>]) -> bool {
        maybe_id.is_some() && nodes[maybe_id.unwrap()].color.is_red()
    }

    fn min(mut id: usize, nodes: &[Node<K, V>]) -> usize {
        while let Some(left) = nodes[id].left {
            id = left;
        }
        id
    }

    fn put(
        maybe_id: Option<usize>,
        parent: Option<usize>,
        key: K,
        value: V,
        nodes: &mut Vec<Node<K, V>>,
    ) -> Option<usize> {
        if let Some(mut id) = maybe_id {
            let cmp = key.cmp(&nodes[id].key);
            match cmp {
                Ordering::Less => {
                    nodes[id].left = Self::put(nodes[id].left, Some(id), key, value, nodes);
                }
                Ordering::Greater => {
                    nodes[id].right = Self::put(nodes[id].right, Some(id), key, value, nodes);
                }
                Ordering::Equal => {
                    nodes[id].value = value;
                }
            }
            nodes[id].size =
                Self::size(nodes[id].left, nodes) + Self::size(nodes[id].right, nodes) + 1;

            if Self::is_red(nodes[id].right, nodes) && !Self::is_red(nodes[id].left, nodes) {
                id = Self::rotate_left(id, nodes);
            }

            if Self::is_red(nodes[id].left, nodes)
                && Self::is_red(nodes[nodes[id].left.unwrap()].left, nodes)
            {
                id = Self::rotate_right(id, nodes);
            }

            if Self::is_red(nodes[id].left, nodes) && Self::is_red(nodes[id].right, nodes) {
                Self::flip_colors(id, nodes[id].left.unwrap(), nodes[id].right.unwrap(), nodes);
            }

            Some(id)
        } else {
            let the_id = nodes.len();
            nodes.push(Node {
                key,
                value,
                parent,
                size: 1,
                left: None,
                right: None,
                color: Color::red(),
            });
            Some(the_id)
        }
    }

    fn flip_colors(base: usize, left: usize, right: usize, nodes: &mut Vec<Node<K, V>>) {
        nodes[base].color.flip();
        nodes[left].color.flip();
        nodes[right].color.flip();
    }

    fn rotate_left(h: usize, nodes: &mut Vec<Node<K, V>>) -> usize {
        let x = nodes[h].right.unwrap();

        nodes[h].right = nodes[x].left;
        nodes[x].left = Some(h);
        nodes[x].color = nodes[h].color;
        nodes[h].color = Color::red();

        // fix parents
        nodes[x].parent = nodes[h].parent;
        nodes[h].parent = Some(x);
        if let Some(right) = nodes[h].right {
            nodes[right].parent = Some(h);
        }

        // fix size
        nodes[x].size = nodes[h].size;
        nodes[h].size = Self::size(nodes[h].left, nodes) + Self::size(nodes[h].right, nodes) + 1;

        x
    }

    fn remove(id: usize, nodes: &mut Vec<Node<K, V>>) -> DeleteResult {
        let other = nodes.len() - 1;
        nodes.swap(id, other);
        if let Some(parent) = nodes[id].parent {
            let mut parent_node = nodes.get_mut(parent).unwrap();
            if parent_node.left.is_some() && parent_node.left.unwrap() == other {
                parent_node.left = Some(id);
            } else {
                parent_node.right = Some(id);
            }
        }
        nodes.pop();
        DeleteResult {
            child: None,
            moved_node: other,
            moved_node_new_id: id,
        }
    }

    fn rotate_right(h: usize, nodes: &mut Vec<Node<K, V>>) -> usize {
        let x = nodes[h].left.unwrap();

        nodes[h].left = nodes[x].right;
        nodes[x].right = Some(h);
        nodes[x].color = nodes[h].color;
        nodes[h].color = Color::red();

        // fix parents
        nodes[x].parent = nodes[h].parent;
        nodes[h].parent = Some(x);
        if let Some(left) = nodes[h].left {
            nodes[left].parent = Some(h);
        }

        // fix size
        nodes[x].size = nodes[h].size;
        nodes[h].size = Self::size(nodes[h].left, nodes) + Self::size(nodes[h].right, nodes) + 1;

        x
    }

    fn size(maybe_id: Option<usize>, nodes: &[Node<K, V>]) -> usize {
        if let Some(id) = maybe_id {
            nodes[id].size
        } else {
            0
        }
    }

    /**
     * Debug Functions
     */

    pub fn check(&self) -> bool {
        let mut good = self.is_bst();
        if !good {
            println!("Not in symmetric order");
        }
        if !self.is_size_consistent() {
            println!("Subtree counts not consistent");
            good = false;
        }
        if !self.is_rank_consistent() {
            println!("Ranks not consistent");
            good = false;
        }
        if !self.is_23() {
            println!("Not a 2-3 tree");
            good = false;
        }
        if !self.is_balanced() {
            println!("Not balanced");
            self.print();
            good = false;
        }
        good
    }

    pub fn is_rank_consistent(&self) -> bool {
        for i in 0..self.len() {
            if i != self.rank(self.select(i)) {
                println!(
                    "Rank {} expected key {:?} but got {}",
                    i,
                    self.select(i),
                    self.rank(self.select(i))
                );
                self.print();
                return false;
            }
        }
        for key in self.keys().iter() {
            if *key != self.select(self.rank(*key)) {
                println!(
                    "Key {:?} has rank {} which evaluates to key {:?}",
                    *key,
                    self.rank(*key),
                    self.select(self.rank(*key))
                );
                return false;
            }
        }
        true
    }

    pub fn keys(&self) -> Vec<&K> {
        self.nodes.iter().map(|node| &node.key).collect::<Vec<&K>>()
    }

    pub fn is_23(&self) -> bool {
        self.is_node_23(self.root)
    }

    fn is_node_23(&self, maybe_id: Option<usize>) -> bool {
        if let Some(id) = maybe_id {
            if Self::is_red(self.nodes[id].right, &self.nodes) {
                return false;
            }
            if id != self.root.unwrap()
                && self.nodes[id].color.is_red()
                && Self::is_red(self.nodes[id].left, &self.nodes)
            {
                return false;
            }
            self.is_node_23(self.nodes[id].left) && self.is_node_23(self.nodes[id].right)
        } else {
            true
        }
    }

    pub fn rank(&self, key: &K) -> usize {
        self.rank_in_subtree(key, self.root)
    }

    fn rank_in_subtree(&self, key: &K, maybe_id: Option<usize>) -> usize {
        if let Some(id) = maybe_id {
            match key.cmp(&self.nodes[id].key) {
                Ordering::Less => self.rank_in_subtree(key, self.nodes[id].left),
                Ordering::Greater => {
                    1 + Self::size(self.nodes[id].left, &self.nodes)
                        + self.rank_in_subtree(key, self.nodes[id].right)
                }
                Ordering::Equal => Self::size(self.nodes[id].left, &self.nodes),
            }
        } else {
            0
        }
    }

    pub fn select(&self, rank: usize) -> &K {
        if rank >= self.len() {
            panic!("Asked for rank greater than size of tree");
        }
        &self.nodes[self.select_from_node(rank, self.root.unwrap())].key
    }

    fn select_from_node(&self, rank: usize, id: usize) -> usize {
        let t = Self::size(self.nodes[id].left, &self.nodes);
        match t.cmp(&rank) {
            Ordering::Greater => self.select_from_node(rank, self.nodes[id].left.unwrap()),
            Ordering::Less => self.select_from_node(rank - t - 1, self.nodes[id].right.unwrap()),
            Ordering::Equal => id,
        }
    }

    pub fn is_size_consistent(&self) -> bool {
        self.is_node_size_consistent(self.root)
    }

    fn is_node_size_consistent(&self, maybe_id: Option<usize>) -> bool {
        if let Some(id) = maybe_id {
            let node = &self.nodes[id];
            if node.size
                != 1 + Self::size(node.left, &self.nodes) + Self::size(node.right, &self.nodes)
            {
                return false;
            }
            self.is_node_size_consistent(node.left) && self.is_node_size_consistent(node.right)
        } else {
            true
        }
    }

    pub fn is_bst(&self) -> bool {
        self.is_node_bst(self.root, None, None)
    }

    fn is_node_bst(
        &self,
        maybe_id: Option<usize>,
        maybe_min: Option<&K>,
        maybe_max: Option<&K>,
    ) -> bool {
        if let Some(id) = maybe_id {
            let key = &self.nodes[id].key;
            if let Some(min) = maybe_min {
                if key <= min {
                    return false;
                }
            }
            if let Some(max) = maybe_max {
                if key >= max {
                    return false;
                }
            }
            self.is_node_bst(self.nodes[id].left, maybe_min, Some(key))
                && self.is_node_bst(self.nodes[id].right, Some(key), maybe_max)
        } else {
            true
        }
    }

    fn find_next(&self, mut from: usize) -> Option<usize> {
        // If there's a right from here, find the min value from there.
        // Don't care about current left.
        // Go to parent.
        // While parent key is less than my key,
        //   that means that I was on the right and I should go up again.
        //
        // If there is a right from here, that means greater than the current
        // key but not necessarily greater than the _from_ key.
        // Only traverse up the right branch if right key < mine.
        let the_key = &self.nodes[from].key;
        if let Some(right) = self.nodes[from].right {
            from = Self::min(right, &self.nodes);
        } else {
            while *the_key >= self.nodes[from].key {
                if let Some(parent) = self.nodes[from].parent {
                    from = parent;
                } else {
                    return None;
                }
            }
            if let Some(right) = self.nodes[from].right {
                if self.nodes[right].key < *the_key {
                    from = Self::min(right, &self.nodes);
                }
            }
        }

        Some(from)
    }
}

impl<K, V> Default for RBTree<K, V>
where
    K: Ord + Debug + Sync,
    V: Debug + Sync,
{
    fn default() -> Self {
        Self {
            root: None,
            nodes: vec![],
        }
    }
}

pub struct TreeIterator<'a, K, V>
where
    K: Ord + Sync,
    V: Sync,
{
    next_node: Option<usize>,
    tree: &'a RBTree<K, V>,
}

impl<'a, K, V> IntoIterator for &'a RBTree<K, V>
where
    K: Ord + Debug + Sync,
    V: Debug + Sync,
{
    type Item = (&'a K, &'a V);
    type IntoIter = TreeIterator<'a, K, V>;
    fn into_iter(self) -> Self::IntoIter {
        let next_node = if self.is_empty() {
            None
        } else {
            Some(RBTree::min(self.root.unwrap(), &self.nodes))
        };

        TreeIterator {
            next_node,
            tree: self,
        }
    }
}

impl<'a, K, V> Iterator for TreeIterator<'a, K, V>
where
    K: Ord + Debug + Sync,
    V: Debug + Sync,
{
    type Item = (&'a K, &'a V);

    fn next(&mut self) -> Option<Self::Item> {
        if let Some(current_id) = self.next_node {
            // find next
            self.next_node = self.tree.find_next(current_id);

            let node = &self.tree.nodes[current_id];
            Some((&node.key, &node.value))
        } else {
            None
        }
    }
}

#[cfg(test)]
mod test {
    use super::RBTree;

    #[test]
    fn test_tree_1() {
        let mut tree = RBTree::new();
        tree.insert(12, 32);
        tree.insert(32, 44);
        tree.insert(123, 321);
        tree.insert(123, 321);
        tree.insert(1, 2);
        tree.insert(14, 32);
        tree.insert(20, 41);
        tree.insert(6, 64);
        tree.insert(41, 22);
        tree.insert(122, 14);
        tree.insert(41, 99);

        assert_eq!(tree.len(), tree.into_iter().count());
        tree.print();

        let mut k = 0;
        for (key, value) in tree.into_iter() {
            println!("{:?} -> {:?}", key, value);
            assert!(*key > k);
            k = *key;
        }

        assert_eq!(99, *tree.get(&41).unwrap());
        assert!(tree.is_balanced());
        assert_eq!(9, tree.len());

        assert_rm(41, &mut tree, 8);
        assert_rm(122, &mut tree, 7);
        assert_rm(6, &mut tree, 6);
        assert_rm(20, &mut tree, 5);
        assert_rm(14, &mut tree, 4);
        assert_rm(1, &mut tree, 3);
        assert_rm(123, &mut tree, 2);
        assert_rm(32, &mut tree, 1);
        assert_rm(12, &mut tree, 0);
        assert!(tree.is_empty());
    }

    fn assert_rm(val: u32, tree: &mut RBTree<u32, u32>, size: usize) {
        assert!(tree.is_balanced());
        assert!(tree.contains(&val));
        tree.delete(&val);
        assert!(!tree.contains(&val));
        if !tree.is_balanced() {
            println!("Not balanced!");
            tree.print();
        }
        assert!(tree.is_balanced());
        assert_eq!(size, tree.len());
    }

    #[test]
    fn test_tree_strings() {
        let mut tree = RBTree::new();
        tree.insert(12, "value: V");
        tree.insert(32, "44");
        tree.insert(123, "321");
        tree.insert(123, "321");
        tree.insert(1, "2");
        tree.insert(14, "32");
        tree.insert(20, "41");
        tree.insert(6, "64");
        tree.insert(41, "22");
        tree.insert(122, "14");
        tree.insert(41, "99");

        assert_eq!("99", *tree.get(&41).unwrap());
        assert!(tree.is_balanced());
        assert_eq!(9, tree.len());
    }

    #[test]
    fn test_tree_string_keys() {
        let mut tree = RBTree::new();
        tree.insert("12", "value: V");
        tree.insert("32", "44");
        tree.insert("123", "321");
        tree.insert("123", "321");
        tree.insert("1", "2");
        tree.insert("14", "32");
        tree.insert("20", "41");
        tree.insert("6", "64");
        tree.insert("41", "22");
        tree.insert("122", "14");
        tree.insert("41", "99");

        assert_eq!("99", *tree.get(&"41").unwrap());
        assert!(tree.is_balanced());
        assert_eq!(9, tree.len());
    }
}

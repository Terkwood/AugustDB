mod atoms {
    rustler::atoms! { value, tombstone, none, ok, proceed, stop }
}

use rpds::map::red_black_tree_map::{RedBlackTreeMap, RedBlackTreeMapSync};
use rustler::{Atom, NifTuple};
use std::sync::Mutex;

#[derive(NifTuple, Clone)]
pub struct ValTomb {
    kind: Atom,
    value: String,
}

#[derive(PartialEq, Eq, PartialOrd, Ord)]
pub enum VT {
    Value(String),
    Tombstone,
}

lazy_static::lazy_static! {
    static ref CURRENT: Mutex<RedBlackTreeMapSync<String, VT>> = Mutex::new(RedBlackTreeMap::new_sync());
}

impl From<&VT> for ValTomb {
    fn from(vt: &VT) -> Self {
        match vt {
            VT::Tombstone => ValTomb {
                kind: atoms::tombstone(),
                value: "".to_string(),
            },
            VT::Value(v) => ValTomb {
                kind: atoms::value(),
                value: v.to_string(),
            },
        }
    }
}

#[derive(NifTuple)]
pub struct PrepareFlushStatus {
    pub status: Atom,
    pub flushing: Vec<ValTomb>,
}

#[rustler::nif]
pub fn update(key: &str, value: &str) -> Atom {
    let mut guard = CURRENT.lock().unwrap();
    let next = guard.insert(key.to_string(), VT::Value(value.to_string()));
    *guard = next;

    atoms::ok()
}

#[rustler::nif]
pub fn delete(key: &str) -> Atom {
    let mut guard = CURRENT.lock().unwrap();

    let next = guard.insert(key.to_string(), VT::Tombstone);
    *guard = next;

    atoms::ok()
}

#[rustler::nif]
pub fn query(key: &str) -> ValTomb {
    CURRENT
        .lock()
        .unwrap()
        .get(key)
        .map(|r| ValTomb::from(r))
        .unwrap_or(ValTomb {
            kind: atoms::none(),
            value: "".to_string(),
        })
}

/// Move the current memtable into the flushing
/// memtable data structure, and then empty the
/// current memtable.  Returns a list of k/v tuples
/// which need to be flushed to disk.
#[rustler::nif]
pub fn prepare_flush() -> PrepareFlushStatus {
    if false {
        PrepareFlushStatus {
            status: atoms::stop(),
            flushing: vec![],
        }
    } else {
        todo!("write me")
    }
}

fn load(_: rustler::Env, _: rustler::Term) -> bool {
    true
}

rustler::init!(
    "Elixir.Memtable.Dirty",
    [query, update, delete, prepare_flush],
    load = load
);

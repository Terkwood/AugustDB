mod atoms {
    rustler::atoms! { value, tombstone, none, ok }
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

#[rustler::nif]
pub fn to_list() -> Vec<ValTomb> {
    todo!()
}

fn load(_: rustler::Env, _: rustler::Term) -> bool {
    true
}

rustler::init!(
    "Elixir.Memtable.Dirty",
    [query, update, delete, to_list],
    load = load
);

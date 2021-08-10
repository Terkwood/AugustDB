mod atoms {
    rustler::atoms! { value, tombstone, none, ok }
}

use rpds::map::red_black_tree_map::RedBlackTreeMap;
use rpds::{RedBlackTreeMapSync, RedBlackTreeSetSync};
use rustler::{Atom, Env, NifTuple, ResourceArc};
use std::collections::HashMap;
use std::rc::Rc;
use std::sync::{Arc, RwLock};

#[derive(NifTuple, Clone)]
pub struct ValTomb {
    kind: Atom,
    val_tomb: String,
}

// use archery::*;

// #[derive(PartialEq, Eq, PartialOrd, Ord)]
// struct KeyValuePair<K, V, P: SharedPointerKind> {
//     pub key: SharedPointer<K, P>,
//     pub value: SharedPointer<V, P>,
// }

// impl<K, V, P: SharedPointerKind> KeyValuePair<K, V, P> {
//     fn new(key: K, value: V) -> KeyValuePair<K, V, P> {
//         KeyValuePair {
//             key: SharedPointer::new(key),
//             value: SharedPointer::new(value),
//         }
//     }
// }

#[derive(PartialEq, Eq, PartialOrd, Ord)]
pub enum VT {
    Value(String),
    Tombstone,
}

//pub struct MemtableResource(RwLock<HashMap<String, ValTomb>>);

lazy_static::lazy_static! {
    static ref CURRENT: RwLock<RedBlackTreeMapSync< String, VT>> = RwLock::new(RedBlackTreeMap::new_sync());
}

impl From<&VT> for ValTomb {
    fn from(vt: &VT) -> Self {
        match *vt {
            VT::Tombstone => ValTomb {
                kind: atoms::tombstone(),
                val_tomb: "".to_string(),
            },
            VT::Value(v) => ValTomb {
                kind: atoms::value(),
                val_tomb: v.to_string(),
            },
        }
    }
}

#[rustler::nif]
pub fn update(key: &str, value: &str) -> Atom {
    CURRENT
        .write()
        .unwrap()
        .insert(key.to_string(), VT::Value(value.to_string()));

    atoms::ok()
}

#[rustler::nif]
pub fn delete(key: &str) -> Atom {
    CURRENT
        .write()
        .unwrap()
        .insert(key.to_string(), VT::Tombstone);

    atoms::ok()
}

#[rustler::nif]
pub fn query(key: &str) -> ValTomb {
    CURRENT
        .read()
        .unwrap()
        .get(key)
        .map(|r| ValTomb::from(r))
        .unwrap_or(ValTomb {
            kind: atoms::none(),
            val_tomb: "".to_string(),
        })
}

#[rustler::nif]
pub fn to_list() -> Vec<ValTomb> {
    vec![]
}

#[rustler::nif]
pub fn keys() -> Vec<String> {
    vec![]
}

pub fn on_load(env: Env) -> bool {
    //rustler::resource!(MemtableResource, env);
    true
}
fn load(env: rustler::Env, _: rustler::Term) -> bool {
    on_load(env);
    true
}

rustler::init!(
    "Elixir.Memtable.Dirty",
    [query, update, delete, keys, to_list],
    load = load
);

use rustler::{Atom, Env, NifTuple, ResourceArc};
use std::collections::HashMap;
use std::sync::RwLock;

/*use intrusive_collections::intrusive_adapter;
use intrusive_collections::{RBTreeLink, RBTree, KeyAdapter, Bound};
*/

#[derive(NifTuple, Clone)]
pub struct ValTomb {
    kind: Atom,
    val_tomb: String,
}
mod atoms {
    rustler::atoms! { value, tombstone, none, ok }
}
pub struct MemtableResource(RwLock<HashMap<String, ValTomb>>);
pub fn on_load(env: Env) -> bool {
    rustler::resource!(MemtableResource, env);
    true
}

lazy_static::lazy_static! {
    static ref CURRENT: RwLock<HashMap<String,ValTomb>> = RwLock::new(HashMap::new());
}

#[rustler::nif]
pub fn update(key: &str, value: &str) -> Atom {
    CURRENT.write().unwrap().insert(
        key.to_string(),
        ValTomb {
            kind: atoms::value(),
            val_tomb: value.to_string(),
        },
    );

    atoms::ok()
}

#[rustler::nif]
pub fn delete(key: &str) -> Atom {
    CURRENT.write().unwrap().insert(
        key.to_string(),
        ValTomb {
            kind: atoms::tombstone(),
            val_tomb: "".to_string(),
        },
    );

    atoms::ok()
}

#[rustler::nif]
pub fn query(key: &str) -> ValTomb {
    CURRENT
        .read()
        .unwrap()
        .get(key)
        .map(|r| r.clone())
        .unwrap_or(ValTomb {
            kind: atoms::none(),
            val_tomb: "".to_string(),
        })
}

#[rustler::nif]
pub fn to_list(_resource: ResourceArc<MemtableResource>) -> Vec<ValTomb> {
    vec![]
}

#[rustler::nif]
pub fn keys(_resource: ResourceArc<MemtableResource>) -> Vec<String> {
    vec![]
}

fn load(env: rustler::Env, _: rustler::Term) -> bool {
    on_load(env);
    true
}
rustler::init!(
    "Elixir.Memtable.Dirty",
    [query, update, delete],
    load = load
);

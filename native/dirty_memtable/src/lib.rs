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
pub struct MemtableResource {
    current: RwLock<HashMap<String, ValTomb>>,
    flushing: RwLock<HashMap<String, ValTomb>>,
}

pub fn on_load(env: Env) -> bool {
    rustler::resource!(MemtableResource, env);
    true
}

#[rustler::nif]
pub fn new() -> ResourceArc<MemtableResource> {
    ResourceArc::new(MemtableResource {
        current: RwLock::new(HashMap::new()),
        flushing: RwLock::new(HashMap::new()),
    })
}

#[rustler::nif]
pub fn update(resource: ResourceArc<MemtableResource>, key: &str, value: &str) -> Atom {
    let mut current = resource.current.write().unwrap();
    current.insert(
        key.to_string(),
        ValTomb {
            kind: atoms::value(),
            val_tomb: value.to_string(),
        },
    );

    atoms::ok()
}

#[rustler::nif]
pub fn delete(resource: ResourceArc<MemtableResource>, key: &str) -> Atom {
    let mut current = resource.current.write().unwrap();
    current.insert(
        key.to_string(),
        ValTomb {
            kind: atoms::tombstone(),
            val_tomb: "".to_string(),
        },
    );

    atoms::ok()
}

#[rustler::nif]
pub fn query(resource: ResourceArc<MemtableResource>, key: &str) -> ValTomb {
    resource
        .current
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
pub fn flush(resource: ResourceArc<MemtableResource>) {
    todo!()
}

fn load(env: rustler::Env, _: rustler::Term) -> bool {
    on_load(env);
    true
}
rustler::init!(
    "Elixir.Memtable.Dirty",
    [new, query, update, delete, flush],
    load = load
);

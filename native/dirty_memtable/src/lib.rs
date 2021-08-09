use rustler::{Atom, Env, NifTuple, ResourceArc};
use std::collections::HashMap;
use std::sync::RwLock;

/*use intrusive_collections::intrusive_adapter;
use intrusive_collections::{RBTreeLink, RBTree, KeyAdapter, Bound};
*/

#[derive(NifTuple)]
pub struct ValTomb {
    kind: Atom,
    val_tomb: String,
}
enum VT {
    Value(String),
    Tombstone,
}

mod atoms {
    rustler::atoms! { value, tombstone, none }
}
impl From<&VT> for ValTomb {
    fn from(val_tomb: &VT) -> Self {
        match val_tomb {
            VT::Value(value) => ValTomb {
                kind: atoms::value(),
                val_tomb: value.clone(),
            },
            VT::Tombstone => ValTomb {
                kind: atoms::tombstone(),
                val_tomb: "".to_string(),
            },
        }
    }
}

pub struct MemtableResource {
    current: RwLock<HashMap<String, VT>>,
    flushing: RwLock<HashMap<String, VT>>,
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
pub fn update(resource: ResourceArc<MemtableResource>, key: &str, value: &str) -> &'static str {
    let mut current = resource.current.write().unwrap();
    current.insert(key.to_string(), VT::Value(value.to_string()));

    "ok"
}

#[rustler::nif]
pub fn delete(resource: ResourceArc<MemtableResource>, key: &str) -> &'static str {
    let mut current = resource.current.write().unwrap();
    current.insert(key.to_string(), VT::Tombstone);

    "ok"
}

#[rustler::nif]
pub fn query(resource: ResourceArc<MemtableResource>, key: &str) -> ValTomb {
    resource
        .current
        .read()
        .unwrap()
        .get(key)
        .map(|vt| ValTomb::from(vt))
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

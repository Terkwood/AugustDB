 
 

use rustler::{Env, ResourceArc};
use std::sync::RwLock;
use std::collections::HashMap;

/*use intrusive_collections::intrusive_adapter;
use intrusive_collections::{RBTreeLink, RBTree, KeyAdapter, Bound};

struct Element {

}*/


pub enum VT {
    Value(String),
    Tombstone
}

pub struct MemtableResource {
    current: RwLock<HashMap<String, String>>,
    flushing: RwLock<HashMap<String, String>>
}

pub fn on_load(env: Env) -> bool {
    rustler::resource!(MemtableResource, env);
    true
}

#[rustler::nif]
pub fn new() -> ResourceArc<MemtableResource> {
    ResourceArc::new(MemtableResource {
        current: RwLock::new(HashMap::new()),
        flushing: RwLock::new(HashMap::new())
    })
}

#[rustler::nif]
pub fn update(resource: ResourceArc<MemtableResource>, key: &str, value: &str) -> &'static str {
    let mut current = resource.current.write().unwrap();
    current.insert(key.to_string(),  value.to_string());

    "ok"
}

#[rustler::nif]
pub fn delete(resource: ResourceArc<MemtableResource>, key: &str) -> &'static str {
    let mut current = resource.current.write().unwrap();
    current.insert(key.to_string(), "VT::Tombstone".to_string());

    "ok"
}

#[rustler::nif]
pub fn query(resource: ResourceArc<MemtableResource>, key: &str) -> Option<String> {
    resource.current.read().unwrap().get(key).map(|r|r.to_string())
}
 

fn load(env: rustler::Env, _: rustler::Term) -> bool {
    on_load(env);
    true
}
rustler::init!("Elixir.Memtable.Dirty", [new, update, delete, query], load = load);

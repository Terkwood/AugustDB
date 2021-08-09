 
 

use rustler::{Env, ResourceArc};
use std::sync::RwLock;

pub struct MemtableResource {
    number: RwLock<i32>,
}

pub fn on_load(env: Env) -> bool {
    rustler::resource!(MemtableResource, env);
    true
}

#[rustler::nif]
pub fn new() -> ResourceArc<MemtableResource> {
    ResourceArc::new(MemtableResource {
        number: RwLock::new(0),
    })
}

#[rustler::nif]
pub fn update(resource: ResourceArc<MemtableResource>, n: i32) -> &'static str {
    let mut number = resource.number.write().unwrap();
    *number = n;

    "ok"
}

#[rustler::nif]
pub fn query(resource: ResourceArc<MemtableResource>) -> i32 {
    *resource.number.read().unwrap()
}
 

fn load(env: rustler::Env, _: rustler::Term) -> bool {
    on_load(env);
    true
}
rustler::init!("Elixir.Memtable.Dirty", [new, update, query], load = load);

use rustler::{Env, ResourceArc};
use std::sync::RwLock;

pub struct MemtableResource {
    no: RwLock<i32>,
}

pub fn on_load(env: Env) -> bool {
    rustler::resource!(MemtableResource, env);
    true
}

#[rustler::nif]
pub fn new() -> ResourceArc<MemtableResource> {
    ResourceArc::new(MemtableResource {
        no: RwLock::new(0),
    })
}

pub fn lookup() {
    
}


rustler::init!("Elixir.Memtable.Dirty", [new]);

use forge_addontest::run::root;
use forge_addontest::{emitted, Addon, RunAddon};
use serde_json::json;

fn load(file: &str) {
	let out = emitted(&RunAddon { addons: vec![Addon::files("Northstar", &[file])], script: "emit(Northstar.name)".into(), ..Default::default() });
	assert_eq!(json!(out), json!(["Northstar"]));
}

#[test]
fn addon_fixtures_load_relative_lua_file() {
	load("Core/Init.lua");
}

#[test]
fn addon_fixtures_load_absolute_lua_file() {
	let file = root().join("addon/Northstar/Core/Init.lua");
	load(file.to_str().unwrap());
}

#[test]
fn addon_fixtures_load_absolute_xml_manifest() {
	let file = root().join("addon/Northstar/Core/Core.xml");
	load(file.to_str().unwrap());
}

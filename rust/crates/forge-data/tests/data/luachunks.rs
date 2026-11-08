//! The addon's copy of the LuaChunks reader (addon/Northstar/Core/LuaChunks.lua, which Northstar.QuestDB and
//! the names packs read their chunks with) is forge-core's, byte for byte.

#[test]
fn the_addon_s_luachunks_reader_is_forge_core_s() {
	let root = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../..");
	let addon = std::fs::read_to_string(root.join("addon/Northstar/Core/LuaChunks.lua")).unwrap();
	assert!(addon == forge_core::luachunks::READER, "addon/Northstar/Core/LuaChunks.lua differs from rust/crates/forge-core/src/luachunks.lua: copy it over");
}

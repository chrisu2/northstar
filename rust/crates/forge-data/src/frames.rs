//! Forever client map frames for the walking grid. Classic Era tables are not read.
//! This is not a quest data build: pfQuest, QuestieDB and the Era coordinate baseline stay out.

use forge_guide::js::{stringify, Arr, Obj, V};

use crate::maps::build_maps;
use crate::tables::Loaded;

#[derive(Debug)]
pub struct ClientFrames {
	pub map_frames: String,
	pub zones: String,
	pub meta: String,
	pub frames: usize,
	pub zones_n: usize,
}

/// `wowf` is the live Forever client. `wow_classic_beta` is the published Forever table product.
pub fn forever_product(product: &str) -> bool {
	product == "wowf" || product == "wow_classic_beta"
}

pub fn from_loaded(loaded: &Loaded) -> Result<ClientFrames, String> {
	if !forever_product(&loaded.product) {
		return Err(format!("refusing product {}: live map frames are read from wowf or wow_classic_beta only", loaded.product));
	}
	if !loaded.build.starts_with("1.60.") {
		return Err(format!("refusing build {}: a Forever map-frame extract needs a 1.60 build", loaded.build));
	}
	let ui = loaded.get("UiMap").ok_or("UiMap was not read from the Forever client")?;
	let assignment = loaded.get("UiMapAssignment").ok_or("UiMapAssignment was not read from the Forever client")?;
	let area = loaded.get("AreaTable").ok_or("AreaTable was not read from the Forever client")?;
	let maps = build_maps(ui, assignment, area);
	if maps.frames.is_empty() {
		return Err("the Forever client tables produced no map frames".into());
	}
	let doc = Obj::new();
	doc.set("forever", maps.frames_v());
	let zones = maps.zones_obj();
	let meta = Obj::new();
	meta.set("product", V::str(&loaded.product));
	meta.set("build", V::str(&loaded.build));
	meta.set("source", V::str("client"));
	meta.set("mapsOnly", V::Bool(true));
	meta.set("eraFrames", V::Bool(false));
	meta.set("mapFrames", V::Num(maps.frames.len() as f64));
	meta.set("zones", V::Num(maps.zones.len() as f64));
	let mut warnings = vec![V::str("Era map tables were not read. map-frames.json has forever frames only. This is not a quest data build.")];
	warnings.extend(maps.warnings.iter().map(|w| V::str(w)));
	meta.set("warnings", V::Arr(Arr::from_vec(warnings)));
	Ok(ClientFrames {
		map_frames: format!("{}\n", stringify(&V::Obj(doc), Some("\t"))),
		zones: format!("{}\n", stringify(&V::Obj(zones), Some("\t"))),
		meta: format!("{}\n", stringify(&V::Obj(meta), Some("\t"))),
		frames: maps.frames.len(),
		zones_n: maps.zones.len(),
	})
}

//! Live Forever map frames. No Classic Era cache is read.

use forge_data::frames::from_loaded;
use forge_data::jsv::Row;
use forge_data::tables::Loaded;

fn row(pairs: &[(&str, &str)]) -> Row {
	pairs.iter().map(|(k, v)| ((*k).to_string(), (*v).to_string())).collect()
}

fn loaded(product: &str, build: &str, with_maps: bool) -> Loaded {
	let mut tables = Vec::new();
	if with_maps {
		tables.push((
			"UiMap",
			vec![row(&[("Name_lang", "Taxi"), ("ID", "2"), ("ParentUiMapID", "0"), ("System", "1"), ("Type", "2")])],
		));
		let mut assignment = row(&[
			("ID", "12"),
			("UiMapID", "2"),
			("OrderIndex", "0"),
			("MapID", "0"),
			("AreaID", "0"),
		]);
		for (k, v) in [("UiMin_0", "0"), ("UiMin_1", "0"), ("UiMax_0", "1"), ("UiMax_1", "1"), ("Region_0", "-1000"), ("Region_1", "-1000"), ("Region_3", "1000"), ("Region_4", "1000")] {
			assignment.insert(k.into(), v.into());
		}
		tables.push(("UiMapAssignment", vec![assignment]));
		tables.push(("AreaTable", vec![]));
	}
	Loaded { build: build.into(), product: product.into(), tables, urls: vec![], from_client: true, saved: false, warnings: vec![] }
}

#[test]
fn wowf_frames_have_no_era_key() {
	let files = from_loaded(&loaded("wowf", "1.60.1.70862", true)).unwrap();
	let doc: serde_json::Value = serde_json::from_str(&files.map_frames).unwrap();
	assert!(doc.get("era").is_none());
	assert!(doc["forever"]["2"]["c"].as_f64().is_some());
	let meta: serde_json::Value = serde_json::from_str(&files.meta).unwrap();
	assert_eq!(meta["product"], "wowf");
	assert_eq!(meta["build"], "1.60.1.70862");
	assert_eq!(meta["mapsOnly"], true);
	assert_eq!(meta["eraFrames"], false);
	assert!(meta["warnings"][0].as_str().unwrap().contains("Era map tables were not read"));
	assert!(meta.get("questieQuests").is_none());
}

#[test]
fn era_product_and_wrong_build_are_refused() {
	assert!(from_loaded(&loaded("wow_classic_era", "1.15.9.70576", true)).unwrap_err().contains("refusing product wow_classic_era"));
	assert!(from_loaded(&loaded("wow", "11.0.0.1", true)).unwrap_err().contains("refusing product wow"));
	assert!(from_loaded(&loaded("wowf", "1.15.9.70576", true)).unwrap_err().contains("refusing build 1.15.9.70576"));
}

#[test]
fn missing_uimap_is_an_error() {
	let err = from_loaded(&loaded("wowf", "1.60.1.70862", false)).unwrap_err();
	assert!(err.contains("UiMap was not read"), "{err}");
}

//! `forge data frames` refuses the wrong product before it looks for a client or a wago cache.

use std::process::Command;

fn forge(args: &[&str]) -> (bool, String) {
	let out = Command::new(env!("CARGO_BIN_EXE_forge")).args(args).output().unwrap();
	let err = String::from_utf8_lossy(&out.stderr).into_owned();
	(out.status.success(), err)
}

#[test]
fn the_wrong_product_is_refused_without_a_wago_cache() {
	let (ok, err) = forge(&["data", "frames", "--out", "out", "--wow", "wow", "--product", "wow_classic_era", "--forever-build", "1.15.9.70576", "--defs", "defs"]);
	assert!(!ok, "{err}");
	assert!(err.contains("refusing product wow_classic_era"), "{err}");
	assert!(!err.contains("wago.tools"), "{err}");
}

#[test]
fn a_retail_build_is_refused() {
	let (ok, err) = forge(&["data", "frames", "--out", "out", "--wow", "wow", "--product", "wowf", "--forever-build", "11.0.0.1", "--defs", "defs"]);
	assert!(!ok, "{err}");
	assert!(err.contains("refusing build 11.0.0.1"), "{err}");
}

#[test]
fn missing_arguments_are_named() {
	let (ok, err) = forge(&["data", "frames", "--product", "wowf"]);
	assert!(!ok, "{err}");
	assert!(err.contains("--out") || err.contains("--wow"), "{err}");
}

#[test]
fn help_names_the_live_client_and_not_the_era_cache() {
	let out = Command::new(env!("CARGO_BIN_EXE_forge")).args(["data", "frames", "--help"]).output().unwrap();
	let text = String::from_utf8_lossy(&out.stdout);
	assert!(out.status.success(), "{}", String::from_utf8_lossy(&out.stderr));
	assert!(text.contains("--product wowf"), "{text}");
	assert!(text.contains("Classic Era tables are not read"), "{text}");
	assert!(text.contains("this command has none of them"), "{text}");
}

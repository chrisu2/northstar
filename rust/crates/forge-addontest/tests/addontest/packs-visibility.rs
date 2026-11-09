//! Community addons switched off and on, where suggestions come from, and the installed packs the core finds
//! in the AddOns list (addon/Northstar/Core/Guides.lua, Search.lua, Lookup/Guide.lua).

use std::collections::HashMap;

use forge_addontest::{emitted, text, Addon, RunAddon};
use serde_json::{json, Value};

fn core() -> Addon {
	Addon::files("Northstar", &["Core/Core.xml"])
}

fn with_lookup() -> Addon {
	Addon::files("Northstar", &["Core/Core.xml", "Lookup/Lookup.xml"])
}

// A Horde character at level 12 in the Barrens.
const WORLD: &str = r#"
local w = stub.world
w.addMap(1413, { name = "The Barrens", c = 1, left = 1000, right = -1000, top = 1000, bottom = -3000 })
w.moveTo(1413, 52, 31)
w.race, w.raceName, w.faction, w.class, w.className, w.level = "Orc", "Orc", "Horde", "WARRIOR", "Warrior", 12
"#;

// Ours (`guides`, from Northstar_Guides) and Joe's pack, each with a Horde and an Alliance leveling guide for
// 10-20 and a guide collecting item 8000.
const PACKS: &str = r#"
G = Northstar.Guides
local function meta(addon, id, title)
	return { addon = addon, id = id, format = 1, title = title, author = "A", version = "1", license = "MIT" }
end
local function guide(id, pack, extra)
	local g = { id = id, pack = pack, title = "T " .. id, minLevel = 10, maxLevel = 20, steps = { { goals = { { t = "level", level = 20 } } } } }
	for k, v in pairs(extra or {}) do g[k] = v end
	assert(Northstar.RegisterGuide(g))
end
assert(Northstar.RegisterPack(meta("Northstar_Guides", "guides", "Northstar Guides")))
guide("forever/horde", "guides", { faction = "Horde" })
guide("forever/alliance", "guides", { faction = "Alliance" })
guide("forever/mount", "guides", { category = "Collectibles", collects = { 8000 } })
assert(Northstar.RegisterPack(meta("JoeAddon", "joe", "Joe's Routes")))
guide("joe/a", "joe", { faction = "Horde", nextChoices = { "joe/b" } })
guide("joe/b", "joe", { faction = "Horde" })
guide("joe/mount", "joe", { category = "Collectibles", collects = { 8000 } })
function ids(list) local out = {} for i, h in ipairs(list) do out[i] = type(h) == "table" and h.id or h end return out end
"#;

fn run_with(script: &str, before: &str, addon: Addon, stubs: &[&'static str]) -> Value {
	let mut all = vec!["stub_world.lua"];
	all.extend_from_slice(stubs);
	emitted(&RunAddon { stubs: all, before: format!("{WORLD}{before}"), addons: vec![addon], script: format!("{PACKS}\nstub.login()\n{script}"), ..Default::default() }).remove(0)
}

fn run(script: &str, before: &str) -> Value {
	run_with(script, before, core(), &[])
}

#[test]
fn a_hidden_pack_s_guides_leave_get_list_suggest_and_offeredby_and_come_back_when_it_is_shown() {
	let out = run(
		r#"
		Northstar.Set("behavior.suggestFrom", "joe")
		local fired = {}
		Northstar.On("PACKS_CHANGED", function(id) fired[#fired + 1] = id end)
		local r = { before = { suggest = G.Suggest(), offered = #G.OfferedBy("joe/b") } }
		G.SetPackShown("joe", false)
		r.hidden = { get = G.Get("joe/a") ~= nil, list = ids(G.List()), suggest = G.Suggestions(), offered = #G.OfferedBy("joe/b"),
			shown = G.PackShown("joe"), off = NorthstarDB.packs.joe.off, status = G.Pack("joe").status, fired = #fired, firedWith = fired[1] }
		G.SetPackShown("joe", false)
		r.again = #fired
		G.SetPackShown("joe", true)
		r.back = { get = G.Get("joe/a") ~= nil, list = ids(G.List()), suggest = G.Suggest(), shown = G.PackShown("joe"),
			status = G.Pack("joe").status, fired = fired, stored = NorthstarDB.packs and NorthstarDB.packs.joe and NorthstarDB.packs.joe.off or false }
		emit(r)
	"#,
		"",
	);
	assert_eq!(out["before"], json!({ "suggest": "joe/a", "offered": 1 }));
	assert_eq!(
		out["hidden"],
		json!({
			"get": false, "list": ["forever/horde", "forever/alliance", "forever/mount"], "suggest": ["forever/horde"], "offered": 0,
			"shown": false, "off": true, "status": "off", "fired": 1, "firedWith": "joe",
		})
	);
	assert_eq!(out["again"], 1, "hiding a hidden pack changes nothing");
	assert_eq!(
		out["back"],
		json!({
			"get": true, "list": ["forever/horde", "forever/alliance", "forever/mount", "joe/a", "joe/b", "joe/mount"], "suggest": "joe/a",
			"shown": true, "status": "on", "fired": ["joe", "joe"], "stored": false,
		})
	);
}

#[test]
fn suggestions_come_from_the_chosen_pack_with_ours_filling_in_where_it_has_nothing() {
	let out = run(
		r#"
		local r = { default = G.SuggestSource(), ours = G.Suggest() }
		Northstar.Set("behavior.suggestFrom", "joe")
		r.source = G.SuggestSource()
		r.joe = G.Suggest()
		stub.world.faction, stub.world.race = "Alliance", "Human"
		r.allianceFromJoe = G.Suggest()
		stub.world.faction, stub.world.race = "Horde", "Orc"
		G.SetPackShown("joe", false)
		r.hiddenSource = G.SuggestSource()
		r.hidden = G.Suggest()
		G.SetPackShown("joe", true)
		Northstar.Set("behavior.suggestFrom", "nope")
		r.nope = G.SuggestSource()
		emit(r)
	"#,
		"",
	);
	assert_eq!(
		out,
		json!({
			"default": "guides", "ours": "forever/horde", "source": "joe", "joe": "joe/a", "allianceFromJoe": "forever/alliance",
			"hiddenSource": "guides", "hidden": "forever/horde", "nope": "guides",
		})
	);
}

#[test]
fn lookup_s_curated_guide_comes_from_the_suggestion_source_then_ours() {
	let out = run_with(
		r#"
		local r = { default = Northstar.Lookup.CuratedGuide("mount", 8000) }
		Northstar.Set("behavior.suggestFrom", "joe")
		r.joe = Northstar.Lookup.CuratedGuide("mount", 8000)
		G.SetPackShown("guides", false)
		Northstar.Set("behavior.suggestFrom", "guides")
		r.oursHidden = Northstar.Lookup.CuratedGuide("mount", 8000) or false
		emit(r)
	"#,
		"",
		with_lookup(),
		&["stub_lookup_runtime.lua"],
	);
	assert_eq!(out, json!({ "default": "forever/mount", "joe": "joe/mount", "oursHidden": false }));
}

#[test]
fn installed_packs_on_broken_turned_off_not_loaded_too_new_never_registered() {
	let out = run(
		r#"
		Northstar.RegisterPack({ addon = "EmptyAddon", id = "empty", format = 1, title = "Empty", author = "E", version = "1", license = "MIT" })
		G.ScanInstalled()
		G.ScanInstalled()
		local rows = {}
		for _, r in ipairs(G.Packs()) do
			local kinds = {}
			for i, p in ipairs(r.problems) do kinds[i] = p.kind end
			rows[#rows + 1] = { id = r.id, addon = r.addon, status = r.status, reason = r.reason or false, needs = r.needs or false,
				title = r.title or false, author = r.author or false, version = r.version or false, license = r.license or false,
				website = r.website or false, problems = kinds }
		end
		emit({ rows = rows, problems = G.ProblemCount() })
	"#,
		r#"
			ADDON_INTERFACE_VERSION = "Out of date"
			stub.addons = {
				{ name = "Northstar", loaded = true },
				{ name = "Northstar_Guides", loaded = true },
				{ name = "JoeAddon", loaded = true },
				{ name = "EmptyAddon", loaded = true },
				{ name = "Off", reason = "DISABLED", enabled = false },
				{ name = "Old", reason = "INTERFACE_VERSION" },
				{ name = "Future", reason = "INTERFACE_VERSION" },
				{ name = "Crash", loaded = true },
				{ name = "SomethingElse", loaded = true },
			}
			local function toc(id, title, extra)
				local m = { ["X-Northstar-Pack"] = id, ["X-Northstar-Format"] = "1", Title = title, Author = title .. " Author", Version = "2.0", ["X-License"] = "CC0-1.0", ["X-Website"] = "https://example.org/" .. id }
				for k, v in pairs(extra or {}) do m[k] = v end
				return m
			end
			stub.addonMeta.Northstar_Guides = toc("guides", "Northstar Guides")
			stub.addonMeta.JoeAddon = toc("joe", "Joe's Routes")
			stub.addonMeta.EmptyAddon = toc("empty", "Empty")
			stub.addonMeta.Off = toc("off", "Switched Off", { Title = "Northstar Community: Switched Off" })
			stub.addonMeta.Old = toc("old", "Old Pack", { Title = "Northstar Pack: Old Pack" })
			stub.addonMeta.Future = toc("future", "Future Pack", { ["X-Northstar-Format"] = "99", ["X-Northstar-Needs"] = "0.4.0" })
			stub.addonMeta.Crash = toc("crash", "Crashing Pack")"#,
	);
	let rows = out["rows"].as_array().unwrap();
	let by: HashMap<&str, &Value> = rows.iter().map(|r| (text(&r["addon"]), r)).collect();
	let addons: Vec<&str> = rows.iter().map(|r| text(&r["addon"])).collect();
	assert_eq!(addons, vec!["Northstar_Guides", "Crash", "EmptyAddon", "Future", "JoeAddon", "Old", "Off"], "ours first, then by title; each addon once after two scans");
	assert_eq!(by["Northstar_Guides"]["status"], "on");
	assert_eq!(by["JoeAddon"]["status"], "on");
	assert_eq!(by["EmptyAddon"]["status"], "broken");
	assert_eq!(by["EmptyAddon"]["problems"], json!(["no-guides"]));
	assert_eq!(by["Off"]["status"], "disabled");
	assert_eq!(by["Old"]["status"], "not-loaded");
	assert_eq!(by["Old"]["reason"], "Out of date");
	assert_eq!(by["Future"]["status"], "too-new");
	assert_eq!(by["Future"]["needs"], "0.4.0");
	assert_eq!(by["Crash"]["status"], "broken");
	assert_eq!(by["Crash"]["problems"], json!(["no-guides"]));
	let off = by["Off"];
	assert_eq!(
		json!({
			"id": off["id"].clone(), "title": off["title"].clone(), "author": off["author"].clone(),
			"version": off["version"].clone(), "license": off["license"].clone(), "website": off["website"].clone(),
		}),
		json!({ "id": "off", "title": "Switched Off", "author": "Switched Off Author", "version": "2.0", "license": "CC0-1.0", "website": "https://example.org/off" }),
		"an unregistered pack reads its TOC, without the \"Northstar Community: \" the compiler puts before its title"
	);
	assert_eq!(by["Old"]["title"], "Old Pack", "the legacy \"Northstar Pack: \" title prefix is stripped too");
	assert_eq!(by["JoeAddon"]["title"], "Joe's Routes", "a registered pack keeps what it registered");
	assert_eq!(out["problems"], 2);
}

#[test]
fn a_pack_not_loaded_for_a_reason_the_client_has_no_text_for_shows_the_reason_as_given() {
	let out = run(
		r#"
		G.ScanInstalled()
		local r
		for _, p in ipairs(G.Packs()) do if p.addon == "Lonely" then r = p end end
		emit({ addon = r.addon, status = r.status, reason = r.reason or false, global = ADDON_DEP_MISSING ~= nil })
	"#,
		r#"
			stub.addons = {
				{ name = "Northstar", loaded = true },
				{ name = "Northstar_Guides", loaded = true },
				{ name = "Lonely", reason = "DEP_MISSING" },
			}
			stub.addonMeta.Northstar_Guides = { ["X-Northstar-Pack"] = "guides", ["X-Northstar-Format"] = "1", Title = "Northstar Guides" }
			stub.addonMeta.Lonely = { ["X-Northstar-Pack"] = "lonely", ["X-Northstar-Format"] = "1", Title = "Lonely Pack" }"#,
	);
	assert_eq!(out, json!({ "addon": "Lonely", "status": "not-loaded", "reason": "DEP_MISSING", "global": false }));
}

#[test]
fn a_pack_whose_file_errors_after_two_guides_keeps_them_and_stays_on() {
	let out = run(
		r#"
		local ok = pcall(function()
			Northstar.RegisterPack({ addon = "PartAddon", id = "part", format = 1, title = "Part", author = "P", version = "1", license = "MIT" })
			Northstar.RegisterGuide({ id = "part/a", pack = "part", title = "A", steps = { { goals = { { t = "level", level = 30 } } } } })
			Northstar.RegisterGuide({ id = "part/b", pack = "part", title = "B", steps = { { goals = { { t = "level", level = 30 } } } } })
			error("boom")
		end)
		G.ScanInstalled()
		local E = Northstar.Engine
		local a, b = E.OpenTab("part/a"), E.OpenTab("part/b")
		local tabs = {}
		for i, t in ipairs(E.GetTabs()) do tabs[i] = t.guideId end
		emit({ ok = ok, status = G.Pack("part").status, count = G.Pack("part").guideCount, problems = #G.Pack("part").problems,
			opened = { a ~= nil, b ~= nil }, tabs = tabs })
	"#,
		r#"stub.addons = { { name = "PartAddon", loaded = true } }; stub.addonMeta.PartAddon = { ["X-Northstar-Pack"] = "part", ["X-Northstar-Format"] = "1" }"#,
	);
	assert_eq!(out["ok"], false);
	assert_eq!(out["status"], "on");
	assert_eq!(out["count"], 2);
	assert_eq!(out["problems"], 0);
	assert_eq!(out["opened"], json!([true, true]));
	let tabs: Vec<&str> = out["tabs"].as_array().unwrap().iter().map(text).collect();
	assert!(tabs.contains(&"part/a") && tabs.contains(&"part/b"), "{}", tabs.join(","));
}

#[test]
fn search_finds_a_shown_pack_s_guide_by_title_and_not_once_the_pack_is_hidden() {
	let out = run(
		r#"
		local function found()
			for _, r in ipairs(Northstar.Search.Query("T joe/a")) do
				if r.kind == "guide" and r.id == "joe/a" then return true end
			end
			return false
		end
		local r = { shown = found() }
		G.SetPackShown("joe", false)
		r.hidden = found()
		G.SetPackShown("joe", true)
		r.back = found()
		emit(r)
	"#,
		"",
	);
	assert_eq!(out, json!({ "shown": true, "hidden": false, "back": true }));
}

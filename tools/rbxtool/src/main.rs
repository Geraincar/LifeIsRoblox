// rbxtool: чтение и запись place-файлов Roblox (.rbxl/.rbxlx/.rbxmx) через rbx-dom — те же библиотеки, что у Rojo.
//   rbxtool tree <place> [depth] [v]            — дерево объектов (v — с позициями и размерами)
//   rbxtool export <place> <dir>                — выгрузить все скрипты в файлы (Rojo-имена)
//   rbxtool props <place> <A/B/C>               — свойства объекта
//   rbxtool parts <place>                       — все детали с CFrame и Size (TSV)
//   rbxtool dumpall <place>                     — все объекты и свойства (для сравнения до/после)
//   rbxtool sync <place> <src> <out> [--own P]… — влить src/ (Rojo-раскладка) в place; --own P — папку P пересобрать начисто
//   rbxtool delete <place> <A/B/C> <out>        — удалить объект
//   rbxtool convert <in> <out>                  — .rbxl ⇄ .rbxlx
//   rbxtool reflect <out.luau>                  — reflection-база классов и Enum для мока тестов
use rbx_dom_weak::{WeakDom, InstanceBuilder, types::{Ref, Variant}, ustr};
use std::{fs, io::BufReader, path::Path};

fn load(p: &str) -> WeakDom {
    let f = BufReader::new(fs::File::open(p).unwrap());
    if p.ends_with(".rbxlx") || p.ends_with(".rbxmx") {
        rbx_xml::from_reader_default(f).unwrap()
    } else {
        rbx_binary::from_reader(f).unwrap()
    }
}
fn save(dom: &WeakDom, p: &str) {
    let root = dom.root().children().to_vec();
    let f = std::io::BufWriter::new(fs::File::create(p).unwrap());
    if p.ends_with(".rbxlx") {
        rbx_xml::to_writer_default(f, dom, &root).unwrap();
    } else {
        rbx_binary::to_writer(f, dom, &root).unwrap();
    }
}
fn src_of(dom: &WeakDom, r: Ref) -> Option<String> {
    match dom.get_by_ref(r).unwrap().properties.get(&ustr("Source")) {
        Some(Variant::String(s)) => Some(s.clone()),
        Some(Variant::BinaryString(b)) => Some(String::from_utf8_lossy(b.as_ref()).into()),
        _ => None,
    }
}
fn tree(dom: &WeakDom, r: Ref, depth: usize, max: usize, verbose: bool) {
    let i = dom.get_by_ref(r).unwrap();
    let mut extra = String::new();
    if let Some(s) = src_of(dom, r) { extra = format!(" [src {} b]", s.len()); }
    if verbose {
        for k in ["Position", "CFrame", "Size", "size"] {
            if let Some(v) = i.properties.get(&ustr(k)) {
                match v {
                    Variant::CFrame(c) => extra += &format!(" pos=({:.1},{:.1},{:.1})", c.position.x, c.position.y, c.position.z),
                    Variant::Vector3(s) => extra += &format!(" {}=({:.1},{:.1},{:.1})", k, s.x, s.y, s.z),
                    _ => {}
                }
            }
        }
    }
    println!("{}{} \"{}\"{}", "  ".repeat(depth), i.class, i.name, extra);
    if depth < max {
        for c in i.children() { tree(dom, *c, depth + 1, max, verbose); }
    }
}
fn export(dom: &WeakDom, r: Ref, path: &Path) {
    let i = dom.get_by_ref(r).unwrap();
    let ext = match i.class.as_str() { "ModuleScript" => Some(".luau"), "LocalScript" => Some(".client.luau"), "Script" => Some(".server.luau"), _ => None };
    if let (Some(e), Some(s)) = (ext, src_of(dom, r)) {
        fs::create_dir_all(path).unwrap();
        let name = i.name.replace('/', "_");
        let mut p = path.join(format!("{}{}", name, e));
        let mut k = 2; while p.exists() { p = path.join(format!("{}~{}{}", name, k, e)); k += 1; }
        fs::write(p, s).unwrap();
    }
    for c in i.children().to_vec() { export(dom, c, &path.join(i.name.replace('/', "_"))); }
}
fn find_child(dom: &WeakDom, parent: Ref, name: &str) -> Option<Ref> {
    dom.get_by_ref(parent).unwrap().children().iter().copied().find(|c| dom.get_by_ref(*c).unwrap().name == name)
}
// Rojo-like sync: dir -> Folder, X.luau -> ModuleScript, X.client.luau -> LocalScript,
// X.server.luau -> Script, X.rbxmx -> model (replaces same-named child), init.luau not supported.
fn sync(dom: &mut WeakDom, parent: Ref, dir: &Path) {
    let mut entries: Vec<_> = fs::read_dir(dir).unwrap().map(|e| e.unwrap().path()).collect();
    entries.sort();
    for p in entries {
        let fname = p.file_name().unwrap().to_string_lossy().to_string();
        if p.is_dir() {
            let r = match find_child(dom, parent, &fname) {
                Some(r) => r,
                None => dom.insert(parent, InstanceBuilder::new("Folder").with_name(&fname)),
            };
            sync(dom, r, &p);
        } else if let Some((name, class)) = [(".client.luau", "LocalScript"), (".server.luau", "Script"), (".luau", "ModuleScript")]
            .iter().find_map(|(e, c)| fname.strip_suffix(e).map(|n| (n.to_string(), *c))) {
            let source = fs::read_to_string(&p).unwrap();
            if let Some(old) = find_child(dom, parent, &name) {
                let inst = dom.get_by_ref_mut(old).unwrap();
                if inst.class != class { panic!("class mismatch at {:?}: {} vs {}", p, inst.class, class); }
                inst.properties.insert(ustr("Source"), Variant::String(source));
            } else {
                dom.insert(parent, InstanceBuilder::new(class).with_name(&name).with_property("Source", Variant::String(source)));
            }
        } else if let Some(name) = fname.strip_suffix(".rbxmx") {
            let model = load(p.to_str().unwrap());
            if let Some(old) = find_child(dom, parent, name) { dom.destroy(old); }
            for c in model.root().children().to_vec() {
                model_clone(&model, c, dom, parent);
            }
        }
    }
}
fn model_clone(src: &WeakDom, r: Ref, dst: &mut WeakDom, parent: Ref) {
    let i = src.get_by_ref(r).unwrap();
    let mut b = InstanceBuilder::new(i.class.as_str()).with_name(&i.name);
    for (k, v) in &i.properties { if !matches!(v, Variant::Ref(_)) { b = b.with_property(k.as_str(), v.clone()); } }
    let nr = dst.insert(parent, b);
    for c in i.children().to_vec() { model_clone(src, c, dst, nr); }
}
fn main() {
    let a: Vec<String> = std::env::args().collect();
    match a[1].as_str() {
        "tree" => { let d = load(&a[2]); let max = a.get(3).map(|s| s.parse().unwrap()).unwrap_or(99); let v = a.get(4).is_some();
            for c in d.root().children() { tree(&d, *c, 0, max, v); } }
        "export" => { let d = load(&a[2]); for c in d.root().children().to_vec() { export(&d, c, Path::new(&a[3])); } }
        "props" => { let d = load(&a[2]); let mut r = d.root_ref();
            for seg in a[3].split('/') { r = find_child(&d, r, seg).expect(seg); }
            for (k, v) in &d.get_by_ref(r).unwrap().properties { if !matches!(v, Variant::String(_)) || k.as_str() != "Source" { println!("{} = {:?}", k, v); } } }
        "delete" => { let mut d = load(&a[2]); let mut r = d.root_ref();
            for seg in a[3].split('/') { r = find_child(&d, r, seg).expect(seg); }
            d.destroy(r); save(&d, &a[4]); }
        "sync" => { let mut d = load(&a[2]); let root = d.root_ref();
            // --own путь: эта папка целиком принадлежит src/ — удалить перед синхронизацией (не оставлять удалённые модули)
            let mut k = 5;
            while k + 1 < a.len() + 1 && a.get(k).map(|x| x == "--own").unwrap_or(false) {
                let mut r = Some(root);
                for seg in a[k + 1].split('/') { r = r.and_then(|r| find_child(&d, r, seg)); }
                if let Some(r) = r { d.destroy(r); }
                k += 2;
            }
            for svc in fs::read_dir(&a[3]).unwrap() { let p = svc.unwrap().path(); if !p.is_dir() { continue; }
                let n = p.file_name().unwrap().to_string_lossy().to_string();
                let r = find_child(&d, root, &n).unwrap_or_else(|| panic!("service {} missing", n));
                sync(&mut d, r, &p); }
            save(&d, &a[4]); }
        "parts" => { let d = load(&a[2]); let mut stack = vec![(d.root_ref(), String::new())];
            while let Some((r, path)) = stack.pop() { let i = d.get_by_ref(r).unwrap();
                let np = format!("{}/{}", path, i.name);
                if let (Some(Variant::CFrame(c)), Some(Variant::Vector3(s))) = (i.properties.get(&ustr("CFrame")), i.properties.get(&ustr("Size")).or(i.properties.get(&ustr("size")))) {
                    println!("{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}", i.class, np, c.position.x, c.position.y, c.position.z, s.x, s.y, s.z); }
                for ch in i.children() { stack.push((*ch, np.clone())); } } }
        "reflect" => { let db = rbx_reflection_database::get_bundled();
            let mut out = String::from("-- Сгенерировано tools/rbxtool reflect (rbx-dom reflection database). Не редактировать.\nreturn {\n\tclasses = {\n");
            let mut names: Vec<_> = db.classes.keys().collect(); names.sort();
            for n in names { let c = &db.classes[n];
                let mut props: Vec<_> = c.properties.iter().filter(|(_, p)| !matches!(p.scriptability, rbx_reflection::Scriptability::None)).map(|(k, p)| {
                    let t = match &p.data_type { rbx_reflection::DataType::Value(v) => format!("{:?}", v), rbx_reflection::DataType::Enum(e) => format!("Enum.{}", e), _ => "?".into() };
                    format!("[{:?}]=\"{}\"", k, t) }).collect(); props.sort();
                out += &format!("\t\t[\"{}\"] = {{ super = {}, props = {{ {} }} }},\n", n, c.superclass.map(|s| format!("\"{}\"", s)).unwrap_or("nil".into()), props.join(", ")); }
            out += "\t},\n\tenums = {\n";
            let mut en: Vec<_> = db.enums.keys().collect(); en.sort();
            for n in en { let e = &db.enums[n]; let mut it: Vec<_> = e.items.iter().map(|(k, v)| format!("[{:?}]={}", k, v)).collect(); it.sort();
                out += &format!("\t\t[\"{}\"] = {{ {} }},\n", n, it.join(", ")); }
            out += "\t},\n}\n"; fs::write(&a[2], out).unwrap(); }
        "dumpall" => { let d = load(&a[2]); let mut stack = vec![(d.root_ref(), String::new())]; let mut out = Vec::new();
            while let Some((r, path)) = stack.pop() { let i = d.get_by_ref(r).unwrap();
                let np = format!("{}/{}[{}]", path, i.name, i.class);
                let mut props: Vec<String> = i.properties.iter().map(|(k, v)| match v {
                    Variant::Ref(x) => format!("{}=Ref({})", k, if x.is_none() { "nil".to_string() } else { d.get_by_ref(*x).map(|t| t.name.to_string()).unwrap_or("?".into()) }),
                    Variant::SharedString(_) => format!("{}=SharedString", k),
                    _ => format!("{}={:?}", k, v) }).collect();
                props.sort();
                out.push(format!("{}\t{}", np, props.join(" | ")));
                for ch in i.children() { stack.push((*ch, np.clone())); } }
            out.sort(); for l in out { println!("{}", l); } }
        "convert" => { let d = load(&a[2]); save(&d, &a[3]); }
        _ => panic!("unknown cmd"),
    }
}

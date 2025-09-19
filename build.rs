use std::env;
use std::fs::File;
use std::io::Write;
use std::path::Path;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");

    // Generate sine table
    let out_dir = env::var("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("sine_table.rs");
    let mut f = File::create(&dest_path).unwrap();

    const SINE_TABLE_SIZE: usize = 4096;
    const TWO_PI: f64 = 2.0 * std::f64::consts::PI;

    let mut table = String::new();
    table.push_str("pub const SINE_TABLE: [f32; ");
    table.push_str(&(SINE_TABLE_SIZE + 1).to_string());
    table.push_str("] = [\n");

    for i in 0..=SINE_TABLE_SIZE {
        let val = ((i as f64 / SINE_TABLE_SIZE as f64) * TWO_PI).sin();
        table.push_str(&format!("    {:.8}f32,\n", val));
    }

    table.push_str("];\n");

    f.write_all(table.as_bytes()).unwrap();

    // AAudio bindings are now manually defined in the source
}

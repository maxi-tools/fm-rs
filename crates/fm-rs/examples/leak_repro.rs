//! Repro: does a tool-enabled Session leak its ToolCallbackData?
//!
//! Creates N sessions with a tool attached, dropping each immediately, and
//! reports RSS. Before the deinit fix every session leaked one
//! ToolCallbackData plus every Arc<dyn Tool> in its map, for process lifetime.
use std::sync::Arc;
use fm_rs::{Result, Session, SystemLanguageModel, Tool, ToolOutput};

struct Noop;
impl Tool for Noop {
    fn name(&self) -> &str { "noop" }
    fn description(&self) -> &str { "does nothing" }
    fn arguments_schema(&self) -> serde_json::Value { serde_json::json!({"type":"object"}) }
    fn call(&self, _args: serde_json::Value) -> Result<ToolOutput> { Ok(ToolOutput::new("{}")) }
}

fn rss_kb() -> u64 {
    let out = std::process::Command::new("ps")
        .args(["-o", "rss=", "-p", &std::process::id().to_string()])
        .output().expect("ps");
    String::from_utf8_lossy(&out.stdout).trim().parse().unwrap_or(0)
}

fn main() {
    let model = SystemLanguageModel::new().expect("model");
    if !model.is_available() {
        println!("SKIP: Foundation Models unavailable");
        return;
    }
    let n: usize = std::env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(300);

    // Warm up so first-session allocations don't count as growth.
    for _ in 0..20 {
        let _ = Session::builder(&model).tool(Arc::new(Noop)).build();
    }
    let before = rss_kb();
    for _ in 0..n {
        let _ = Session::builder(&model).tool(Arc::new(Noop)).build();
    }
    let after = rss_kb();
    println!("sessions:   {n}");
    println!("rss before: {before} KB");
    println!("rss after:  {after} KB");
    println!("growth:     {} KB ({:.1} bytes/session)",
             after as i64 - before as i64,
             (after as f64 - before as f64) * 1024.0 / n as f64);
}

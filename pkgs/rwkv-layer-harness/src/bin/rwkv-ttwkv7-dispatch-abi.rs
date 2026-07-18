use rwkv_layer_harness::run_ttwkv7_dispatch_abi_fixture;
use std::error::Error;
use std::io::{self, Write};

fn main() -> Result<(), Box<dyn Error>> {
    if std::env::args_os().len() != 1 {
        return Err("rwkv-ttwkv7-dispatch-abi accepts no arguments".into());
    }
    let receipt = run_ttwkv7_dispatch_abi_fixture().map_err(io::Error::other)?;
    let stdout = io::stdout();
    let mut output = stdout.lock();
    serde_json::to_writer_pretty(&mut output, &receipt)?;
    writeln!(output)?;
    Ok(())
}

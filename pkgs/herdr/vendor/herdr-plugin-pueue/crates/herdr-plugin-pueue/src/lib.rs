#![forbid(unsafe_code)]

pub mod process;
mod terminal;
mod ui;

pub use terminal::{run_dashboard, run_open_dashboard, run_open_split_dashboard};

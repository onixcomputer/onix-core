#[path = "/home/brittonr/git/OnixResearch/trellis/src/nix_version.rs"]
mod nix_version;

use std::io::{self, BufRead};

fn bytes(hex: &str) -> Vec<u8> {
    hex.as_bytes().chunks_exact(2).map(|pair| {
        let digit = |b: u8| if b <= b'9' { b - b'0' } else { b - b'a' + 10 };
        digit(pair[0]) * 16 + digit(pair[1])
    }).collect()
}

fn compare(a: &str, b: &str) {
    println!("{}", nix_version::compare_versions(&bytes(a), &bytes(b)));
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() == 3 {
        compare(&args[1], &args[2]);
    } else {
        for line in io::stdin().lock().lines() {
            let line = line.unwrap();
            let (a, b) = line.split_once(' ').unwrap();
            compare(a, b);
        }
    }
}

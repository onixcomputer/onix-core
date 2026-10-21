#![no_std]
#![feature(register_tool)]
#![register_tool(tigerstyle)]

//! A read-only probe. This crate contains no firmware update operation.

pub mod adapter;
pub mod apcb;
pub mod domain;
pub mod entry;
pub mod report;

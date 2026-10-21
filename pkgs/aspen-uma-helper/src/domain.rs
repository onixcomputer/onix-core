//! Deterministic decoding. A valid snapshot never authorizes an update.

pub const OEM_PAYLOAD_BYTES: usize = 0x320;
pub const AMD_PAYLOAD_BYTES: usize = 0x5f2;
pub const VARIABLE_ATTRIBUTES: u32 = 7;
pub const AUTO_MODE: u8 = 2;
pub const CUSTOM_MODE: u8 = 1;
pub const HIGH_LEVEL: u8 = 2;
pub const MINIMUM_LEVEL: u8 = 0;
pub const MEDIUM_LEVEL: u8 = 1;
pub const MINIMUM_MIB: u32 = 512;
pub const AUTO_SIZE_SENTINEL: u32 = u32::MAX;
pub const MODE_TOKEN: u32 = 0x1fb3_5295;
pub const LEVEL_TOKEN: u32 = 0xe3ab_8ca4;
pub const BIOS_PURPOSE: u8 = 3;
pub const APCB_REVISION_WORD: u64 = 3;
const U32_BYTES: usize = core::mem::size_of::<u32>();

#[derive(Clone, Copy)]
pub struct Layout {
    pub bytes: usize,
    pub mode: usize,
    pub level: usize,
    pub custom_mib: usize,
}

pub const OEM_LAYOUT: Layout = Layout {
    bytes: OEM_PAYLOAD_BYTES,
    mode: 0xb9,
    level: 0xba,
    custom_mib: 0xbb,
};
pub const AMD_LAYOUT: Layout = Layout {
    bytes: AMD_PAYLOAD_BYTES,
    mode: 0xf8,
    level: 0x101,
    custom_mib: 0xfb,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct UmaSnapshot {
    pub mode: u8,
    pub level: u8,
    pub custom_mib: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DecodeError {
    Attributes,
    Size,
    Offset,
    Mode,
    Level,
}

pub fn decode(payload: &[u8], attributes: u32, layout: Layout) -> Result<UmaSnapshot, DecodeError> {
    if attributes != VARIABLE_ATTRIBUTES {
        return Err(DecodeError::Attributes);
    }
    if payload.len() != layout.bytes {
        return Err(DecodeError::Size);
    }
    let mode = *payload.get(layout.mode).ok_or(DecodeError::Offset)?;
    let level = *payload.get(layout.level).ok_or(DecodeError::Offset)?;
    if mode != AUTO_MODE && mode != CUSTOM_MODE {
        return Err(DecodeError::Mode);
    }
    if level > HIGH_LEVEL {
        return Err(DecodeError::Level);
    }
    let end = layout
        .custom_mib
        .checked_add(U32_BYTES)
        .ok_or(DecodeError::Offset)?;
    let bytes = payload
        .get(layout.custom_mib..end)
        .ok_or(DecodeError::Offset)?;
    assert_eq!(
        bytes.len(),
        U32_BYTES,
        "the admitted field has the exact integer width"
    );
    assert!(
        [AUTO_MODE, CUSTOM_MODE].contains(&mode),
        "the mode passed validation"
    );
    let custom_mib = u32::from_le_bytes(bytes.try_into().map_err(|_| DecodeError::Offset)?);
    Ok(UmaSnapshot {
        mode,
        level,
        custom_mib,
    })
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TokenSample {
    pub purpose: u8,
    pub value: u8,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ProbeVerdict {
    HighObserved,
    MinimumObserved,
    Inconsistent,
    UnsupportedRevision,
    DifferentPurpose,
}

pub fn assess(
    revision: u64,
    oem: UmaSnapshot,
    amd: UmaSnapshot,
    mode: TokenSample,
    level: TokenSample,
) -> ProbeVerdict {
    if revision != APCB_REVISION_WORD {
        return ProbeVerdict::UnsupportedRevision;
    }
    if mode.purpose != BIOS_PURPOSE || level.purpose != BIOS_PURPOSE {
        return ProbeVerdict::DifferentPurpose;
    }
    assert_eq!(
        revision, APCB_REVISION_WORD,
        "the revision passed admission"
    );
    assert_eq!(
        level.purpose, BIOS_PURPOSE,
        "the token belongs to the inspected purpose"
    );
    if oem.mode != AUTO_MODE || amd.mode != AUTO_MODE || mode.value != AUTO_MODE {
        return ProbeVerdict::Inconsistent;
    }
    if oem.level != amd.level || oem.level != level.value {
        return ProbeVerdict::Inconsistent;
    }
    match level.value {
        HIGH_LEVEL => ProbeVerdict::HighObserved,
        MINIMUM_LEVEL => ProbeVerdict::MinimumObserved,
        _ => ProbeVerdict::Inconsistent,
    }
}

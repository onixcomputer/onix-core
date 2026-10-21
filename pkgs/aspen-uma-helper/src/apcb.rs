//! Binary-compatible read view of the exact BIOS 03.03 x64 APCB interface.
//! The unused words are opaque. No setter, erase, lock, or flush is callable here.

pub const PROTOCOL_GUID: r_efi::efi::Guid = r_efi::efi::Guid::from_fields(
    0x7189e04e,
    0x6284,
    0x4953,
    0xa5,
    0x43,
    &[0xa3, 0x1f, 0x89, 0xa1, 0xa7, 0xbf],
);
pub const GET8_OFFSET: usize = 0x98;
pub const OPAQUE_METHOD_WORDS: usize = 18;

/// This is an observed x64 header word, not a claim about the vendor C typedef.
#[repr(C)]
pub struct ReadProtocol {
    pub revision_word: u64,
    pub opaque: [usize; OPAQUE_METHOD_WORDS],
    pub get8: Option<Get8>,
}

pub type Get8 =
    unsafe extern "efiapi" fn(*mut core::ffi::c_void, *mut u8, u32, *mut u8) -> r_efi::efi::Status;

/// Read one token through the firmware getter.
///
/// # Safety
/// `interface` must point to a live, correctly aligned BIOS 03.03 APCB interface.
/// The caller must remain in boot services with no concurrent APCB caller.
/// The getter can change RAM selection state but must not persist configuration.
#[allow(
    tigerstyle::public_unsafe_api,
    reason = "apcb owns the BIOS 03.03 getter FFI contract: the raw firmware interface must be live, aligned, and exclusive in boot services"
)]
pub unsafe fn get8(
    interface: core::ptr::NonNull<ReadProtocol>,
    token: u32,
) -> Result<crate::domain::TokenSample, r_efi::efi::Status> {
    // SAFETY: The caller supplies the exact live interface and its lifetime.
    let protocol = unsafe { interface.as_ref() };
    if protocol.revision_word != crate::domain::APCB_REVISION_WORD {
        return Err(r_efi::efi::Status::INCOMPATIBLE_VERSION);
    }
    assert_eq!(protocol.revision_word, crate::domain::APCB_REVISION_WORD);
    let getter = protocol.get8.ok_or(r_efi::efi::Status::UNSUPPORTED)?;
    let mut purpose = 0;
    let mut value = 0;
    // SAFETY: The inspected Microsoft x64 ABI has four arguments. Both outputs
    // are valid writable bytes, including on the SMM-success path.
    let status = unsafe { getter(interface.as_ptr().cast(), &mut purpose, token, &mut value) };
    if status != r_efi::efi::Status::SUCCESS {
        return Err(status);
    }
    assert_eq!(
        status,
        r_efi::efi::Status::SUCCESS,
        "the getter accepted this sample"
    );
    Ok(crate::domain::TokenSample { purpose, value })
}

//! UEFI effects. The only write capability is the probe report on its ESP.

use core::fmt::Write;

mod filesystem;

const NAME_UNITS: usize = 32;
const OEM_GUID: r_efi::efi::Guid = r_efi::efi::Guid::from_fields(
    0xa04a27f4,
    0xdf00,
    0x4d42,
    0xb5,
    0x52,
    &[0x39, 0x51, 0x13, 0x02, 0x11, 0x3d],
);
const AMD_GUID: r_efi::efi::Guid = r_efi::efi::Guid::from_fields(
    0x3a997502,
    0x647a,
    0x4c82,
    0x99,
    0x8e,
    &[0x52, 0xef, 0x94, 0x86, 0xa2, 0x47],
);

const fn require_success(status: r_efi::efi::Status) -> Result<(), r_efi::efi::Status> {
    if status.as_usize() == r_efi::efi::Status::SUCCESS.as_usize() {
        Ok(())
    } else {
        Err(status)
    }
}

/// # Safety
/// The runtime table must remain live. The buffer is private to this call.
unsafe fn variable<const N: usize>(
    runtime: &r_efi::efi::RuntimeServices,
    name: &str,
    mut guid: r_efi::efi::Guid,
) -> Result<([u8; N], u32), r_efi::efi::Status> {
    let mut name = crate::report::utf16::<NAME_UNITS>(name)
        .map_err(|_| r_efi::efi::Status::INVALID_PARAMETER)?;
    assert_eq!(
        name.last(),
        Some(&0),
        "the fixed name buffer retains its terminator"
    );
    let mut bytes = [0; N];
    let mut size_bytes = bytes.len();
    let mut attributes = 0;
    // The name is terminated and all output buffers have the declared size.
    require_success((runtime.get_variable)(
        name.as_mut_ptr(),
        &mut guid,
        &mut attributes,
        &mut size_bytes,
        bytes.as_mut_ptr().cast(),
    ))?;
    if size_bytes != N {
        return Err(r_efi::efi::Status::BAD_BUFFER_SIZE);
    }
    assert_eq!(
        size_bytes,
        bytes.len(),
        "the variable fills its exact payload"
    );
    Ok((bytes, attributes))
}

/// # Safety
/// The caller guarantees live UEFI tables throughout this read-only observation.
unsafe fn observe(
    table: &r_efi::efi::SystemTable,
    buffer: &mut crate::report::Buffer,
) -> Result<(), r_efi::efi::Status> {
    let mut pointer = core::ptr::null_mut::<core::ffi::c_void>();
    let mut guid = crate::apcb::PROTOCOL_GUID;
    // SAFETY: The entry validated both table pointers and the boot phase is live.
    let boot = unsafe { &*table.boot_services };
    // LocateProtocol receives a known GUID and a valid output address.
    let status = (boot.locate_protocol)(&mut guid, core::ptr::null_mut(), &mut pointer);
    writeln!(buffer, "apcb.locate={:#x}", status.as_usize())
        .map_err(|_| r_efi::efi::Status::BAD_BUFFER_SIZE)?;
    require_success(status)?;
    let interface = core::ptr::NonNull::new(pointer.cast::<crate::apcb::ReadProtocol>())
        .ok_or(r_efi::efi::Status::NOT_FOUND)?;
    // SAFETY: This is the live interface for the matching APCB GUID.
    let revision = unsafe { interface.as_ref().revision_word };
    writeln!(buffer, "apcb.revision_word={revision}")
        .map_err(|_| r_efi::efi::Status::BAD_BUFFER_SIZE)?;
    if revision != crate::domain::APCB_REVISION_WORD {
        return Err(r_efi::efi::Status::INCOMPATIBLE_VERSION);
    }
    assert_eq!(
        revision,
        crate::domain::APCB_REVISION_WORD,
        "the APCB ABI is validated"
    );
    // SAFETY: The entry validates the runtime pointer. GetVariable is a read.
    let runtime = unsafe { &*table.runtime_services };
    // SAFETY: Each read owns its output buffer and uses the matching variable GUID.
    let (oem, attributes) =
        unsafe { variable::<{ crate::domain::OEM_PAYLOAD_BYTES }>(runtime, "Setup", OEM_GUID) }?;
    let oem = crate::domain::decode(&oem, attributes, crate::domain::OEM_LAYOUT)
        .map_err(|_| r_efi::efi::Status::COMPROMISED_DATA)?;
    // SAFETY: The AMD variable uses its own exact payload size and output buffer.
    let (amd, attributes) =
        unsafe { variable::<{ crate::domain::AMD_PAYLOAD_BYTES }>(runtime, "AmdSetup", AMD_GUID) }?;
    let amd = crate::domain::decode(&amd, attributes, crate::domain::AMD_LAYOUT)
        .map_err(|_| r_efi::efi::Status::COMPROMISED_DATA)?;
    assert!(
        oem.level <= crate::domain::HIGH_LEVEL,
        "the OEM decoder bounds the level"
    );
    assert!(
        amd.level <= crate::domain::HIGH_LEVEL,
        "the AMD decoder bounds the level"
    );
    writeln!(buffer, "oem={oem:?}\namd={amd:?}")
        .map_err(|_| r_efi::efi::Status::BAD_BUFFER_SIZE)?;
    // SAFETY: The interface and revision match. This synchronous application calls
    // no other APCB method. The getter has no setter or persistent commit path.
    let mode = unsafe { crate::apcb::get8(interface, crate::domain::MODE_TOKEN) };
    writeln!(buffer, "apcb.mode={mode:?}").map_err(|_| r_efi::efi::Status::BAD_BUFFER_SIZE)?;
    let mode = mode?;
    // SAFETY: Same live interface and read-only operation after the first call returns.
    let level = unsafe { crate::apcb::get8(interface, crate::domain::LEVEL_TOKEN) };
    writeln!(buffer, "apcb.level={level:?}").map_err(|_| r_efi::efi::Status::BAD_BUFFER_SIZE)?;
    let level = level?;
    let verdict = crate::domain::assess(revision, oem, amd, mode, level);
    writeln!(buffer, "verdict={verdict:?}").map_err(|_| r_efi::efi::Status::BAD_BUFFER_SIZE)?;
    Ok(())
}

/// Execute a bounded observation and return to the parent boot loader.
///
/// # Safety
/// The UEFI loader must supply the live image handle and system table.
/// Boot services must be active. This function never calls ExitBootServices.
#[allow(
    tigerstyle::public_unsafe_api,
    reason = "adapter owns the UEFI loader FFI contract: raw firmware pointers must remain live and aligned in boot services"
)]
pub unsafe fn run(
    image: r_efi::efi::Handle,
    table: *mut r_efi::efi::SystemTable,
) -> r_efi::efi::Status {
    let Some(table) = core::ptr::NonNull::new(table) else {
        return r_efi::efi::Status::INVALID_PARAMETER;
    };
    // SAFETY: The UEFI loader owns the supplied non-null system table.
    let table = unsafe { table.as_ref() };
    if table.hdr.signature != r_efi::efi::SYSTEM_TABLE_SIGNATURE
        || table.boot_services.is_null()
        || table.runtime_services.is_null()
    {
        return r_efi::efi::Status::INVALID_PARAMETER;
    }
    assert_eq!(table.hdr.signature, r_efi::efi::SYSTEM_TABLE_SIGNATURE);
    assert!(
        !table.boot_services.is_null(),
        "the boot table passed validation"
    );
    assert!(
        !table.runtime_services.is_null(),
        "the runtime table passed validation"
    );
    // SAFETY: The validated table is live in boot services.
    let boot = unsafe { &*table.boot_services };
    // SAFETY: The loader supplied the image and live boot table.
    let root = match unsafe { crate::adapter::filesystem::open_root(boot, image) } {
        Ok(root) => root,
        Err(status) => return status,
    };
    // SAFETY: open_root returned a live root owned by this application.
    let output = unsafe { crate::adapter::filesystem::open_report(root) };
    // SAFETY: The root is no longer needed. The child file has an independent handle.
    let close_root = unsafe { (root.as_ref().close)(root.as_ptr()) };
    if close_root != r_efi::efi::Status::SUCCESS {
        if let Ok(output) = output {
            // SAFETY: The child is independently owned and must close on this error path.
            let _ = unsafe { (output.as_ref().close)(output.as_ptr()) };
        }
        return close_root;
    }
    let output = match output {
        Ok(output) => output,
        Err(status) => return status,
    };
    let mut buffer = crate::report::Buffer::default();
    let initial = writeln!(
        buffer,
        "aspen-uma-probe/v1\nfirmware_updates=disabled\nstarted=true"
    );
    let result = if initial.is_err() {
        Err(r_efi::efi::Status::BAD_BUFFER_SIZE)
    } else {
        // SAFETY: The output handle is live and the report contains initialized bytes.
        unsafe { crate::adapter::filesystem::persist(output, &buffer) }.and_then(|()| {
            // SAFETY: The loader tables remain live. observe exposes only reads.
            unsafe { observe(table, &mut buffer) }
        })
    };
    let status = result.err().unwrap_or(r_efi::efi::Status::SUCCESS);
    let final_line = writeln!(
        buffer,
        "observation.status={:#x}\ncompleted=true",
        status.as_usize()
    );
    // SAFETY: The output remains open and has no other owner.
    let persisted = unsafe { crate::adapter::filesystem::persist(output, &buffer) };
    // SAFETY: This is the final use of the live output file handle.
    let closed = unsafe { (output.as_ref().close)(output.as_ptr()) };
    if final_line.is_err() {
        return r_efi::efi::Status::BAD_BUFFER_SIZE;
    }
    if let Err(error) = persisted {
        return error;
    }
    if closed != r_efi::efi::Status::SUCCESS {
        return closed;
    }
    // A rejected observation is an expected result, not a boot error.
    r_efi::efi::Status::SUCCESS
}

#[cfg(test)]
mod tests {
    #[test]
    fn accepts_exact_success() {
        assert_eq!(super::require_success(r_efi::efi::Status::SUCCESS), Ok(()));
    }

    #[test]
    fn preserves_errors_and_rejects_warnings() {
        assert_eq!(
            super::require_success(r_efi::efi::Status::DEVICE_ERROR),
            Err(r_efi::efi::Status::DEVICE_ERROR)
        );
        assert_eq!(
            super::require_success(r_efi::efi::Status::WARN_UNKNOWN_GLYPH),
            Err(r_efi::efi::Status::WARN_UNKNOWN_GLYPH)
        );
    }
}

//! The only persistent output is the dedicated report on this image's ESP.

const PATH_UNITS: usize = 80;
const REPORT_PATH: &str = "\\EFI\\OnixUMA\\probe.log";

/// # Safety
/// The image and boot table must remain live under the UEFI loader.
pub(super) unsafe fn open_root(
    boot: &r_efi::efi::BootServices,
    image: r_efi::efi::Handle,
) -> Result<core::ptr::NonNull<r_efi::protocols::file::Protocol>, r_efi::efi::Status> {
    if image.is_null() {
        return Err(r_efi::efi::Status::INVALID_PARAMETER);
    }
    assert!(!image.is_null(), "the loader supplied an image handle");
    let mut loaded = core::ptr::null_mut::<core::ffi::c_void>();
    let mut guid = r_efi::protocols::loaded_image::PROTOCOL_GUID;
    crate::adapter::require_success((boot.handle_protocol)(image, &mut guid, &mut loaded))?;
    let loaded = core::ptr::NonNull::new(loaded.cast::<r_efi::protocols::loaded_image::Protocol>())
        .ok_or(r_efi::efi::Status::NOT_FOUND)?;
    let mut filesystem = core::ptr::null_mut::<core::ffi::c_void>();
    guid = r_efi::protocols::simple_file_system::PROTOCOL_GUID;
    // SAFETY: HandleProtocol returned the live loaded-image interface.
    let device = unsafe { loaded.as_ref().device_handle };
    if device.is_null() {
        return Err(r_efi::efi::Status::NOT_FOUND);
    }
    assert!(
        !device.is_null(),
        "the image has a backing filesystem device"
    );
    crate::adapter::require_success((boot.handle_protocol)(device, &mut guid, &mut filesystem))?;
    let filesystem = core::ptr::NonNull::new(
        filesystem.cast::<r_efi::protocols::simple_file_system::Protocol>(),
    )
    .ok_or(r_efi::efi::Status::NOT_FOUND)?;
    let mut root = core::ptr::null_mut();
    // SAFETY: HandleProtocol returned the live filesystem interface.
    crate::adapter::require_success(unsafe {
        (filesystem.as_ref().open_volume)(filesystem.as_ptr(), &mut root)
    })?;
    core::ptr::NonNull::new(root).ok_or(r_efi::efi::Status::NOT_FOUND)
}

/// # Safety
/// The root must be a live handle owned by this application.
pub(super) unsafe fn open_report(
    root: core::ptr::NonNull<r_efi::protocols::file::Protocol>,
) -> Result<core::ptr::NonNull<r_efi::protocols::file::Protocol>, r_efi::efi::Status> {
    let mut path = crate::report::utf16::<PATH_UNITS>(REPORT_PATH)
        .map_err(|_| r_efi::efi::Status::BAD_BUFFER_SIZE)?;
    let mut output = core::ptr::null_mut();
    assert_eq!(
        path.last(),
        Some(&0),
        "the report path retains its terminator"
    );
    assert!(
        REPORT_PATH.starts_with('\\'),
        "the report path is rooted on this ESP"
    );
    // SAFETY: The root is live. This first open has read-only access.
    let existing = unsafe {
        (root.as_ref().open)(
            root.as_ptr(),
            &mut output,
            path.as_mut_ptr(),
            r_efi::protocols::file::MODE_READ,
            0,
        )
    };
    if existing == r_efi::efi::Status::SUCCESS {
        if let Some(handle) = core::ptr::NonNull::new(output) {
            // SAFETY: The successful open returned this independent file handle.
            crate::adapter::require_success(unsafe { (handle.as_ref().close)(handle.as_ptr()) })?;
        }
        return Err(r_efi::efi::Status::ACCESS_DENIED);
    }
    if existing != r_efi::efi::Status::NOT_FOUND {
        return Err(existing);
    }
    output = core::ptr::null_mut();
    let mode = r_efi::protocols::file::MODE_CREATE
        | r_efi::protocols::file::MODE_READ
        | r_efi::protocols::file::MODE_WRITE;
    // SAFETY: The root is live, the path is terminated, and the output is writable.
    crate::adapter::require_success(unsafe {
        (root.as_ref().open)(root.as_ptr(), &mut output, path.as_mut_ptr(), mode, 0)
    })?;
    core::ptr::NonNull::new(output).ok_or(r_efi::efi::Status::NOT_FOUND)
}

/// # Safety
/// The output must be the live report file with no concurrent cursor user.
pub(super) unsafe fn persist(
    output: core::ptr::NonNull<r_efi::protocols::file::Protocol>,
    buffer: &crate::report::Buffer,
) -> Result<(), r_efi::efi::Status> {
    // SAFETY: The caller owns this live file handle.
    let file = unsafe { output.as_ref() };
    crate::adapter::require_success((file.set_position)(output.as_ptr(), 0))?;
    let mut size_bytes = buffer.as_bytes().len();
    crate::adapter::require_success((file.write)(
        output.as_ptr(),
        &mut size_bytes,
        buffer.as_bytes().as_ptr().cast_mut().cast(),
    ))?;
    if size_bytes != buffer.as_bytes().len() {
        return Err(r_efi::efi::Status::DEVICE_ERROR);
    }
    assert_eq!(
        size_bytes,
        buffer.as_bytes().len(),
        "the report write is complete"
    );
    crate::adapter::require_success((file.flush)(output.as_ptr()))
}

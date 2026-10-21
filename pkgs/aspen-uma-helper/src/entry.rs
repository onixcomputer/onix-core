//! Panic recovery belongs to the UEFI process boundary, never to the core.

static IMAGE: core::sync::atomic::AtomicPtr<core::ffi::c_void> =
    core::sync::atomic::AtomicPtr::new(core::ptr::null_mut());
static TABLE: core::sync::atomic::AtomicPtr<r_efi::efi::SystemTable> =
    core::sync::atomic::AtomicPtr::new(core::ptr::null_mut());

/// # Safety
/// The UEFI loader must supply a live image handle and system table.
#[allow(
    tigerstyle::public_unsafe_api,
    reason = "UEFI entry owner: only the firmware loader can establish the raw handle and table lifetime"
)]
pub unsafe fn run(
    image: r_efi::efi::Handle,
    table: *mut r_efi::efi::SystemTable,
) -> r_efi::efi::Status {
    if image.is_null() || table.is_null() {
        return r_efi::efi::Status::INVALID_PARAMETER;
    }
    IMAGE.store(image, core::sync::atomic::Ordering::Release);
    TABLE.store(table, core::sync::atomic::Ordering::Release);
    // SAFETY: The loader supplied these live objects. The adapter validates the table.
    unsafe { crate::adapter::run(image, table) }
}

/// Return an unexpected panic to the parent image rather than wait indefinitely.
/// The terminal trap is reachable only if the firmware violates Exit's contract.
#[cfg(target_arch = "x86_64")]
pub fn abort_to_loader() -> ! {
    let table = TABLE.load(core::sync::atomic::Ordering::Acquire);
    let image = IMAGE.load(core::sync::atomic::Ordering::Acquire);
    if !table.is_null() && !image.is_null() {
        // SAFETY: Only the loader entry installs this context. It remains live for
        // the application's lifetime. Exit terminates this child image on success.
        unsafe {
            let boot = (*table).boot_services;
            if !boot.is_null() {
                ((*boot).exit)(image, r_efi::efi::Status::ABORTED, 0, core::ptr::null_mut());
            }
        }
    }
    // SAFETY: A broken loader cannot accept a normal return from a panic handler.
    // A terminal CPU exception is explicit and avoids an unbounded busy loop.
    unsafe {
        core::arch::asm!("ud2", options(noreturn));
    }
}

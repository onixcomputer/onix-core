#![cfg_attr(target_os = "uefi", no_std)]
#![cfg_attr(target_os = "uefi", no_main)]
#![feature(register_tool)]
#![register_tool(tigerstyle)]

#[cfg(not(target_os = "uefi"))]
fn main() {
    eprintln!("The probe runs only under UEFI.");
    std::process::exit(1);
}

#[cfg(target_os = "uefi")]
#[unsafe(no_mangle)]
/// # Safety
/// The firmware loader supplies the live image handle and system table.
#[allow(
    tigerstyle::public_unsafe_api,
    reason = "UEFI entry owner: the loader alone establishes the raw image and system-table lifetimes"
)]
pub unsafe extern "efiapi" fn efi_main(
    image: r_efi::efi::Handle,
    table: *mut r_efi::efi::SystemTable,
) -> r_efi::efi::Status {
    // SAFETY: This is the loader entry. The entry adapter validates the pointers.
    unsafe { aspen_uma_helper::entry::run(image, table) }
}

#[cfg(target_os = "uefi")]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo<'_>) -> ! {
    aspen_uma_helper::entry::abort_to_loader()
}

#[cfg(test)]
mod tests {
    unsafe extern "efiapi" fn getter(
        this: *mut core::ffi::c_void,
        purpose: *mut u8,
        token: u32,
        value: *mut u8,
    ) -> r_efi::efi::Status {
        assert!(!this.is_null());
        assert!(!purpose.is_null());
        assert!(!value.is_null());
        if token != aspen_uma_helper::domain::LEVEL_TOKEN {
            return r_efi::efi::Status::NOT_FOUND;
        }
        // SAFETY: The wrapper passes live writable bytes and the test verifies both pointers.
        unsafe {
            *purpose = aspen_uma_helper::domain::BIOS_PURPOSE;
            *value = aspen_uma_helper::domain::MINIMUM_LEVEL;
        }
        r_efi::efi::Status::SUCCESS
    }

    unsafe extern "efiapi" fn rejected(
        _this: *mut core::ffi::c_void,
        purpose: *mut u8,
        _token: u32,
        value: *mut u8,
    ) -> r_efi::efi::Status {
        // SAFETY: The wrapper supplies both initialized, writable outputs.
        unsafe {
            *purpose = u8::MAX;
            *value = u8::MAX;
        }
        r_efi::efi::Status::ABORTED
    }

    const fn protocol(
        getter: Option<aspen_uma_helper::apcb::Get8>,
    ) -> aspen_uma_helper::apcb::ReadProtocol {
        aspen_uma_helper::apcb::ReadProtocol {
            revision_word: aspen_uma_helper::domain::APCB_REVISION_WORD,
            opaque: [0; aspen_uma_helper::apcb::OPAQUE_METHOD_WORDS],
            get8: getter,
        }
    }

    #[test]
    fn binary_layout_matches_the_exact_x64_method_offset() {
        assert_eq!(
            core::mem::offset_of!(aspen_uma_helper::apcb::ReadProtocol, get8),
            aspen_uma_helper::apcb::GET8_OFFSET
        );
        assert_eq!(
            core::mem::size_of::<aspen_uma_helper::apcb::ReadProtocol>(),
            aspen_uma_helper::apcb::GET8_OFFSET
                .checked_add(core::mem::size_of::<aspen_uma_helper::apcb::Get8>())
                .expect("the interface size fits")
        );
    }

    #[test]
    fn passes_valid_output_pointers_and_preserves_a_zero_value() {
        let mut interface = protocol(Some(getter));
        // SAFETY: The fake has the exact layout and a valid Microsoft x64 getter.
        let sample = unsafe {
            aspen_uma_helper::apcb::get8(
                core::ptr::NonNull::from(&mut interface),
                aspen_uma_helper::domain::LEVEL_TOKEN,
            )
        };
        assert_eq!(
            sample,
            Ok(aspen_uma_helper::domain::TokenSample {
                purpose: aspen_uma_helper::domain::BIOS_PURPOSE,
                value: aspen_uma_helper::domain::MINIMUM_LEVEL
            })
        );
    }

    #[test]
    fn rejects_missing_method_and_unsupported_revision_before_call() {
        let mut interface = protocol(None);
        assert_eq!(
            // SAFETY: The complete fake interface remains live throughout the call.
            unsafe {
                aspen_uma_helper::apcb::get8(
                    core::ptr::NonNull::from(&mut interface),
                    aspen_uma_helper::domain::LEVEL_TOKEN,
                )
            },
            Err(r_efi::efi::Status::UNSUPPORTED)
        );
        interface.revision_word = aspen_uma_helper::domain::APCB_REVISION_WORD
            .checked_add(1)
            .expect("the revision has a successor");
        assert_eq!(
            // SAFETY: The complete fake interface remains live throughout the call.
            unsafe {
                aspen_uma_helper::apcb::get8(
                    core::ptr::NonNull::from(&mut interface),
                    aspen_uma_helper::domain::LEVEL_TOKEN,
                )
            },
            Err(r_efi::efi::Status::INCOMPATIBLE_VERSION)
        );
    }

    #[test]
    fn does_not_interpret_outputs_after_firmware_denial() {
        let mut interface = protocol(Some(rejected));
        assert_eq!(
            // SAFETY: The fake implements the exact ABI and writes only the output bytes.
            unsafe {
                aspen_uma_helper::apcb::get8(
                    core::ptr::NonNull::from(&mut interface),
                    aspen_uma_helper::domain::LEVEL_TOKEN,
                )
            },
            Err(r_efi::efi::Status::ABORTED)
        );
    }

    #[test]
    fn preserves_not_found_as_an_error_not_a_zero_token() {
        let mut interface = protocol(Some(getter));
        assert_eq!(
            // SAFETY: The fake is live and the getter rejects this distinct token.
            unsafe {
                aspen_uma_helper::apcb::get8(
                    core::ptr::NonNull::from(&mut interface),
                    aspen_uma_helper::domain::MODE_TOKEN,
                )
            },
            Err(r_efi::efi::Status::NOT_FOUND)
        );
    }
}

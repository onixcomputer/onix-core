#[cfg(test)]
mod tests {
    const ATTRIBUTE_HEADER_BYTES: usize = 4;
    const CUSTOM_SIZE_BYTES: usize = core::mem::size_of::<u32>();

    const fn oem_payload() -> [u8; aspen_uma_helper::domain::OEM_PAYLOAD_BYTES] {
        let mut bytes = [0; aspen_uma_helper::domain::OEM_PAYLOAD_BYTES];
        bytes[aspen_uma_helper::domain::OEM_LAYOUT.mode] = aspen_uma_helper::domain::AUTO_MODE;
        bytes[aspen_uma_helper::domain::OEM_LAYOUT.level] = aspen_uma_helper::domain::HIGH_LEVEL;
        let custom_mib = aspen_uma_helper::domain::MINIMUM_MIB.to_le_bytes();
        let mut index = 0;
        while index < CUSTOM_SIZE_BYTES {
            let offset_bytes = aspen_uma_helper::domain::OEM_LAYOUT
                .custom_mib
                .checked_add(index)
                .expect("the fixture offset fits");
            bytes[offset_bytes] = custom_mib[index];
            index += 1;
        }
        bytes
    }

    const fn snapshot(level: u8) -> aspen_uma_helper::domain::UmaSnapshot {
        aspen_uma_helper::domain::UmaSnapshot {
            mode: aspen_uma_helper::domain::AUTO_MODE,
            level,
            custom_mib: aspen_uma_helper::domain::MINIMUM_MIB,
        }
    }

    const fn sample(value: u8) -> aspen_uma_helper::domain::TokenSample {
        aspen_uma_helper::domain::TokenSample {
            purpose: aspen_uma_helper::domain::BIOS_PURPOSE,
            value,
        }
    }

    #[test]
    fn accepts_oem_payload_without_linux_attribute_header() {
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &oem_payload(),
                aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Ok(snapshot(aspen_uma_helper::domain::HIGH_LEVEL))
        );
    }

    #[test]
    fn accepts_amd_auto_sentinel_without_treating_it_as_reserved_memory() {
        let mut bytes = [0; aspen_uma_helper::domain::AMD_PAYLOAD_BYTES];
        bytes[aspen_uma_helper::domain::AMD_LAYOUT.mode] = aspen_uma_helper::domain::AUTO_MODE;
        bytes[aspen_uma_helper::domain::AMD_LAYOUT.level] = aspen_uma_helper::domain::HIGH_LEVEL;
        bytes[aspen_uma_helper::domain::AMD_LAYOUT.custom_mib
            ..aspen_uma_helper::domain::AMD_LAYOUT
                .custom_mib
                .checked_add(CUSTOM_SIZE_BYTES)
                .expect("the fixture field fits")]
            .copy_from_slice(&aspen_uma_helper::domain::AUTO_SIZE_SENTINEL.to_le_bytes());
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &bytes,
                aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                aspen_uma_helper::domain::AMD_LAYOUT
            ),
            Ok(aspen_uma_helper::domain::UmaSnapshot {
                mode: aspen_uma_helper::domain::AUTO_MODE,
                level: aspen_uma_helper::domain::HIGH_LEVEL,
                custom_mib: aspen_uma_helper::domain::AUTO_SIZE_SENTINEL,
            })
        );
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &bytes,
                aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Err(aspen_uma_helper::domain::DecodeError::Size)
        );
    }

    #[test]
    fn rejects_empty_short_and_header_prefixed_payloads() {
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &[],
                aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Err(aspen_uma_helper::domain::DecodeError::Size)
        );
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &[0; aspen_uma_helper::domain::OEM_PAYLOAD_BYTES
                    .checked_sub(1)
                    .expect("the fixture is nonempty")],
                aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Err(aspen_uma_helper::domain::DecodeError::Size)
        );
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &[0; aspen_uma_helper::domain::OEM_PAYLOAD_BYTES
                    .checked_add(ATTRIBUTE_HEADER_BYTES)
                    .expect("the fixture size fits")],
                aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Err(aspen_uma_helper::domain::DecodeError::Size)
        );
    }

    #[test]
    fn rejects_zero_filled_copy_and_wrong_attributes() {
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &[0; aspen_uma_helper::domain::OEM_PAYLOAD_BYTES],
                aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Err(aspen_uma_helper::domain::DecodeError::Mode)
        );
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &oem_payload(),
                0,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Err(aspen_uma_helper::domain::DecodeError::Attributes)
        );
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &oem_payload(),
                u32::MAX,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Err(aspen_uma_helper::domain::DecodeError::Attributes)
        );
    }

    #[test]
    fn rejects_unknown_mode_and_level() {
        let mut bytes = oem_payload();
        bytes[aspen_uma_helper::domain::OEM_LAYOUT.mode] = u8::MAX;
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &bytes,
                aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Err(aspen_uma_helper::domain::DecodeError::Mode)
        );
        bytes[aspen_uma_helper::domain::OEM_LAYOUT.mode] = aspen_uma_helper::domain::AUTO_MODE;
        bytes[aspen_uma_helper::domain::OEM_LAYOUT.level] = aspen_uma_helper::domain::HIGH_LEVEL
            .checked_add(1)
            .expect("the level has a successor");
        assert_eq!(
            aspen_uma_helper::domain::decode(
                &bytes,
                aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                aspen_uma_helper::domain::OEM_LAYOUT
            ),
            Err(aspen_uma_helper::domain::DecodeError::Level)
        );
    }

    #[test]
    fn rejects_out_of_range_and_overflowing_layouts_without_panicking() {
        for layout in [
            aspen_uma_helper::domain::Layout {
                mode: usize::MAX,
                ..aspen_uma_helper::domain::OEM_LAYOUT
            },
            aspen_uma_helper::domain::Layout {
                level: usize::MAX,
                ..aspen_uma_helper::domain::OEM_LAYOUT
            },
            aspen_uma_helper::domain::Layout {
                custom_mib: usize::MAX,
                ..aspen_uma_helper::domain::OEM_LAYOUT
            },
            aspen_uma_helper::domain::Layout {
                custom_mib: aspen_uma_helper::domain::OEM_PAYLOAD_BYTES
                    .checked_sub(1)
                    .expect("the fixture is nonempty"),
                ..aspen_uma_helper::domain::OEM_LAYOUT
            },
        ] {
            assert_eq!(
                aspen_uma_helper::domain::decode(
                    &oem_payload(),
                    aspen_uma_helper::domain::VARIABLE_ATTRIBUTES,
                    layout
                ),
                Err(aspen_uma_helper::domain::DecodeError::Offset)
            );
        }
    }

    #[test]
    fn agrees_on_high_or_minimum_without_authorizing_an_effect() {
        for (level, expected) in [
            (
                aspen_uma_helper::domain::HIGH_LEVEL,
                aspen_uma_helper::domain::ProbeVerdict::HighObserved,
            ),
            (
                aspen_uma_helper::domain::MINIMUM_LEVEL,
                aspen_uma_helper::domain::ProbeVerdict::MinimumObserved,
            ),
        ] {
            assert_eq!(
                aspen_uma_helper::domain::assess(
                    aspen_uma_helper::domain::APCB_REVISION_WORD,
                    snapshot(level),
                    snapshot(level),
                    sample(aspen_uma_helper::domain::AUTO_MODE),
                    sample(level)
                ),
                expected
            );
        }
    }

    #[test]
    fn rejects_a_different_revision_or_token_purpose() {
        assert_eq!(
            aspen_uma_helper::domain::assess(
                aspen_uma_helper::domain::APCB_REVISION_WORD
                    .checked_add(1)
                    .expect("the revision has a successor"),
                snapshot(aspen_uma_helper::domain::HIGH_LEVEL),
                snapshot(aspen_uma_helper::domain::HIGH_LEVEL),
                sample(aspen_uma_helper::domain::AUTO_MODE),
                sample(aspen_uma_helper::domain::HIGH_LEVEL)
            ),
            aspen_uma_helper::domain::ProbeVerdict::UnsupportedRevision
        );
        let different = aspen_uma_helper::domain::TokenSample {
            purpose: aspen_uma_helper::domain::BIOS_PURPOSE
                .checked_add(1)
                .expect("the purpose has a successor"),
            value: aspen_uma_helper::domain::HIGH_LEVEL,
        };
        assert_eq!(
            aspen_uma_helper::domain::assess(
                aspen_uma_helper::domain::APCB_REVISION_WORD,
                snapshot(aspen_uma_helper::domain::HIGH_LEVEL),
                snapshot(aspen_uma_helper::domain::HIGH_LEVEL),
                sample(aspen_uma_helper::domain::AUTO_MODE),
                different
            ),
            aspen_uma_helper::domain::ProbeVerdict::DifferentPurpose
        );
    }

    #[test]
    fn rejects_disagreement_custom_mode_and_medium_level() {
        assert_eq!(
            aspen_uma_helper::domain::assess(
                aspen_uma_helper::domain::APCB_REVISION_WORD,
                snapshot(aspen_uma_helper::domain::HIGH_LEVEL),
                snapshot(aspen_uma_helper::domain::MINIMUM_LEVEL),
                sample(aspen_uma_helper::domain::AUTO_MODE),
                sample(aspen_uma_helper::domain::HIGH_LEVEL)
            ),
            aspen_uma_helper::domain::ProbeVerdict::Inconsistent
        );
        assert_eq!(
            aspen_uma_helper::domain::assess(
                aspen_uma_helper::domain::APCB_REVISION_WORD,
                snapshot(aspen_uma_helper::domain::HIGH_LEVEL),
                snapshot(aspen_uma_helper::domain::HIGH_LEVEL),
                sample(aspen_uma_helper::domain::CUSTOM_MODE),
                sample(aspen_uma_helper::domain::HIGH_LEVEL)
            ),
            aspen_uma_helper::domain::ProbeVerdict::Inconsistent
        );
        assert_eq!(
            aspen_uma_helper::domain::assess(
                aspen_uma_helper::domain::APCB_REVISION_WORD,
                snapshot(aspen_uma_helper::domain::MEDIUM_LEVEL),
                snapshot(aspen_uma_helper::domain::MEDIUM_LEVEL),
                sample(aspen_uma_helper::domain::AUTO_MODE),
                sample(aspen_uma_helper::domain::MEDIUM_LEVEL)
            ),
            aspen_uma_helper::domain::ProbeVerdict::Inconsistent
        );
    }
}

#[cfg(test)]
mod tests {
    use core::fmt::Write;

    const TEXT_CAPACITY: usize = 8;

    #[test]
    fn encodes_text_and_a_terminated_ascii_path() {
        let mut buffer = aspen_uma_helper::report::Buffer::default();
        assert!(writeln!(buffer, "completed=true").is_ok());
        assert_eq!(buffer.as_bytes(), b"completed=true\n");
        let path = aspen_uma_helper::report::utf16::<TEXT_CAPACITY>("EFI")
            .expect("the fixed fixture fits");
        assert_eq!(
            path,
            [
                u16::from(b'E'),
                u16::from(b'F'),
                u16::from(b'I'),
                0,
                0,
                0,
                0,
                0
            ]
        );
    }

    #[test]
    fn rejects_overflow_without_partial_report_mutation() {
        let mut buffer = aspen_uma_helper::report::Buffer::default();
        let full = "x".repeat(aspen_uma_helper::report::REPORT_BYTES);
        assert!(buffer.write_str(&full).is_ok());
        assert!(buffer.write_str("y").is_err());
        assert_eq!(buffer.as_bytes(), full.as_bytes());
    }

    #[test]
    fn rejects_non_ascii_embedded_null_and_unterminated_capacity() {
        assert!(aspen_uma_helper::report::utf16::<TEXT_CAPACITY>("é").is_err());
        assert!(aspen_uma_helper::report::utf16::<TEXT_CAPACITY>("E\0FI").is_err());
        assert!(
            aspen_uma_helper::report::utf16::<TEXT_CAPACITY>(&"x".repeat(TEXT_CAPACITY)).is_err()
        );
        assert!(aspen_uma_helper::report::utf16::<0>("").is_err());
    }
}

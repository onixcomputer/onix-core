//! Bounded report encoding for the imperative shell. No heap allocation occurs.

pub const REPORT_BYTES: usize = 4096;

pub struct Buffer {
    bytes: [u8; REPORT_BYTES],
    used_bytes: usize,
}

impl Default for Buffer {
    fn default() -> Self {
        Self {
            bytes: [0; REPORT_BYTES],
            used_bytes: 0,
        }
    }
}

impl Buffer {
    pub fn as_bytes(&self) -> &[u8] {
        assert!(
            self.used_bytes <= REPORT_BYTES,
            "the report remains within its capacity"
        );
        &self.bytes[..self.used_bytes]
    }
}

impl core::fmt::Write for Buffer {
    fn write_str(&mut self, text: &str) -> core::fmt::Result {
        let end = self
            .used_bytes
            .checked_add(text.len())
            .ok_or(core::fmt::Error)?;
        let destination = self
            .bytes
            .get_mut(self.used_bytes..end)
            .ok_or(core::fmt::Error)?;
        destination.copy_from_slice(text.as_bytes());
        self.used_bytes = end;
        Ok(())
    }
}

pub fn utf16<const N: usize>(text: &str) -> Result<[u16; N], core::fmt::Error> {
    if !text.is_ascii() || text.as_bytes().contains(&0) || text.len() >= N {
        return Err(core::fmt::Error);
    }
    let mut output = [0; N];
    for (destination, source) in output.iter_mut().zip(text.bytes()) {
        *destination = u16::from(source);
    }
    Ok(output)
}

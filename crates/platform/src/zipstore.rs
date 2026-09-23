//! Stored-only zip files. Enough for a game package, not a general archive tool.

use std::io::{self, Write};

pub fn write_stored(files: &[(&str, &[u8])]) -> io::Result<Vec<u8>> {
    let mut body = Vec::new();
    let mut directory = Vec::new();
    for (name, data) in files {
        if name.is_empty() || name.contains('\\') || name.split('/').any(|part| part == "..") {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "unsafe zip path",
            ));
        }
        let crc = crc32(data);
        let offset = body.len() as u32;
        write_header(&mut body, name, data, crc)?;
        directory.extend_from_slice(&central(name, data, crc, offset));
    }
    let directory_start = body.len() as u32;
    body.extend_from_slice(&directory);
    body.extend_from_slice(&end_of_directory(
        files.len() as u16,
        directory.len() as u32,
        directory_start,
    ));
    Ok(body)
}

pub fn extract_stored(
    bytes: &[u8],
    mut write: impl FnMut(&str, &[u8]) -> io::Result<()>,
) -> io::Result<()> {
    let mut index = 0;
    while index + 30 <= bytes.len() && bytes[index..index + 4] == [0x50, 0x4b, 0x03, 0x04] {
        let method = u16_at(bytes, index + 8);
        let compressed = u32_at(bytes, index + 18) as usize;
        let name_len = u16_at(bytes, index + 26) as usize;
        let extra_len = u16_at(bytes, index + 28) as usize;
        let name_at = index + 30;
        let data_at = name_at + name_len + extra_len;
        if method != 0 || data_at + compressed > bytes.len() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "unsupported zip",
            ));
        }
        let name = std::str::from_utf8(&bytes[name_at..name_at + name_len])
            .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "zip name"))?;
        if name
            .split('/')
            .any(|part| part.is_empty() || part == "." || part == "..")
        {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "unsafe zip path",
            ));
        }
        write(name, &bytes[data_at..data_at + compressed])?;
        index = data_at + compressed;
    }
    Ok(())
}

fn write_header(out: &mut Vec<u8>, name: &str, data: &[u8], crc: u32) -> io::Result<()> {
    out.write_all(&0x04034b50u32.to_le_bytes())?;
    out.write_all(&20u16.to_le_bytes())?;
    out.write_all(&0u16.to_le_bytes())?;
    out.write_all(&0u16.to_le_bytes())?;
    out.write_all(&[0, 0, 0, 0])?;
    out.write_all(&crc.to_le_bytes())?;
    out.write_all(&(data.len() as u32).to_le_bytes())?;
    out.write_all(&(data.len() as u32).to_le_bytes())?;
    out.write_all(&(name.len() as u16).to_le_bytes())?;
    out.write_all(&0u16.to_le_bytes())?;
    out.write_all(name.as_bytes())?;
    out.write_all(data)?;
    Ok(())
}

fn central(name: &str, data: &[u8], crc: u32, offset: u32) -> Vec<u8> {
    let mut out = Vec::new();
    out.extend_from_slice(&0x02014b50u32.to_le_bytes());
    out.extend_from_slice(&20u16.to_le_bytes());
    out.extend_from_slice(&20u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&[0, 0, 0, 0]);
    out.extend_from_slice(&crc.to_le_bytes());
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(&(name.len() as u16).to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u32.to_le_bytes());
    out.extend_from_slice(&offset.to_le_bytes());
    out.extend_from_slice(name.as_bytes());
    out
}

fn end_of_directory(count: u16, size: u32, offset: u32) -> [u8; 22] {
    let mut out = [0; 22];
    out[0..4].copy_from_slice(&0x06054b50u32.to_le_bytes());
    out[8..10].copy_from_slice(&count.to_le_bytes());
    out[10..12].copy_from_slice(&count.to_le_bytes());
    out[12..16].copy_from_slice(&size.to_le_bytes());
    out[16..20].copy_from_slice(&offset.to_le_bytes());
    out
}

fn u16_at(bytes: &[u8], index: usize) -> u16 {
    u16::from_le_bytes([bytes[index], bytes[index + 1]])
}

fn u32_at(bytes: &[u8], index: usize) -> u32 {
    u32::from_le_bytes([
        bytes[index],
        bytes[index + 1],
        bytes[index + 2],
        bytes[index + 3],
    ])
}

fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xffff_ffffu32;
    for byte in data {
        crc ^= u32::from(*byte);
        for _ in 0..8 {
            let mask = 0u32.wrapping_sub(crc & 1);
            crc = (crc >> 1) ^ (0xedb8_8320 & mask);
        }
    }
    !crc
}

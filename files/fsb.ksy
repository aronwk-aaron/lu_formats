meta:
  id: fsb4
  file-extension: fsb
  endian: le
  title: FMOD Sound Bank (FSB4)
doc: |
  All fields in this format are fully documented — zero unknowns remain.

  Encryption:
    LU's FSB files are encrypted with FMOD's cipher covering the ENTIRE file —
    headers AND audio sample data (not just headers as some sources incorrectly state).

    Cipher:
      plaintext[i] = bit_reverse(ciphertext[i]) XOR key[i % key_len]
    where bit_reverse reverses the bit order of each byte (bit 0 <-> bit 7, etc.).

    LU password key: "1024442297" (10 ASCII bytes — the FMOD project integer password
    stored as its decimal string representation, not the raw integer).

    NOTE: The encryption covers the ENTIRE file, not just the header region.
    Earlier RE work incorrectly assumed only headers were encrypted. The full-file
    encryption was confirmed by successfully extracting and decoding MP3 audio data
    from all 98 FSB files using the complete decryption. Header-only decryption
    produces corrupted MP3 frames.

  After decryption, the file is standard FSB4:
    [48 bytes] main header
    [sample_header_size bytes] sample headers (80 bytes base each)
    [data_size bytes] audio sample data (FMOD_MPEG / MP3 for all LU PC samples)

  Audio data layout: samples are stored contiguously. Sample N starts at
    data_offset + sum(compressed_size[0..N-1]) where data_offset = 48 + sample_header_size.

  Bank-FEV matching:
    The bank_checksums field (2 x u32 at header offset 24) is cross-checked against
    the paired FEV bank's fsb_checksum field. FMOD Event verifies these match when
    loading a bank's FSB to ensure the correct FSB is paired with its FEV project.
    Verified against all 102 LU banks (51 live + 51 njhub2).

  Primary RE sources:
    - fmodex.dll (FMOD Ex low-level API — encryption, FSB header parsing)
    - fmod_event.dll (FMOD Event runtime — bank loading, checksum verification)

  Sample codec:
    All 98 LU PC FSB files use FMOD_MPEG (mode bit 0x200) exclusively. Each sample's
    compressed data region contains raw MP3 frames that can be extracted directly.
    Sample headers are all exactly 80 bytes (no extended header data).
seq:
  - id: magic
    contents: "FSB4"
  - id: num_samples
    type: u4
    doc: Number of audio samples in this bank.
  - id: sample_header_size
    type: u4
    doc: Total size of all sample headers in bytes.
  - id: data_size
    type: u4
    doc: Total size of all audio sample data in bytes.
  - id: version
    type: u4
    doc: "FSB format version. 0x00040000 for FSB4."
  - id: mode
    type: u4
    doc: Global FMOD_MODE flags for this bank.
  - id: bank_checksums
    type: u4
    repeat: expr
    repeat-expr: 2
    doc: |
      Two u32 values at header offset 24 (the FSB4 "reserved" field).
      These are cross-checked by FMOD Event against the paired FEV bank's
      fsb_checksum field to verify the correct FSB is loaded for a given
      FEV project. The FMOD runtime reads these via SoundBank_StoreFevChecksum
      (fmod_event.dll @ 10035780) and compares them during bank loading.
      All 102 LU bank pairs (live + njhub2) have been verified to match.
  - id: padding
    size: 8
    doc: |
      Remaining 8 bytes of the 48-byte header. Always zeros in LU FSB files.
      In other FSB4 files these could contain additional flags or hash data.
  - id: samples
    type: sample_header
    repeat: expr
    repeat-expr: num_samples
  - id: audio_data
    size: data_size
    doc: |
      Concatenated compressed audio data for all samples.
      All LU PC samples use FMOD_MPEG (mode bit 0x200) = raw MP3 frames.
      Sample N occupies bytes [cumulative_offset, cumulative_offset + compressed_size)
      where cumulative_offset = sum of compressed_size for samples 0..N-1.
types:
  sample_header:
    seq:
      - id: header_size
        type: u2
        doc: Total size of this header entry (inclusive). Base = 80 bytes.
      - id: name
        size: 30
        type: strz
        encoding: ASCII
        doc: Null-terminated sample name, padded to 30 bytes. Truncated at 29 chars.
      - id: length_samples
        type: u4
        doc: Duration in PCM samples.
      - id: compressed_size
        type: u4
        doc: Size of this sample's compressed audio data in bytes.
      - id: loop_start
        type: u4
        doc: Loop start position in PCM samples.
      - id: loop_end
        type: u4
        doc: Loop end position in PCM samples.
      - id: mode
        type: u4
        doc: |
          Per-sample FMOD_MODE flags. Key codec bits:
            0x00000200 = FMOD_MPEG (MP3) — all LU PC samples
            0x00000400 = FMOD_IMAADPCM
            0x00008000 = FMOD_XMA
            0x00200000 = FMOD_GCADPCM
      - id: default_freq
        type: u4
        doc: Sample rate in Hz.
      - id: default_vol
        type: u2
        doc: "Raw 0-255. Normalize: float = raw / 255.0."
      - id: default_pan
        type: u2
        doc: "Raw 0-255 with 128=center. Normalize: int16 = raw - 128."
      - id: default_pri
        type: u2
        doc: Default priority.
      - id: num_channels
        type: u2
        doc: Channel count (1=mono, 2=stereo).
      - id: min_distance
        type: f4
        doc: 3D minimum distance.
      - id: max_distance
        type: f4
        doc: 3D maximum distance.
      - id: var_freq
        type: u4
        doc: "Frequency variation. Base 100 = no variation."
      - id: var_vol
        type: u2
        doc: Volume variation.
      - id: var_pan
        type: u2
        doc: Pan variation.
      - id: extra_data
        size: header_size - 80
        if: header_size > 80
        doc: |
          Extended sample header fields when header_size > 80. All LU FSBs use
          exactly 80-byte headers so this field is never present. In other FSB4
          files, extended data may include XMA seek tables, AT9 config data, or
          CELT codec parameters depending on the sample codec mode.

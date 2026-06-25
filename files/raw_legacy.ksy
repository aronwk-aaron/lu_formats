meta:
  id: raw_legacy
  file-extension: raw
  endian: le
doc: >
  LEGO Universe legacy .raw terrain file format (zone LUZ version < 30).

  This format has no file header — the zone's LUZ file version determines
  the field layout. It uses a single flat grid instead of chunks.
  No known .raw files use this format in any shipped client.

  The `map_version` parameter must be provided externally (from the
  zone's LUZ file version). The client's `OpenTerrain` (0x01048080)
  calls four functions in sequence, each gated on map_version.

  See `raw.ksy` for the chunked format used by LUZ version >= 30.
params:
  - id: map_version
    type: u4
seq:
  # --- Heightmap (FUN_01013db0) ---
  - id: width
    type: u4
    if: map_version >= 11
  - id: height
    type: u4
    if: map_version >= 11
  - id: scale
    type: f4
    if: map_version >= 12
    doc: Heightmap scale factor; v<12 uses hardcoded 3.0
  - id: height_map_u16
    type: u2
    repeat: expr
    repeat-expr: total_cells
    if: map_version < 4
    doc: v<4 u16 heights, scaled to float by multiplying with scale
  - id: height_map_f32
    type: f4
    repeat: expr
    repeat-expr: total_cells
    if: map_version >= 4
    doc: >
      v4+ f32 heights. v4-10 are pre-scaled (multiply by scale factor
      at load time); v11+ are already in world units.

  # --- Color map (FUN_01013880) ---
  - id: color_map_argb
    type: u4
    repeat: expr
    repeat-expr: total_cells
    if: map_version == 3
    doc: v3 packed ARGB color per cell
  - id: color_map_float_rgba
    type: f4
    repeat: expr
    repeat-expr: total_cells * 4
    if: map_version >= 4 and map_version < 11
    doc: >
      v4-10 float RGBA per cell (4 floats each).
      v4-7 values are scaled by a constant at load time;
      v8-10 are used directly.
  - id: color_map_bytes
    size: total_cells * 4
    if: map_version >= 11
    doc: v11+ RGBA bytes per cell (4 bytes each)
  - id: uv_coords
    type: f4
    repeat: expr
    repeat-expr: total_cells * 2
    if: map_version >= 4
    doc: v4+ UV coordinates per cell (2 floats each)

  # --- Texture/material (FUN_01013640) ---
  - id: material_ids
    type: u4
    repeat: expr
    repeat-expr: total_cells
    if: map_version >= 6 and map_version < 10
    doc: v6-9 material ID per cell
  - id: material_structs
    size: 20
    repeat: expr
    repeat-expr: total_cells
    if: map_version >= 10
    doc: >
      v10+ material struct per cell (20 bytes):
      u1 materialId, f32 blendWeight, 3x f32 blend weights

  # --- Scene map (FUN_01013550) ---
  - id: scene_palette
    size: 1024
    if: map_version >= 20
    doc: v20+ scene palette/header (1024 bytes, usage unknown)
  - id: scene_map
    size: total_cells
    if: map_version >= 20
    doc: v20+ u1 scene ID per cell
instances:
  default_width:
    value: 1280
  default_height:
    value: 1280
  actual_width:
    value: 'map_version >= 11 ? width : default_width'
  actual_height:
    value: 'map_version >= 11 ? height : default_height'
  total_cells:
    value: actual_width * actual_height

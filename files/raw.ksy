meta:
  id: raw
  file-extension: raw
  endian: le
  imports:
    - ../common/common
doc: >
  LEGO Universe .raw terrain file format (chunked, version >= 30).

  There are two distinct formats sharing the .raw extension:

  1. **Chunked format** (zone LUZ version >= 30): Self-describing with a
     u16 version + u1 dev header, followed by chunked terrain data.
     This is the format described here. File versions 31 and 32 exist.

  2. **Legacy flat-grid format** (zone LUZ version < 30): No file header.
     See `raw_legacy.ksy` for that format.

  The client's `OpenTerrain` function (0x01048080) selects the reader:
    mapVersion < 30 → legacy flat-grid reader
    mapVersion >= 30 → `ReadNewTerrainFormat` (chunked reader)
seq:
  - id: version
    type: u2
  - id: dev
    type: u1
    doc: Must be 0 for valid terrain data; non-zero aborts loading
  - id: num_chunks
    type: u4
    if: dev == 0
  - id: num_chunks_width
    type: u4
    if: dev == 0
  - id: num_chunks_height
    type: u4
    if: dev == 0
  - id: chunks
    type: chunk
    repeat: expr
    repeat-expr: num_chunks
    if: dev == 0
types:
  chunk:
    seq:
      - id: id
        type: u4
      - id: width
        type: u4
      - id: height
        type: u4
      - id: offset_world_x
        type: f4
      - id: offset_world_z
        type: f4
      - id: shader_id
        type: u4
        if: _root.version < 32
      - id: texture_ids
        type: u4
        repeat: expr
        repeat-expr: 4
      - id: scale
        type: f4
        doc: Heightmap scale factor, used to transform grid coords to world coords
      - id: height_map
        type: f4
        repeat: expr
        repeat-expr: width * height
      - id: color_map_resolution
        type: u4
        if: _root.version >= 32
        doc: Resolution of the color/diffuse map
      - id: color_map_pixels
        size: color_map_resolution * color_map_resolution * 4
        if: _root.version >= 32
        doc: RGBA color map pixels (raw block)
      - id: color_map_pixels_legacy
        size: width * width * 4
        if: _root.version < 32
        doc: >
          v<32 color map. Client reads width*width pixels (4 bytes each)
          with per-pixel BGRA byte swizzle. colorMapResolution = width - 1;
          only the inner (width-1)^2 pixels are used.
      - id: diffuse_map_dds_size
        type: u4
        if: _root.version >= 32
      - id: diffuse_map_dds
        size: diffuse_map_dds_size
        if: _root.version >= 32
        doc: DDS texture data for diffuse/light map
      - id: blend_res
        type: u4
      - id: blend_pixels
        size: blend_res * blend_res * 4
        doc: >
          Blend/texture map pixels. v>=32 reads as raw RGBA block;
          v<32 reads per-pixel as B,G,R,A (byte-swizzled).
      - id: blend_channel_mask
        type: u1
        if: _root.version >= 32
        doc: Bitmask of active detail textures (bits 0-3)
      - id: blend_map_dds_size
        type: u4
        if: _root.version >= 32
      - id: blend_map_dds
        size: blend_map_dds_size
        if: _root.version >= 32
        doc: DDS texture data for blend map (DXT5)
      - id: num_flairs
        type: u4
      - id: flairs
        type: flair_attributes
        repeat: expr
        repeat-expr: num_flairs
      - id: scene_map
        size: color_map_resolution * color_map_resolution
        if: _root.version >= 32
        doc: Per-pixel scene ID assignment, indexes into LUZ scene list
      - id: scene_map_v31
        size: width * width
        if: _root.version == 31
        doc: >
          v31 scene map. Allocates (colorMapRes+1)^2 where colorMapRes=width-1.
          Client reads (colorMapRes+1)^2 cells; inner colorMapRes^2 cells
          contain scene IDs, border cells are skipped/discarded.
      - id: scene_map_skip
        size: 1
        if: _root.version < 31
        doc: v<31 skips 1 byte; scene map is zero-filled by client
      - id: vert_size
        type: u4
        if: _root.version >= 32
      - id: mesh_vert_usage
        type: u2
        repeat: expr
        repeat-expr: vert_size
        if: _root.version >= 32 and vert_size != 0
      - id: mesh_vert_size
        type: u2
        repeat: expr
        repeat-expr: 16
        if: _root.version >= 32 and vert_size != 0
      - id: mesh_tri
        type: mesh_tri
        repeat: expr
        repeat-expr: 16
        if: _root.version >= 32 and vert_size != 0

  flair_attributes:
    seq:
      - id: id
        type: u4
      - id: scale_factor
        type: f4
      - id: pos
        type: common::vector3
      - id: rot
        type: common::vector3
      - id: color_r
        type: u1
      - id: color_g
        type: u1
      - id: color_b
        type: u1
      - id: color_a
        type: u1
  mesh_tri:
    seq:
      - id: mesh_tri_list_size
        type: u2
      - id: mesh_tri_list
        type: u2
        repeat: expr
        repeat-expr: mesh_tri_list_size

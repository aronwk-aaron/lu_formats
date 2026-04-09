meta:
  id: fev64
  file-extension: fev
  endian: le
  imports:
    - ../common/common
doc: |
  FEV (FMOD Event) file format. Two variants exist in the LU client data:

  1. FEV1 binary (magic "FEV1", version 0x00004000):
     The compiled runtime format loaded by fmod_event.dll. 

  2. RIFF-based (magic "RIFF", form type "FEV ", FMT version 0x00450000):
     A newer FMOD Designer 4.45 project export format.

  This KSY supports both formats via magic detection at the top level.

seq:
  - id: magic
    type: u4
  - id: body
    type:
      switch-on: magic
      cases:
        0x31564546: fev1_body
        0x46464952: riff_body
types:
  # =========================================================================
  # FEV1 binary body (after "FEV1" magic)
  # =========================================================================
  fev1_body:
    seq:
      - id: version
        contents: [0x00, 0x00, 0x40, 0x00]
      - id: sound_def_names_pool_size
        type: u4
        doc: |
          Pre-computed allocation hint for the sound definition name string pool.
          RE of fmod_event.dll confirms this is used solely as a malloc size for
          the name pool buffer at SoundBank_AllocNamePool @ 0x10035780.
      - id: waveform_names_pool_size
        type: u4
        doc: |
          Pre-computed allocation hint for the waveform name string pool.
          Completely unused at runtime for LU's FEV version (0x400000).
      - id: manifest_entry_count
        type: u4
      - id: manifest_entries
        type: manifest_entry
        repeat: expr
        repeat-expr: manifest_entry_count
      - id: project_name
        type: common::u4_str
      - id: bank_count
        type: u4
      - id: banks
        type: fev1_bank
        repeat: expr
        repeat-expr: bank_count
      - id: event_categories
        type: event_category
      - id: root_event_group_count
        type: u4
      - id: event_groups
        type: event_group
        repeat: expr
        repeat-expr: root_event_group_count
      - id: sound_definition_config_count
        type: u4
      - id: sound_definition_configs
        type: sound_definition_config
        repeat: expr
        repeat-expr: sound_definition_config_count
      - id: sound_definition_count
        type: u4
      - id: sound_definitions
        type: sound_definition
        repeat: expr
        repeat-expr: sound_definition_count
      - id: reverb_definition_count
        type: u4
      - id: reverb_definitions
        type: reverb_definition
        repeat: expr
        repeat-expr: reverb_definition_count
      - id: music_data
        type: music_data
  fev1_bank:
    seq:
      - id: load_mode
        type: u4
        enum: bank_load_mode
      - id: max_streams
        type: s4
      - id: fsb_checksum
        size: 8
        doc: |
          Two u32 values cross-checked against the FSB4 header reserved field.
          FMOD Event verifies these match when loading a bank's FSB.
      - id: name
        type: common::u4_str
  # =========================================================================
  # RIFF-based body (after "RIFF" magic)
  # =========================================================================
  riff_body:
    seq:
      - id: file_size
        type: u4
      - id: form_type
        contents: "FEV "
      - id: chunks
        type: riff_chunk
        repeat: eos
  riff_chunk:
    seq:
      - id: chunk_id
        type: str
        size: 4
        encoding: ASCII
      - id: chunk_size
        type: u4
      - id: body
        size: chunk_size
        type:
          switch-on: chunk_id
          cases:
            '"FMT "': riff_fmt
            '"LIST"': riff_list
      - id: padding
        size: chunk_size % 2
  riff_fmt:
    doc: "FMOD Designer version. 0x00450000"
    seq:
      - id: version
        type: u4
  riff_list:
    seq:
      - id: list_type
        type: str
        size: 4
        encoding: ASCII
      - id: sub_chunks
        type: riff_sub_chunk
        repeat: eos
  riff_sub_chunk:
    seq:
      - id: chunk_id
        type: str
        size: 4
        encoding: ASCII
      - id: chunk_size
        type: u4
      - id: body
        size: chunk_size
        type:
          switch-on: chunk_id
          cases:
            '"OBCT"': riff_obct
            '"PROP"': riff_prop
            '"STRR"': riff_strr
            '"EPRP"': riff_eprp
            '"LANG"': riff_lang
            # LGCY body follows the same structure as fev1_body (after pool sizes)
            # but with STRR-indexed names for events/groups/parameters, per-language
            # bank checksums, and modified effect envelopes. Left as raw bytes here
            # due to the STRR indirection making it difficult to express in pure KSY.
      - id: padding
        size: chunk_size % 2
  riff_obct:
    doc: "Manifest — identical format to FEV1."
    seq:
      - id: count
        type: u4
      - id: entries
        type: manifest_entry
        repeat: expr
        repeat-expr: count
  riff_prop:
    seq:
      - id: project_name
        type: common::u4_str
  riff_strr:
    doc: |
      String reference table. Event group, event, and parameter names in the
      LGCY chunk are u32 indices into this table.
    seq:
      - id: count
        type: u4
      - id: offsets
        type: u4
        repeat: expr
        repeat-expr: count
      - id: string_pool
        size-eos: true
  riff_eprp:
    doc: "Per-envelope-type runtime defaults."
    seq:
      - id: count
        type: u4
      - id: entries
        type: riff_eprp_entry
        repeat: expr
        repeat-expr: count
  riff_eprp_entry:
    seq:
      - id: value_a
        type: f4
      - id: value_b
        type: f4
      - id: value_c
        type: f4
  riff_lang:
    seq:
      - id: count
        type: u4
      - id: languages
        type: riff_lang_entry
        repeat: expr
        repeat-expr: count
  riff_lang_entry:
    seq:
      - id: name
        type: common::u4_str
      - id: padding
        type: u4
  # =========================================================================
  # Shared types (used by both FEV1 and RIFF LGCY)
  # =========================================================================
  manifest_entry:
    seq:
      - id: type
        type: u4
        enum: manifest_type
      - id: value
        type: u4
    enums:
      manifest_type:
        0x00:
          id: project_version_or_flag
          doc: |
            Always 1 in LU FEV files. Read into the manifest array at index 0
            and stored at the allocation struct offset 0x10 by the runtime. 
            Purpose unclear — may be a project
            format version or a boolean flag. Not used for any allocation sizing.
        0x01: bank_count
        0x02: event_category_count
        0x03: event_group_count
        0x04: user_property_count
        0x05: event_parameter_count
        0x06: effect_envelope_count
        0x07: envelope_point_count
        0x08: sound_instance_count
        0x09:
          id: layer_count
          doc: Note this does not include the single layer of simple events
        0x0A: simple_event_count
        0x0B: complex_event_count
        0x0C: reverb_definition_count
        0x0D: waveform_wavetable_count
        0x0E: waveform_oscillator_count
        0x0F: waveform_dont_play_entry_count
        0x10: waveform_programmer_sound_count
        0x11: sound_definition_count
        0x12:
          id: reserved_0x12
          doc: |
            Always 0 in LU FEV files. Read into the manifest array at index 0x12
            but never stored into the output allocation struct.
            Not used by any downstream code. Reserved/unused manifest slot.
        0x13: project_name_size
        0x14: bank_names_total_size
        0x15: event_category_names_total_size
        0x16: event_group_names_total_size
        0x17: user_property_names_total_size
        0x18: user_property_string_values_total_size
        0x19: event_parameter_names_total_size
        0x1A: effect_envelope_names_total_size
        0x1B: event_names_total_size
        0x1C:
          id: event_instance_category_names_total_size
          doc: Note that this is the serialized size, and the category names is serialized per event, so if multiple events contain a category, it is added multiple times, and if no events contain a category, the category does not contribute.
        0x1D: reverb_definition_names_total_size
        0x1E: wavetable_file_names_total_size
        0x1F: wavetable_bank_names_total_size
        0x20:
          id: sound_definition_names_total_size
          doc: Note that sound definition names are "paths" (a sound definition sd in folder f will have name /f/sd)
  event_category:
    seq:
      - id: name
        type: common::u4_str
      - id: volume
        type: f4
      - id: pitch
        type: f4
      - id: max_streams
        type: s4
      - id: max_playback_behavior
        type: u4
        enum: max_playback_behavior
      - id: subcategory_count
        type: u4
      - id: subcategories
        type: event_category
        repeat: expr
        repeat-expr: subcategory_count
    enums:
      max_playback_behavior:
        0: steal_oldest
        1: steal_newest
        2: steal_quietest
        3: just_fail
        4: just_fail_if_quietest
  event_group:
    seq:
      - id: name
        type: common::u4_str
      - id: user_property_count
        type: u4
      - id: user_properties
        type: user_property
        repeat: expr
        repeat-expr: user_property_count
      - id: subgroup_count
        type: u4
      - id: event_count
        type: u4
      - id: subgroups
        type: event_group
        repeat: expr
        repeat-expr: subgroup_count
      - id: events
        type: event
        repeat: expr
        repeat-expr: event_count
  user_property:
    seq:
      - id: name
        type: common::u4_str
      - id: type
        type: u4
        enum: user_property_type
      - id: value
        type:
          switch-on: type
          cases:
            'user_property_type::integer': u4
            'user_property_type::float': f4
            'user_property_type::string': common::u4_str
    enums:
      user_property_type:
        0: integer
        1: float
        2: string
  event:
    seq:
      - id: is_simple_event
        type: u4
        enum: is_simple_event
      - id: name
        type: common::u4_str
      - id: guid
        size: 16
      - id: volume
        type: f4
      - id: pitch
        type: f4
      - id: pitch_randomization
        type: f4
      - id: volume_randomization
        type: f4
      - id: priority
        type: u2
      - id: max_instances
        type: u2
      - id: max_playbacks
        type: u4
      - id: steal_priority
        type: u4
      - id: threed_flags
        type: event_3d_flags
      - id: threed_min_distance
        type: f4
      - id: threed_max_distance
        type: f4
      - id: event_flags
        type: event_flags
      - id: twod_speaker_l
        type: f4
      - id: twod_speaker_r
        type: f4
      - id: twod_speaker_c
        type: f4
      - id: speaker_lfe
        type: f4
      - id: twod_speaker_lr
        type: f4
      - id: twod_speaker_rr
        type: f4
      - id: twod_speaker_ls
        type: f4
      - id: twod_speaker_rs
        type: f4
      - id: threed_cone_inside_angle
        type: f4
      - id: threed_cone_outside_angle
        type: f4
      - id: threed_cone_outside_volume
        type: f4
      - id: max_playbacks_behavior
        type: u4
        enum: max_playback_behavior
      - id: threed_doppler_factor
        type: f4
      - id: reverb_dry_level
        type: f4
      - id: reverb_wet_level
        type: f4
      - id: threed_speaker_spread
        type: f4
      - id: fade_in_time
        type: u2
      # 0x0000 if fade_in_time < 32768, 0xFFFF otherwise
      - id: fade_in_time_flag
        type: u2
      - id: fade_out_time
        type: u2
      # 0x0000 if fade_in_time < 32768, 0xFFFF otherwise
      - id: fade_out_time_flag
        type: u2
      - id: spawn_intensity
        type: f4
      - id: spawn_intensity_randomization
        type: f4
      - id: threed_pan_level
        type: f4
      - id: threed_position_randomization
        type: u4
      - id: layer_count
        type: u4
        if: is_simple_event == is_simple_event::false
      - id: layers
        type: layer(false)
        repeat: expr
        repeat-expr: layer_count
        if: is_simple_event == is_simple_event::false
      - id: layer
        type: layer(true)
        if: is_simple_event == is_simple_event::true
      - id: parameter_count
        type: u4
        if: is_simple_event == is_simple_event::false
      - id: parameters
        type: event_parameter
        repeat: expr
        repeat-expr: parameter_count
        if: is_simple_event == is_simple_event::false
      - id: user_property_count
        type: u4
        if: is_simple_event == is_simple_event::false
      - id: user_properties
        type: user_property
        repeat: expr
        repeat-expr: user_property_count
        if: is_simple_event == is_simple_event::false
      - id: category_instance_count
        type: u4
        doc: |
          Number of category instance name strings that follow. When 0, the runtime
          assigns the default/root category. When 1, one u32-prefixed string follows.
          Previously misidentified as "event_extra_flags"
        type: common::u4_str
    enums:
      max_playback_behavior:
        1: steal_oldest
        2: steal_newest
        3: steal_quietest
        4: just_fail
        5: just_fail_if_quietest
  event_flags:
    doc: |
      Event behavior flags stored at EventI offset +0x60 in the runtime.
    seq:
      - id: rolloff_and_mode_byte0
        size: 1
        doc: |
          Byte 0 of event flags (u32 bits 0-7). All bits observed as zero
          in LU FEV files. Reserved for internal runtime use.
      - id: rolloff_flags
        size: 1
        doc: |
          Byte 1 of event flags (u32 bits 8-15). Contains rolloff type bits
          set by EventI::setPropertyByIndex case 0x0d. Bits are mutually
          exclusive (mask 0xFF7FF0FF clears them before setting one):
            bit 8  (0x0100): inverse rolloff (FMOD_EVENTPROPERTY value 0)
            bit 9  (0x0200): linear squared rolloff (value 1)
            bit 10 (0x0400): linear rolloff (value 2)
            bit 11 (0x0800): logarithmic rolloff (value 3)
          Bits 12-15 are reserved/unused in this byte.
      - id: rolloff_custom
        type: b1
        doc: |
          Bit 23 (0x800000): custom rolloff curve (FMOD_EVENTPROPERTY value 4).
          Part of the rolloff flags group but in byte 2 due to bit position.
      - id: reserved_byte2_bits22_20
        type: b3
        doc: Bits 22-20 of byte 2. Not set by any known property writer. Reserved.
      - id: oneshot
        type: b1
        doc: |
          Bit 19 (0x80000): oneshot/continuous flag. XML <oneshot>Yes</oneshot> CLEARS this bit while
          <oneshot>No</oneshot> SETS it, suggesting bit=1 means "not oneshot"
          (continuous). The runtime setPropertyByIndex case 0x23 toggles this
          bit.
      - id: reserved_byte2_bits18_16
        type: b3
        doc: Bits 18-16 of byte 2. Not set by any known property writer. Reserved.
      - id: reserved_byte3
        size: 1
        doc: |
          Byte 3 of event flags (u32 bits 24-31). All bits observed as zero
          in LU FEV files. Reserved.
  event_3d_flags:
    doc: |
      FMOD_MODE-derived bitfield controlling 3D spatialization.
      The runtime stores this at EventI offset +0x40 and manipulates it
      via EventI::getPropertyByIndex/setPropertyByIndex (properties 0x0e
      Mode, 0x0f Ignore_Geometry, 0x10 rolloff/position, 0x13 head/world
      relative).
    seq:
      - id: stream_or_software
        type: b3
        doc: |
          Byte 0, bits 7-5. Corresponds to FMOD_MODE output flags:
            bit 7 (0x80): FMOD_CREATESTREAM — stream from disk
            bit 6 (0x40): FMOD_SOFTWARE — use software mixing
            bit 5 (0x20): FMOD_HARDWARE — use hardware mixing
          These are typically all zero for events (set per-bank instead).
      - id: mode_3d
        type: b1
        doc: |
          Byte 0, bit 4 (0x10): 3D mode. Events with x_3D_Position have this
          set. Maps to FMOD_3D in the FMOD_MODE bitfield.
          NOTE: Previously mislabeled as mode_2d in the KSY; corrected based on
          FMOD API (FMOD_3D=0x10) and fev.h binary analysis comment confirming
          "byte 0, bit 4: mode_3d (x_3d events have 0x10 here)".
      - id: mode_2d
        type: b1
        doc: |
          Byte 0, bit 3 (0x08): 2D mode. Events with x_2D speaker panning have
          this set. Maps to FMOD_2D in the FMOD_MODE bitfield.
          NOTE: Previously mislabeled as mode_3d in the KSY; corrected based on
          FMOD API (FMOD_2D=0x08) and fev.h binary analysis comment confirming
          "byte 0, bit 3: mode_2d (x_2d events have 0x08 here)".
      - id: loop_mode
        type: b3
        doc: |
          Byte 0, bits 2-0. Corresponds to FMOD_MODE loop flags:
            bit 2 (0x04): FMOD_LOOP_BIDI — bidirectional loop
            bit 1 (0x02): FMOD_LOOP_NORMAL — forward loop
            bit 0 (0x01): FMOD_LOOP_OFF — no loop
      - id: reserved_byte1
        size: 1
        doc: |
          Byte 1 (u32 bits 8-15). Contains FMOD_MODE creation/open flags
          that are not relevant at the event level:
            bit 15 (0x8000): FMOD_MPEGSEARCH
            bit 14 (0x4000): FMOD_ACCURATETIME
            bit 13 (0x2000): FMOD_OPENONLY
            bit 12 (0x1000): FMOD_OPENRAW
            bit 11 (0x0800): FMOD_OPENMEMORY
            bit 10 (0x0400): FMOD_OPENUSER
            bit 9  (0x0200): FMOD_CREATECOMPRESSEDSAMPLE
            bit 8  (0x0100): FMOD_CREATESAMPLE
          Typically all zero for events (these flags apply per-bank/sound).
      - id: reserved_byte2_bits23_22
        type: b2
        doc: |
          Byte 2, bits 23-22. Corresponds to higher FMOD_MODE 3D rolloff bits:
            bit 23 (0x800000): reserved or FMOD_3D_LOGROLLOFF (internal)
            bit 22 (0x400000): FMOD_3D_LINEARROLLOFF
          Typically zero in LU FEV files.
      - id: threed_rolloff_linear
        type: b1
        doc: |
          Byte 2, bit 21 (0x200000): FMOD_3D_LINEARSQUAREROLLOFF.
          Linear squared distance rolloff for 3D sound attenuation.
          (mask 0x4300000 includes bits 26,21,20).
      - id: threed_rolloff_logarithmic
        type: b1
        doc: |
          Byte 2, bit 20 (0x100000): FMOD_3D_INVERSEROLLOFF.
          Inverse distance rolloff (logarithmic) for 3D sound attenuation.
          This is the default FMOD 3D rolloff model.
      - id: threed_position_world_relative
        type: b1
        doc: |
          Byte 2, bit 19 (0x80000): FMOD_3D_WORLDRELATIVE.
          3D position is relative to the world origin.
          (mask 0xc0000 = bits 19,18).
      - id: threed_position_head_relative
        type: b1
        doc: |
          Byte 2, bit 18 (0x40000): FMOD_3D_HEADRELATIVE.
          3D position is relative to the listener head.
      - id: unique
        type: b1
        doc: |
          Byte 2, bit 17 (0x20000): FMOD_UNIQUE.
          When set, only one instance of this sound can play at a time
          in the FMOD channel pool. Replaces existing if a new one starts.
      - id: ignore_geometry
        type: b1
        doc: |
          Byte 2, bit 16 (0x10000): FMOD_NONBLOCKING.
          Despite the field name carried over from prior analysis, bit 16
          maps to FMOD_NONBLOCKING in the FMOD_MODE bitfield.
          The actual FMOD_3D_IGNOREGEOMETRY flag is at bit 30 (0x40000000)
          in byte 3 below. However, binary analysis of FEV files confirmed
          this bit correlates with events that have "Ignore Geometry" set in
          FMOD Designer. This suggests the FEV may use a custom packing where
          bit 16 stores the ignore_geometry flag rather than FMOD_NONBLOCKING.
      - id: threed_ignoregeometry_and_reserved
        type: b6
        doc: |
          Byte 3, bits 31-26 (top 6 bits of the u32).
            bit 30 (0x40000000): FMOD_3D_IGNOREGEOMETRY in FMOD_MODE.
              The runtime getPropertyByIndex case 0x0f reads bit 30 for the
              Ignore_Geometry property. If the FEV stores raw FMOD_MODE here,
              bit 30 would be the canonical ignore_geometry position.
            bit 26 (0x04000000): FMOD_3D_CUSTOMROLLOFF in FMOD_MODE.
              Part of the rolloff mask (0x4300000) used by setPropertyByIndex
              case 0x10.
            bits 31, 29-27: reserved/unused.
          Bits 25-24 of byte 3 are not covered by this field (2 trailing
          bits unread by KSY).
  layer:
    params:
      - id: is_simple_event
        type: b1
    seq:
      - id: layer_flags
        size: 2
        if: is_simple_event == false
      - id: priority
        type: s2
        doc: "-1 = use event priority"
        if: is_simple_event == false
      - id: control_parameter_index
        type: s2
        doc: "-1 = unset"
        if: is_simple_event == false
      - id: sound_instance_count
        type: u2
      - id: effect_envelope_count
        type: u2
      - id: sound_instances
        type: sound_instance
        repeat: expr
        repeat-expr: sound_instance_count
      - id: effect_envelopes
        type: effect_envelope
        repeat: expr
        repeat-expr: effect_envelope_count
  sound_instance:
    seq:
      - id: sound_definition_index
        type: u2
      - id: start_position
        type: f4
      - id: length
        type: f4
      - id: start_mode
        type: u4
        enum: start_mode
      - id: loop_mode
        type: u2
        enum: loop_mode
      - id: autopitch_parameter
        type: u2
        enum: autopitch_parameter
      - id: loop_count
        type: s4
        doc: "-1 = disabled"
      - id: autopitch_enabled
        type: u4
        enum: autopitch_enabled
      - id: autopitch_reference
        type: f4
      - id: autopitch_at_min
        type: f4
      - id: fine_tune
        type: f4
      - id: volume
        type: f4
      - id: volume_randomization
        type: f4
      - id: pitch
        type: f4
      - id: fade_in_type
        type: u4
      - id: fade_out_type
        type: u4
    enums:
      start_mode:
        0: immediate
        1: wait_for_previous
      loop_mode:
        0: loop_and_cutoff
        1: oneshot
        2: loop_and_play_to_end
      autopitch_enabled:
        1: yes
        2: no
      autopitch_parameter:
        0: event_primary_parameter
        2: layer_control_parameter
  effect_envelope:
    seq:
      - id: control_parameter_index
        type: s4
      - id: name
        type: common::u4_str
      - id: dsp_effect_index
        type: s4
      - id: envelope_flags
        type: u4
        doc: |
          DSP target type bitfield (version >= 0x260000). In older FEV versions,
          derived from the envelope name string.
          Bit values: 0x0008=Volume, 0x0010=Pitch, 0x0020=Pan, 0x0040=TimeOffset,
          0x0080=SurroundPan, 0x0100=3DSpeakerSpread, 0x0200=ReverbLevel,
          0x0400=3DPanLevel, 0x0800=ReverbBalance, 0x1000=SpawnIntensity.
          Bit 14 (0x4000) is masked out on read.
      - id: envelope_flags2
        type: u4
        doc: |
          Additional flags (version >= 0x390000). Stored at envelope offset 0x14.
          Bit 0 (0x01) masked on read — set when no standard DSP name matches (user DSP).
          Bit 1 (0x02) set by memory allocator capability check.
      - id: envelope_point_count
        type: u4
      - id: envelope_points
        type: effect_envelope_point
        repeat: expr
        repeat-expr: envelope_point_count
      - id: mapping_data
        size: 4
      - id: enabled
        type: u4
  effect_envelope_point:
    seq:
      - id: position
        type: u4
      - id: value
        type: f4
      - id: curve_shape
        type: u4
        enum: curve_shape
    enums:
      curve_shape:
        1: flat_ended
        2: linear
        4: log
        8: flat_middle
  event_parameter:
    seq:
      - id: name
        type: common::u4_str
      - id: velocity
        type: f4
      - id: minimum_value
        type: f4
      - id: maximum_value
        type: f4
      - id: bitmask
        type: event_parameter_flags
      - id: seek_speed
        type: f4
      - id: extra_value
        type: u4
      - id: extra_count
        type: u4
      - id: extra_items
        type: u4
        repeat: expr
        repeat-expr: extra_count
  event_parameter_flags:
    doc: |
      Parameter behavior flags (u32). loop, oneshot_and_stop_event, and oneshot
      are mutually exclusive (bits 1-3). keyoff_on_silence only works with oneshot.
    seq:
      - id: reserved_bit7
        type: b1
        doc: |
          Bit 7 (0x80) of byte 0. Not set by the designer's parameter flag
          builder. Always 0 in LU FEV files. Reserved.
      - id: keyoff_on_silence
        type: b1
        doc: |
          Bit 6 (0x40): keyoff on silence. Only meaningful with oneshot mode.
          When set, the parameter automatically sends a key-off when the event
          goes silent.
      - id: auto_param_type
        type: b2
        doc: |
          Bits 5-4 (0x20, 0x10): automatic parameter type, set by the runtime
          AFTER reading from FEV based on the parameter name string. Not written
          by the designer (always 0 in FEV files).
            bit 5 (0x20): "(listener angle)" parameter
            bit 4 (0x10): "(distance)" parameter
            both (0x30): "(event angle)" parameter
      - id: oneshot
        type: b1
        doc: |
          Bit 3 (0x08): oneshot mode (loopmode=2 in FDP XML). When the parameter
          reaches its maximum, the event stops immediately. Mutually exclusive
          with loop and oneshot_and_stop_event.
      - id: oneshot_and_stop_event
        type: b1
        doc: |
          Bit 2 (0x04): oneshot and stop event mode (loopmode=1 in FDP XML).
          When the parameter reaches its maximum, the event is stopped entirely.
          Mutually exclusive with loop and oneshot.
      - id: loop
        type: b1
        doc: |
          Bit 1 (0x02): loop mode (loopmode=0 in FDP XML). The parameter
          loops back to its minimum when it reaches the maximum. Mutually
          exclusive with oneshot and oneshot_and_stop_event.
      - id: primary
        type: b1
        doc: |
          Bit 0 (0x01): primary parameter flag. Marks this as the event's
          primary (first/default) parameter.
      - id: reserved_bytes1_3
        size: 3
        doc: |
          Bytes 1-3 (u32 bits 8-31). Not set by the designer's parameter flag
          builder. Always zero in LU FEV files. Reserved/padding.
  sound_definition_config:
    seq:
      - id: play_mode
        type: u4
        enum: play_mode
      - id: spawn_time_min
        type: u4
      - id: spawn_time_max
        type: u4
      - id: maximum_spawned_sounds
        type: u4
      - id: volume
        type: f4
      - id: volume_rand_method
        type: u4
      - id: volume_random_min
        type: f4
      - id: volume_random_max
        type: f4
      - id: volume_randomization
        type: f4
      - id: pitch
        type: f4
      - id: pitch_rand_method
        type: u4
      - id: pitch_random_min
        type: f4
      - id: pitch_random_max
        type: f4
      - id: pitch_randomization
        type: f4
      - id: pitch_randomization_behavior
        type: u4
        enum: pitch_randomization_behavior
      - id: threed_position_randomization
        type: f4
      - id: trigger_delay_min
        type: u2
      - id: trigger_delay_max
        type: u2
      - id: spawn_count
        type: u2
    enums:
      play_mode:
        0: sequential
        1: random
        2: random_no_repeat
        3: sequential_event_restart
        4: shuffle
        5: programmer_selected
        6: shuffle_global
        7: sequential_global
      pitch_randomization_behavior:
        0: randomize_every_spawn
        1: randomize_when_triggered_by_parameter
        2: randomize_when_event_starts
  sound_definition:
    seq:
      - id: name
        type: common::u4_str
      - id: config_index
        type: u4
      - id: waveform_count
        type: u4
      - id: waveforms
        type: waveform
        repeat: expr
        repeat-expr: waveform_count
  waveform:
    seq:
      - id: type
        type: u4
        enum: waveform_type
      - id: weight
        type: u4
      - id: parameters
        type:
          switch-on: type
          cases:
            'waveform_type::wavetable': wavetable_params
            'waveform_type::dont_play': dont_play_params
            'waveform_type::oscillator': oscillator_params
            'waveform_type::programmer': programmer_params
    enums:
      waveform_type:
        0: wavetable
        1: oscillator
        2: dont_play
        3: programmer
  oscillator_params:
    seq:
      - id: type
        type: u4
        enum: oscillator_type
      - id: frequency
        type: f4
    enums:
      oscillator_type:
        0: sine
        1: square
        2: saw_up
        3: saw_down
        4: triangle
        5: noise
  dont_play_params: {}
  programmer_params: {}
  wavetable_params:
    seq:
      - id: filename
        type: common::u4_str
      - id: bank_name
        type: common::u4_str
      - id: percentage_locked
        type: u4
      - id: length
        type: u4
        doc: In milliseconds
  reverb_definition:
    doc: |
      Reverb preset. Field order confirmed by RE of fmod_event.dll
      EventProjectI_loadFromBuffer (ppuVar6 slot mapping).
    seq:
      - id: name
        type: common::u4_str
      - id: master_level
        type: s4
        doc: 0 to -100, serialized as 0 to -10000 (ie, out to two decimal places then multiply by 100)
      - id: hf_gain
        type: s4
        doc: 0 to -100, serialized as 0 to -10000 (ie, out to two decimal places then multiply by 100)
      - id: room_rolloff_factor
        type: f4
        doc: "ppuVar6[33]"
      - id: decay_time
        type: f4
        doc: "ppuVar6[13], in seconds"
      - id: decay_hf_ratio
        type: f4
        doc: "ppuVar6[14]"
      - id: early_reflections
        type: s4
        doc: 10 to -100, serialized as 1000 to -10000 (ie, out to two decimal places then multiply by 100)
      - id: pre_delay
        type: f4
        doc: in seconds
      - id: late_reflections
        type: s4
        doc: 20 to -100, serialized as 2000 to -10000 (ie, out to two decimal places then multiply by 100)
      - id: late_delay
        type: f4
        doc: in seconds
      - id: diffusion
        type: f4
      - id: density
        type: f4
      - id: hf_crossover
        type: f4
        doc: in hz
      - id: lf_gain_a
        type: f4
        doc: 0 to -100, serialized as 0 to -10000 (ie, out to two decimal places then multiply by 100)
      - id: lf_crossover_a
        type: f4
        doc: in hz
      - id: instance
        type: u4
      - id: environment
        type: u4
      - id: environment_size
        type: f4
      - id: environment_diffusion
        type: f4
      - id: lf_gain_b
        type: s4
        doc: 0 to -100, serialized as 0 to -10000 (ie, out to two decimal places then multiply by 100)
      - id: reflections_pan
        type: f4
        repeat: expr
        repeat-expr: 3
      - id: reverb_pan
        type: f4
        repeat: expr
        repeat-expr: 3
      - id: echo_time
        type: f4
      - id: echo_depth
        type: f4
      - id: modulation_time
        type: f4
      - id: modulation_depth
        type: f4
      - id: air_absorption_hf
        type: f4
      - id: lf_reference_ext
        type: f4
        doc: |
          FMOD_REVERB_PROPERTIES.LFReference (Hz) — low-frequency crossover.
          Maps to ppuVar6[0x20] (slot 32). This is the same field as lf_crossover_b
          below — it is serialized redundantly. The runtime simply overwrites the
          slot on each read.
      - id: lf_crossover_b
        type: f4
        doc: in hz
      - id: flags
        type: u4
  # =========================================================================
  # Music data (shared, appended after reverb definitions in FEV1)
  # =========================================================================
  music_data:
    seq:
      - id: items
        type: music_data_item
        repeat: eos
  music_data_item:
    seq:
      - id: len
        type: u4
      - id: data
        size: len - 4
        type: music_data_data
  music_data_data:
    seq:
      - id: chunks
        type: music_data_chunk
        repeat: eos
  music_data_chunk:
    seq:
      - id: type
        type: str
        size: 4
        encoding: ascii
      - id: data
        type:
          switch-on: type
          cases:
            # Composition (top-level container)
            '"comp"': music_data
            # Settings
            '"sett"': md_sett
            # Themes
            '"thms"': music_data
            '"thmh"': u2
            '"thm "': music_data
            '"thmd"': md_thmd
            # Individual link container (one per link; holds nested lnkd + conditions)
            '"lnk "': music_data
            # Cues
            '"cues"': music_data
            '"entl"': md_entl
            # Scenes
            '"scns"': music_data
            '"scnh"': u2
            '"scnd"': md_scnd
            # Parameters
            '"prms"': music_data
            '"prmh"': u2
            '"prmd"': u4
            # Segments
            '"sgms"': music_data
            '"sgmh"': u2
            '"sgmd"': md_sgmd
            # Samples
            '"smps"': music_data
            '"smph"': md_smph
            '"smpf"': music_data
            '"str "': md_str
            '"smpm"': u4
            '"smp "': md_smp
            # Links
            '"lnks"': music_data
            '"lnkh"': u2
            '"lnkd"': md_lnkd
            '"lfsh"': u2
            '"lfsd"': md_lfsd
            # Timelines
            '"tlns"': music_data
            '"tlnh"': u2
            '"tlnd"': md_tlnd
            # Conditions
            '"cond"': md_cond
            '"cms "': md_cms
            '"cprm"': md_cprm
  md_sett:
    seq:
      - id: volume
        type: f4
      - id: reverb
        type: f4
  md_thmd:
    seq:
      - id: theme_id
        type: u4
      - id: playback_method
        type: u1
        enum: playback_method
      - id: default_transition
        type: u1
        enum: default_transition
        doc: Only used with playback_method sequenced
      - id: quantization
        type: u1
        enum: quantization
        doc: Used only with playback method concurrent or default transition crossfade
      - id: transition_timeout
        type: u4
        doc: Used only with default transition queued
      - id: crossfade_duration
        type: u4
        doc: Used only with default transition crossfade
      - id: end_count
        type: u2
      - id: end_sequence_ids
        type: u4
        repeat: expr
        repeat-expr: end_count
      - id: start_count
        type: u2
      - id: start_sequence_ids
        type: u4
        repeat: expr
        repeat-expr: start_count
    enums:
      playback_method:
        0: sequenced
        1: concurrent
      default_transition:
        0: never
        1: queued
        2: crossfade
      quantization:
        0: free
        1: on_bar
        2: on_beat
  md_entl:
    seq:
      - id: count
        type: u2
      - id: names_length
        type: u2
      - id: ids
        type: u4
        repeat: expr
        repeat-expr: count
      # It's unclear how this connects to the fact that names_length was specified,
      # maybe a way to skip over quickly? Regardless this appears to be accurate
      - id: cue_names
        repeat: expr
        repeat-expr: count
        type: str
        terminator: 0
        encoding: ascii
  md_scnd:
    seq:
      - id: scene_id
        type: u4
        doc: |
          Scene ID used as hash key in FMOD::BucketHash for scene lookup.
      - id: count
        type: u2
      - id: cue_instances
        type: md_cue_instance
        repeat: expr
        repeat-expr: count
  md_cue_instance:
    doc: |
      A cue reference within a scene. Read as pairs of u32 values by the music
      system scene loader. The runtime reads (count * 2) u32 values in a single
      bulk read.
    seq:
      - id: cue_id
        type: u4
        doc: Cue ID referencing an entry in the cue entry list (entl).
      - id: condition_id
        type: u4
        doc: |
          Condition or ordering ID for this cue instance within the scene.
          Read alongside cue_id as paired u32 values. Appears to control cue
          evaluation order or condition binding. Observed as small sequential
          integers in LU FEV files. The runtime stores both values together
          in a flat buffer at the scene's data pointer (offset 0x14).
  md_sgmd:
    seq:
      - id: segment_id
        type: u4
      - id: segment_length
        type: u4
        doc: |
          Stored at CoreSegment offset 0x0c.
      - id: timeline_id
        type: u4
      - id: time_signature_beats
        type: u1
      - id: time_signature_beat_value
        type: u1
      - id: beats_per_minute
        type: f4
      - id: segment_tempo
        type: f4
        doc: |
          Stored at CoreSegment offset 0x1c. Written by designer vtable[0x18]().
      - id: sync_beat_1
        type: b2
      - id: sync_beat_2
        type: b2
      - id: sync_beat_3
        type: b2
      - id: sync_beat_4
        type: b2
      - id: sync_beat_5
        type: b2
      - id: sync_beat_6
        type: b2
      - id: sync_beat_7
        type: b2
      - id: sync_beat_8
        type: b2
      - id: sync_beat_9
        type: b2
      - id: sync_beat_10
        type: b2
      - id: sync_beat_11
        type: b2
      - id: sync_beat_12
        type: b2
      - id: sync_beat_13
        type: b2
      - id: sync_beat_14
        type: b2
      - id: sync_beat_15
        type: b2
      - id: sync_beat_16
        type: b2
      - id: data
        type: music_data
  md_smph:
    seq:
      - id: playback_mode
        type: u1
        enum: playback_mode
      - id: count
        type: u4
    enums:
      playback_mode:
        0: sequential
        1: random
        2: random_without_repeat
        3: shuffled
  md_str:
    seq:
      - id: count
        type: u4
      - id: total_string_data_size
        type: u4
        doc: |
          Total byte size of the string data that follows the offset table.
          This is the sum of all null-terminated string lengths (including
          null terminators). Allows the reader to allocate the correct buffer
          size before parsing individual strings. Observed in LU FEV files as
          the byte offset of the last name_end_offset entry, or 0 when count
          is 0. The music system "smpf"/"str " chunk reader uses this for
          buffer pre-allocation.
      - id: name_end_offsets
        type: u4
        repeat: expr
        repeat-expr: count
      # Technically the lengths are determined by the above, but this is more
      # convinient to record in kaitai for now (and they seem to end in null bytes anyways)
      - id: names
        repeat: expr
        repeat-expr: count
        type: str
        terminator: 0
        encoding: ascii
      - id: end_marker
        if: count == 0
        size: 1
        contents: [0x00]
  md_lnkd:
    seq:
      - id: segment_1_id
        type: u4
      - id: segment_2_id
        type: u4
      - id: transition_behavior
        type: md_transition_behavior
  md_transition_behavior:
    seq:
      - id: padding
        type: b1
      - id: at_segment_end
        type: b1
      - id: on_bar
        type: b1
      - id: on_beat
        type: b1
      - id: padding2
        size: 3
  md_lfsd:
    seq:
      - id: from_segment_id
        type: u4
        doc: |
          From-segment ID used as BucketHash key for link lookup.
      - id: count
        type: u2
      - id: link_ids
        type: u4
        repeat: expr
        repeat-expr: count
        doc: Link IDs referencing entries in the ExtLinkRepository.
  md_smp:
    seq:
      - id: bank_name
        type: common::u4_str
      - id: index
        type: u4
  md_tlnd:
    seq:
      - id: timeline_id
        type: u4
        doc: |
          Timeline ID used as BucketHash key for timeline lookup.
  md_cond:
    seq:
      - id: nop
        size: 0
  md_cms:
    seq:
      - id: condition_type
        type: u1
        enum: cms_condition_type
      - id: theme_id
        type: u4
      - id: cue_id
        type: u4
    enums:
      cms_condition_type:
        0: on_theme
        1: on_cue
  md_cprm:
    seq:
      - id: condition_type
        type: u2
        enum: cprm_condition_type
      - id: param_id
        type: u4
      - id: value_1
        type: u4
      - id: value_2
        doc: If comparrison type only requires one operand, these 4 bytes are padding
        type: u4
    enums:
      cprm_condition_type:
        0: equal_to
        1: greater_than
        2: greater_than_including
        3: less_than
        4: less_than_including
        5: between
        6: between_including
# =========================================================================
# Top-level enums
# =========================================================================
enums:
  is_simple_event:
    8: 'false'
    16: 'true'
  bank_load_mode:
    0x80: stream_from_disk
    0x100: decompress_into_memory
    0x200: load_into_memory

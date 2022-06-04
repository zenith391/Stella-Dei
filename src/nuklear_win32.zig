pub const __builtin_bswap16 = @import("std").zig.c_builtins.__builtin_bswap16;
pub const __builtin_bswap32 = @import("std").zig.c_builtins.__builtin_bswap32;
pub const __builtin_bswap64 = @import("std").zig.c_builtins.__builtin_bswap64;
pub const __builtin_signbit = @import("std").zig.c_builtins.__builtin_signbit;
pub const __builtin_signbitf = @import("std").zig.c_builtins.__builtin_signbitf;
pub const __builtin_popcount = @import("std").zig.c_builtins.__builtin_popcount;
pub const __builtin_ctz = @import("std").zig.c_builtins.__builtin_ctz;
pub const __builtin_clz = @import("std").zig.c_builtins.__builtin_clz;
pub const __builtin_sqrt = @import("std").zig.c_builtins.__builtin_sqrt;
pub const __builtin_sqrtf = @import("std").zig.c_builtins.__builtin_sqrtf;
pub const __builtin_sin = @import("std").zig.c_builtins.__builtin_sin;
pub const __builtin_sinf = @import("std").zig.c_builtins.__builtin_sinf;
pub const __builtin_cos = @import("std").zig.c_builtins.__builtin_cos;
pub const __builtin_cosf = @import("std").zig.c_builtins.__builtin_cosf;
pub const __builtin_exp = @import("std").zig.c_builtins.__builtin_exp;
pub const __builtin_expf = @import("std").zig.c_builtins.__builtin_expf;
pub const __builtin_exp2 = @import("std").zig.c_builtins.__builtin_exp2;
pub const __builtin_exp2f = @import("std").zig.c_builtins.__builtin_exp2f;
pub const __builtin_log = @import("std").zig.c_builtins.__builtin_log;
pub const __builtin_logf = @import("std").zig.c_builtins.__builtin_logf;
pub const __builtin_log2 = @import("std").zig.c_builtins.__builtin_log2;
pub const __builtin_log2f = @import("std").zig.c_builtins.__builtin_log2f;
pub const __builtin_log10 = @import("std").zig.c_builtins.__builtin_log10;
pub const __builtin_log10f = @import("std").zig.c_builtins.__builtin_log10f;
pub const __builtin_abs = @import("std").zig.c_builtins.__builtin_abs;
pub const __builtin_fabs = @import("std").zig.c_builtins.__builtin_fabs;
pub const __builtin_fabsf = @import("std").zig.c_builtins.__builtin_fabsf;
pub const __builtin_floor = @import("std").zig.c_builtins.__builtin_floor;
pub const __builtin_floorf = @import("std").zig.c_builtins.__builtin_floorf;
pub const __builtin_ceil = @import("std").zig.c_builtins.__builtin_ceil;
pub const __builtin_ceilf = @import("std").zig.c_builtins.__builtin_ceilf;
pub const __builtin_trunc = @import("std").zig.c_builtins.__builtin_trunc;
pub const __builtin_truncf = @import("std").zig.c_builtins.__builtin_truncf;
pub const __builtin_round = @import("std").zig.c_builtins.__builtin_round;
pub const __builtin_roundf = @import("std").zig.c_builtins.__builtin_roundf;
pub const __builtin_strlen = @import("std").zig.c_builtins.__builtin_strlen;
pub const __builtin_strcmp = @import("std").zig.c_builtins.__builtin_strcmp;
pub const __builtin_object_size = @import("std").zig.c_builtins.__builtin_object_size;
pub const __builtin___memset_chk = @import("std").zig.c_builtins.__builtin___memset_chk;
pub const __builtin_memset = @import("std").zig.c_builtins.__builtin_memset;
pub const __builtin___memcpy_chk = @import("std").zig.c_builtins.__builtin___memcpy_chk;
pub const __builtin_memcpy = @import("std").zig.c_builtins.__builtin_memcpy;
pub const __builtin_expect = @import("std").zig.c_builtins.__builtin_expect;
pub const __builtin_nanf = @import("std").zig.c_builtins.__builtin_nanf;
pub const __builtin_huge_valf = @import("std").zig.c_builtins.__builtin_huge_valf;
pub const __builtin_inff = @import("std").zig.c_builtins.__builtin_inff;
pub const __builtin_isnan = @import("std").zig.c_builtins.__builtin_isnan;
pub const __builtin_isinf = @import("std").zig.c_builtins.__builtin_isinf;
pub const __builtin_isinf_sign = @import("std").zig.c_builtins.__builtin_isinf_sign;
pub const __has_builtin = @import("std").zig.c_builtins.__has_builtin;
pub const __builtin_assume = @import("std").zig.c_builtins.__builtin_assume;
pub const __builtin_unreachable = @import("std").zig.c_builtins.__builtin_unreachable;
pub const __builtin_constant_p = @import("std").zig.c_builtins.__builtin_constant_p;
pub const __builtin_mul_overflow = @import("std").zig.c_builtins.__builtin_mul_overflow;
pub const int_least64_t = i64;
pub const uint_least64_t = u64;
pub const int_fast64_t = i64;
pub const uint_fast64_t = u64;
pub const int_least32_t = i32;
pub const uint_least32_t = u32;
pub const int_fast32_t = i32;
pub const uint_fast32_t = u32;
pub const int_least16_t = i16;
pub const uint_least16_t = u16;
pub const int_fast16_t = i16;
pub const uint_fast16_t = u16;
pub const int_least8_t = i8;
pub const uint_least8_t = u8;
pub const int_fast8_t = i8;
pub const uint_fast8_t = u8;
pub const intmax_t = c_longlong;
pub const uintmax_t = c_ulonglong;
pub const nk_char = i8;
pub const nk_uchar = u8;
pub const nk_byte = u8;
pub const nk_short = i16;
pub const nk_ushort = u16;
pub const nk_int = i32;
pub const nk_uint = u32;
pub const nk_size = usize;
pub const nk_ptr = usize;
pub const nk_bool = c_int;
pub const nk_hash = nk_uint;
pub const nk_flags = nk_uint;
pub const nk_rune = nk_uint;
pub const _dummy_array428 = [1]u8;
pub const _dummy_array429 = [1]u8;
pub const _dummy_array430 = [1]u8;
pub const _dummy_array431 = [1]u8;
pub const _dummy_array432 = [1]u8;
pub const _dummy_array433 = [1]u8;
pub const _dummy_array434 = [1]u8;
pub const _dummy_array435 = [1]u8;
pub const _dummy_array436 = [1]u8;
pub const _dummy_array440 = [1]u8;
pub const struct_nk_buffer_marker = extern struct {
    active: nk_bool,
    offset: nk_size,
};
pub const nk_plugin_alloc = ?fn (nk_handle, ?*anyopaque, nk_size) callconv(.C) ?*anyopaque;
pub const nk_plugin_free = ?fn (nk_handle, ?*anyopaque) callconv(.C) void;
pub const struct_nk_allocator = extern struct {
    userdata: nk_handle,
    alloc: nk_plugin_alloc,
    free: nk_plugin_free,
};
pub const NK_BUFFER_FIXED: c_int = 0;
pub const NK_BUFFER_DYNAMIC: c_int = 1;
pub const enum_nk_allocation_type = c_uint;
pub const struct_nk_memory = extern struct {
    ptr: ?*anyopaque,
    size: nk_size,
};
pub const struct_nk_buffer = extern struct {
    marker: [2]struct_nk_buffer_marker,
    pool: struct_nk_allocator,
    type: enum_nk_allocation_type,
    memory: struct_nk_memory,
    grow_factor: f32,
    allocated: nk_size,
    needed: nk_size,
    calls: nk_size,
    size: nk_size,
};
pub const struct_nk_rect = extern struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};
pub const struct_nk_command_buffer = extern struct {
    base: [*c]struct_nk_buffer,
    clip: struct_nk_rect,
    use_clipping: c_int,
    userdata: nk_handle,
    begin: nk_size,
    end: nk_size,
    last: nk_size,
};
pub const struct_nk_draw_command = extern struct {
    elem_count: c_uint,
    clip_rect: struct_nk_rect,
    texture: nk_handle,
};
pub const NK_ANTI_ALIASING_OFF: c_int = 0;
pub const NK_ANTI_ALIASING_ON: c_int = 1;
pub const enum_nk_anti_aliasing = c_uint;
pub const struct_nk_vec2 = extern struct {
    x: f32,
    y: f32,
};
pub const struct_nk_draw_null_texture = extern struct {
    texture: nk_handle,
    uv: struct_nk_vec2,
};
pub const NK_VERTEX_POSITION: c_int = 0;
pub const NK_VERTEX_COLOR: c_int = 1;
pub const NK_VERTEX_TEXCOORD: c_int = 2;
pub const NK_VERTEX_ATTRIBUTE_COUNT: c_int = 3;
pub const enum_nk_draw_vertex_layout_attribute = c_uint;
pub const NK_FORMAT_SCHAR: c_int = 0;
pub const NK_FORMAT_SSHORT: c_int = 1;
pub const NK_FORMAT_SINT: c_int = 2;
pub const NK_FORMAT_UCHAR: c_int = 3;
pub const NK_FORMAT_USHORT: c_int = 4;
pub const NK_FORMAT_UINT: c_int = 5;
pub const NK_FORMAT_FLOAT: c_int = 6;
pub const NK_FORMAT_DOUBLE: c_int = 7;
pub const NK_FORMAT_COLOR_BEGIN: c_int = 8;
pub const NK_FORMAT_R8G8B8: c_int = 8;
pub const NK_FORMAT_R16G15B16: c_int = 9;
pub const NK_FORMAT_R32G32B32: c_int = 10;
pub const NK_FORMAT_R8G8B8A8: c_int = 11;
pub const NK_FORMAT_B8G8R8A8: c_int = 12;
pub const NK_FORMAT_R16G15B16A16: c_int = 13;
pub const NK_FORMAT_R32G32B32A32: c_int = 14;
pub const NK_FORMAT_R32G32B32A32_FLOAT: c_int = 15;
pub const NK_FORMAT_R32G32B32A32_DOUBLE: c_int = 16;
pub const NK_FORMAT_RGB32: c_int = 17;
pub const NK_FORMAT_RGBA32: c_int = 18;
pub const NK_FORMAT_COLOR_END: c_int = 18;
pub const NK_FORMAT_COUNT: c_int = 19;
pub const enum_nk_draw_vertex_layout_format = c_uint;
pub const struct_nk_draw_vertex_layout_element = extern struct {
    attribute: enum_nk_draw_vertex_layout_attribute,
    format: enum_nk_draw_vertex_layout_format,
    offset: nk_size,
};
pub const struct_nk_convert_config = extern struct {
    global_alpha: f32,
    line_AA: enum_nk_anti_aliasing,
    shape_AA: enum_nk_anti_aliasing,
    circle_segment_count: c_uint,
    arc_segment_count: c_uint,
    curve_segment_count: c_uint,
    @"null": struct_nk_draw_null_texture,
    vertex_layout: [*c]const struct_nk_draw_vertex_layout_element,
    vertex_size: nk_size,
    vertex_alignment: nk_size,
};
pub const NK_STYLE_ITEM_COLOR: c_int = 0;
pub const NK_STYLE_ITEM_IMAGE: c_int = 1;
pub const NK_STYLE_ITEM_NINE_SLICE: c_int = 2;
pub const enum_nk_style_item_type = c_uint;
pub const struct_nk_color = extern struct {
    r: nk_byte,
    g: nk_byte,
    b: nk_byte,
    a: nk_byte,
};
pub const struct_nk_image = extern struct {
    handle: nk_handle,
    w: nk_ushort,
    h: nk_ushort,
    region: [4]nk_ushort,
};
pub const struct_nk_nine_slice = extern struct {
    img: struct_nk_image,
    l: nk_ushort,
    t: nk_ushort,
    r: nk_ushort,
    b: nk_ushort,
};
pub const union_nk_style_item_data = extern union {
    color: struct_nk_color,
    image: struct_nk_image,
    slice: struct_nk_nine_slice,
};
pub const struct_nk_style_item = extern struct {
    type: enum_nk_style_item_type,
    data: union_nk_style_item_data,
};
pub const nk_plugin_paste = ?fn (nk_handle, [*c]struct_nk_text_edit) callconv(.C) void;
pub const nk_plugin_copy = ?fn (nk_handle, [*c]const u8, c_int) callconv(.C) void;
pub const struct_nk_clipboard = extern struct {
    userdata: nk_handle,
    paste: nk_plugin_paste,
    copy: nk_plugin_copy,
};
pub const struct_nk_str = extern struct {
    buffer: struct_nk_buffer,
    len: c_int,
};
pub const nk_plugin_filter = ?fn ([*c]const struct_nk_text_edit, nk_rune) callconv(.C) nk_bool;
pub const struct_nk_text_undo_record = extern struct {
    where: c_int,
    insert_length: c_short,
    delete_length: c_short,
    char_storage: c_short,
};
pub const struct_nk_text_undo_state = extern struct {
    undo_rec: [99]struct_nk_text_undo_record,
    undo_char: [999]nk_rune,
    undo_point: c_short,
    redo_point: c_short,
    undo_char_point: c_short,
    redo_char_point: c_short,
};
pub const struct_nk_text_edit = extern struct {
    clip: struct_nk_clipboard,
    string: struct_nk_str,
    filter: nk_plugin_filter,
    scrollbar: struct_nk_vec2,
    cursor: c_int,
    select_start: c_int,
    select_end: c_int,
    mode: u8,
    cursor_at_end_of_line: u8,
    initialized: u8,
    has_preferred_x: u8,
    single_line: u8,
    active: u8,
    padding1: u8,
    preferred_x: f32,
    undo: struct_nk_text_undo_state,
};
pub const struct_nk_draw_list = extern struct {
    clip_rect: struct_nk_rect,
    circle_vtx: [12]struct_nk_vec2,
    config: struct_nk_convert_config,
    buffer: [*c]struct_nk_buffer,
    vertices: [*c]struct_nk_buffer,
    elements: [*c]struct_nk_buffer,
    element_count: c_uint,
    vertex_count: c_uint,
    cmd_count: c_uint,
    cmd_offset: nk_size,
    path_count: c_uint,
    path_offset: c_uint,
    line_AA: enum_nk_anti_aliasing,
    shape_AA: enum_nk_anti_aliasing,
};
pub const nk_text_width_f = ?fn (nk_handle, f32, [*c]const u8, c_int) callconv(.C) f32;
pub const struct_nk_user_font_glyph = extern struct {
    uv: [2]struct_nk_vec2,
    offset: struct_nk_vec2,
    width: f32,
    height: f32,
    xadvance: f32,
};
pub const nk_query_font_glyph_f = ?fn (nk_handle, f32, [*c]struct_nk_user_font_glyph, nk_rune, nk_rune) callconv(.C) void;
pub const struct_nk_user_font = extern struct {
    userdata: nk_handle,
    height: f32,
    width: nk_text_width_f,
    query: nk_query_font_glyph_f,
    texture: nk_handle,
};
pub const NK_PANEL_NONE: c_int = 0;
pub const NK_PANEL_WINDOW: c_int = 1;
pub const NK_PANEL_GROUP: c_int = 2;
pub const NK_PANEL_POPUP: c_int = 4;
pub const NK_PANEL_CONTEXTUAL: c_int = 16;
pub const NK_PANEL_COMBO: c_int = 32;
pub const NK_PANEL_MENU: c_int = 64;
pub const NK_PANEL_TOOLTIP: c_int = 128;
pub const enum_nk_panel_type = c_uint;
pub const struct_nk_scroll = extern struct {
    x: nk_uint,
    y: nk_uint,
};
pub const struct_nk_menu_state = extern struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    offset: struct_nk_scroll,
};
pub const NK_LAYOUT_DYNAMIC_FIXED: c_int = 0;
pub const NK_LAYOUT_DYNAMIC_ROW: c_int = 1;
pub const NK_LAYOUT_DYNAMIC_FREE: c_int = 2;
pub const NK_LAYOUT_DYNAMIC: c_int = 3;
pub const NK_LAYOUT_STATIC_FIXED: c_int = 4;
pub const NK_LAYOUT_STATIC_ROW: c_int = 5;
pub const NK_LAYOUT_STATIC_FREE: c_int = 6;
pub const NK_LAYOUT_STATIC: c_int = 7;
pub const NK_LAYOUT_TEMPLATE: c_int = 8;
pub const NK_LAYOUT_COUNT: c_int = 9;
pub const enum_nk_panel_row_layout_type = c_uint;
pub const struct_nk_row_layout = extern struct {
    type: enum_nk_panel_row_layout_type,
    index: c_int,
    height: f32,
    min_height: f32,
    columns: c_int,
    ratio: [*c]const f32,
    item_width: f32,
    item_height: f32,
    item_offset: f32,
    filled: f32,
    item: struct_nk_rect,
    tree_depth: c_int,
    templates: [16]f32,
};
pub const NK_CHART_LINES: c_int = 0;
pub const NK_CHART_COLUMN: c_int = 1;
pub const NK_CHART_MAX: c_int = 2;
pub const enum_nk_chart_type = c_uint;
pub const struct_nk_chart_slot = extern struct {
    type: enum_nk_chart_type,
    color: struct_nk_color,
    highlight: struct_nk_color,
    min: f32,
    max: f32,
    range: f32,
    count: c_int,
    last: struct_nk_vec2,
    index: c_int,
};
pub const struct_nk_chart = extern struct {
    slot: c_int,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    slots: [4]struct_nk_chart_slot,
};
pub const struct_nk_panel = extern struct {
    type: enum_nk_panel_type,
    flags: nk_flags,
    bounds: struct_nk_rect,
    offset_x: [*c]nk_uint,
    offset_y: [*c]nk_uint,
    at_x: f32,
    at_y: f32,
    max_x: f32,
    footer_height: f32,
    header_height: f32,
    border: f32,
    has_scrolling: c_uint,
    clip: struct_nk_rect,
    menu: struct_nk_menu_state,
    row: struct_nk_row_layout,
    chart: struct_nk_chart,
    buffer: [*c]struct_nk_command_buffer,
    parent: [*c]struct_nk_panel,
};
pub const struct_nk_key = extern struct {
    down: nk_bool,
    clicked: c_uint,
};
pub const struct_nk_keyboard = extern struct {
    keys: [30]struct_nk_key,
    text: [16]u8,
    text_len: c_int,
};
pub const struct_nk_mouse_button = extern struct {
    down: nk_bool,
    clicked: c_uint,
    clicked_pos: struct_nk_vec2,
};
pub const struct_nk_mouse = extern struct {
    buttons: [4]struct_nk_mouse_button,
    pos: struct_nk_vec2,
    prev: struct_nk_vec2,
    delta: struct_nk_vec2,
    scroll_delta: struct_nk_vec2,
    grab: u8,
    grabbed: u8,
    ungrab: u8,
};
pub const struct_nk_input = extern struct {
    keyboard: struct_nk_keyboard,
    mouse: struct_nk_mouse,
};
pub const struct_nk_cursor = extern struct {
    img: struct_nk_image,
    size: struct_nk_vec2,
    offset: struct_nk_vec2,
};
pub const struct_nk_style_text = extern struct {
    color: struct_nk_color,
    padding: struct_nk_vec2,
};
pub const struct_nk_style_button = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    active: struct_nk_style_item,
    border_color: struct_nk_color,
    text_background: struct_nk_color,
    text_normal: struct_nk_color,
    text_hover: struct_nk_color,
    text_active: struct_nk_color,
    text_alignment: nk_flags,
    border: f32,
    rounding: f32,
    padding: struct_nk_vec2,
    image_padding: struct_nk_vec2,
    touch_padding: struct_nk_vec2,
    userdata: nk_handle,
    draw_begin: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
    draw_end: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
};
pub const struct_nk_style_toggle = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    active: struct_nk_style_item,
    border_color: struct_nk_color,
    cursor_normal: struct_nk_style_item,
    cursor_hover: struct_nk_style_item,
    text_normal: struct_nk_color,
    text_hover: struct_nk_color,
    text_active: struct_nk_color,
    text_background: struct_nk_color,
    text_alignment: nk_flags,
    padding: struct_nk_vec2,
    touch_padding: struct_nk_vec2,
    spacing: f32,
    border: f32,
    userdata: nk_handle,
    draw_begin: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
    draw_end: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
};
pub const struct_nk_style_selectable = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    pressed: struct_nk_style_item,
    normal_active: struct_nk_style_item,
    hover_active: struct_nk_style_item,
    pressed_active: struct_nk_style_item,
    text_normal: struct_nk_color,
    text_hover: struct_nk_color,
    text_pressed: struct_nk_color,
    text_normal_active: struct_nk_color,
    text_hover_active: struct_nk_color,
    text_pressed_active: struct_nk_color,
    text_background: struct_nk_color,
    text_alignment: nk_flags,
    rounding: f32,
    padding: struct_nk_vec2,
    touch_padding: struct_nk_vec2,
    image_padding: struct_nk_vec2,
    userdata: nk_handle,
    draw_begin: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
    draw_end: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
};
pub const NK_SYMBOL_NONE: c_int = 0;
pub const NK_SYMBOL_X: c_int = 1;
pub const NK_SYMBOL_UNDERSCORE: c_int = 2;
pub const NK_SYMBOL_CIRCLE_SOLID: c_int = 3;
pub const NK_SYMBOL_CIRCLE_OUTLINE: c_int = 4;
pub const NK_SYMBOL_RECT_SOLID: c_int = 5;
pub const NK_SYMBOL_RECT_OUTLINE: c_int = 6;
pub const NK_SYMBOL_TRIANGLE_UP: c_int = 7;
pub const NK_SYMBOL_TRIANGLE_DOWN: c_int = 8;
pub const NK_SYMBOL_TRIANGLE_LEFT: c_int = 9;
pub const NK_SYMBOL_TRIANGLE_RIGHT: c_int = 10;
pub const NK_SYMBOL_PLUS: c_int = 11;
pub const NK_SYMBOL_MINUS: c_int = 12;
pub const NK_SYMBOL_MAX: c_int = 13;
pub const enum_nk_symbol_type = c_uint;
pub const struct_nk_style_slider = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    active: struct_nk_style_item,
    border_color: struct_nk_color,
    bar_normal: struct_nk_color,
    bar_hover: struct_nk_color,
    bar_active: struct_nk_color,
    bar_filled: struct_nk_color,
    cursor_normal: struct_nk_style_item,
    cursor_hover: struct_nk_style_item,
    cursor_active: struct_nk_style_item,
    border: f32,
    rounding: f32,
    bar_height: f32,
    padding: struct_nk_vec2,
    spacing: struct_nk_vec2,
    cursor_size: struct_nk_vec2,
    show_buttons: c_int,
    inc_button: struct_nk_style_button,
    dec_button: struct_nk_style_button,
    inc_symbol: enum_nk_symbol_type,
    dec_symbol: enum_nk_symbol_type,
    userdata: nk_handle,
    draw_begin: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
    draw_end: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
};
pub const struct_nk_style_progress = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    active: struct_nk_style_item,
    border_color: struct_nk_color,
    cursor_normal: struct_nk_style_item,
    cursor_hover: struct_nk_style_item,
    cursor_active: struct_nk_style_item,
    cursor_border_color: struct_nk_color,
    rounding: f32,
    border: f32,
    cursor_border: f32,
    cursor_rounding: f32,
    padding: struct_nk_vec2,
    userdata: nk_handle,
    draw_begin: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
    draw_end: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
};
pub const struct_nk_style_scrollbar = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    active: struct_nk_style_item,
    border_color: struct_nk_color,
    cursor_normal: struct_nk_style_item,
    cursor_hover: struct_nk_style_item,
    cursor_active: struct_nk_style_item,
    cursor_border_color: struct_nk_color,
    border: f32,
    rounding: f32,
    border_cursor: f32,
    rounding_cursor: f32,
    padding: struct_nk_vec2,
    show_buttons: c_int,
    inc_button: struct_nk_style_button,
    dec_button: struct_nk_style_button,
    inc_symbol: enum_nk_symbol_type,
    dec_symbol: enum_nk_symbol_type,
    userdata: nk_handle,
    draw_begin: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
    draw_end: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
};
pub const struct_nk_style_edit = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    active: struct_nk_style_item,
    border_color: struct_nk_color,
    scrollbar: struct_nk_style_scrollbar,
    cursor_normal: struct_nk_color,
    cursor_hover: struct_nk_color,
    cursor_text_normal: struct_nk_color,
    cursor_text_hover: struct_nk_color,
    text_normal: struct_nk_color,
    text_hover: struct_nk_color,
    text_active: struct_nk_color,
    selected_normal: struct_nk_color,
    selected_hover: struct_nk_color,
    selected_text_normal: struct_nk_color,
    selected_text_hover: struct_nk_color,
    border: f32,
    rounding: f32,
    cursor_size: f32,
    scrollbar_size: struct_nk_vec2,
    padding: struct_nk_vec2,
    row_padding: f32,
};
pub const struct_nk_style_property = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    active: struct_nk_style_item,
    border_color: struct_nk_color,
    label_normal: struct_nk_color,
    label_hover: struct_nk_color,
    label_active: struct_nk_color,
    sym_left: enum_nk_symbol_type,
    sym_right: enum_nk_symbol_type,
    border: f32,
    rounding: f32,
    padding: struct_nk_vec2,
    edit: struct_nk_style_edit,
    inc_button: struct_nk_style_button,
    dec_button: struct_nk_style_button,
    userdata: nk_handle,
    draw_begin: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
    draw_end: ?fn ([*c]struct_nk_command_buffer, nk_handle) callconv(.C) void,
};
pub const struct_nk_style_chart = extern struct {
    background: struct_nk_style_item,
    border_color: struct_nk_color,
    selected_color: struct_nk_color,
    color: struct_nk_color,
    border: f32,
    rounding: f32,
    padding: struct_nk_vec2,
};
pub const struct_nk_style_tab = extern struct {
    background: struct_nk_style_item,
    border_color: struct_nk_color,
    text: struct_nk_color,
    tab_maximize_button: struct_nk_style_button,
    tab_minimize_button: struct_nk_style_button,
    node_maximize_button: struct_nk_style_button,
    node_minimize_button: struct_nk_style_button,
    sym_minimize: enum_nk_symbol_type,
    sym_maximize: enum_nk_symbol_type,
    border: f32,
    rounding: f32,
    indent: f32,
    padding: struct_nk_vec2,
    spacing: struct_nk_vec2,
};
pub const struct_nk_style_combo = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    active: struct_nk_style_item,
    border_color: struct_nk_color,
    label_normal: struct_nk_color,
    label_hover: struct_nk_color,
    label_active: struct_nk_color,
    symbol_normal: struct_nk_color,
    symbol_hover: struct_nk_color,
    symbol_active: struct_nk_color,
    button: struct_nk_style_button,
    sym_normal: enum_nk_symbol_type,
    sym_hover: enum_nk_symbol_type,
    sym_active: enum_nk_symbol_type,
    border: f32,
    rounding: f32,
    content_padding: struct_nk_vec2,
    button_padding: struct_nk_vec2,
    spacing: struct_nk_vec2,
};
pub const NK_HEADER_LEFT: c_int = 0;
pub const NK_HEADER_RIGHT: c_int = 1;
pub const enum_nk_style_header_align = c_uint;
pub const struct_nk_style_window_header = extern struct {
    normal: struct_nk_style_item,
    hover: struct_nk_style_item,
    active: struct_nk_style_item,
    close_button: struct_nk_style_button,
    minimize_button: struct_nk_style_button,
    close_symbol: enum_nk_symbol_type,
    minimize_symbol: enum_nk_symbol_type,
    maximize_symbol: enum_nk_symbol_type,
    label_normal: struct_nk_color,
    label_hover: struct_nk_color,
    label_active: struct_nk_color,
    @"align": enum_nk_style_header_align,
    padding: struct_nk_vec2,
    label_padding: struct_nk_vec2,
    spacing: struct_nk_vec2,
};
pub const struct_nk_style_window = extern struct {
    header: struct_nk_style_window_header,
    fixed_background: struct_nk_style_item,
    background: struct_nk_color,
    border_color: struct_nk_color,
    popup_border_color: struct_nk_color,
    combo_border_color: struct_nk_color,
    contextual_border_color: struct_nk_color,
    menu_border_color: struct_nk_color,
    group_border_color: struct_nk_color,
    tooltip_border_color: struct_nk_color,
    scaler: struct_nk_style_item,
    border: f32,
    combo_border: f32,
    contextual_border: f32,
    menu_border: f32,
    group_border: f32,
    tooltip_border: f32,
    popup_border: f32,
    min_row_height_padding: f32,
    rounding: f32,
    spacing: struct_nk_vec2,
    scrollbar_size: struct_nk_vec2,
    min_size: struct_nk_vec2,
    padding: struct_nk_vec2,
    group_padding: struct_nk_vec2,
    popup_padding: struct_nk_vec2,
    combo_padding: struct_nk_vec2,
    contextual_padding: struct_nk_vec2,
    menu_padding: struct_nk_vec2,
    tooltip_padding: struct_nk_vec2,
};
pub const struct_nk_style = extern struct {
    font: [*c]const struct_nk_user_font,
    cursors: [7][*c]const struct_nk_cursor,
    cursor_active: [*c]const struct_nk_cursor,
    cursor_last: [*c]struct_nk_cursor,
    cursor_visible: c_int,
    text: struct_nk_style_text,
    button: struct_nk_style_button,
    contextual_button: struct_nk_style_button,
    menu_button: struct_nk_style_button,
    option: struct_nk_style_toggle,
    checkbox: struct_nk_style_toggle,
    selectable: struct_nk_style_selectable,
    slider: struct_nk_style_slider,
    progress: struct_nk_style_progress,
    property: struct_nk_style_property,
    edit: struct_nk_style_edit,
    chart: struct_nk_style_chart,
    scrollh: struct_nk_style_scrollbar,
    scrollv: struct_nk_style_scrollbar,
    tab: struct_nk_style_tab,
    combo: struct_nk_style_combo,
    window: struct_nk_style_window,
};
pub const NK_BUTTON_DEFAULT: c_int = 0;
pub const NK_BUTTON_REPEATER: c_int = 1;
pub const enum_nk_button_behavior = c_uint;
pub const struct_nk_config_stack_style_item_element = extern struct {
    address: [*c]struct_nk_style_item,
    old_value: struct_nk_style_item,
};
pub const struct_nk_config_stack_style_item = extern struct {
    head: c_int,
    elements: [16]struct_nk_config_stack_style_item_element,
};
pub const struct_nk_config_stack_float_element = extern struct {
    address: [*c]f32,
    old_value: f32,
};
pub const struct_nk_config_stack_float = extern struct {
    head: c_int,
    elements: [32]struct_nk_config_stack_float_element,
};
pub const struct_nk_config_stack_vec2_element = extern struct {
    address: [*c]struct_nk_vec2,
    old_value: struct_nk_vec2,
};
pub const struct_nk_config_stack_vec2 = extern struct {
    head: c_int,
    elements: [16]struct_nk_config_stack_vec2_element,
};
pub const struct_nk_config_stack_flags_element = extern struct {
    address: [*c]nk_flags,
    old_value: nk_flags,
};
pub const struct_nk_config_stack_flags = extern struct {
    head: c_int,
    elements: [32]struct_nk_config_stack_flags_element,
};
pub const struct_nk_config_stack_color_element = extern struct {
    address: [*c]struct_nk_color,
    old_value: struct_nk_color,
};
pub const struct_nk_config_stack_color = extern struct {
    head: c_int,
    elements: [32]struct_nk_config_stack_color_element,
};
pub const struct_nk_config_stack_user_font_element = extern struct {
    address: [*c][*c]const struct_nk_user_font,
    old_value: [*c]const struct_nk_user_font,
};
pub const struct_nk_config_stack_user_font = extern struct {
    head: c_int,
    elements: [8]struct_nk_config_stack_user_font_element,
};
pub const struct_nk_config_stack_button_behavior_element = extern struct {
    address: [*c]enum_nk_button_behavior,
    old_value: enum_nk_button_behavior,
};
pub const struct_nk_config_stack_button_behavior = extern struct {
    head: c_int,
    elements: [8]struct_nk_config_stack_button_behavior_element,
};
pub const struct_nk_configuration_stacks = extern struct {
    style_items: struct_nk_config_stack_style_item,
    floats: struct_nk_config_stack_float,
    vectors: struct_nk_config_stack_vec2,
    flags: struct_nk_config_stack_flags,
    colors: struct_nk_config_stack_color,
    fonts: struct_nk_config_stack_user_font,
    button_behaviors: struct_nk_config_stack_button_behavior,
};
pub const struct_nk_table = extern struct {
    seq: c_uint,
    size: c_uint,
    keys: [59]nk_hash,
    values: [59]nk_uint,
    next: [*c]struct_nk_table,
    prev: [*c]struct_nk_table,
};
pub const struct_nk_property_state = extern struct {
    active: c_int,
    prev: c_int,
    buffer: [64]u8,
    length: c_int,
    cursor: c_int,
    select_start: c_int,
    select_end: c_int,
    name: nk_hash,
    seq: c_uint,
    old: c_uint,
    state: c_int,
};
pub const struct_nk_popup_buffer = extern struct {
    begin: nk_size,
    parent: nk_size,
    last: nk_size,
    end: nk_size,
    active: nk_bool,
};
pub const struct_nk_popup_state = extern struct {
    win: [*c]struct_nk_window,
    type: enum_nk_panel_type,
    buf: struct_nk_popup_buffer,
    name: nk_hash,
    active: nk_bool,
    combo_count: c_uint,
    con_count: c_uint,
    con_old: c_uint,
    active_con: c_uint,
    header: struct_nk_rect,
};
pub const struct_nk_edit_state = extern struct {
    name: nk_hash,
    seq: c_uint,
    old: c_uint,
    active: c_int,
    prev: c_int,
    cursor: c_int,
    sel_start: c_int,
    sel_end: c_int,
    scrollbar: struct_nk_scroll,
    mode: u8,
    single_line: u8,
};
pub const struct_nk_window = extern struct {
    seq: c_uint,
    name: nk_hash,
    name_string: [64]u8,
    flags: nk_flags,
    bounds: struct_nk_rect,
    scrollbar: struct_nk_scroll,
    buffer: struct_nk_command_buffer,
    layout: [*c]struct_nk_panel,
    scrollbar_hiding_timer: f32,
    property: struct_nk_property_state,
    popup: struct_nk_popup_state,
    edit: struct_nk_edit_state,
    scrolled: c_uint,
    tables: [*c]struct_nk_table,
    table_count: c_uint,
    next: [*c]struct_nk_window,
    prev: [*c]struct_nk_window,
    parent: [*c]struct_nk_window,
};
pub const union_nk_page_data = extern union {
    tbl: struct_nk_table,
    pan: struct_nk_panel,
    win: struct_nk_window,
};
pub const struct_nk_page_element = extern struct {
    data: union_nk_page_data,
    next: [*c]struct_nk_page_element,
    prev: [*c]struct_nk_page_element,
};
pub const struct_nk_page = extern struct {
    size: c_uint,
    next: [*c]struct_nk_page,
    win: [1]struct_nk_page_element,
};
pub const struct_nk_pool = extern struct {
    alloc: struct_nk_allocator,
    type: enum_nk_allocation_type,
    page_count: c_uint,
    pages: [*c]struct_nk_page,
    freelist: [*c]struct_nk_page_element,
    capacity: c_uint,
    size: nk_size,
    cap: nk_size,
};
pub const struct_nk_context = extern struct {
    input: struct_nk_input,
    style: struct_nk_style,
    memory: struct_nk_buffer,
    clip: struct_nk_clipboard,
    last_widget_state: nk_flags,
    button_behavior: enum_nk_button_behavior,
    stacks: struct_nk_configuration_stacks,
    delta_time_seconds: f32,
    draw_list: struct_nk_draw_list,
    text_edit: struct_nk_text_edit,
    overlay: struct_nk_command_buffer,
    build: c_int,
    use_pool: c_int,
    pool: struct_nk_pool,
    begin: [*c]struct_nk_window,
    end: [*c]struct_nk_window,
    active: [*c]struct_nk_window,
    current: [*c]struct_nk_window,
    freelist: [*c]struct_nk_page_element,
    count: c_uint,
    seq: c_uint,
};
pub const struct_nk_style_slide = opaque {};
pub const nk_false: c_int = 0;
pub const nk_true: c_int = 1;
const enum_unnamed_1 = c_uint;
pub const struct_nk_colorf = extern struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};
pub const struct_nk_vec2i = extern struct {
    x: c_short,
    y: c_short,
};
pub const struct_nk_recti = extern struct {
    x: c_short,
    y: c_short,
    w: c_short,
    h: c_short,
};
pub const nk_glyph = [4]u8;
pub const nk_handle = extern union {
    ptr: ?*anyopaque,
    id: c_int,
};
pub const NK_UP: c_int = 0;
pub const NK_RIGHT: c_int = 1;
pub const NK_DOWN: c_int = 2;
pub const NK_LEFT: c_int = 3;
pub const enum_nk_heading = c_uint;
pub const NK_FIXED: c_int = 0;
pub const NK_MODIFIABLE: c_int = 1;
pub const enum_nk_modify = c_uint;
pub const NK_VERTICAL: c_int = 0;
pub const NK_HORIZONTAL: c_int = 1;
pub const enum_nk_orientation = c_uint;
pub const NK_MINIMIZED: c_int = 0;
pub const NK_MAXIMIZED: c_int = 1;
pub const enum_nk_collapse_states = c_uint;
pub const NK_HIDDEN: c_int = 0;
pub const NK_SHOWN: c_int = 1;
pub const enum_nk_show_states = c_uint;
pub const NK_CHART_HOVERING: c_int = 1;
pub const NK_CHART_CLICKED: c_int = 2;
pub const enum_nk_chart_event = c_uint;
pub const NK_RGB: c_int = 0;
pub const NK_RGBA: c_int = 1;
pub const enum_nk_color_format = c_uint;
pub const NK_POPUP_STATIC: c_int = 0;
pub const NK_POPUP_DYNAMIC: c_int = 1;
pub const enum_nk_popup_type = c_uint;
pub const NK_DYNAMIC: c_int = 0;
pub const NK_STATIC: c_int = 1;
pub const enum_nk_layout_format = c_uint;
pub const NK_TREE_NODE: c_int = 0;
pub const NK_TREE_TAB: c_int = 1;
pub const enum_nk_tree_type = c_uint;
pub extern fn nk_init_fixed([*c]struct_nk_context, memory: ?*anyopaque, size: nk_size, [*c]const struct_nk_user_font) nk_bool;
pub extern fn nk_init([*c]struct_nk_context, [*c]struct_nk_allocator, [*c]const struct_nk_user_font) nk_bool;
pub extern fn nk_init_custom([*c]struct_nk_context, cmds: [*c]struct_nk_buffer, pool: [*c]struct_nk_buffer, [*c]const struct_nk_user_font) nk_bool;
pub extern fn nk_clear([*c]struct_nk_context) void;
pub extern fn nk_free([*c]struct_nk_context) void;
pub const NK_KEY_NONE: c_int = 0;
pub const NK_KEY_SHIFT: c_int = 1;
pub const NK_KEY_CTRL: c_int = 2;
pub const NK_KEY_DEL: c_int = 3;
pub const NK_KEY_ENTER: c_int = 4;
pub const NK_KEY_TAB: c_int = 5;
pub const NK_KEY_BACKSPACE: c_int = 6;
pub const NK_KEY_COPY: c_int = 7;
pub const NK_KEY_CUT: c_int = 8;
pub const NK_KEY_PASTE: c_int = 9;
pub const NK_KEY_UP: c_int = 10;
pub const NK_KEY_DOWN: c_int = 11;
pub const NK_KEY_LEFT: c_int = 12;
pub const NK_KEY_RIGHT: c_int = 13;
pub const NK_KEY_TEXT_INSERT_MODE: c_int = 14;
pub const NK_KEY_TEXT_REPLACE_MODE: c_int = 15;
pub const NK_KEY_TEXT_RESET_MODE: c_int = 16;
pub const NK_KEY_TEXT_LINE_START: c_int = 17;
pub const NK_KEY_TEXT_LINE_END: c_int = 18;
pub const NK_KEY_TEXT_START: c_int = 19;
pub const NK_KEY_TEXT_END: c_int = 20;
pub const NK_KEY_TEXT_UNDO: c_int = 21;
pub const NK_KEY_TEXT_REDO: c_int = 22;
pub const NK_KEY_TEXT_SELECT_ALL: c_int = 23;
pub const NK_KEY_TEXT_WORD_LEFT: c_int = 24;
pub const NK_KEY_TEXT_WORD_RIGHT: c_int = 25;
pub const NK_KEY_SCROLL_START: c_int = 26;
pub const NK_KEY_SCROLL_END: c_int = 27;
pub const NK_KEY_SCROLL_DOWN: c_int = 28;
pub const NK_KEY_SCROLL_UP: c_int = 29;
pub const NK_KEY_MAX: c_int = 30;
pub const enum_nk_keys = c_uint;
pub const NK_BUTTON_LEFT: c_int = 0;
pub const NK_BUTTON_MIDDLE: c_int = 1;
pub const NK_BUTTON_RIGHT: c_int = 2;
pub const NK_BUTTON_DOUBLE: c_int = 3;
pub const NK_BUTTON_MAX: c_int = 4;
pub const enum_nk_buttons = c_uint;
pub extern fn nk_input_begin([*c]struct_nk_context) void;
pub extern fn nk_input_motion([*c]struct_nk_context, x: c_int, y: c_int) void;
pub extern fn nk_input_key([*c]struct_nk_context, enum_nk_keys, down: nk_bool) void;
pub extern fn nk_input_button([*c]struct_nk_context, enum_nk_buttons, x: c_int, y: c_int, down: nk_bool) void;
pub extern fn nk_input_scroll([*c]struct_nk_context, val: struct_nk_vec2) void;
pub extern fn nk_input_char([*c]struct_nk_context, u8) void;
pub extern fn nk_input_glyph([*c]struct_nk_context, [*c]const u8) void;
pub extern fn nk_input_unicode([*c]struct_nk_context, nk_rune) void;
pub extern fn nk_input_end([*c]struct_nk_context) void;
pub const NK_CONVERT_SUCCESS: c_int = 0;
pub const NK_CONVERT_INVALID_PARAM: c_int = 1;
pub const NK_CONVERT_COMMAND_BUFFER_FULL: c_int = 2;
pub const NK_CONVERT_VERTEX_BUFFER_FULL: c_int = 4;
pub const NK_CONVERT_ELEMENT_BUFFER_FULL: c_int = 8;
pub const enum_nk_convert_result = c_uint;
pub const NK_COMMAND_NOP: c_int = 0;
pub const NK_COMMAND_SCISSOR: c_int = 1;
pub const NK_COMMAND_LINE: c_int = 2;
pub const NK_COMMAND_CURVE: c_int = 3;
pub const NK_COMMAND_RECT: c_int = 4;
pub const NK_COMMAND_RECT_FILLED: c_int = 5;
pub const NK_COMMAND_RECT_MULTI_COLOR: c_int = 6;
pub const NK_COMMAND_CIRCLE: c_int = 7;
pub const NK_COMMAND_CIRCLE_FILLED: c_int = 8;
pub const NK_COMMAND_ARC: c_int = 9;
pub const NK_COMMAND_ARC_FILLED: c_int = 10;
pub const NK_COMMAND_TRIANGLE: c_int = 11;
pub const NK_COMMAND_TRIANGLE_FILLED: c_int = 12;
pub const NK_COMMAND_POLYGON: c_int = 13;
pub const NK_COMMAND_POLYGON_FILLED: c_int = 14;
pub const NK_COMMAND_POLYLINE: c_int = 15;
pub const NK_COMMAND_TEXT: c_int = 16;
pub const NK_COMMAND_IMAGE: c_int = 17;
pub const NK_COMMAND_CUSTOM: c_int = 18;
pub const enum_nk_command_type = c_uint;
pub const struct_nk_command = extern struct {
    type: enum_nk_command_type,
    next: nk_size,
};
pub extern fn nk__begin([*c]struct_nk_context) [*c]const struct_nk_command;
pub extern fn nk__next([*c]struct_nk_context, [*c]const struct_nk_command) [*c]const struct_nk_command;
pub extern fn nk_convert([*c]struct_nk_context, cmds: [*c]struct_nk_buffer, vertices: [*c]struct_nk_buffer, elements: [*c]struct_nk_buffer, [*c]const struct_nk_convert_config) nk_flags;
pub extern fn nk__draw_begin([*c]const struct_nk_context, [*c]const struct_nk_buffer) [*c]const struct_nk_draw_command;
pub extern fn nk__draw_end([*c]const struct_nk_context, [*c]const struct_nk_buffer) [*c]const struct_nk_draw_command;
pub extern fn nk__draw_next([*c]const struct_nk_draw_command, [*c]const struct_nk_buffer, [*c]const struct_nk_context) [*c]const struct_nk_draw_command;
pub const NK_WINDOW_BORDER: c_int = 1;
pub const NK_WINDOW_MOVABLE: c_int = 2;
pub const NK_WINDOW_SCALABLE: c_int = 4;
pub const NK_WINDOW_CLOSABLE: c_int = 8;
pub const NK_WINDOW_MINIMIZABLE: c_int = 16;
pub const NK_WINDOW_NO_SCROLLBAR: c_int = 32;
pub const NK_WINDOW_TITLE: c_int = 64;
pub const NK_WINDOW_SCROLL_AUTO_HIDE: c_int = 128;
pub const NK_WINDOW_BACKGROUND: c_int = 256;
pub const NK_WINDOW_SCALE_LEFT: c_int = 512;
pub const NK_WINDOW_NO_INPUT: c_int = 1024;
pub const enum_nk_panel_flags = c_uint;
pub extern fn nk_begin(ctx: [*c]struct_nk_context, title: [*c]const u8, bounds: struct_nk_rect, flags: nk_flags) nk_bool;
pub extern fn nk_begin_titled(ctx: [*c]struct_nk_context, name: [*c]const u8, title: [*c]const u8, bounds: struct_nk_rect, flags: nk_flags) nk_bool;
pub extern fn nk_end(ctx: [*c]struct_nk_context) void;
pub extern fn nk_window_find(ctx: [*c]struct_nk_context, name: [*c]const u8) [*c]struct_nk_window;
pub extern fn nk_window_get_bounds(ctx: [*c]const struct_nk_context) struct_nk_rect;
pub extern fn nk_window_get_position(ctx: [*c]const struct_nk_context) struct_nk_vec2;
pub extern fn nk_window_get_size([*c]const struct_nk_context) struct_nk_vec2;
pub extern fn nk_window_get_width([*c]const struct_nk_context) f32;
pub extern fn nk_window_get_height([*c]const struct_nk_context) f32;
pub extern fn nk_window_get_panel([*c]struct_nk_context) [*c]struct_nk_panel;
pub extern fn nk_window_get_content_region([*c]struct_nk_context) struct_nk_rect;
pub extern fn nk_window_get_content_region_min([*c]struct_nk_context) struct_nk_vec2;
pub extern fn nk_window_get_content_region_max([*c]struct_nk_context) struct_nk_vec2;
pub extern fn nk_window_get_content_region_size([*c]struct_nk_context) struct_nk_vec2;
pub extern fn nk_window_get_canvas([*c]struct_nk_context) [*c]struct_nk_command_buffer;
pub extern fn nk_window_get_scroll([*c]struct_nk_context, offset_x: [*c]nk_uint, offset_y: [*c]nk_uint) void;
pub extern fn nk_window_has_focus([*c]const struct_nk_context) nk_bool;
pub extern fn nk_window_is_hovered([*c]struct_nk_context) nk_bool;
pub extern fn nk_window_is_collapsed(ctx: [*c]struct_nk_context, name: [*c]const u8) nk_bool;
pub extern fn nk_window_is_closed([*c]struct_nk_context, [*c]const u8) nk_bool;
pub extern fn nk_window_is_hidden([*c]struct_nk_context, [*c]const u8) nk_bool;
pub extern fn nk_window_is_active([*c]struct_nk_context, [*c]const u8) nk_bool;
pub extern fn nk_window_is_any_hovered([*c]struct_nk_context) nk_bool;
pub extern fn nk_item_is_any_active([*c]struct_nk_context) nk_bool;
pub extern fn nk_window_set_bounds([*c]struct_nk_context, name: [*c]const u8, bounds: struct_nk_rect) void;
pub extern fn nk_window_set_position([*c]struct_nk_context, name: [*c]const u8, pos: struct_nk_vec2) void;
pub extern fn nk_window_set_size([*c]struct_nk_context, name: [*c]const u8, struct_nk_vec2) void;
pub extern fn nk_window_set_focus([*c]struct_nk_context, name: [*c]const u8) void;
pub extern fn nk_window_set_scroll([*c]struct_nk_context, offset_x: nk_uint, offset_y: nk_uint) void;
pub extern fn nk_window_close(ctx: [*c]struct_nk_context, name: [*c]const u8) void;
pub extern fn nk_window_collapse([*c]struct_nk_context, name: [*c]const u8, state: enum_nk_collapse_states) void;
pub extern fn nk_window_collapse_if([*c]struct_nk_context, name: [*c]const u8, enum_nk_collapse_states, cond: c_int) void;
pub extern fn nk_window_show([*c]struct_nk_context, name: [*c]const u8, enum_nk_show_states) void;
pub extern fn nk_window_show_if([*c]struct_nk_context, name: [*c]const u8, enum_nk_show_states, cond: c_int) void;
pub extern fn nk_layout_set_min_row_height([*c]struct_nk_context, height: f32) void;
pub extern fn nk_layout_reset_min_row_height([*c]struct_nk_context) void;
pub extern fn nk_layout_widget_bounds([*c]struct_nk_context) struct_nk_rect;
pub extern fn nk_layout_ratio_from_pixel([*c]struct_nk_context, pixel_width: f32) f32;
pub extern fn nk_layout_row_dynamic(ctx: [*c]struct_nk_context, height: f32, cols: c_int) void;
pub extern fn nk_layout_row_static(ctx: [*c]struct_nk_context, height: f32, item_width: c_int, cols: c_int) void;
pub extern fn nk_layout_row_begin(ctx: [*c]struct_nk_context, fmt: enum_nk_layout_format, row_height: f32, cols: c_int) void;
pub extern fn nk_layout_row_push([*c]struct_nk_context, value: f32) void;
pub extern fn nk_layout_row_end([*c]struct_nk_context) void;
pub extern fn nk_layout_row([*c]struct_nk_context, enum_nk_layout_format, height: f32, cols: c_int, ratio: [*c]const f32) void;
pub extern fn nk_layout_row_template_begin([*c]struct_nk_context, row_height: f32) void;
pub extern fn nk_layout_row_template_push_dynamic([*c]struct_nk_context) void;
pub extern fn nk_layout_row_template_push_variable([*c]struct_nk_context, min_width: f32) void;
pub extern fn nk_layout_row_template_push_static([*c]struct_nk_context, width: f32) void;
pub extern fn nk_layout_row_template_end([*c]struct_nk_context) void;
pub extern fn nk_layout_space_begin([*c]struct_nk_context, enum_nk_layout_format, height: f32, widget_count: c_int) void;
pub extern fn nk_layout_space_push([*c]struct_nk_context, bounds: struct_nk_rect) void;
pub extern fn nk_layout_space_end([*c]struct_nk_context) void;
pub extern fn nk_layout_space_bounds([*c]struct_nk_context) struct_nk_rect;
pub extern fn nk_layout_space_to_screen([*c]struct_nk_context, struct_nk_vec2) struct_nk_vec2;
pub extern fn nk_layout_space_to_local([*c]struct_nk_context, struct_nk_vec2) struct_nk_vec2;
pub extern fn nk_layout_space_rect_to_screen([*c]struct_nk_context, struct_nk_rect) struct_nk_rect;
pub extern fn nk_layout_space_rect_to_local([*c]struct_nk_context, struct_nk_rect) struct_nk_rect;
pub extern fn nk_spacer([*c]struct_nk_context) void;
pub extern fn nk_group_begin([*c]struct_nk_context, title: [*c]const u8, nk_flags) nk_bool;
pub extern fn nk_group_begin_titled([*c]struct_nk_context, name: [*c]const u8, title: [*c]const u8, nk_flags) nk_bool;
pub extern fn nk_group_end([*c]struct_nk_context) void;
pub extern fn nk_group_scrolled_offset_begin([*c]struct_nk_context, x_offset: [*c]nk_uint, y_offset: [*c]nk_uint, title: [*c]const u8, flags: nk_flags) nk_bool;
pub extern fn nk_group_scrolled_begin([*c]struct_nk_context, off: [*c]struct_nk_scroll, title: [*c]const u8, nk_flags) nk_bool;
pub extern fn nk_group_scrolled_end([*c]struct_nk_context) void;
pub extern fn nk_group_get_scroll([*c]struct_nk_context, id: [*c]const u8, x_offset: [*c]nk_uint, y_offset: [*c]nk_uint) void;
pub extern fn nk_group_set_scroll([*c]struct_nk_context, id: [*c]const u8, x_offset: nk_uint, y_offset: nk_uint) void;
pub extern fn nk_tree_push_hashed([*c]struct_nk_context, enum_nk_tree_type, title: [*c]const u8, initial_state: enum_nk_collapse_states, hash: [*c]const u8, len: c_int, seed: c_int) nk_bool;
pub extern fn nk_tree_image_push_hashed([*c]struct_nk_context, enum_nk_tree_type, struct_nk_image, title: [*c]const u8, initial_state: enum_nk_collapse_states, hash: [*c]const u8, len: c_int, seed: c_int) nk_bool;
pub extern fn nk_tree_pop([*c]struct_nk_context) void;
pub extern fn nk_tree_state_push([*c]struct_nk_context, enum_nk_tree_type, title: [*c]const u8, state: [*c]enum_nk_collapse_states) nk_bool;
pub extern fn nk_tree_state_image_push([*c]struct_nk_context, enum_nk_tree_type, struct_nk_image, title: [*c]const u8, state: [*c]enum_nk_collapse_states) nk_bool;
pub extern fn nk_tree_state_pop([*c]struct_nk_context) void;
pub extern fn nk_tree_element_push_hashed([*c]struct_nk_context, enum_nk_tree_type, title: [*c]const u8, initial_state: enum_nk_collapse_states, selected: [*c]nk_bool, hash: [*c]const u8, len: c_int, seed: c_int) nk_bool;
pub extern fn nk_tree_element_image_push_hashed([*c]struct_nk_context, enum_nk_tree_type, struct_nk_image, title: [*c]const u8, initial_state: enum_nk_collapse_states, selected: [*c]nk_bool, hash: [*c]const u8, len: c_int, seed: c_int) nk_bool;
pub extern fn nk_tree_element_pop([*c]struct_nk_context) void;
pub const struct_nk_list_view = extern struct {
    begin: c_int,
    end: c_int,
    count: c_int,
    total_height: c_int,
    ctx: [*c]struct_nk_context,
    scroll_pointer: [*c]nk_uint,
    scroll_value: nk_uint,
};
pub extern fn nk_list_view_begin([*c]struct_nk_context, out: [*c]struct_nk_list_view, id: [*c]const u8, nk_flags, row_height: c_int, row_count: c_int) nk_bool;
pub extern fn nk_list_view_end([*c]struct_nk_list_view) void;
pub const NK_WIDGET_INVALID: c_int = 0;
pub const NK_WIDGET_VALID: c_int = 1;
pub const NK_WIDGET_ROM: c_int = 2;
pub const enum_nk_widget_layout_states = c_uint;
pub const NK_WIDGET_STATE_MODIFIED: c_int = 2;
pub const NK_WIDGET_STATE_INACTIVE: c_int = 4;
pub const NK_WIDGET_STATE_ENTERED: c_int = 8;
pub const NK_WIDGET_STATE_HOVER: c_int = 16;
pub const NK_WIDGET_STATE_ACTIVED: c_int = 32;
pub const NK_WIDGET_STATE_LEFT: c_int = 64;
pub const NK_WIDGET_STATE_HOVERED: c_int = 18;
pub const NK_WIDGET_STATE_ACTIVE: c_int = 34;
pub const enum_nk_widget_states = c_uint;
pub extern fn nk_widget([*c]struct_nk_rect, [*c]const struct_nk_context) enum_nk_widget_layout_states;
pub extern fn nk_widget_fitting([*c]struct_nk_rect, [*c]struct_nk_context, struct_nk_vec2) enum_nk_widget_layout_states;
pub extern fn nk_widget_bounds([*c]struct_nk_context) struct_nk_rect;
pub extern fn nk_widget_position([*c]struct_nk_context) struct_nk_vec2;
pub extern fn nk_widget_size([*c]struct_nk_context) struct_nk_vec2;
pub extern fn nk_widget_width([*c]struct_nk_context) f32;
pub extern fn nk_widget_height([*c]struct_nk_context) f32;
pub extern fn nk_widget_is_hovered([*c]struct_nk_context) nk_bool;
pub extern fn nk_widget_is_mouse_clicked([*c]struct_nk_context, enum_nk_buttons) nk_bool;
pub extern fn nk_widget_has_mouse_click_down([*c]struct_nk_context, enum_nk_buttons, down: nk_bool) nk_bool;
pub extern fn nk_spacing([*c]struct_nk_context, cols: c_int) void;
pub const NK_TEXT_ALIGN_LEFT: c_int = 1;
pub const NK_TEXT_ALIGN_CENTERED: c_int = 2;
pub const NK_TEXT_ALIGN_RIGHT: c_int = 4;
pub const NK_TEXT_ALIGN_TOP: c_int = 8;
pub const NK_TEXT_ALIGN_MIDDLE: c_int = 16;
pub const NK_TEXT_ALIGN_BOTTOM: c_int = 32;
pub const enum_nk_text_align = c_uint;
pub const NK_TEXT_LEFT: c_int = 17;
pub const NK_TEXT_CENTERED: c_int = 18;
pub const NK_TEXT_RIGHT: c_int = 20;
pub const enum_nk_text_alignment = c_uint;
pub extern fn nk_text([*c]struct_nk_context, [*c]const u8, c_int, nk_flags) void;
pub extern fn nk_text_colored([*c]struct_nk_context, [*c]const u8, c_int, nk_flags, struct_nk_color) void;
pub extern fn nk_text_wrap([*c]struct_nk_context, [*c]const u8, c_int) void;
pub extern fn nk_text_wrap_colored([*c]struct_nk_context, [*c]const u8, c_int, struct_nk_color) void;
pub extern fn nk_label([*c]struct_nk_context, [*c]const u8, @"align": nk_flags) void;
pub extern fn nk_label_colored([*c]struct_nk_context, [*c]const u8, @"align": nk_flags, struct_nk_color) void;
pub extern fn nk_label_wrap([*c]struct_nk_context, [*c]const u8) void;
pub extern fn nk_label_colored_wrap([*c]struct_nk_context, [*c]const u8, struct_nk_color) void;
pub extern fn nk_image([*c]struct_nk_context, struct_nk_image) void;
pub extern fn nk_image_color([*c]struct_nk_context, struct_nk_image, struct_nk_color) void;
pub extern fn nk_button_text([*c]struct_nk_context, title: [*c]const u8, len: c_int) nk_bool;
pub extern fn nk_button_label([*c]struct_nk_context, title: [*c]const u8) nk_bool;
pub extern fn nk_button_color([*c]struct_nk_context, struct_nk_color) nk_bool;
pub extern fn nk_button_symbol([*c]struct_nk_context, enum_nk_symbol_type) nk_bool;
pub extern fn nk_button_image([*c]struct_nk_context, img: struct_nk_image) nk_bool;
pub extern fn nk_button_symbol_label([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, text_alignment: nk_flags) nk_bool;
pub extern fn nk_button_symbol_text([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_button_image_label([*c]struct_nk_context, img: struct_nk_image, [*c]const u8, text_alignment: nk_flags) nk_bool;
pub extern fn nk_button_image_text([*c]struct_nk_context, img: struct_nk_image, [*c]const u8, c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_button_text_styled([*c]struct_nk_context, [*c]const struct_nk_style_button, title: [*c]const u8, len: c_int) nk_bool;
pub extern fn nk_button_label_styled([*c]struct_nk_context, [*c]const struct_nk_style_button, title: [*c]const u8) nk_bool;
pub extern fn nk_button_symbol_styled([*c]struct_nk_context, [*c]const struct_nk_style_button, enum_nk_symbol_type) nk_bool;
pub extern fn nk_button_image_styled([*c]struct_nk_context, [*c]const struct_nk_style_button, img: struct_nk_image) nk_bool;
pub extern fn nk_button_symbol_text_styled([*c]struct_nk_context, [*c]const struct_nk_style_button, enum_nk_symbol_type, [*c]const u8, c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_button_symbol_label_styled(ctx: [*c]struct_nk_context, style: [*c]const struct_nk_style_button, symbol: enum_nk_symbol_type, title: [*c]const u8, @"align": nk_flags) nk_bool;
pub extern fn nk_button_image_label_styled([*c]struct_nk_context, [*c]const struct_nk_style_button, img: struct_nk_image, [*c]const u8, text_alignment: nk_flags) nk_bool;
pub extern fn nk_button_image_text_styled([*c]struct_nk_context, [*c]const struct_nk_style_button, img: struct_nk_image, [*c]const u8, c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_button_set_behavior([*c]struct_nk_context, enum_nk_button_behavior) void;
pub extern fn nk_button_push_behavior([*c]struct_nk_context, enum_nk_button_behavior) nk_bool;
pub extern fn nk_button_pop_behavior([*c]struct_nk_context) nk_bool;
pub extern fn nk_check_label([*c]struct_nk_context, [*c]const u8, active: nk_bool) nk_bool;
pub extern fn nk_check_text([*c]struct_nk_context, [*c]const u8, c_int, active: nk_bool) nk_bool;
pub extern fn nk_check_flags_label([*c]struct_nk_context, [*c]const u8, flags: c_uint, value: c_uint) c_uint;
pub extern fn nk_check_flags_text([*c]struct_nk_context, [*c]const u8, c_int, flags: c_uint, value: c_uint) c_uint;
pub extern fn nk_checkbox_label([*c]struct_nk_context, [*c]const u8, active: [*c]nk_bool) nk_bool;
pub extern fn nk_checkbox_text([*c]struct_nk_context, [*c]const u8, c_int, active: [*c]nk_bool) nk_bool;
pub extern fn nk_checkbox_flags_label([*c]struct_nk_context, [*c]const u8, flags: [*c]c_uint, value: c_uint) nk_bool;
pub extern fn nk_checkbox_flags_text([*c]struct_nk_context, [*c]const u8, c_int, flags: [*c]c_uint, value: c_uint) nk_bool;
pub extern fn nk_radio_label([*c]struct_nk_context, [*c]const u8, active: [*c]nk_bool) nk_bool;
pub extern fn nk_radio_text([*c]struct_nk_context, [*c]const u8, c_int, active: [*c]nk_bool) nk_bool;
pub extern fn nk_option_label([*c]struct_nk_context, [*c]const u8, active: nk_bool) nk_bool;
pub extern fn nk_option_text([*c]struct_nk_context, [*c]const u8, c_int, active: nk_bool) nk_bool;
pub extern fn nk_selectable_label([*c]struct_nk_context, [*c]const u8, @"align": nk_flags, value: [*c]nk_bool) nk_bool;
pub extern fn nk_selectable_text([*c]struct_nk_context, [*c]const u8, c_int, @"align": nk_flags, value: [*c]nk_bool) nk_bool;
pub extern fn nk_selectable_image_label([*c]struct_nk_context, struct_nk_image, [*c]const u8, @"align": nk_flags, value: [*c]nk_bool) nk_bool;
pub extern fn nk_selectable_image_text([*c]struct_nk_context, struct_nk_image, [*c]const u8, c_int, @"align": nk_flags, value: [*c]nk_bool) nk_bool;
pub extern fn nk_selectable_symbol_label([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, @"align": nk_flags, value: [*c]nk_bool) nk_bool;
pub extern fn nk_selectable_symbol_text([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, c_int, @"align": nk_flags, value: [*c]nk_bool) nk_bool;
pub extern fn nk_select_label([*c]struct_nk_context, [*c]const u8, @"align": nk_flags, value: nk_bool) nk_bool;
pub extern fn nk_select_text([*c]struct_nk_context, [*c]const u8, c_int, @"align": nk_flags, value: nk_bool) nk_bool;
pub extern fn nk_select_image_label([*c]struct_nk_context, struct_nk_image, [*c]const u8, @"align": nk_flags, value: nk_bool) nk_bool;
pub extern fn nk_select_image_text([*c]struct_nk_context, struct_nk_image, [*c]const u8, c_int, @"align": nk_flags, value: nk_bool) nk_bool;
pub extern fn nk_select_symbol_label([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, @"align": nk_flags, value: nk_bool) nk_bool;
pub extern fn nk_select_symbol_text([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, c_int, @"align": nk_flags, value: nk_bool) nk_bool;
pub extern fn nk_slide_float([*c]struct_nk_context, min: f32, val: f32, max: f32, step: f32) f32;
pub extern fn nk_slide_int([*c]struct_nk_context, min: c_int, val: c_int, max: c_int, step: c_int) c_int;
pub extern fn nk_slider_float([*c]struct_nk_context, min: f32, val: [*c]f32, max: f32, step: f32) nk_bool;
pub extern fn nk_slider_int([*c]struct_nk_context, min: c_int, val: [*c]c_int, max: c_int, step: c_int) nk_bool;
pub extern fn nk_progress([*c]struct_nk_context, cur: [*c]nk_size, max: nk_size, modifyable: nk_bool) nk_bool;
pub extern fn nk_prog([*c]struct_nk_context, cur: nk_size, max: nk_size, modifyable: nk_bool) nk_size;
pub extern fn nk_color_picker([*c]struct_nk_context, struct_nk_colorf, enum_nk_color_format) struct_nk_colorf;
pub extern fn nk_color_pick([*c]struct_nk_context, [*c]struct_nk_colorf, enum_nk_color_format) nk_bool;
pub extern fn nk_property_int([*c]struct_nk_context, name: [*c]const u8, min: c_int, val: [*c]c_int, max: c_int, step: c_int, inc_per_pixel: f32) void;
pub extern fn nk_property_float([*c]struct_nk_context, name: [*c]const u8, min: f32, val: [*c]f32, max: f32, step: f32, inc_per_pixel: f32) void;
pub extern fn nk_property_double([*c]struct_nk_context, name: [*c]const u8, min: f64, val: [*c]f64, max: f64, step: f64, inc_per_pixel: f32) void;
pub extern fn nk_propertyi([*c]struct_nk_context, name: [*c]const u8, min: c_int, val: c_int, max: c_int, step: c_int, inc_per_pixel: f32) c_int;
pub extern fn nk_propertyf([*c]struct_nk_context, name: [*c]const u8, min: f32, val: f32, max: f32, step: f32, inc_per_pixel: f32) f32;
pub extern fn nk_propertyd([*c]struct_nk_context, name: [*c]const u8, min: f64, val: f64, max: f64, step: f64, inc_per_pixel: f32) f64;
pub const NK_EDIT_DEFAULT: c_int = 0;
pub const NK_EDIT_READ_ONLY: c_int = 1;
pub const NK_EDIT_AUTO_SELECT: c_int = 2;
pub const NK_EDIT_SIG_ENTER: c_int = 4;
pub const NK_EDIT_ALLOW_TAB: c_int = 8;
pub const NK_EDIT_NO_CURSOR: c_int = 16;
pub const NK_EDIT_SELECTABLE: c_int = 32;
pub const NK_EDIT_CLIPBOARD: c_int = 64;
pub const NK_EDIT_CTRL_ENTER_NEWLINE: c_int = 128;
pub const NK_EDIT_NO_HORIZONTAL_SCROLL: c_int = 256;
pub const NK_EDIT_ALWAYS_INSERT_MODE: c_int = 512;
pub const NK_EDIT_MULTILINE: c_int = 1024;
pub const NK_EDIT_GOTO_END_ON_ACTIVATE: c_int = 2048;
pub const enum_nk_edit_flags = c_uint;
pub const NK_EDIT_SIMPLE: c_int = 512;
pub const NK_EDIT_FIELD: c_int = 608;
pub const NK_EDIT_BOX: c_int = 1640;
pub const NK_EDIT_EDITOR: c_int = 1128;
pub const enum_nk_edit_types = c_uint;
pub const NK_EDIT_ACTIVE: c_int = 1;
pub const NK_EDIT_INACTIVE: c_int = 2;
pub const NK_EDIT_ACTIVATED: c_int = 4;
pub const NK_EDIT_DEACTIVATED: c_int = 8;
pub const NK_EDIT_COMMITED: c_int = 16;
pub const enum_nk_edit_events = c_uint;
pub extern fn nk_edit_string([*c]struct_nk_context, nk_flags, buffer: [*c]u8, len: [*c]c_int, max: c_int, nk_plugin_filter) nk_flags;
pub extern fn nk_edit_string_zero_terminated([*c]struct_nk_context, nk_flags, buffer: [*c]u8, max: c_int, nk_plugin_filter) nk_flags;
pub extern fn nk_edit_buffer([*c]struct_nk_context, nk_flags, [*c]struct_nk_text_edit, nk_plugin_filter) nk_flags;
pub extern fn nk_edit_focus([*c]struct_nk_context, flags: nk_flags) void;
pub extern fn nk_edit_unfocus([*c]struct_nk_context) void;
pub extern fn nk_chart_begin([*c]struct_nk_context, enum_nk_chart_type, num: c_int, min: f32, max: f32) nk_bool;
pub extern fn nk_chart_begin_colored([*c]struct_nk_context, enum_nk_chart_type, struct_nk_color, active: struct_nk_color, num: c_int, min: f32, max: f32) nk_bool;
pub extern fn nk_chart_add_slot(ctx: [*c]struct_nk_context, enum_nk_chart_type, count: c_int, min_value: f32, max_value: f32) void;
pub extern fn nk_chart_add_slot_colored(ctx: [*c]struct_nk_context, enum_nk_chart_type, struct_nk_color, active: struct_nk_color, count: c_int, min_value: f32, max_value: f32) void;
pub extern fn nk_chart_push([*c]struct_nk_context, f32) nk_flags;
pub extern fn nk_chart_push_slot([*c]struct_nk_context, f32, c_int) nk_flags;
pub extern fn nk_chart_end([*c]struct_nk_context) void;
pub extern fn nk_plot([*c]struct_nk_context, enum_nk_chart_type, values: [*c]const f32, count: c_int, offset: c_int) void;
pub extern fn nk_plot_function([*c]struct_nk_context, enum_nk_chart_type, userdata: ?*anyopaque, value_getter: ?fn (?*anyopaque, c_int) callconv(.C) f32, count: c_int, offset: c_int) void;
pub extern fn nk_popup_begin([*c]struct_nk_context, enum_nk_popup_type, [*c]const u8, nk_flags, bounds: struct_nk_rect) nk_bool;
pub extern fn nk_popup_close([*c]struct_nk_context) void;
pub extern fn nk_popup_end([*c]struct_nk_context) void;
pub extern fn nk_popup_get_scroll([*c]struct_nk_context, offset_x: [*c]nk_uint, offset_y: [*c]nk_uint) void;
pub extern fn nk_popup_set_scroll([*c]struct_nk_context, offset_x: nk_uint, offset_y: nk_uint) void;
pub extern fn nk_combo([*c]struct_nk_context, items: [*c][*c]const u8, count: c_int, selected: c_int, item_height: c_int, size: struct_nk_vec2) c_int;
pub extern fn nk_combo_separator([*c]struct_nk_context, items_separated_by_separator: [*c]const u8, separator: c_int, selected: c_int, count: c_int, item_height: c_int, size: struct_nk_vec2) c_int;
pub extern fn nk_combo_string([*c]struct_nk_context, items_separated_by_zeros: [*c]const u8, selected: c_int, count: c_int, item_height: c_int, size: struct_nk_vec2) c_int;
pub extern fn nk_combo_callback([*c]struct_nk_context, item_getter: ?fn (?*anyopaque, c_int, [*c][*c]const u8) callconv(.C) void, userdata: ?*anyopaque, selected: c_int, count: c_int, item_height: c_int, size: struct_nk_vec2) c_int;
pub extern fn nk_combobox([*c]struct_nk_context, items: [*c][*c]const u8, count: c_int, selected: [*c]c_int, item_height: c_int, size: struct_nk_vec2) void;
pub extern fn nk_combobox_string([*c]struct_nk_context, items_separated_by_zeros: [*c]const u8, selected: [*c]c_int, count: c_int, item_height: c_int, size: struct_nk_vec2) void;
pub extern fn nk_combobox_separator([*c]struct_nk_context, items_separated_by_separator: [*c]const u8, separator: c_int, selected: [*c]c_int, count: c_int, item_height: c_int, size: struct_nk_vec2) void;
pub extern fn nk_combobox_callback([*c]struct_nk_context, item_getter: ?fn (?*anyopaque, c_int, [*c][*c]const u8) callconv(.C) void, ?*anyopaque, selected: [*c]c_int, count: c_int, item_height: c_int, size: struct_nk_vec2) void;
pub extern fn nk_combo_begin_text([*c]struct_nk_context, selected: [*c]const u8, c_int, size: struct_nk_vec2) nk_bool;
pub extern fn nk_combo_begin_label([*c]struct_nk_context, selected: [*c]const u8, size: struct_nk_vec2) nk_bool;
pub extern fn nk_combo_begin_color([*c]struct_nk_context, color: struct_nk_color, size: struct_nk_vec2) nk_bool;
pub extern fn nk_combo_begin_symbol([*c]struct_nk_context, enum_nk_symbol_type, size: struct_nk_vec2) nk_bool;
pub extern fn nk_combo_begin_symbol_label([*c]struct_nk_context, selected: [*c]const u8, enum_nk_symbol_type, size: struct_nk_vec2) nk_bool;
pub extern fn nk_combo_begin_symbol_text([*c]struct_nk_context, selected: [*c]const u8, c_int, enum_nk_symbol_type, size: struct_nk_vec2) nk_bool;
pub extern fn nk_combo_begin_image([*c]struct_nk_context, img: struct_nk_image, size: struct_nk_vec2) nk_bool;
pub extern fn nk_combo_begin_image_label([*c]struct_nk_context, selected: [*c]const u8, struct_nk_image, size: struct_nk_vec2) nk_bool;
pub extern fn nk_combo_begin_image_text([*c]struct_nk_context, selected: [*c]const u8, c_int, struct_nk_image, size: struct_nk_vec2) nk_bool;
pub extern fn nk_combo_item_label([*c]struct_nk_context, [*c]const u8, alignment: nk_flags) nk_bool;
pub extern fn nk_combo_item_text([*c]struct_nk_context, [*c]const u8, c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_combo_item_image_label([*c]struct_nk_context, struct_nk_image, [*c]const u8, alignment: nk_flags) nk_bool;
pub extern fn nk_combo_item_image_text([*c]struct_nk_context, struct_nk_image, [*c]const u8, c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_combo_item_symbol_label([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, alignment: nk_flags) nk_bool;
pub extern fn nk_combo_item_symbol_text([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_combo_close([*c]struct_nk_context) void;
pub extern fn nk_combo_end([*c]struct_nk_context) void;
pub extern fn nk_contextual_begin([*c]struct_nk_context, nk_flags, struct_nk_vec2, trigger_bounds: struct_nk_rect) nk_bool;
pub extern fn nk_contextual_item_text([*c]struct_nk_context, [*c]const u8, c_int, @"align": nk_flags) nk_bool;
pub extern fn nk_contextual_item_label([*c]struct_nk_context, [*c]const u8, @"align": nk_flags) nk_bool;
pub extern fn nk_contextual_item_image_label([*c]struct_nk_context, struct_nk_image, [*c]const u8, alignment: nk_flags) nk_bool;
pub extern fn nk_contextual_item_image_text([*c]struct_nk_context, struct_nk_image, [*c]const u8, len: c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_contextual_item_symbol_label([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, alignment: nk_flags) nk_bool;
pub extern fn nk_contextual_item_symbol_text([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_contextual_close([*c]struct_nk_context) void;
pub extern fn nk_contextual_end([*c]struct_nk_context) void;
pub extern fn nk_tooltip([*c]struct_nk_context, [*c]const u8) void;
pub extern fn nk_tooltip_begin([*c]struct_nk_context, width: f32) nk_bool;
pub extern fn nk_tooltip_end([*c]struct_nk_context) void;
pub extern fn nk_menubar_begin([*c]struct_nk_context) void;
pub extern fn nk_menubar_end([*c]struct_nk_context) void;
pub extern fn nk_menu_begin_text([*c]struct_nk_context, title: [*c]const u8, title_len: c_int, @"align": nk_flags, size: struct_nk_vec2) nk_bool;
pub extern fn nk_menu_begin_label([*c]struct_nk_context, [*c]const u8, @"align": nk_flags, size: struct_nk_vec2) nk_bool;
pub extern fn nk_menu_begin_image([*c]struct_nk_context, [*c]const u8, struct_nk_image, size: struct_nk_vec2) nk_bool;
pub extern fn nk_menu_begin_image_text([*c]struct_nk_context, [*c]const u8, c_int, @"align": nk_flags, struct_nk_image, size: struct_nk_vec2) nk_bool;
pub extern fn nk_menu_begin_image_label([*c]struct_nk_context, [*c]const u8, @"align": nk_flags, struct_nk_image, size: struct_nk_vec2) nk_bool;
pub extern fn nk_menu_begin_symbol([*c]struct_nk_context, [*c]const u8, enum_nk_symbol_type, size: struct_nk_vec2) nk_bool;
pub extern fn nk_menu_begin_symbol_text([*c]struct_nk_context, [*c]const u8, c_int, @"align": nk_flags, enum_nk_symbol_type, size: struct_nk_vec2) nk_bool;
pub extern fn nk_menu_begin_symbol_label([*c]struct_nk_context, [*c]const u8, @"align": nk_flags, enum_nk_symbol_type, size: struct_nk_vec2) nk_bool;
pub extern fn nk_menu_item_text([*c]struct_nk_context, [*c]const u8, c_int, @"align": nk_flags) nk_bool;
pub extern fn nk_menu_item_label([*c]struct_nk_context, [*c]const u8, alignment: nk_flags) nk_bool;
pub extern fn nk_menu_item_image_label([*c]struct_nk_context, struct_nk_image, [*c]const u8, alignment: nk_flags) nk_bool;
pub extern fn nk_menu_item_image_text([*c]struct_nk_context, struct_nk_image, [*c]const u8, len: c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_menu_item_symbol_text([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, c_int, alignment: nk_flags) nk_bool;
pub extern fn nk_menu_item_symbol_label([*c]struct_nk_context, enum_nk_symbol_type, [*c]const u8, alignment: nk_flags) nk_bool;
pub extern fn nk_menu_close([*c]struct_nk_context) void;
pub extern fn nk_menu_end([*c]struct_nk_context) void;
pub const NK_COLOR_TEXT: c_int = 0;
pub const NK_COLOR_WINDOW: c_int = 1;
pub const NK_COLOR_HEADER: c_int = 2;
pub const NK_COLOR_BORDER: c_int = 3;
pub const NK_COLOR_BUTTON: c_int = 4;
pub const NK_COLOR_BUTTON_HOVER: c_int = 5;
pub const NK_COLOR_BUTTON_ACTIVE: c_int = 6;
pub const NK_COLOR_TOGGLE: c_int = 7;
pub const NK_COLOR_TOGGLE_HOVER: c_int = 8;
pub const NK_COLOR_TOGGLE_CURSOR: c_int = 9;
pub const NK_COLOR_SELECT: c_int = 10;
pub const NK_COLOR_SELECT_ACTIVE: c_int = 11;
pub const NK_COLOR_SLIDER: c_int = 12;
pub const NK_COLOR_SLIDER_CURSOR: c_int = 13;
pub const NK_COLOR_SLIDER_CURSOR_HOVER: c_int = 14;
pub const NK_COLOR_SLIDER_CURSOR_ACTIVE: c_int = 15;
pub const NK_COLOR_PROPERTY: c_int = 16;
pub const NK_COLOR_EDIT: c_int = 17;
pub const NK_COLOR_EDIT_CURSOR: c_int = 18;
pub const NK_COLOR_COMBO: c_int = 19;
pub const NK_COLOR_CHART: c_int = 20;
pub const NK_COLOR_CHART_COLOR: c_int = 21;
pub const NK_COLOR_CHART_COLOR_HIGHLIGHT: c_int = 22;
pub const NK_COLOR_SCROLLBAR: c_int = 23;
pub const NK_COLOR_SCROLLBAR_CURSOR: c_int = 24;
pub const NK_COLOR_SCROLLBAR_CURSOR_HOVER: c_int = 25;
pub const NK_COLOR_SCROLLBAR_CURSOR_ACTIVE: c_int = 26;
pub const NK_COLOR_TAB_HEADER: c_int = 27;
pub const NK_COLOR_COUNT: c_int = 28;
pub const enum_nk_style_colors = c_uint;
pub const NK_CURSOR_ARROW: c_int = 0;
pub const NK_CURSOR_TEXT: c_int = 1;
pub const NK_CURSOR_MOVE: c_int = 2;
pub const NK_CURSOR_RESIZE_VERTICAL: c_int = 3;
pub const NK_CURSOR_RESIZE_HORIZONTAL: c_int = 4;
pub const NK_CURSOR_RESIZE_TOP_LEFT_DOWN_RIGHT: c_int = 5;
pub const NK_CURSOR_RESIZE_TOP_RIGHT_DOWN_LEFT: c_int = 6;
pub const NK_CURSOR_COUNT: c_int = 7;
pub const enum_nk_style_cursor = c_uint;
pub extern fn nk_style_default([*c]struct_nk_context) void;
pub extern fn nk_style_from_table([*c]struct_nk_context, [*c]const struct_nk_color) void;
pub extern fn nk_style_load_cursor([*c]struct_nk_context, enum_nk_style_cursor, [*c]const struct_nk_cursor) void;
pub extern fn nk_style_load_all_cursors([*c]struct_nk_context, [*c]struct_nk_cursor) void;
pub extern fn nk_style_get_color_by_name(enum_nk_style_colors) [*c]const u8;
pub extern fn nk_style_set_font([*c]struct_nk_context, [*c]const struct_nk_user_font) void;
pub extern fn nk_style_set_cursor([*c]struct_nk_context, enum_nk_style_cursor) nk_bool;
pub extern fn nk_style_show_cursor([*c]struct_nk_context) void;
pub extern fn nk_style_hide_cursor([*c]struct_nk_context) void;
pub extern fn nk_style_push_font([*c]struct_nk_context, [*c]const struct_nk_user_font) nk_bool;
pub extern fn nk_style_push_float([*c]struct_nk_context, [*c]f32, f32) nk_bool;
pub extern fn nk_style_push_vec2([*c]struct_nk_context, [*c]struct_nk_vec2, struct_nk_vec2) nk_bool;
pub extern fn nk_style_push_style_item([*c]struct_nk_context, [*c]struct_nk_style_item, struct_nk_style_item) nk_bool;
pub extern fn nk_style_push_flags([*c]struct_nk_context, [*c]nk_flags, nk_flags) nk_bool;
pub extern fn nk_style_push_color([*c]struct_nk_context, [*c]struct_nk_color, struct_nk_color) nk_bool;
pub extern fn nk_style_pop_font([*c]struct_nk_context) nk_bool;
pub extern fn nk_style_pop_float([*c]struct_nk_context) nk_bool;
pub extern fn nk_style_pop_vec2([*c]struct_nk_context) nk_bool;
pub extern fn nk_style_pop_style_item([*c]struct_nk_context) nk_bool;
pub extern fn nk_style_pop_flags([*c]struct_nk_context) nk_bool;
pub extern fn nk_style_pop_color([*c]struct_nk_context) nk_bool;
pub extern fn nk_rgb(r: c_int, g: c_int, b: c_int) struct_nk_color;
pub extern fn nk_rgb_iv(rgb: [*c]const c_int) struct_nk_color;
pub extern fn nk_rgb_bv(rgb: [*c]const nk_byte) struct_nk_color;
pub extern fn nk_rgb_f(r: f32, g: f32, b: f32) struct_nk_color;
pub extern fn nk_rgb_fv(rgb: [*c]const f32) struct_nk_color;
pub extern fn nk_rgb_cf(c: struct_nk_colorf) struct_nk_color;
pub extern fn nk_rgb_hex(rgb: [*c]const u8) struct_nk_color;
pub extern fn nk_rgba(r: c_int, g: c_int, b: c_int, a: c_int) struct_nk_color;
pub extern fn nk_rgba_u32(nk_uint) struct_nk_color;
pub extern fn nk_rgba_iv(rgba: [*c]const c_int) struct_nk_color;
pub extern fn nk_rgba_bv(rgba: [*c]const nk_byte) struct_nk_color;
pub extern fn nk_rgba_f(r: f32, g: f32, b: f32, a: f32) struct_nk_color;
pub extern fn nk_rgba_fv(rgba: [*c]const f32) struct_nk_color;
pub extern fn nk_rgba_cf(c: struct_nk_colorf) struct_nk_color;
pub extern fn nk_rgba_hex(rgb: [*c]const u8) struct_nk_color;
pub extern fn nk_hsva_colorf(h: f32, s: f32, v: f32, a: f32) struct_nk_colorf;
pub extern fn nk_hsva_colorfv(c: [*c]f32) struct_nk_colorf;
pub extern fn nk_colorf_hsva_f(out_h: [*c]f32, out_s: [*c]f32, out_v: [*c]f32, out_a: [*c]f32, in: struct_nk_colorf) void;
pub extern fn nk_colorf_hsva_fv(hsva: [*c]f32, in: struct_nk_colorf) void;
pub extern fn nk_hsv(h: c_int, s: c_int, v: c_int) struct_nk_color;
pub extern fn nk_hsv_iv(hsv: [*c]const c_int) struct_nk_color;
pub extern fn nk_hsv_bv(hsv: [*c]const nk_byte) struct_nk_color;
pub extern fn nk_hsv_f(h: f32, s: f32, v: f32) struct_nk_color;
pub extern fn nk_hsv_fv(hsv: [*c]const f32) struct_nk_color;
pub extern fn nk_hsva(h: c_int, s: c_int, v: c_int, a: c_int) struct_nk_color;
pub extern fn nk_hsva_iv(hsva: [*c]const c_int) struct_nk_color;
pub extern fn nk_hsva_bv(hsva: [*c]const nk_byte) struct_nk_color;
pub extern fn nk_hsva_f(h: f32, s: f32, v: f32, a: f32) struct_nk_color;
pub extern fn nk_hsva_fv(hsva: [*c]const f32) struct_nk_color;
pub extern fn nk_color_f(r: [*c]f32, g: [*c]f32, b: [*c]f32, a: [*c]f32, struct_nk_color) void;
pub extern fn nk_color_fv(rgba_out: [*c]f32, struct_nk_color) void;
pub extern fn nk_color_cf(struct_nk_color) struct_nk_colorf;
pub extern fn nk_color_d(r: [*c]f64, g: [*c]f64, b: [*c]f64, a: [*c]f64, struct_nk_color) void;
pub extern fn nk_color_dv(rgba_out: [*c]f64, struct_nk_color) void;
pub extern fn nk_color_u32(struct_nk_color) nk_uint;
pub extern fn nk_color_hex_rgba(output: [*c]u8, struct_nk_color) void;
pub extern fn nk_color_hex_rgb(output: [*c]u8, struct_nk_color) void;
pub extern fn nk_color_hsv_i(out_h: [*c]c_int, out_s: [*c]c_int, out_v: [*c]c_int, struct_nk_color) void;
pub extern fn nk_color_hsv_b(out_h: [*c]nk_byte, out_s: [*c]nk_byte, out_v: [*c]nk_byte, struct_nk_color) void;
pub extern fn nk_color_hsv_iv(hsv_out: [*c]c_int, struct_nk_color) void;
pub extern fn nk_color_hsv_bv(hsv_out: [*c]nk_byte, struct_nk_color) void;
pub extern fn nk_color_hsv_f(out_h: [*c]f32, out_s: [*c]f32, out_v: [*c]f32, struct_nk_color) void;
pub extern fn nk_color_hsv_fv(hsv_out: [*c]f32, struct_nk_color) void;
pub extern fn nk_color_hsva_i(h: [*c]c_int, s: [*c]c_int, v: [*c]c_int, a: [*c]c_int, struct_nk_color) void;
pub extern fn nk_color_hsva_b(h: [*c]nk_byte, s: [*c]nk_byte, v: [*c]nk_byte, a: [*c]nk_byte, struct_nk_color) void;
pub extern fn nk_color_hsva_iv(hsva_out: [*c]c_int, struct_nk_color) void;
pub extern fn nk_color_hsva_bv(hsva_out: [*c]nk_byte, struct_nk_color) void;
pub extern fn nk_color_hsva_f(out_h: [*c]f32, out_s: [*c]f32, out_v: [*c]f32, out_a: [*c]f32, struct_nk_color) void;
pub extern fn nk_color_hsva_fv(hsva_out: [*c]f32, struct_nk_color) void;
pub extern fn nk_handle_ptr(?*anyopaque) nk_handle;
pub extern fn nk_handle_id(c_int) nk_handle;
pub extern fn nk_image_handle(nk_handle) struct_nk_image;
pub extern fn nk_image_ptr(?*anyopaque) struct_nk_image;
pub extern fn nk_image_id(c_int) struct_nk_image;
pub extern fn nk_image_is_subimage(img: [*c]const struct_nk_image) nk_bool;
pub extern fn nk_subimage_ptr(?*anyopaque, w: nk_ushort, h: nk_ushort, sub_region: struct_nk_rect) struct_nk_image;
pub extern fn nk_subimage_id(c_int, w: nk_ushort, h: nk_ushort, sub_region: struct_nk_rect) struct_nk_image;
pub extern fn nk_subimage_handle(nk_handle, w: nk_ushort, h: nk_ushort, sub_region: struct_nk_rect) struct_nk_image;
pub extern fn nk_nine_slice_handle(nk_handle, l: nk_ushort, t: nk_ushort, r: nk_ushort, b: nk_ushort) struct_nk_nine_slice;
pub extern fn nk_nine_slice_ptr(?*anyopaque, l: nk_ushort, t: nk_ushort, r: nk_ushort, b: nk_ushort) struct_nk_nine_slice;
pub extern fn nk_nine_slice_id(c_int, l: nk_ushort, t: nk_ushort, r: nk_ushort, b: nk_ushort) struct_nk_nine_slice;
pub extern fn nk_nine_slice_is_sub9slice(img: [*c]const struct_nk_nine_slice) c_int;
pub extern fn nk_sub9slice_ptr(?*anyopaque, w: nk_ushort, h: nk_ushort, sub_region: struct_nk_rect, l: nk_ushort, t: nk_ushort, r: nk_ushort, b: nk_ushort) struct_nk_nine_slice;
pub extern fn nk_sub9slice_id(c_int, w: nk_ushort, h: nk_ushort, sub_region: struct_nk_rect, l: nk_ushort, t: nk_ushort, r: nk_ushort, b: nk_ushort) struct_nk_nine_slice;
pub extern fn nk_sub9slice_handle(nk_handle, w: nk_ushort, h: nk_ushort, sub_region: struct_nk_rect, l: nk_ushort, t: nk_ushort, r: nk_ushort, b: nk_ushort) struct_nk_nine_slice;
pub extern fn nk_murmur_hash(key: ?*const anyopaque, len: c_int, seed: nk_hash) nk_hash;
pub extern fn nk_triangle_from_direction(result: [*c]struct_nk_vec2, r: struct_nk_rect, pad_x: f32, pad_y: f32, enum_nk_heading) void;
pub extern fn nk_vec2(x: f32, y: f32) struct_nk_vec2;
pub extern fn nk_vec2i(x: c_int, y: c_int) struct_nk_vec2;
pub extern fn nk_vec2v(xy: [*c]const f32) struct_nk_vec2;
pub extern fn nk_vec2iv(xy: [*c]const c_int) struct_nk_vec2;
pub extern fn nk_get_null_rect() struct_nk_rect;
pub extern fn nk_rect(x: f32, y: f32, w: f32, h: f32) struct_nk_rect;
pub extern fn nk_recti(x: c_int, y: c_int, w: c_int, h: c_int) struct_nk_rect;
pub extern fn nk_recta(pos: struct_nk_vec2, size: struct_nk_vec2) struct_nk_rect;
pub extern fn nk_rectv(xywh: [*c]const f32) struct_nk_rect;
pub extern fn nk_rectiv(xywh: [*c]const c_int) struct_nk_rect;
pub extern fn nk_rect_pos(struct_nk_rect) struct_nk_vec2;
pub extern fn nk_rect_size(struct_nk_rect) struct_nk_vec2;
pub extern fn nk_strlen(str: [*c]const u8) c_int;
pub extern fn nk_stricmp(s1: [*c]const u8, s2: [*c]const u8) c_int;
pub extern fn nk_stricmpn(s1: [*c]const u8, s2: [*c]const u8, n: c_int) c_int;
pub extern fn nk_strtoi(str: [*c]const u8, endptr: [*c][*c]const u8) c_int;
pub extern fn nk_strtof(str: [*c]const u8, endptr: [*c][*c]const u8) f32;
pub extern fn nk_strtod(str: [*c]const u8, endptr: [*c][*c]const u8) f64;
pub extern fn nk_strfilter(text: [*c]const u8, regexp: [*c]const u8) c_int;
pub extern fn nk_strmatch_fuzzy_string(str: [*c]const u8, pattern: [*c]const u8, out_score: [*c]c_int) c_int;
pub extern fn nk_strmatch_fuzzy_text(txt: [*c]const u8, txt_len: c_int, pattern: [*c]const u8, out_score: [*c]c_int) c_int;
pub extern fn nk_utf_decode([*c]const u8, [*c]nk_rune, c_int) c_int;
pub extern fn nk_utf_encode(nk_rune, [*c]u8, c_int) c_int;
pub extern fn nk_utf_len([*c]const u8, byte_len: c_int) c_int;
pub extern fn nk_utf_at(buffer: [*c]const u8, length: c_int, index: c_int, unicode: [*c]nk_rune, len: [*c]c_int) [*c]const u8;
pub const NK_COORD_UV: c_int = 0;
pub const NK_COORD_PIXEL: c_int = 1;
pub const enum_nk_font_coord_type = c_uint;
pub const struct_nk_baked_font = extern struct {
    height: f32,
    ascent: f32,
    descent: f32,
    glyph_offset: nk_rune,
    glyph_count: nk_rune,
    ranges: [*c]const nk_rune,
};
pub const struct_nk_font_glyph = extern struct {
    codepoint: nk_rune,
    xadvance: f32,
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    w: f32,
    h: f32,
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
};
pub const struct_nk_font_config = extern struct {
    next: [*c]struct_nk_font_config,
    ttf_blob: ?*anyopaque,
    ttf_size: nk_size,
    ttf_data_owned_by_atlas: u8,
    merge_mode: u8,
    pixel_snap: u8,
    oversample_v: u8,
    oversample_h: u8,
    padding: [3]u8,
    size: f32,
    coord_type: enum_nk_font_coord_type,
    spacing: struct_nk_vec2,
    range: [*c]const nk_rune,
    font: [*c]struct_nk_baked_font,
    fallback_glyph: nk_rune,
    n: [*c]struct_nk_font_config,
    p: [*c]struct_nk_font_config,
};
pub const struct_nk_font = extern struct {
    next: [*c]struct_nk_font,
    handle: struct_nk_user_font,
    info: struct_nk_baked_font,
    scale: f32,
    glyphs: [*c]struct_nk_font_glyph,
    fallback: [*c]const struct_nk_font_glyph,
    fallback_codepoint: nk_rune,
    texture: nk_handle,
    config: [*c]struct_nk_font_config,
};
pub const NK_FONT_ATLAS_ALPHA8: c_int = 0;
pub const NK_FONT_ATLAS_RGBA32: c_int = 1;
pub const enum_nk_font_atlas_format = c_uint;
pub const struct_nk_font_atlas = extern struct {
    pixel: ?*anyopaque,
    tex_width: c_int,
    tex_height: c_int,
    permanent: struct_nk_allocator,
    temporary: struct_nk_allocator,
    custom: struct_nk_recti,
    cursors: [7]struct_nk_cursor,
    glyph_count: c_int,
    glyphs: [*c]struct_nk_font_glyph,
    default_font: [*c]struct_nk_font,
    fonts: [*c]struct_nk_font,
    config: [*c]struct_nk_font_config,
    font_num: c_int,
};
pub extern fn nk_font_default_glyph_ranges() [*c]const nk_rune;
pub extern fn nk_font_chinese_glyph_ranges() [*c]const nk_rune;
pub extern fn nk_font_cyrillic_glyph_ranges() [*c]const nk_rune;
pub extern fn nk_font_korean_glyph_ranges() [*c]const nk_rune;
pub extern fn nk_font_atlas_init([*c]struct_nk_font_atlas, [*c]struct_nk_allocator) void;
pub extern fn nk_font_atlas_init_custom([*c]struct_nk_font_atlas, persistent: [*c]struct_nk_allocator, transient: [*c]struct_nk_allocator) void;
pub extern fn nk_font_atlas_begin([*c]struct_nk_font_atlas) void;
pub extern fn nk_font_config(pixel_height: f32) struct_nk_font_config;
pub extern fn nk_font_atlas_add([*c]struct_nk_font_atlas, [*c]const struct_nk_font_config) [*c]struct_nk_font;
pub extern fn nk_font_atlas_add_default([*c]struct_nk_font_atlas, height: f32, [*c]const struct_nk_font_config) [*c]struct_nk_font;
pub extern fn nk_font_atlas_add_from_memory(atlas: [*c]struct_nk_font_atlas, memory: ?*anyopaque, size: nk_size, height: f32, config: [*c]const struct_nk_font_config) [*c]struct_nk_font;
pub extern fn nk_font_atlas_add_compressed([*c]struct_nk_font_atlas, memory: ?*anyopaque, size: nk_size, height: f32, [*c]const struct_nk_font_config) [*c]struct_nk_font;
pub extern fn nk_font_atlas_add_compressed_base85([*c]struct_nk_font_atlas, data: [*c]const u8, height: f32, config: [*c]const struct_nk_font_config) [*c]struct_nk_font;
pub extern fn nk_font_atlas_bake([*c]struct_nk_font_atlas, width: [*c]c_int, height: [*c]c_int, enum_nk_font_atlas_format) ?*const anyopaque;
pub extern fn nk_font_atlas_end([*c]struct_nk_font_atlas, tex: nk_handle, [*c]struct_nk_draw_null_texture) void;
pub extern fn nk_font_find_glyph([*c]struct_nk_font, unicode: nk_rune) [*c]const struct_nk_font_glyph;
pub extern fn nk_font_atlas_cleanup(atlas: [*c]struct_nk_font_atlas) void;
pub extern fn nk_font_atlas_clear([*c]struct_nk_font_atlas) void;
pub const struct_nk_memory_status = extern struct {
    memory: ?*anyopaque,
    type: c_uint,
    size: nk_size,
    allocated: nk_size,
    needed: nk_size,
    calls: nk_size,
};
pub const NK_BUFFER_FRONT: c_int = 0;
pub const NK_BUFFER_BACK: c_int = 1;
pub const NK_BUFFER_MAX: c_int = 2;
pub const enum_nk_buffer_allocation_type = c_uint;
pub extern fn nk_buffer_init([*c]struct_nk_buffer, [*c]const struct_nk_allocator, size: nk_size) void;
pub extern fn nk_buffer_init_fixed([*c]struct_nk_buffer, memory: ?*anyopaque, size: nk_size) void;
pub extern fn nk_buffer_info([*c]struct_nk_memory_status, [*c]struct_nk_buffer) void;
pub extern fn nk_buffer_push([*c]struct_nk_buffer, @"type": enum_nk_buffer_allocation_type, memory: ?*const anyopaque, size: nk_size, @"align": nk_size) void;
pub extern fn nk_buffer_mark([*c]struct_nk_buffer, @"type": enum_nk_buffer_allocation_type) void;
pub extern fn nk_buffer_reset([*c]struct_nk_buffer, @"type": enum_nk_buffer_allocation_type) void;
pub extern fn nk_buffer_clear([*c]struct_nk_buffer) void;
pub extern fn nk_buffer_free([*c]struct_nk_buffer) void;
pub extern fn nk_buffer_memory([*c]struct_nk_buffer) ?*anyopaque;
pub extern fn nk_buffer_memory_const([*c]const struct_nk_buffer) ?*const anyopaque;
pub extern fn nk_buffer_total([*c]struct_nk_buffer) nk_size;
pub extern fn nk_str_init([*c]struct_nk_str, [*c]const struct_nk_allocator, size: nk_size) void;
pub extern fn nk_str_init_fixed([*c]struct_nk_str, memory: ?*anyopaque, size: nk_size) void;
pub extern fn nk_str_clear([*c]struct_nk_str) void;
pub extern fn nk_str_free([*c]struct_nk_str) void;
pub extern fn nk_str_append_text_char([*c]struct_nk_str, [*c]const u8, c_int) c_int;
pub extern fn nk_str_append_str_char([*c]struct_nk_str, [*c]const u8) c_int;
pub extern fn nk_str_append_text_utf8([*c]struct_nk_str, [*c]const u8, c_int) c_int;
pub extern fn nk_str_append_str_utf8([*c]struct_nk_str, [*c]const u8) c_int;
pub extern fn nk_str_append_text_runes([*c]struct_nk_str, [*c]const nk_rune, c_int) c_int;
pub extern fn nk_str_append_str_runes([*c]struct_nk_str, [*c]const nk_rune) c_int;
pub extern fn nk_str_insert_at_char([*c]struct_nk_str, pos: c_int, [*c]const u8, c_int) c_int;
pub extern fn nk_str_insert_at_rune([*c]struct_nk_str, pos: c_int, [*c]const u8, c_int) c_int;
pub extern fn nk_str_insert_text_char([*c]struct_nk_str, pos: c_int, [*c]const u8, c_int) c_int;
pub extern fn nk_str_insert_str_char([*c]struct_nk_str, pos: c_int, [*c]const u8) c_int;
pub extern fn nk_str_insert_text_utf8([*c]struct_nk_str, pos: c_int, [*c]const u8, c_int) c_int;
pub extern fn nk_str_insert_str_utf8([*c]struct_nk_str, pos: c_int, [*c]const u8) c_int;
pub extern fn nk_str_insert_text_runes([*c]struct_nk_str, pos: c_int, [*c]const nk_rune, c_int) c_int;
pub extern fn nk_str_insert_str_runes([*c]struct_nk_str, pos: c_int, [*c]const nk_rune) c_int;
pub extern fn nk_str_remove_chars([*c]struct_nk_str, len: c_int) void;
pub extern fn nk_str_remove_runes(str: [*c]struct_nk_str, len: c_int) void;
pub extern fn nk_str_delete_chars([*c]struct_nk_str, pos: c_int, len: c_int) void;
pub extern fn nk_str_delete_runes([*c]struct_nk_str, pos: c_int, len: c_int) void;
pub extern fn nk_str_at_char([*c]struct_nk_str, pos: c_int) [*c]u8;
pub extern fn nk_str_at_rune([*c]struct_nk_str, pos: c_int, unicode: [*c]nk_rune, len: [*c]c_int) [*c]u8;
pub extern fn nk_str_rune_at([*c]const struct_nk_str, pos: c_int) nk_rune;
pub extern fn nk_str_at_char_const([*c]const struct_nk_str, pos: c_int) [*c]const u8;
pub extern fn nk_str_at_const([*c]const struct_nk_str, pos: c_int, unicode: [*c]nk_rune, len: [*c]c_int) [*c]const u8;
pub extern fn nk_str_get([*c]struct_nk_str) [*c]u8;
pub extern fn nk_str_get_const([*c]const struct_nk_str) [*c]const u8;
pub extern fn nk_str_len([*c]struct_nk_str) c_int;
pub extern fn nk_str_len_char([*c]struct_nk_str) c_int;
pub const NK_TEXT_EDIT_SINGLE_LINE: c_int = 0;
pub const NK_TEXT_EDIT_MULTI_LINE: c_int = 1;
pub const enum_nk_text_edit_type = c_uint;
pub const NK_TEXT_EDIT_MODE_VIEW: c_int = 0;
pub const NK_TEXT_EDIT_MODE_INSERT: c_int = 1;
pub const NK_TEXT_EDIT_MODE_REPLACE: c_int = 2;
pub const enum_nk_text_edit_mode = c_uint;
pub extern fn nk_filter_default([*c]const struct_nk_text_edit, unicode: nk_rune) nk_bool;
pub extern fn nk_filter_ascii([*c]const struct_nk_text_edit, unicode: nk_rune) nk_bool;
pub extern fn nk_filter_float([*c]const struct_nk_text_edit, unicode: nk_rune) nk_bool;
pub extern fn nk_filter_decimal([*c]const struct_nk_text_edit, unicode: nk_rune) nk_bool;
pub extern fn nk_filter_hex([*c]const struct_nk_text_edit, unicode: nk_rune) nk_bool;
pub extern fn nk_filter_oct([*c]const struct_nk_text_edit, unicode: nk_rune) nk_bool;
pub extern fn nk_filter_binary([*c]const struct_nk_text_edit, unicode: nk_rune) nk_bool;
pub extern fn nk_textedit_init([*c]struct_nk_text_edit, [*c]struct_nk_allocator, size: nk_size) void;
pub extern fn nk_textedit_init_fixed([*c]struct_nk_text_edit, memory: ?*anyopaque, size: nk_size) void;
pub extern fn nk_textedit_free([*c]struct_nk_text_edit) void;
pub extern fn nk_textedit_text([*c]struct_nk_text_edit, [*c]const u8, total_len: c_int) void;
pub extern fn nk_textedit_delete([*c]struct_nk_text_edit, where: c_int, len: c_int) void;
pub extern fn nk_textedit_delete_selection([*c]struct_nk_text_edit) void;
pub extern fn nk_textedit_select_all([*c]struct_nk_text_edit) void;
pub extern fn nk_textedit_cut([*c]struct_nk_text_edit) nk_bool;
pub extern fn nk_textedit_paste([*c]struct_nk_text_edit, [*c]const u8, len: c_int) nk_bool;
pub extern fn nk_textedit_undo([*c]struct_nk_text_edit) void;
pub extern fn nk_textedit_redo([*c]struct_nk_text_edit) void;
pub const struct_nk_command_scissor = extern struct {
    header: struct_nk_command,
    x: c_short,
    y: c_short,
    w: c_ushort,
    h: c_ushort,
};
pub const struct_nk_command_line = extern struct {
    header: struct_nk_command,
    line_thickness: c_ushort,
    begin: struct_nk_vec2i,
    end: struct_nk_vec2i,
    color: struct_nk_color,
};
pub const struct_nk_command_curve = extern struct {
    header: struct_nk_command,
    line_thickness: c_ushort,
    begin: struct_nk_vec2i,
    end: struct_nk_vec2i,
    ctrl: [2]struct_nk_vec2i,
    color: struct_nk_color,
};
pub const struct_nk_command_rect = extern struct {
    header: struct_nk_command,
    rounding: c_ushort,
    line_thickness: c_ushort,
    x: c_short,
    y: c_short,
    w: c_ushort,
    h: c_ushort,
    color: struct_nk_color,
};
pub const struct_nk_command_rect_filled = extern struct {
    header: struct_nk_command,
    rounding: c_ushort,
    x: c_short,
    y: c_short,
    w: c_ushort,
    h: c_ushort,
    color: struct_nk_color,
};
pub const struct_nk_command_rect_multi_color = extern struct {
    header: struct_nk_command,
    x: c_short,
    y: c_short,
    w: c_ushort,
    h: c_ushort,
    left: struct_nk_color,
    top: struct_nk_color,
    bottom: struct_nk_color,
    right: struct_nk_color,
};
pub const struct_nk_command_triangle = extern struct {
    header: struct_nk_command,
    line_thickness: c_ushort,
    a: struct_nk_vec2i,
    b: struct_nk_vec2i,
    c: struct_nk_vec2i,
    color: struct_nk_color,
};
pub const struct_nk_command_triangle_filled = extern struct {
    header: struct_nk_command,
    a: struct_nk_vec2i,
    b: struct_nk_vec2i,
    c: struct_nk_vec2i,
    color: struct_nk_color,
};
pub const struct_nk_command_circle = extern struct {
    header: struct_nk_command,
    x: c_short,
    y: c_short,
    line_thickness: c_ushort,
    w: c_ushort,
    h: c_ushort,
    color: struct_nk_color,
};
pub const struct_nk_command_circle_filled = extern struct {
    header: struct_nk_command,
    x: c_short,
    y: c_short,
    w: c_ushort,
    h: c_ushort,
    color: struct_nk_color,
};
pub const struct_nk_command_arc = extern struct {
    header: struct_nk_command,
    cx: c_short,
    cy: c_short,
    r: c_ushort,
    line_thickness: c_ushort,
    a: [2]f32,
    color: struct_nk_color,
};
pub const struct_nk_command_arc_filled = extern struct {
    header: struct_nk_command,
    cx: c_short,
    cy: c_short,
    r: c_ushort,
    a: [2]f32,
    color: struct_nk_color,
};
pub const struct_nk_command_polygon = extern struct {
    header: struct_nk_command,
    color: struct_nk_color,
    line_thickness: c_ushort,
    point_count: c_ushort,
    points: [1]struct_nk_vec2i,
};
pub const struct_nk_command_polygon_filled = extern struct {
    header: struct_nk_command,
    color: struct_nk_color,
    point_count: c_ushort,
    points: [1]struct_nk_vec2i,
};
pub const struct_nk_command_polyline = extern struct {
    header: struct_nk_command,
    color: struct_nk_color,
    line_thickness: c_ushort,
    point_count: c_ushort,
    points: [1]struct_nk_vec2i,
};
pub const struct_nk_command_image = extern struct {
    header: struct_nk_command,
    x: c_short,
    y: c_short,
    w: c_ushort,
    h: c_ushort,
    img: struct_nk_image,
    col: struct_nk_color,
};
pub const nk_command_custom_callback = ?fn (?*anyopaque, c_short, c_short, c_ushort, c_ushort, nk_handle) callconv(.C) void;
pub const struct_nk_command_custom = extern struct {
    header: struct_nk_command,
    x: c_short,
    y: c_short,
    w: c_ushort,
    h: c_ushort,
    callback_data: nk_handle,
    callback: nk_command_custom_callback,
};
pub const struct_nk_command_text = extern struct {
    header: struct_nk_command,
    font: [*c]const struct_nk_user_font,
    background: struct_nk_color,
    foreground: struct_nk_color,
    x: c_short,
    y: c_short,
    w: c_ushort,
    h: c_ushort,
    height: f32,
    length: c_int,
    string: [1]u8,
};
pub const NK_CLIPPING_OFF: c_int = 0;
pub const NK_CLIPPING_ON: c_int = 1;
pub const enum_nk_command_clipping = c_uint;
pub extern fn nk_stroke_line(b: [*c]struct_nk_command_buffer, x0: f32, y0: f32, x1: f32, y1: f32, line_thickness: f32, struct_nk_color) void;
pub extern fn nk_stroke_curve([*c]struct_nk_command_buffer, f32, f32, f32, f32, f32, f32, f32, f32, line_thickness: f32, struct_nk_color) void;
pub extern fn nk_stroke_rect([*c]struct_nk_command_buffer, struct_nk_rect, rounding: f32, line_thickness: f32, struct_nk_color) void;
pub extern fn nk_stroke_circle([*c]struct_nk_command_buffer, struct_nk_rect, line_thickness: f32, struct_nk_color) void;
pub extern fn nk_stroke_arc([*c]struct_nk_command_buffer, cx: f32, cy: f32, radius: f32, a_min: f32, a_max: f32, line_thickness: f32, struct_nk_color) void;
pub extern fn nk_stroke_triangle([*c]struct_nk_command_buffer, f32, f32, f32, f32, f32, f32, line_thichness: f32, struct_nk_color) void;
pub extern fn nk_stroke_polyline([*c]struct_nk_command_buffer, points: [*c]f32, point_count: c_int, line_thickness: f32, col: struct_nk_color) void;
pub extern fn nk_stroke_polygon([*c]struct_nk_command_buffer, [*c]f32, point_count: c_int, line_thickness: f32, struct_nk_color) void;
pub extern fn nk_fill_rect([*c]struct_nk_command_buffer, struct_nk_rect, rounding: f32, struct_nk_color) void;
pub extern fn nk_fill_rect_multi_color([*c]struct_nk_command_buffer, struct_nk_rect, left: struct_nk_color, top: struct_nk_color, right: struct_nk_color, bottom: struct_nk_color) void;
pub extern fn nk_fill_circle([*c]struct_nk_command_buffer, struct_nk_rect, struct_nk_color) void;
pub extern fn nk_fill_arc([*c]struct_nk_command_buffer, cx: f32, cy: f32, radius: f32, a_min: f32, a_max: f32, struct_nk_color) void;
pub extern fn nk_fill_triangle([*c]struct_nk_command_buffer, x0: f32, y0: f32, x1: f32, y1: f32, x2: f32, y2: f32, struct_nk_color) void;
pub extern fn nk_fill_polygon([*c]struct_nk_command_buffer, [*c]f32, point_count: c_int, struct_nk_color) void;
pub extern fn nk_draw_image([*c]struct_nk_command_buffer, struct_nk_rect, [*c]const struct_nk_image, struct_nk_color) void;
pub extern fn nk_draw_nine_slice([*c]struct_nk_command_buffer, struct_nk_rect, [*c]const struct_nk_nine_slice, struct_nk_color) void;
pub extern fn nk_draw_text([*c]struct_nk_command_buffer, struct_nk_rect, text: [*c]const u8, len: c_int, [*c]const struct_nk_user_font, struct_nk_color, struct_nk_color) void;
pub extern fn nk_push_scissor([*c]struct_nk_command_buffer, struct_nk_rect) void;
pub extern fn nk_push_custom([*c]struct_nk_command_buffer, struct_nk_rect, nk_command_custom_callback, usr: nk_handle) void;
pub extern fn nk_input_has_mouse_click([*c]const struct_nk_input, enum_nk_buttons) nk_bool;
pub extern fn nk_input_has_mouse_click_in_rect([*c]const struct_nk_input, enum_nk_buttons, struct_nk_rect) nk_bool;
pub extern fn nk_input_has_mouse_click_down_in_rect([*c]const struct_nk_input, enum_nk_buttons, struct_nk_rect, down: nk_bool) nk_bool;
pub extern fn nk_input_is_mouse_click_in_rect([*c]const struct_nk_input, enum_nk_buttons, struct_nk_rect) nk_bool;
pub extern fn nk_input_is_mouse_click_down_in_rect(i: [*c]const struct_nk_input, id: enum_nk_buttons, b: struct_nk_rect, down: nk_bool) nk_bool;
pub extern fn nk_input_any_mouse_click_in_rect([*c]const struct_nk_input, struct_nk_rect) nk_bool;
pub extern fn nk_input_is_mouse_prev_hovering_rect([*c]const struct_nk_input, struct_nk_rect) nk_bool;
pub extern fn nk_input_is_mouse_hovering_rect([*c]const struct_nk_input, struct_nk_rect) nk_bool;
pub extern fn nk_input_mouse_clicked([*c]const struct_nk_input, enum_nk_buttons, struct_nk_rect) nk_bool;
pub extern fn nk_input_is_mouse_down([*c]const struct_nk_input, enum_nk_buttons) nk_bool;
pub extern fn nk_input_is_mouse_pressed([*c]const struct_nk_input, enum_nk_buttons) nk_bool;
pub extern fn nk_input_is_mouse_released([*c]const struct_nk_input, enum_nk_buttons) nk_bool;
pub extern fn nk_input_is_key_pressed([*c]const struct_nk_input, enum_nk_keys) nk_bool;
pub extern fn nk_input_is_key_released([*c]const struct_nk_input, enum_nk_keys) nk_bool;
pub extern fn nk_input_is_key_down([*c]const struct_nk_input, enum_nk_keys) nk_bool;
pub const nk_draw_index = nk_ushort;
pub const NK_STROKE_OPEN: c_int = 0;
pub const NK_STROKE_CLOSED: c_int = 1;
pub const enum_nk_draw_list_stroke = c_uint;
pub extern fn nk_draw_list_init([*c]struct_nk_draw_list) void;
pub extern fn nk_draw_list_setup([*c]struct_nk_draw_list, [*c]const struct_nk_convert_config, cmds: [*c]struct_nk_buffer, vertices: [*c]struct_nk_buffer, elements: [*c]struct_nk_buffer, line_aa: enum_nk_anti_aliasing, shape_aa: enum_nk_anti_aliasing) void;
pub extern fn nk__draw_list_begin([*c]const struct_nk_draw_list, [*c]const struct_nk_buffer) [*c]const struct_nk_draw_command;
pub extern fn nk__draw_list_next([*c]const struct_nk_draw_command, [*c]const struct_nk_buffer, [*c]const struct_nk_draw_list) [*c]const struct_nk_draw_command;
pub extern fn nk__draw_list_end([*c]const struct_nk_draw_list, [*c]const struct_nk_buffer) [*c]const struct_nk_draw_command;
pub extern fn nk_draw_list_path_clear([*c]struct_nk_draw_list) void;
pub extern fn nk_draw_list_path_line_to([*c]struct_nk_draw_list, pos: struct_nk_vec2) void;
pub extern fn nk_draw_list_path_arc_to_fast([*c]struct_nk_draw_list, center: struct_nk_vec2, radius: f32, a_min: c_int, a_max: c_int) void;
pub extern fn nk_draw_list_path_arc_to([*c]struct_nk_draw_list, center: struct_nk_vec2, radius: f32, a_min: f32, a_max: f32, segments: c_uint) void;
pub extern fn nk_draw_list_path_rect_to([*c]struct_nk_draw_list, a: struct_nk_vec2, b: struct_nk_vec2, rounding: f32) void;
pub extern fn nk_draw_list_path_curve_to([*c]struct_nk_draw_list, p2: struct_nk_vec2, p3: struct_nk_vec2, p4: struct_nk_vec2, num_segments: c_uint) void;
pub extern fn nk_draw_list_path_fill([*c]struct_nk_draw_list, struct_nk_color) void;
pub extern fn nk_draw_list_path_stroke([*c]struct_nk_draw_list, struct_nk_color, closed: enum_nk_draw_list_stroke, thickness: f32) void;
pub extern fn nk_draw_list_stroke_line([*c]struct_nk_draw_list, a: struct_nk_vec2, b: struct_nk_vec2, struct_nk_color, thickness: f32) void;
pub extern fn nk_draw_list_stroke_rect([*c]struct_nk_draw_list, rect: struct_nk_rect, struct_nk_color, rounding: f32, thickness: f32) void;
pub extern fn nk_draw_list_stroke_triangle([*c]struct_nk_draw_list, a: struct_nk_vec2, b: struct_nk_vec2, c: struct_nk_vec2, struct_nk_color, thickness: f32) void;
pub extern fn nk_draw_list_stroke_circle([*c]struct_nk_draw_list, center: struct_nk_vec2, radius: f32, struct_nk_color, segs: c_uint, thickness: f32) void;
pub extern fn nk_draw_list_stroke_curve([*c]struct_nk_draw_list, p0: struct_nk_vec2, cp0: struct_nk_vec2, cp1: struct_nk_vec2, p1: struct_nk_vec2, struct_nk_color, segments: c_uint, thickness: f32) void;
pub extern fn nk_draw_list_stroke_poly_line([*c]struct_nk_draw_list, pnts: [*c]const struct_nk_vec2, cnt: c_uint, struct_nk_color, enum_nk_draw_list_stroke, thickness: f32, enum_nk_anti_aliasing) void;
pub extern fn nk_draw_list_fill_rect([*c]struct_nk_draw_list, rect: struct_nk_rect, struct_nk_color, rounding: f32) void;
pub extern fn nk_draw_list_fill_rect_multi_color([*c]struct_nk_draw_list, rect: struct_nk_rect, left: struct_nk_color, top: struct_nk_color, right: struct_nk_color, bottom: struct_nk_color) void;
pub extern fn nk_draw_list_fill_triangle([*c]struct_nk_draw_list, a: struct_nk_vec2, b: struct_nk_vec2, c: struct_nk_vec2, struct_nk_color) void;
pub extern fn nk_draw_list_fill_circle([*c]struct_nk_draw_list, center: struct_nk_vec2, radius: f32, col: struct_nk_color, segs: c_uint) void;
pub extern fn nk_draw_list_fill_poly_convex([*c]struct_nk_draw_list, points: [*c]const struct_nk_vec2, count: c_uint, struct_nk_color, enum_nk_anti_aliasing) void;
pub extern fn nk_draw_list_add_image([*c]struct_nk_draw_list, texture: struct_nk_image, rect: struct_nk_rect, struct_nk_color) void;
pub extern fn nk_draw_list_add_text([*c]struct_nk_draw_list, [*c]const struct_nk_user_font, struct_nk_rect, text: [*c]const u8, len: c_int, font_height: f32, struct_nk_color) void;
pub extern fn nk_style_item_color(struct_nk_color) struct_nk_style_item;
pub extern fn nk_style_item_image(img: struct_nk_image) struct_nk_style_item;
pub extern fn nk_style_item_nine_slice(slice: struct_nk_nine_slice) struct_nk_style_item;
pub extern fn nk_style_item_hide() struct_nk_style_item;
pub const NK_PANEL_SET_NONBLOCK: c_int = 240;
pub const NK_PANEL_SET_POPUP: c_int = 244;
pub const NK_PANEL_SET_SUB: c_int = 246;
pub const enum_nk_panel_set = c_uint;
pub const NK_WINDOW_PRIVATE: c_int = 2048;
pub const NK_WINDOW_DYNAMIC: c_int = 2048;
pub const NK_WINDOW_ROM: c_int = 4096;
pub const NK_WINDOW_NOT_INTERACTIVE: c_int = 5120;
pub const NK_WINDOW_HIDDEN: c_int = 8192;
pub const NK_WINDOW_CLOSED: c_int = 16384;
pub const NK_WINDOW_MINIMIZED: c_int = 32768;
pub const NK_WINDOW_REMOVE_ROM: c_int = 65536;
pub const enum_nk_window_flags = c_uint;
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `LL`"); // (no file):66:9
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `ULL`"); // (no file):72:9
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `LL`"); // (no file):164:9
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`"); // (no file):186:9
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `ULL`"); // (no file):194:9
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):314:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):315:9
pub const __declspec = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):346:9
pub const _cdecl = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):347:9
pub const __cdecl = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):348:9
pub const _stdcall = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):349:9
pub const __stdcall = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):350:9
pub const _fastcall = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):351:9
pub const __fastcall = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):352:9
pub const _thiscall = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):353:9
pub const __thiscall = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):354:9
pub const _pascal = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):355:9
pub const __pascal = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):356:9
pub const NK_API = @compileError("unable to translate C expr: unexpected token 'extern'"); // deps/nuklear.h:264:13
pub const NK_LIB = @compileError("unable to translate C expr: unexpected token 'static'"); // deps/nuklear.h:269:13
pub const NK_INTERN = @compileError("unable to translate C expr: unexpected token 'static'"); // deps/nuklear.h:275:9
pub const NK_STORAGE = @compileError("unable to translate C expr: unexpected token 'static'"); // deps/nuklear.h:276:9
pub const NK_GLOBAL = @compileError("unable to translate C expr: unexpected token 'static'"); // deps/nuklear.h:277:9
pub const NK_STRINGIFY = @compileError("unable to translate C expr: unexpected token '#'"); // deps/nuklear.h:280:9
pub const NK_STRING_JOIN_IMMEDIATE = @compileError("unable to translate C expr: unexpected token '##'"); // deps/nuklear.h:282:9
pub const NK_UNIQUE_NAME = @compileError("unable to translate macro: undefined identifier `__LINE__`"); // deps/nuklear.h:289:11
pub const NK_STATIC_ASSERT = @compileError("unable to translate macro: undefined identifier `_dummy_array`"); // deps/nuklear.h:293:11
pub const NK_FILE_LINE = @compileError("unable to translate macro: undefined identifier `__FILE__`"); // deps/nuklear.h:300:11
pub const __stdint_join3 = @compileError("unable to translate C expr: unexpected token '##'"); // /opt/ziglang/lib/include/stdint.h:245:9
pub const __int_c_join = @compileError("unable to translate C expr: unexpected token '##'"); // /opt/ziglang/lib/include/stdint.h:282:9
pub const __uint_c = @compileError("unable to translate macro: undefined identifier `U`"); // /opt/ziglang/lib/include/stdint.h:284:9
pub const __INTN_MIN = @compileError("unable to translate macro: undefined identifier `INT`"); // /opt/ziglang/lib/include/stdint.h:639:10
pub const __INTN_MAX = @compileError("unable to translate macro: undefined identifier `INT`"); // /opt/ziglang/lib/include/stdint.h:640:10
pub const __UINTN_MAX = @compileError("unable to translate macro: undefined identifier `UINT`"); // /opt/ziglang/lib/include/stdint.h:641:9
pub const __INTN_C = @compileError("unable to translate macro: undefined identifier `INT`"); // /opt/ziglang/lib/include/stdint.h:642:10
pub const __UINTN_C = @compileError("unable to translate macro: undefined identifier `UINT`"); // /opt/ziglang/lib/include/stdint.h:643:9
pub const nk_foreach = @compileError("unable to translate C expr: unexpected token 'for'"); // deps/nuklear.h:1229:9
pub const nk_draw_foreach = @compileError("unable to translate C expr: unexpected token 'for'"); // deps/nuklear.h:1320:9
pub const nk_tree_push = @compileError("unable to translate macro: undefined identifier `__LINE__`"); // deps/nuklear.h:2890:9
pub const nk_tree_image_push = @compileError("unable to translate macro: undefined identifier `__LINE__`"); // deps/nuklear.h:2950:9
pub const nk_tree_element_push = @compileError("unable to translate macro: undefined identifier `__LINE__`"); // deps/nuklear.h:3048:9
pub const nk_draw_list_foreach = @compileError("unable to translate C expr: unexpected token 'for'"); // deps/nuklear.h:4811:9
pub const NK_CONFIGURATION_STACK_TYPE = @compileError("unable to translate macro: undefined identifier `nk_config_stack_`"); // deps/nuklear.h:5541:9
pub const NK_CONFIG_STACK = @compileError("unable to translate macro: undefined identifier `nk_config_stack_`"); // deps/nuklear.h:5546:9
pub const NK_LEN = @compileError("unable to translate C expr: expected ')' instead got '['"); // deps/nuklear.h:5672:9
pub const nk_ptr_add = @compileError("unable to translate C expr: unexpected token ')'"); // deps/nuklear.h:5688:9
pub const nk_ptr_add_const = @compileError("unable to translate C expr: unexpected token 'const'"); // deps/nuklear.h:5689:9
pub const nk_zero_struct = @compileError("unable to translate macro: undefined identifier `nk_zero`"); // deps/nuklear.h:5690:9
pub const NK_OFFSETOF = @compileError("unable to translate macro: undefined identifier `__builtin_offsetof`"); // deps/nuklear.h:5716:9
pub const NK_ALIGNOF = @compileError("unable to translate macro: undefined identifier `c`"); // deps/nuklear.h:5733:9
pub const NK_CONTAINER_OF = @compileError("unable to translate C expr: unexpected token ')'"); // deps/nuklear.h:5736:9
pub const __llvm__ = @as(c_int, 1);
pub const __clang__ = @as(c_int, 1);
pub const __clang_major__ = @as(c_int, 13);
pub const __clang_minor__ = @as(c_int, 0);
pub const __clang_patchlevel__ = @as(c_int, 1);
pub const __clang_version__ = "13.0.1 (git@github.com:ziglang/zig-bootstrap.git 81f0e6c5b902ead84753490db4f0007d08df964a)";
pub const __GNUC__ = @as(c_int, 4);
pub const __GNUC_MINOR__ = @as(c_int, 2);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 1);
pub const __GXX_ABI_VERSION = @as(c_int, 1002);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __OPENCL_MEMORY_SCOPE_WORK_ITEM = @as(c_int, 0);
pub const __OPENCL_MEMORY_SCOPE_WORK_GROUP = @as(c_int, 1);
pub const __OPENCL_MEMORY_SCOPE_DEVICE = @as(c_int, 2);
pub const __OPENCL_MEMORY_SCOPE_ALL_SVM_DEVICES = @as(c_int, 3);
pub const __OPENCL_MEMORY_SCOPE_SUB_GROUP = @as(c_int, 4);
pub const __PRAGMA_REDEFINE_EXTNAME = @as(c_int, 1);
pub const __VERSION__ = "Clang 13.0.1 (git@github.com:ziglang/zig-bootstrap.git 81f0e6c5b902ead84753490db4f0007d08df964a)";
pub const __OBJC_BOOL_IS_BOOL = @as(c_int, 0);
pub const __CONSTANT_CFSTRINGS__ = @as(c_int, 1);
pub const __SEH__ = @as(c_int, 1);
pub const __clang_literal_encoding__ = "UTF-8";
pub const __clang_wide_literal_encoding__ = "UTF-16";
pub const __OPTIMIZE__ = @as(c_int, 1);
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __INT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __LONG_MAX__ = @as(c_long, 2147483647);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __WCHAR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __WINT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INTMAX_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __SIZE_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __UINTMAX_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __PTRDIFF_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __INTPTR_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __UINTPTR_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 4);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 16);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 2);
pub const __SIZEOF_WINT_T__ = @as(c_int, 2);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTMAX_TYPE__ = c_longlong;
pub const __INTMAX_FMTd__ = "lld";
pub const __INTMAX_FMTi__ = "lli";
pub const __UINTMAX_TYPE__ = c_ulonglong;
pub const __UINTMAX_FMTo__ = "llo";
pub const __UINTMAX_FMTu__ = "llu";
pub const __UINTMAX_FMTx__ = "llx";
pub const __UINTMAX_FMTX__ = "llX";
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_TYPE__ = c_longlong;
pub const __PTRDIFF_FMTd__ = "lld";
pub const __PTRDIFF_FMTi__ = "lli";
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_TYPE__ = c_longlong;
pub const __INTPTR_FMTd__ = "lld";
pub const __INTPTR_FMTi__ = "lli";
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIZE_TYPE__ = c_ulonglong;
pub const __SIZE_FMTo__ = "llo";
pub const __SIZE_FMTu__ = "llu";
pub const __SIZE_FMTx__ = "llx";
pub const __SIZE_FMTX__ = "llX";
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __WCHAR_TYPE__ = c_ushort;
pub const __WCHAR_WIDTH__ = @as(c_int, 16);
pub const __WINT_TYPE__ = c_ushort;
pub const __WINT_WIDTH__ = @as(c_int, 16);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __SIG_ATOMIC_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_TYPE__ = c_ulonglong;
pub const __UINTPTR_FMTo__ = "llo";
pub const __UINTPTR_FMTu__ = "llu";
pub const __UINTPTR_FMTx__ = "llx";
pub const __UINTPTR_FMTX__ = "llX";
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = 4.9406564584124654e-324;
pub const __DBL_HAS_DENORM__ = @as(c_int, 1);
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = 2.2204460492503131e-16;
pub const __DBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __DBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = 1.7976931348623157e+308;
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = 2.2250738585072014e-308;
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_HAS_DENORM__ = @as(c_int, 1);
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __LDBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __POINTER_WIDTH__ = @as(c_int, 64);
pub const __BIGGEST_ALIGNMENT__ = @as(c_int, 16);
pub const __WCHAR_UNSIGNED__ = @as(c_int, 1);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub const __INT64_TYPE__ = c_longlong;
pub const __INT64_FMTd__ = "lld";
pub const __INT64_FMTi__ = "lli";
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub const __UINT16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulonglong;
pub const __UINT64_FMTo__ = "llo";
pub const __UINT64_FMTu__ = "llu";
pub const __UINT64_FMTx__ = "llx";
pub const __UINT64_FMTX__ = "llX";
pub const __UINT64_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __INT64_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_FMTd__ = "hhd";
pub const __INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const __UINT_LEAST8_FMTo__ = "hho";
pub const __UINT_LEAST8_FMTu__ = "hhu";
pub const __UINT_LEAST8_FMTx__ = "hhx";
pub const __UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_FMTd__ = "hd";
pub const __INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_LEAST16_FMTo__ = "ho";
pub const __UINT_LEAST16_FMTu__ = "hu";
pub const __UINT_LEAST16_FMTx__ = "hx";
pub const __UINT_LEAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_FMTd__ = "d";
pub const __INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_LEAST32_FMTo__ = "o";
pub const __UINT_LEAST32_FMTu__ = "u";
pub const __UINT_LEAST32_FMTx__ = "x";
pub const __UINT_LEAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_longlong;
pub const __INT_LEAST64_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __INT_LEAST64_FMTd__ = "lld";
pub const __INT_LEAST64_FMTi__ = "lli";
pub const __UINT_LEAST64_TYPE__ = c_ulonglong;
pub const __UINT_LEAST64_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __UINT_LEAST64_FMTo__ = "llo";
pub const __UINT_LEAST64_FMTu__ = "llu";
pub const __UINT_LEAST64_FMTx__ = "llx";
pub const __UINT_LEAST64_FMTX__ = "llX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_FMTd__ = "hhd";
pub const __INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const __UINT_FAST8_FMTo__ = "hho";
pub const __UINT_FAST8_FMTu__ = "hhu";
pub const __UINT_FAST8_FMTx__ = "hhx";
pub const __UINT_FAST8_FMTX__ = "hhX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_FMTd__ = "hd";
pub const __INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_FAST16_FMTo__ = "ho";
pub const __UINT_FAST16_FMTu__ = "hu";
pub const __UINT_FAST16_FMTx__ = "hx";
pub const __UINT_FAST16_FMTX__ = "hX";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_FMTd__ = "d";
pub const __INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_FAST32_FMTo__ = "o";
pub const __UINT_FAST32_FMTu__ = "u";
pub const __UINT_FAST32_FMTx__ = "x";
pub const __UINT_FAST32_FMTX__ = "X";
pub const __INT_FAST64_TYPE__ = c_longlong;
pub const __INT_FAST64_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __INT_FAST64_FMTd__ = "lld";
pub const __INT_FAST64_FMTi__ = "lli";
pub const __UINT_FAST64_TYPE__ = c_ulonglong;
pub const __UINT_FAST64_MAX__ = @as(c_ulonglong, 18446744073709551615);
pub const __UINT_FAST64_FMTo__ = "llo";
pub const __UINT_FAST64_FMTu__ = "llu";
pub const __UINT_FAST64_FMTx__ = "llx";
pub const __UINT_FAST64_FMTX__ = "llX";
pub const __USER_LABEL_PREFIX__ = "";
pub const __FINITE_MATH_ONLY__ = @as(c_int, 0);
pub const __GNUC_STDC_INLINE__ = @as(c_int, 1);
pub const __GCC_ATOMIC_TEST_AND_SET_TRUEVAL = @as(c_int, 1);
pub const __CLANG_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __PIC__ = @as(c_int, 2);
pub const __pic__ = @as(c_int, 2);
pub const __FLT_EVAL_METHOD__ = @as(c_int, 0);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const __GCC_ASM_FLAG_OUTPUTS__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __k8 = @as(c_int, 1);
pub const __k8__ = @as(c_int, 1);
pub const __tune_k8__ = @as(c_int, 1);
pub const __REGISTER_PREFIX__ = "";
pub const __NO_MATH_INLINES = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE2_MATH__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_1 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_2 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_4 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const _WIN32 = @as(c_int, 1);
pub const _WIN64 = @as(c_int, 1);
pub const WIN32 = @as(c_int, 1);
pub const __WIN32 = @as(c_int, 1);
pub const __WIN32__ = @as(c_int, 1);
pub const WINNT = @as(c_int, 1);
pub const __WINNT = @as(c_int, 1);
pub const __WINNT__ = @as(c_int, 1);
pub const WIN64 = @as(c_int, 1);
pub const __WIN64 = @as(c_int, 1);
pub const __WIN64__ = @as(c_int, 1);
pub const __MINGW64__ = @as(c_int, 1);
pub const __MSVCRT__ = @as(c_int, 1);
pub const __MINGW32__ = @as(c_int, 1);
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const _DEBUG = @as(c_int, 1);
pub const NK_INCLUDE_FIXED_TYPES = @as(c_int, 1);
pub const NK_INCLUDE_VERTEX_BUFFER_OUTPUT = @as(c_int, 1);
pub const NK_INCLUDE_FONT_BAKING = @as(c_int, 1);
pub const NK_INCLUDE_DEFAULT_FONT = @as(c_int, 1);
pub const NK_SINGLE_FILE = "";
pub const NK_NUKLEAR_H_ = "";
pub const NK_UNDEFINED = -@as(f32, 1.0);
pub const NK_UTF_INVALID = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xFFFD, .hexadecimal);
pub const NK_UTF_SIZE = @as(c_int, 4);
pub const NK_INPUT_MAX = @as(c_int, 16);
pub const NK_MAX_NUMBER_BUFFER = @as(c_int, 64);
pub const NK_SCROLLBAR_HIDING_TIMEOUT = @as(f32, 4.0);
pub inline fn NK_FLAG(x: anytype) @TypeOf(@as(c_int, 1) << x) {
    return @as(c_int, 1) << x;
}
pub inline fn NK_MACRO_STRINGIFY(x: anytype) @TypeOf(NK_STRINGIFY(x)) {
    return NK_STRINGIFY(x);
}
pub inline fn NK_STRING_JOIN_DELAY(arg1: anytype, arg2: anytype) @TypeOf(NK_STRING_JOIN_IMMEDIATE(arg1, arg2)) {
    return NK_STRING_JOIN_IMMEDIATE(arg1, arg2);
}
pub inline fn NK_STRING_JOIN(arg1: anytype, arg2: anytype) @TypeOf(NK_STRING_JOIN_DELAY(arg1, arg2)) {
    return NK_STRING_JOIN_DELAY(arg1, arg2);
}
pub inline fn NK_MIN(a: anytype, b: anytype) @TypeOf(if (a < b) a else b) {
    return if (a < b) a else b;
}
pub inline fn NK_MAX(a: anytype, b: anytype) @TypeOf(if (a < b) b else a) {
    return if (a < b) b else a;
}
pub inline fn NK_CLAMP(i: anytype, v: anytype, x: anytype) @TypeOf(NK_MAX(NK_MIN(v, x), i)) {
    return NK_MAX(NK_MIN(v, x), i);
}
pub const __CLANG_STDINT_H = "";
pub const __int_least64_t = i64;
pub const __uint_least64_t = u64;
pub const __int_least32_t = i64;
pub const __uint_least32_t = u64;
pub const __int_least16_t = i64;
pub const __uint_least16_t = u64;
pub const __int_least8_t = i64;
pub const __uint_least8_t = u64;
pub const __uint32_t_defined = "";
pub const __int8_t_defined = "";
pub const __intptr_t_defined = "";
pub const _INTPTR_T = "";
pub const _UINTPTR_T = "";
pub inline fn __int_c(v: anytype, suffix: anytype) @TypeOf(__int_c_join(v, suffix)) {
    return __int_c_join(v, suffix);
}
pub const __int64_c_suffix = __INT64_C_SUFFIX__;
pub const __int32_c_suffix = __INT64_C_SUFFIX__;
pub const __int16_c_suffix = __INT64_C_SUFFIX__;
pub const __int8_c_suffix = __INT64_C_SUFFIX__;
pub inline fn INT64_C(v: anytype) @TypeOf(__int_c(v, __int64_c_suffix)) {
    return __int_c(v, __int64_c_suffix);
}
pub inline fn UINT64_C(v: anytype) @TypeOf(__uint_c(v, __int64_c_suffix)) {
    return __uint_c(v, __int64_c_suffix);
}
pub inline fn INT32_C(v: anytype) @TypeOf(__int_c(v, __int32_c_suffix)) {
    return __int_c(v, __int32_c_suffix);
}
pub inline fn UINT32_C(v: anytype) @TypeOf(__uint_c(v, __int32_c_suffix)) {
    return __uint_c(v, __int32_c_suffix);
}
pub inline fn INT16_C(v: anytype) @TypeOf(__int_c(v, __int16_c_suffix)) {
    return __int_c(v, __int16_c_suffix);
}
pub inline fn UINT16_C(v: anytype) @TypeOf(__uint_c(v, __int16_c_suffix)) {
    return __uint_c(v, __int16_c_suffix);
}
pub inline fn INT8_C(v: anytype) @TypeOf(__int_c(v, __int8_c_suffix)) {
    return __int_c(v, __int8_c_suffix);
}
pub inline fn UINT8_C(v: anytype) @TypeOf(__uint_c(v, __int8_c_suffix)) {
    return __uint_c(v, __int8_c_suffix);
}
pub const INT64_MAX = INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const INT64_MIN = -INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const UINT64_MAX = UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const __INT_LEAST64_MIN = INT64_MIN;
pub const __INT_LEAST64_MAX = INT64_MAX;
pub const __UINT_LEAST64_MAX = UINT64_MAX;
pub const __INT_LEAST32_MIN = INT64_MIN;
pub const __INT_LEAST32_MAX = INT64_MAX;
pub const __UINT_LEAST32_MAX = UINT64_MAX;
pub const __INT_LEAST16_MIN = INT64_MIN;
pub const __INT_LEAST16_MAX = INT64_MAX;
pub const __UINT_LEAST16_MAX = UINT64_MAX;
pub const __INT_LEAST8_MIN = INT64_MIN;
pub const __INT_LEAST8_MAX = INT64_MAX;
pub const __UINT_LEAST8_MAX = UINT64_MAX;
pub const INT_LEAST64_MIN = __INT_LEAST64_MIN;
pub const INT_LEAST64_MAX = __INT_LEAST64_MAX;
pub const UINT_LEAST64_MAX = __UINT_LEAST64_MAX;
pub const INT_FAST64_MIN = __INT_LEAST64_MIN;
pub const INT_FAST64_MAX = __INT_LEAST64_MAX;
pub const UINT_FAST64_MAX = __UINT_LEAST64_MAX;
pub const INT32_MAX = INT32_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal));
pub const INT32_MIN = -INT32_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal)) - @as(c_int, 1);
pub const UINT32_MAX = UINT32_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 4294967295, .decimal));
pub const INT_LEAST32_MIN = __INT_LEAST32_MIN;
pub const INT_LEAST32_MAX = __INT_LEAST32_MAX;
pub const UINT_LEAST32_MAX = __UINT_LEAST32_MAX;
pub const INT_FAST32_MIN = __INT_LEAST32_MIN;
pub const INT_FAST32_MAX = __INT_LEAST32_MAX;
pub const UINT_FAST32_MAX = __UINT_LEAST32_MAX;
pub const INT16_MAX = INT16_C(@as(c_int, 32767));
pub const INT16_MIN = -INT16_C(@as(c_int, 32767)) - @as(c_int, 1);
pub const UINT16_MAX = UINT16_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal));
pub const INT_LEAST16_MIN = __INT_LEAST16_MIN;
pub const INT_LEAST16_MAX = __INT_LEAST16_MAX;
pub const UINT_LEAST16_MAX = __UINT_LEAST16_MAX;
pub const INT_FAST16_MIN = __INT_LEAST16_MIN;
pub const INT_FAST16_MAX = __INT_LEAST16_MAX;
pub const UINT_FAST16_MAX = __UINT_LEAST16_MAX;
pub const INT8_MAX = INT8_C(@as(c_int, 127));
pub const INT8_MIN = -INT8_C(@as(c_int, 127)) - @as(c_int, 1);
pub const UINT8_MAX = UINT8_C(@as(c_int, 255));
pub const INT_LEAST8_MIN = __INT_LEAST8_MIN;
pub const INT_LEAST8_MAX = __INT_LEAST8_MAX;
pub const UINT_LEAST8_MAX = __UINT_LEAST8_MAX;
pub const INT_FAST8_MIN = __INT_LEAST8_MIN;
pub const INT_FAST8_MAX = __INT_LEAST8_MAX;
pub const UINT_FAST8_MAX = __UINT_LEAST8_MAX;
pub const INTPTR_MIN = -__INTPTR_MAX__ - @as(c_int, 1);
pub const INTPTR_MAX = __INTPTR_MAX__;
pub const UINTPTR_MAX = __UINTPTR_MAX__;
pub const PTRDIFF_MIN = -__PTRDIFF_MAX__ - @as(c_int, 1);
pub const PTRDIFF_MAX = __PTRDIFF_MAX__;
pub const SIZE_MAX = __SIZE_MAX__;
pub const INTMAX_MIN = -__INTMAX_MAX__ - @as(c_int, 1);
pub const INTMAX_MAX = __INTMAX_MAX__;
pub const UINTMAX_MAX = __UINTMAX_MAX__;
pub const SIG_ATOMIC_MIN = __INTN_MIN(__SIG_ATOMIC_WIDTH__);
pub const SIG_ATOMIC_MAX = __INTN_MAX(__SIG_ATOMIC_WIDTH__);
pub const WINT_MIN = __UINTN_C(__WINT_WIDTH__, @as(c_int, 0));
pub const WINT_MAX = __UINTN_MAX(__WINT_WIDTH__);
pub const WCHAR_MAX = __WCHAR_MAX__;
pub const WCHAR_MIN = __UINTN_C(__WCHAR_WIDTH__, @as(c_int, 0));
pub inline fn INTMAX_C(v: anytype) @TypeOf(__int_c(v, __INTMAX_C_SUFFIX__)) {
    return __int_c(v, __INTMAX_C_SUFFIX__);
}
pub inline fn UINTMAX_C(v: anytype) @TypeOf(__int_c(v, __UINTMAX_C_SUFFIX__)) {
    return __int_c(v, __UINTMAX_C_SUFFIX__);
}
pub const NK_INT8 = i8;
pub const NK_UINT8 = u8;
pub const NK_INT16 = i16;
pub const NK_UINT16 = u16;
pub const NK_INT32 = i32;
pub const NK_UINT32 = u32;
pub const NK_SIZE_TYPE = usize;
pub const NK_POINTER_TYPE = usize;
pub const NK_BOOL = c_int;
pub inline fn nk_tree_push_id(ctx: anytype, @"type": anytype, title: anytype, state: anytype, id: anytype) @TypeOf(nk_tree_push_hashed(ctx, @"type", title, state, NK_FILE_LINE, nk_strlen(NK_FILE_LINE), id)) {
    return nk_tree_push_hashed(ctx, @"type", title, state, NK_FILE_LINE, nk_strlen(NK_FILE_LINE), id);
}
pub inline fn nk_tree_image_push_id(ctx: anytype, @"type": anytype, img: anytype, title: anytype, state: anytype, id: anytype) @TypeOf(nk_tree_image_push_hashed(ctx, @"type", img, title, state, NK_FILE_LINE, nk_strlen(NK_FILE_LINE), id)) {
    return nk_tree_image_push_hashed(ctx, @"type", img, title, state, NK_FILE_LINE, nk_strlen(NK_FILE_LINE), id);
}
pub inline fn nk_tree_element_push_id(ctx: anytype, @"type": anytype, title: anytype, state: anytype, sel: anytype, id: anytype) @TypeOf(nk_tree_element_push_hashed(ctx, @"type", title, state, sel, NK_FILE_LINE, nk_strlen(NK_FILE_LINE), id)) {
    return nk_tree_element_push_hashed(ctx, @"type", title, state, sel, NK_FILE_LINE, nk_strlen(NK_FILE_LINE), id);
}
pub const NK_STRTOD = nk_strtod;
pub const NK_TEXTEDIT_UNDOSTATECOUNT = @as(c_int, 99);
pub const NK_TEXTEDIT_UNDOCHARCOUNT = @as(c_int, 999);
pub const NK_VERTEX_LAYOUT_END = blk: {
    _ = NK_VERTEX_ATTRIBUTE_COUNT;
    _ = NK_FORMAT_COUNT;
    break :blk @as(c_int, 0);
};
pub const NK_MAX_LAYOUT_ROW_TEMPLATE_COLUMNS = @as(c_int, 16);
pub const NK_CHART_MAX_SLOT = @as(c_int, 4);
pub const NK_WINDOW_MAX_NAME = @as(c_int, 64);
pub const NK_BUTTON_BEHAVIOR_STACK_SIZE = @as(c_int, 8);
pub const NK_FONT_STACK_SIZE = @as(c_int, 8);
pub const NK_STYLE_ITEM_STACK_SIZE = @as(c_int, 16);
pub const NK_FLOAT_STACK_SIZE = @as(c_int, 32);
pub const NK_VECTOR_STACK_SIZE = @as(c_int, 16);
pub const NK_FLAGS_STACK_SIZE = @as(c_int, 32);
pub const NK_COLOR_STACK_SIZE = @as(c_int, 32);
pub const nk_float = f32;
pub const NK_VALUE_PAGE_CAPACITY = (NK_MAX(@import("std").zig.c_translation.sizeof(struct_nk_window), @import("std").zig.c_translation.sizeof(struct_nk_panel)) / @import("std").zig.c_translation.sizeof(nk_uint)) / @as(c_int, 2);
pub const NK_PI = @as(f32, 3.141592654);
pub const NK_MAX_FLOAT_PRECISION = @as(c_int, 2);
pub const NK_UNUSED = @import("std").zig.c_translation.Macros.DISCARD;
pub inline fn NK_SATURATE(x: anytype) @TypeOf(NK_MAX(@as(c_int, 0), NK_MIN(@as(f32, 1.0), x))) {
    return NK_MAX(@as(c_int, 0), NK_MIN(@as(f32, 1.0), x));
}
pub inline fn NK_ABS(a: anytype) @TypeOf(if (a < @as(c_int, 0)) -a else a) {
    return if (a < @as(c_int, 0)) -a else a;
}
pub inline fn NK_BETWEEN(x: anytype, a: anytype, b: anytype) @TypeOf((a <= x) and (x < b)) {
    return (a <= x) and (x < b);
}
pub inline fn NK_INBOX(px: anytype, py: anytype, x: anytype, y: anytype, w: anytype, h: anytype) @TypeOf((NK_BETWEEN(px, x, x + w) != 0) and (NK_BETWEEN(py, y, y + h) != 0)) {
    return (NK_BETWEEN(px, x, x + w) != 0) and (NK_BETWEEN(py, y, y + h) != 0);
}
pub inline fn NK_INTERSECT(x0: anytype, y0: anytype, w0: anytype, h0: anytype, x1: anytype, y1: anytype, w1: anytype, h1: anytype) @TypeOf((((x1 < (x0 + w0)) and (x0 < (x1 + w1))) and (y1 < (y0 + h0))) and (y0 < (y1 + h1))) {
    return (((x1 < (x0 + w0)) and (x0 < (x1 + w1))) and (y1 < (y0 + h0))) and (y0 < (y1 + h1));
}
pub inline fn NK_CONTAINS(x: anytype, y: anytype, w: anytype, h: anytype, bx: anytype, by: anytype, bw: anytype, bh: anytype) @TypeOf((NK_INBOX(x, y, bx, by, bw, bh) != 0) and (NK_INBOX(x + w, y + h, bx, by, bw, bh) != 0)) {
    return (NK_INBOX(x, y, bx, by, bw, bh) != 0) and (NK_INBOX(x + w, y + h, bx, by, bw, bh) != 0);
}
pub inline fn nk_vec2_sub(a: anytype, b: anytype) @TypeOf(nk_vec2(a.x - b.x, a.y - b.y)) {
    return nk_vec2(a.x - b.x, a.y - b.y);
}
pub inline fn nk_vec2_add(a: anytype, b: anytype) @TypeOf(nk_vec2(a.x + b.x, a.y + b.y)) {
    return nk_vec2(a.x + b.x, a.y + b.y);
}
pub inline fn nk_vec2_len_sqr(a: anytype) @TypeOf((a.x * a.x) + (a.y * a.y)) {
    return (a.x * a.x) + (a.y * a.y);
}
pub inline fn nk_vec2_muls(a: anytype, t: anytype) @TypeOf(nk_vec2(a.x * t, a.y * t)) {
    return nk_vec2(a.x * t, a.y * t);
}
pub inline fn NK_UINT_TO_PTR(x: anytype) ?*anyopaque {
    return @import("std").zig.c_translation.cast(?*anyopaque, __PTRDIFF_TYPE__(x));
}
pub inline fn NK_PTR_TO_UINT(x: anytype) nk_size {
    return @import("std").zig.c_translation.cast(nk_size, __PTRDIFF_TYPE__(x));
}
pub inline fn NK_ALIGN_PTR(x: anytype, mask: anytype) @TypeOf(NK_UINT_TO_PTR(NK_PTR_TO_UINT(@import("std").zig.c_translation.cast([*c]nk_byte, x) + (mask - @as(c_int, 1))) & ~(mask - @as(c_int, 1)))) {
    return NK_UINT_TO_PTR(NK_PTR_TO_UINT(@import("std").zig.c_translation.cast([*c]nk_byte, x) + (mask - @as(c_int, 1))) & ~(mask - @as(c_int, 1)));
}
pub inline fn NK_ALIGN_PTR_BACK(x: anytype, mask: anytype) @TypeOf(NK_UINT_TO_PTR(NK_PTR_TO_UINT(@import("std").zig.c_translation.cast([*c]nk_byte, x)) & ~(mask - @as(c_int, 1)))) {
    return NK_UINT_TO_PTR(NK_PTR_TO_UINT(@import("std").zig.c_translation.cast([*c]nk_byte, x)) & ~(mask - @as(c_int, 1)));
}
pub const nk_buffer_marker = struct_nk_buffer_marker;
pub const nk_allocator = struct_nk_allocator;
pub const nk_allocation_type = enum_nk_allocation_type;
pub const nk_memory = struct_nk_memory;
pub const nk_buffer = struct_nk_buffer;
pub const nk_command_buffer = struct_nk_command_buffer;
pub const nk_draw_command = struct_nk_draw_command;
pub const nk_anti_aliasing = enum_nk_anti_aliasing;
pub const nk_draw_null_texture = struct_nk_draw_null_texture;
pub const nk_draw_vertex_layout_attribute = enum_nk_draw_vertex_layout_attribute;
pub const nk_draw_vertex_layout_format = enum_nk_draw_vertex_layout_format;
pub const nk_draw_vertex_layout_element = struct_nk_draw_vertex_layout_element;
pub const nk_convert_config = struct_nk_convert_config;
pub const nk_style_item_type = enum_nk_style_item_type;
pub const nk_color = struct_nk_color;
pub const nk_nine_slice = struct_nk_nine_slice;
pub const nk_style_item_data = union_nk_style_item_data;
pub const nk_style_item = struct_nk_style_item;
pub const nk_clipboard = struct_nk_clipboard;
pub const nk_str = struct_nk_str;
pub const nk_text_undo_record = struct_nk_text_undo_record;
pub const nk_text_undo_state = struct_nk_text_undo_state;
pub const nk_text_edit = struct_nk_text_edit;
pub const nk_draw_list = struct_nk_draw_list;
pub const nk_user_font_glyph = struct_nk_user_font_glyph;
pub const nk_user_font = struct_nk_user_font;
pub const nk_panel_type = enum_nk_panel_type;
pub const nk_scroll = struct_nk_scroll;
pub const nk_menu_state = struct_nk_menu_state;
pub const nk_panel_row_layout_type = enum_nk_panel_row_layout_type;
pub const nk_row_layout = struct_nk_row_layout;
pub const nk_chart_type = enum_nk_chart_type;
pub const nk_chart_slot = struct_nk_chart_slot;
pub const nk_chart = struct_nk_chart;
pub const nk_panel = struct_nk_panel;
pub const nk_key = struct_nk_key;
pub const nk_keyboard = struct_nk_keyboard;
pub const nk_mouse_button = struct_nk_mouse_button;
pub const nk_mouse = struct_nk_mouse;
pub const nk_input = struct_nk_input;
pub const nk_cursor = struct_nk_cursor;
pub const nk_style_text = struct_nk_style_text;
pub const nk_style_button = struct_nk_style_button;
pub const nk_style_toggle = struct_nk_style_toggle;
pub const nk_style_selectable = struct_nk_style_selectable;
pub const nk_symbol_type = enum_nk_symbol_type;
pub const nk_style_slider = struct_nk_style_slider;
pub const nk_style_progress = struct_nk_style_progress;
pub const nk_style_scrollbar = struct_nk_style_scrollbar;
pub const nk_style_edit = struct_nk_style_edit;
pub const nk_style_property = struct_nk_style_property;
pub const nk_style_chart = struct_nk_style_chart;
pub const nk_style_tab = struct_nk_style_tab;
pub const nk_style_combo = struct_nk_style_combo;
pub const nk_style_header_align = enum_nk_style_header_align;
pub const nk_style_window_header = struct_nk_style_window_header;
pub const nk_style_window = struct_nk_style_window;
pub const nk_style = struct_nk_style;
pub const nk_button_behavior = enum_nk_button_behavior;
pub const nk_config_stack_style_item_element = struct_nk_config_stack_style_item_element;
pub const nk_config_stack_style_item = struct_nk_config_stack_style_item;
pub const nk_config_stack_float_element = struct_nk_config_stack_float_element;
pub const nk_config_stack_float = struct_nk_config_stack_float;
pub const nk_config_stack_vec2_element = struct_nk_config_stack_vec2_element;
pub const nk_config_stack_vec2 = struct_nk_config_stack_vec2;
pub const nk_config_stack_flags_element = struct_nk_config_stack_flags_element;
pub const nk_config_stack_flags = struct_nk_config_stack_flags;
pub const nk_config_stack_color_element = struct_nk_config_stack_color_element;
pub const nk_config_stack_color = struct_nk_config_stack_color;
pub const nk_config_stack_user_font_element = struct_nk_config_stack_user_font_element;
pub const nk_config_stack_user_font = struct_nk_config_stack_user_font;
pub const nk_config_stack_button_behavior_element = struct_nk_config_stack_button_behavior_element;
pub const nk_config_stack_button_behavior = struct_nk_config_stack_button_behavior;
pub const nk_configuration_stacks = struct_nk_configuration_stacks;
pub const nk_table = struct_nk_table;
pub const nk_property_state = struct_nk_property_state;
pub const nk_popup_buffer = struct_nk_popup_buffer;
pub const nk_popup_state = struct_nk_popup_state;
pub const nk_edit_state = struct_nk_edit_state;
pub const nk_window = struct_nk_window;
pub const nk_page_data = union_nk_page_data;
pub const nk_page_element = struct_nk_page_element;
pub const nk_page = struct_nk_page;
pub const nk_pool = struct_nk_pool;
pub const nk_context = struct_nk_context;
pub const nk_style_slide = struct_nk_style_slide;
pub const nk_colorf = struct_nk_colorf;
pub const nk_heading = enum_nk_heading;
pub const nk_modify = enum_nk_modify;
pub const nk_orientation = enum_nk_orientation;
pub const nk_collapse_states = enum_nk_collapse_states;
pub const nk_show_states = enum_nk_show_states;
pub const nk_chart_event = enum_nk_chart_event;
pub const nk_color_format = enum_nk_color_format;
pub const nk_popup_type = enum_nk_popup_type;
pub const nk_layout_format = enum_nk_layout_format;
pub const nk_tree_type = enum_nk_tree_type;
pub const nk_keys = enum_nk_keys;
pub const nk_buttons = enum_nk_buttons;
pub const nk_convert_result = enum_nk_convert_result;
pub const nk_command_type = enum_nk_command_type;
pub const nk_command = struct_nk_command;
pub const nk_panel_flags = enum_nk_panel_flags;
pub const nk_list_view = struct_nk_list_view;
pub const nk_widget_layout_states = enum_nk_widget_layout_states;
pub const nk_widget_states = enum_nk_widget_states;
pub const nk_text_align = enum_nk_text_align;
pub const nk_text_alignment = enum_nk_text_alignment;
pub const nk_edit_flags = enum_nk_edit_flags;
pub const nk_edit_types = enum_nk_edit_types;
pub const nk_edit_events = enum_nk_edit_events;
pub const nk_style_colors = enum_nk_style_colors;
pub const nk_style_cursor = enum_nk_style_cursor;
pub const nk_font_coord_type = enum_nk_font_coord_type;
pub const nk_baked_font = struct_nk_baked_font;
pub const nk_font_glyph = struct_nk_font_glyph;
pub const nk_font = struct_nk_font;
pub const nk_font_atlas_format = enum_nk_font_atlas_format;
pub const nk_font_atlas = struct_nk_font_atlas;
pub const nk_memory_status = struct_nk_memory_status;
pub const nk_buffer_allocation_type = enum_nk_buffer_allocation_type;
pub const nk_text_edit_type = enum_nk_text_edit_type;
pub const nk_text_edit_mode = enum_nk_text_edit_mode;
pub const nk_command_scissor = struct_nk_command_scissor;
pub const nk_command_line = struct_nk_command_line;
pub const nk_command_curve = struct_nk_command_curve;
pub const nk_command_rect = struct_nk_command_rect;
pub const nk_command_rect_filled = struct_nk_command_rect_filled;
pub const nk_command_rect_multi_color = struct_nk_command_rect_multi_color;
pub const nk_command_triangle = struct_nk_command_triangle;
pub const nk_command_triangle_filled = struct_nk_command_triangle_filled;
pub const nk_command_circle = struct_nk_command_circle;
pub const nk_command_circle_filled = struct_nk_command_circle_filled;
pub const nk_command_arc = struct_nk_command_arc;
pub const nk_command_arc_filled = struct_nk_command_arc_filled;
pub const nk_command_polygon = struct_nk_command_polygon;
pub const nk_command_polygon_filled = struct_nk_command_polygon_filled;
pub const nk_command_polyline = struct_nk_command_polyline;
pub const nk_command_image = struct_nk_command_image;
pub const nk_command_custom = struct_nk_command_custom;
pub const nk_command_text = struct_nk_command_text;
pub const nk_command_clipping = enum_nk_command_clipping;
pub const nk_draw_list_stroke = enum_nk_draw_list_stroke;
pub const nk_panel_set = enum_nk_panel_set;
pub const nk_window_flags = enum_nk_window_flags;

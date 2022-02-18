const c = @cImport({
	@cDefine("NK_INCLUDE_VERTEX_BUFFER_OUTPUT", {});
	@cDefine("NK_INCLUDE_FONT_BAKING", {});
	@cDefine("NK_INCLUDE_DEFAULT_FONT", {});
	@cInclude("nuklear.h");
});

pub usingnamespace c;

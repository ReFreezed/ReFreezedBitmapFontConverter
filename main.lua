--[[============================================================
--=
--=  ReFreezed Bitmap Font converter - convert RBMF files to BMFont
--=  by Marcus 'ReFreezed' Thunström
--=
--=  Works with LÖVE 11.3
--=
--============================================================]]

local CMD_HELP = [=[
	Arguments:
		<inputPath1> [<inputPath2> ...]
		[--outdir   <outputDirectory>]      # Where to output files. (Default: Same directory as the input.)
		[--icons    <outputFilePath>]       # Where to put the icons file if any icons are specified. (Default: <outputDirectory>/.fonticons)
		[--mergeicons]                      # Merge new icons with existing icons if the icons file exists. (Default: Icon file is replaced.)
		[--maxwidth <outputImageMaxWidth>]  # Default: 1024
		[--textfile <filePath1> [--textfile <filePath2> ...]]

	Notes:
		<inputPath> can be a .rbmf file or a directory with .rbmf files.
		The filenames of outputted files is specified in the font descriptor.
		Relative --textfile paths will be relative to CWD, unlike the 'textFile' input descriptor field.
]=]

local CMD_TITLE     = "ReFreezed Bitmap Font converter"
local CMD_SEPARATOR = ("-"):rep(#CMD_TITLE)

local programArguments = arg



local function RbmfFile()
	return {
		path = "",
		ln   = 0, -- Current line number.

		-- Params.
		version = 0,

		codepoints = {--[[ [row1]={cp1,...}, ... ]]},
		icons      = {--[[ iconName1,        ... ]]},

		isColored = true, -- Uncolored fonts can be optimized so the 4 channels contain different glyphs in the output.

		fontFilename = "",
		fontSize     = 0,
		fontHinting  = "normal",

		textFilePaths = {--[[ path1, ... ]]},

		editAlphaTreshold = 0, -- 0 means no cleaning of font pixels.

		outputDescriptors = {--[[ outputDescriptor1, ... ]]},

		kernings = {--[[ [pair1]=offset1, ... ]]},
		--

		codepointLines = {--[[ [cp1]=ln1,   ... ]]}, -- For dupe checking.
		kerningLines   = {--[[ [pair1]=ln1, ... ]]}, -- For dupe checking.
		lastRow        = 0,

		useTextFiles   = false,
		textCodepoints = {--[[ [cp1]=true, ... ]]},
	}
end

local function OutputDescriptor()
	return {
		ln = 0,

		-- Params.
		filenameImage      = "",
		filenameDescriptor = "",

		glyphPaddingU = 0,
		glyphPaddingR = 0,
		glyphPaddingD = 0,
		glyphPaddingL = 0,

		glyphSpacingH = 1,
		glyphSpacingV = 1,

		outlineWidth = 0,
		outlineColor = {0,0,0,1},

		customValues = {--[[ [1]=k1, [k1]=v1, ... ]]},
		--

		pathImage      = "",
		pathDescriptor = "",
	}
end



function love.errorhandler(err)
	io.stderr:write(debug.traceback("Error: "..tostring(err), 3), "\n", "\n") -- @UX
end
love.errhand = nil



function love.run()
	local startTime = require"socket".gettime()

	_G.physfs = require"physfs"
	_G.socket = require"socket"
	_G.utf8   = require"utf8"

	require"functions"

	_G.LF = love.filesystem
	_G.LI = love.image

	_G.warningCount = 0

	io.stdout:setvbuf"no"
	io.stderr:setvbuf"no"

	--
	-- Get args
	--

	local in_paths           = {}
	local in_textFilesForAll = {}
	local out_directory      = ""
	local out_iconsPath      = ""
	local out_mergeIcons     = false
	local out_imageMaxWidth  = 1024

	local args = love.arg.parseGameArguments(programArguments)
	local i    = 1

	args[1] = args[1] or "--help"

	while args[i] do
		if not args[i]:find"^%-" then
			table.insert(in_paths, normalizePath(args[i])) -- Directory or file.
			i = i+1

		elseif args[i] == "--help" then
			print(CMD_TITLE)
			print()
			print((CMD_HELP:gsub("\t", "    ")))
			return

		elseif args[i] == "--outdir" then
			out_directory = args[i+1] or errorLine("Argument: Missing path after '%s'.", args[i])
			out_directory = normalizePath(out_directory)
			i = i+2

		elseif args[i] == "--maxwidth" then
			local v           = args[i+1] or errorLine("Argument: Missing number after '%s'.", args[i])
			out_imageMaxWidth = tonumber(out_imageMaxWidth:match"^%-?%d+$") or errorLine("Argument: '%s' is not an integer.", v)
			if out_imageMaxWidth < 1 then
				errorLine("--maxwidth must be positive.")
			end
			i = i+2

		elseif args[i] == "--icons" then
			out_iconsPath = args[i+1] or errorLine("Argument: Missing path after '%s'.", args[i])
			out_iconsPath = normalizePath(out_iconsPath)
			i = i+2

		elseif args[i] == "--mergeicons" then
			out_mergeIcons = true
			i = i+1

		elseif args[i] == "--textfile" then
			local path = args[i+1] or errorLine("Argument: Missing path after '%s'.", args[i])
			table.insert(in_textFilesForAll, normalizePath(path))
			i = i+2

		else
			errorLine("Argument: Unknown option %s", args[i])
		end
	end

	if not in_paths[1] then
		errorLine("Argument: Missing any input path.") -- @UX: Show help.
	end

	print(CMD_TITLE)
	print(CMD_SEPARATOR)
	print(os.date"          %Y-%m-%d %H:%M:%S")
	printf(      "   Input: %s", table.concat(in_paths, ", "))
	printf(      "  Output: %s", (out_directory ~= "" and out_directory or "(in input directory)"))
	printf(      "MaxWidth: %d", out_imageMaxWidth)
	print(CMD_SEPARATOR)

	-- Collect all paths to process.
	local rbmfFiles = {}

	for _, path in ipairs(in_paths) do
		if isFile(path) then
			local rbmfFile = RbmfFile()
			rbmfFile.path  = path
			table.insert(rbmfFiles, rbmfFile)
		else
			for _, filename in ipairs(getDirectoryItems(path)) do
				if filename:find"%.rbmf$" then
					local rbmfFile = RbmfFile()
					rbmfFile.path  = path.."/"..filename
					table.insert(rbmfFiles, rbmfFile)
				end
			end
		end
	end

	--
	-- Load existing icons
	--
	if out_iconsPath == "" then
		out_iconsPath = (out_directory ~= "" and appendPath(out_directory, ".fonticons") or "")
	end

	if out_mergeIcons and out_iconsPath ~= "" and isFile(out_iconsPath) then
		local dir = getDirectory(out_iconsPath)
		local ln  = 0

		if not connectToDirectory(dir) then
			errorLine("Cannot access directory '%s'.", dir)
		end

		for line in LF.lines(getFilename(out_iconsPath)) do
			ln = ln+1

			local cp, icon = line:match"^ *(%d+) +(%S+) *$"
			cp             = tonumber(cp)

			if not cp then  errorf("%s:%d: Bad line format: %s", out_iconsPath, ln, line)  end

			setIconCodepoint(icon, cp)
		end
	end

	--
	-- Read rbmf files
	--
	for _, rbmfFile in ipairs(rbmfFiles) do
		if rbmfFile.path == "" then
			errorLine("An input path is empty.")
		end

		if not connectToDirectory(getDirectory(rbmfFile.path)) then
			errorLine("Could not read from directory '%s'.", getDirectory(rbmfFile.path))
		end

		local section         = ""
		local sectionLines    = {}
		local currentOutDescr = nil

		local file, err = LF.newFile(getFilename(rbmfFile.path), "r")
		if not file then
			errorLine("Could not open file '%s'. (%s)", rbmfFile.path, err)
		end

		for line in file:lines() do
			rbmfFile.ln = rbmfFile.ln + 1
			local k, v  = line:match"^([%a][%w_.]+)=(.*)$"

			-- Empty/comment.
			if line == "" or line:find"^#" then
				-- void

			-- Version line.
			elseif rbmfFile.version == 0 then
				if k ~= "version" then
					fileError(rbmfFile, "The first line must be the file version number!")
				end

				rbmfFile.version = fileAssert(rbmfFile, parseInt(v))
				if rbmfFile.version ~= 1 then
					fileError(rbmfFile, "Unsupported file version '%d'.", rbmfFile.version)
				end

			-- Section start.
			elseif line:find"^%[" then
				section = line:match"%[(%w+)%]" or fileError(rbmfFile, "Invalid section name line format: %s", line)

				if sectionLines[section] and not (section == "out") then
					fileError(rbmfFile, "Duplicate section '%s'. (Previous is on line %d)", section, sectionLines[section])
				end

				sectionLines[section] = rbmfFile.ln

				if section == "out" then
					currentOutDescr    = OutputDescriptor()
					currentOutDescr.ln = rbmfFile.ln
					table.insert(rbmfFile.outputDescriptors, currentOutDescr)
				else
					currentOutDescr = nil
				end

				if section:find"^%d+$" then
					rbmfFile.lastRow = math.max(rbmfFile.lastRow, tonumber(section))
				end

			elseif not k then
				fileError(rbmfFile, "Invalid key-value line format: %s", line)

			----------------------------------------------------------------

			elseif section == "in" then
				v = trim(v)

				if k == "colored" then
					rbmfFile.isColored = fileAssert(rbmfFile, parseBool(v))

				elseif k == "fontFile" then
					rbmfFile.fontFilename = (v ~= "" and v or fileError(rbmfFile, "TrueType font path cannot be empty."))
				elseif k == "fontSize" then
					rbmfFile.fontSize = fileAssert(rbmfFile, parseInt(v))
					if rbmfFile.fontSize < 1 then
						fileError(rbmfFile, "TrueType font size must be positive. (Value is '%s')", v)
					end
				elseif k == "fontHinting" then
					rbmfFile.fontHinting = v
					if not (v == "normal" or v == "light" or v == "mono" or v == "none") then
						fileError(rbmfFile, "Invalid TrueType font hinting '%s'. (Valid values: normal, light, mono, none)", v)
					end

				elseif k == "textFile" then
					-- Note: Paths are relative to inputPath, unlike the --textfile argument.
					local path = (v ~= "" and v or fileError(rbmfFile, "Path cannot be empty."))
					table.insert(rbmfFile.textFilePaths, path)

				else
					fileError(rbmfFile, "Unknown [%s] key '%s'.", section, k)
				end

			----------------------------------------------------------------

			elseif section == "edit" then
				v = trim(v)

				if k == "alphaTreshold" then
					rbmfFile.editAlphaTreshold = fileAssert(rbmfFile, parseNumber(v))
					if rbmfFile.editAlphaTreshold < 0 or rbmfFile.editAlphaTreshold > 1 then
						fileError(rbmfFile, "Alpha treshold must be between 0 and 1. (Value is '%s')", v)
					end

				else
					fileError(rbmfFile, "Unknown [%s] key '%s'.", section, k)
				end

			----------------------------------------------------------------

			elseif section == "out" then
				v = trim(v)

				if k == "fileImage" then
					local path                    = normalizePath(v ~= "" and v or fileError(rbmfFile, "Path cannot be empty."))
					currentOutDescr.filenameImage = processPathTemplate(rbmfFile, path)
					currentOutDescr.pathImage     = appendPath(out_directory, currentOutDescr.filenameImage)
				elseif k == "fileDescriptor" then
					local path                         = normalizePath(v ~= "" and v or fileError(rbmfFile, "Path cannot be empty."))
					currentOutDescr.filenameDescriptor = processPathTemplate(rbmfFile, path)
					currentOutDescr.pathDescriptor     = appendPath(out_directory, currentOutDescr.filenameDescriptor)

				elseif k == "glyphPadding" then
					currentOutDescr.glyphPaddingU, currentOutDescr.glyphPaddingR, currentOutDescr.glyphPaddingD, currentOutDescr.glyphPaddingL = fileAssert(rbmfFile, parseInt4(v))
				elseif k == "glyphSpacing" then
					currentOutDescr.glyphSpacingH, currentOutDescr.glyphSpacingV = fileAssert(rbmfFile, parseInt2(v))

				elseif k == "outlineWidth" then
					currentOutDescr.outlineWidth = fileAssert(rbmfFile, parseInt(v))
				elseif k == "outlineColor" then
					local r, g, b, a = v:match"^(%d*%.?%d+) +(%d*%.?%d+) +(%d*%.?%d+) +(%d*%.?%d+)$"

					r = tonumber(r)
					g = tonumber(g)
					b = tonumber(b)
					a = tonumber(a)

					if not (r and g and b and a) then
						fileError(rbmfFile, "Invalid color format: %s", v)
					end

					currentOutDescr.outlineColor[1] = math.min(math.max(r, 0), 1)
					currentOutDescr.outlineColor[2] = math.min(math.max(g, 0), 1)
					currentOutDescr.outlineColor[3] = math.min(math.max(b, 0), 1)
					currentOutDescr.outlineColor[4] = math.min(math.max(a, 0), 1)

				elseif k:find"^custom%.[%a_][%w_]*$" then
					k = k:sub(8)

					if currentOutDescr.customValues[k] == nil then
						table.insert(currentOutDescr.customValues, k)
					end

					currentOutDescr.customValues[k] = v

				else
					fileError(rbmfFile, "Unknown [%s] key '%s'.", section, k)
				end

			----------------------------------------------------------------

			elseif section:find"^%d+$" then
				if k == "glyphs" then
					for _, cp in utf8.codes(v) do
						if rbmfFile.codepointLines[cp] then
							fileError(
								rbmfFile, "Glyph '%s' (codepoint %d) already appeared previously on line %d.",
								utf8.char(cp), cp, rbmfFile.codepointLines[cp]
							)
						end

						local row = tonumber(section) -- @Speed
						addCodepoint(rbmfFile, row, cp, nil)
					end

				else
					v = trim(v)

					if k == "icons" then
						for icon in v:gmatch"%S+" do
							local cp = getIconCodepoint(icon)

							if rbmfFile.codepointLines[cp] then
								fileError(rbmfFile, "Icon '%s' already appeared previously on line %d.", icon, rbmfFile.codepointLines[cp])
							end

							local row = tonumber(section) -- @Speed
							addCodepoint(rbmfFile, row, cp, icon)
						end

					else
						fileError(rbmfFile, "Unknown [%s] key '%s'.", section, k)
					end
				end

			----------------------------------------------------------------

			elseif section == "kerning" then
				v = trim(v)

				if k == "forward" then
					local firsts, seconds, thirds, offset = v:match"^(%S+) +(%S+) +(%S+) +(%S+)$"
					if not firsts then
						firsts, seconds, offset = v:match"^(%S+) +(%S+) +(%S+)$"
					end
					if not firsts then
						fileError(rbmfFile, "Invalid 'forward' kerning value format '%s'. (Format is 'firstGlyphs secondGlyphs [thirdGlyphs] offset').", v)
					end

					offset = fileAssert(rbmfFile, parseInt(offset))

					addKerningPairs(rbmfFile, firsts, seconds, offset, false)
					if thirds then  addKerningPairs(rbmfFile, seconds, thirds, offset, false)  end

				elseif k == "bothways" then
					local firsts, seconds, offset = v:match"^(%S+) +(%S+) +(%S+)$"

					if not firsts then
						fileError(rbmfFile, "Invalid 'bothways' kerning value format '%s'. (Format is 'firstGlyphs secondGlyphs offset').", v)
					end

					offset = fileAssert(rbmfFile, parseInt(offset))

					addKerningPairs(rbmfFile, firsts, seconds, offset, true)

				else
					fileError(rbmfFile, "Unknown [%s] key '%s'.", section, k)
				end

			----------------------------------------------------------------

			elseif section == "" then
				fileError(rbmfFile, "Expected a section.")
			else
				rbmfFile.ln = sectionLines[section]
				fileError(rbmfFile, "Unknown section name '%s'.")
			end
		end

		file:close()
		rbmfFile.ln = 0

		if not rbmfFile.outputDescriptors[1] then
			fileError(rbmfFile, "No outputs specified.")
		end

		if rbmfFile.textFilePaths[1] and rbmfFile.fontFilename == "" then
			fileError(rbmfFile, "%d text file%s was specified, but no TrueType font.", #rbmfFile.textFilePaths, S(rbmfFile.textFilePaths))
		end

		if rbmfFile.fontFilename ~= "" and rbmfFile.fontSize == 0 then
			fileError(rbmfFile, "A TrueType font was specified, but no font size.", #rbmfFile.textFilePaths, S(rbmfFile.textFilePaths))
		end
		if rbmfFile.fontSize > 0 and rbmfFile.fontFilename == "" then
			fileError(rbmfFile, "A font size was specified, but no TrueType font.", #rbmfFile.textFilePaths, S(rbmfFile.textFilePaths))
		end

		rbmfFile.useTextFiles = (in_textFilesForAll[1] or rbmfFile.textFilePaths[1]) ~= nil

		if not rbmfFile.useTextFiles and rbmfFile.lastRow == 0 then
			fileError(rbmfFile, "No glyphs specified or imported from text files.")
		end

		for _, outDescr in ipairs(rbmfFile.outputDescriptors) do
			if outDescr.filenameImage == "" then
				rbmfFile.ln = outDescr.ln
				fileWarning(rbmfFile, "No image file specified for this output.")
				rbmfFile.ln = 0
			end
			if outDescr.filenameDescriptor == "" then
				rbmfFile.ln = outDescr.ln
				fileWarning(rbmfFile, "No descriptor file specified for this output.")
				rbmfFile.ln = 0
			end
		end
	end

	--
	-- Load glyph filter text files
	--
	for _, rbmfFile in ipairs(rbmfFiles) do
		if rbmfFile.useTextFiles then
			local function processTextFile(path, textCps)
				printf("Loading text file: %s", path)

				local s, err = getFileContents(path)
				if not s then
					errorLine("Could not open text file '%s'. (%s)", path, err)
				end

				for _, cp in utf8.codes(s) do
					if cp >= 32 then  textCps[cp] = true  end -- @Robustness: Better printable character check.
				end
			end

			for _, path in ipairs(in_textFilesForAll) do -- @Speed: Only process these files from args once.
				processTextFile(path, rbmfFile.textCodepoints)
			end
			for _, pathRel in ipairs(rbmfFile.textFilePaths) do
				local dir  = getDirectory(rbmfFile.path)
				local path = appendPath(dir, pathRel)
				processTextFile(path, rbmfFile.textCodepoints)
			end
		end
	end

	--
	-- Convert font files
	--

	for _, rbmfFile in ipairs(rbmfFiles) do
		--
		-- Load input image
		--
		local in_imageData
		local in_lineHeight, in_lineDist
		local glyphs = {}

		----------------

		if rbmfFile.fontFilename ~= "" then
			if not love.window then
				require"love.window"
				require"love.graphics"
				require"love.font"
				-- @UX: Can we hide the window somehow? At least it seems to be transparent because we don't call present() (tested on Windows 7).
				love.window.setMode(1, 1, {borderless=true, vsync=false, x=0, y=0})
			end

			local LG = love.graphics

			local dir = getDirectory(rbmfFile.path)
			if not connectToDirectory(dir) then
				errorLine("Could not read from directory '%s'.", dir)
			end

			printf("Loading font: %s", appendPath(dir, rbmfFile.fontFilename))
			local font = LG.newFont(rbmfFile.fontFilename, rbmfFile.fontSize, rbmfFile.fontHinting)

			in_lineHeight = font:getHeight()
			in_lineDist   = in_lineHeight + 1

			-- Collect all characters. Note that we set the coords later.
			local missingCps = {}

			for cp in pairs(rbmfFile.textCodepoints) do -- textCodepoints should be empty if useTextFiles is unset.
				if not font:hasGlyphs(utf8.char(cp)) then
					local blockName       = getUnicodeBlockName(cp)
					missingCps[blockName] = missingCps[blockName] or {}
					table.insert(missingCps[blockName], cp)
				else
					local glyphInfo = {cp=cp, x1=nil, y1=nil, x2=nil, y2=nil}
					table.insert(glyphs, glyphInfo)
				end
			end

			for row, cpsOnRow in pairs(rbmfFile.codepoints) do
				for _, cp in ipairs(cpsOnRow) do
					if rbmfFile.textCodepoints[cp] then
						-- void
					elseif not font:hasGlyphs(utf8.char(cp)) then
						local blockName       = getUnicodeBlockName(cp)
						missingCps[blockName] = missingCps[blockName] or {}
						table.insert(missingCps[blockName], cp)
					else
						local glyphInfo = {cp=cp, x1=nil, y1=nil, x2=nil, y2=nil}
						table.insert(glyphs, glyphInfo)
					end
				end
			end

			if not glyphs[1] then
				fileError(rbmfFile, "No characters to export from fontFile '%s'.", rbmfFile.fontFilename)
			end

			if next(missingCps) then
				local blockNames = {}

				for blockName, cps in pairs(missingCps) do
					table.insert(blockNames, blockName)
					table.sort(cps)
				end

				table.sort(blockNames)

				for _, blockName in ipairs(blockNames) do
					local cps = missingCps[blockName]
					warning(
						"%s: Font is missing %d '%s' codepoints:\n  %s",
						rbmfFile.fontFilename, #cps, blockName, table.concat(cps, " ")
					)
				end
			end

			-- Figure out virtual input image size and character coords.
			local virtual_imageMaxWidth = LG.getSystemLimits().texturesize
			local virtual_imageWidth    = 0
			local virtual_imageHeight   = 0
			local x1                    = 1/0
			local y1                    = -in_lineHeight

			for _, glyphInfo in ipairs(glyphs) do
				local c = utf8.char(glyphInfo.cp)
				local w = font:getWidth(c)

				if x1+w-1 > virtual_imageMaxWidth then
					virtual_imageHeight = virtual_imageHeight + in_lineHeight
					x1                  = 0
					y1                  = y1 + in_lineHeight
				end

				local x2 = x1 + w - 1
				local y2 = y1 + in_lineHeight - 1

				glyphInfo.x1 = x1
				glyphInfo.x2 = x2
				glyphInfo.y1 = y1
				glyphInfo.y2 = y2

				virtual_imageWidth = math.max(virtual_imageWidth, x2+1)
				x1                 = x2 + 1
			end

			assert(virtual_imageWidth  > 0)
			assert(virtual_imageHeight > 0)

			-- Create virtual input image.
			local fontCanvas = LG.newCanvas(virtual_imageWidth, virtual_imageHeight)

			LG.setCanvas(fontCanvas)
			LG.clear(0, 0, 0, 0)

			LG.setFont(font)
			LG.setColor(1, 1, 1)
			LG.setBlendMode("alpha", "premultiplied")
			for _, glyphInfo in ipairs(glyphs) do
				local c = utf8.char(glyphInfo.cp)
				LG.print(c, glyphInfo.x1, glyphInfo.y1)
			end

			LG.setCanvas(nil)

			in_imageData = fontCanvas:newImageData()
			-- assert(connectToDirectory(LF.getSaveDirectory()), LF.getSaveDirectory()) ; in_imageData:encode("png", "virt_in_image.png") -- DEBUG

			font:release()
			fontCanvas:release()

		----------------

		else--if rbmfFile.fontFilename == "" then
			local dir           = getDirectory(rbmfFile.path)
			local imageFilename = getBasename(getFilename(rbmfFile.path))..".png" -- @Incomplete: Make sure input and output image do not have the same path.

			if not connectToDirectory(dir) then
				errorLine("Could not read from directory '%s'.", getDirectory(rbmfFile.path))
			end
			in_imageData = LI.newImageData(imageFilename)

			-- Get separator line color.
			local sepR, sepG, sepB, sepA = in_imageData:getPixel(0, 0) -- @Speed: Don't use getPixel() - use getData() and JIT!

			-- Get line height and distance.
			-- LineDistance = SeparatorHeight + LineHeight
			in_lineDist = in_imageData:getHeight() - 1

			for y = 1, in_imageData:getHeight()-1 do
				local r, g, b, a = in_imageData:getPixel(1, y)
				if r == sepR and g == sepG and b == sepB and a == sepA then
					in_lineDist = y
					break
				end
			end
			in_lineHeight = in_lineDist - 1
			assert(in_lineHeight >= 1)

			-- Check if everything fits in the source image like the descriptor says.
			local maxRowsInFont = math.floor(in_imageData:getHeight() / in_lineDist)

			if rbmfFile.lastRow > maxRowsInFont then
				errorLine(
					"%s: Font descriptor specifies glyphs up to row %d but only %d rows fit."
					.." (Line height is %d, image height is %d)",
					imageFilename, rbmfFile.lastRow, maxRowsInFont, in_lineHeight, in_imageData:getHeight()
				)
			end

			-- Collect all glyphs.
			local textCps = (rbmfFile.useTextFiles and rbmfFile.textCodepoints or nil)

			for row, cpsOnRow in pairs(rbmfFile.codepoints) do -- @Robustness: Is the output stable if we use pairs() here?
				local x           = 1
				local y           = 1 + (row-1) * in_lineDist
				local glyphStartX = x

				for i, cp in ipairs(cpsOnRow) do
					x = findNextPixelOnX(in_imageData, x,y, sepR,sepG,sepB,sepA)
					if not x then
						errorLine(
							"%s: Missing glyphs on row %d. (Expected %d, found %d)",
							imageFilename, row, #cpsOnRow, i-1
						)
					end

					if not (textCps and not textCps[cp]) then
						local glyphInfo = {cp=cp, x1=glyphStartX, y1=y, x2=x-1, y2=y+in_lineDist-2}
						table.insert(glyphs, glyphInfo)
					end

					x           = x + 1
					glyphStartX = x
				end
			end
		end

		----------------

		if not glyphs[1] then
			fileError(rbmfFile, "No glyphs to export.")
		end

		--
		-- Edit input image
		--
		if rbmfFile.editAlphaTreshold > 0 then
			-- Need to @Revise all this! 2021-03-21
			local function applyAlphaTreshold(x,y, r,g,b,a)
				return r, g, b, (a >= rbmfFile.editAlphaTreshold and 1 or 0)
			end

			for _, glyphInfo in ipairs(glyphs) do
				local outerX1, outerX2, outerY1, outerY2 = getImageContentBounds(in_imageData, glyphInfo.x1, glyphInfo.y1, glyphInfo.x2, glyphInfo.y2, .0001)
				-- local outerX1, outerX2, outerY1, outerY2 = getImageContentBounds(in_imageData, glyphInfo.x1, glyphInfo.y1, glyphInfo.x2, glyphInfo.y2, 1) -- This doesn't seem right?

				if outerX1 then
					--[[ Nah, this all messes stuff up.
					local innerX1, innerX2, innerY1, innerY2 = getImageContentBounds(in_imageData, outerX1, outerY1, outerX2, outerY2, 1/128)
					if not innerX1 then
						innerX1, innerX2, innerY1, innerY2 = outerX1, outerX2, outerY1, outerY2
					end

					print("measure pre ", glyphInfo.cp, glyphInfo.x2-glyphInfo.x1)
					glyphInfo.x1 = glyphInfo.x1+innerX1-outerX1
					glyphInfo.x2 = glyphInfo.x2+innerX2-outerX2
					print("measure post", glyphInfo.cp, glyphInfo.x2-glyphInfo.x1)
					--]]

					in_imageData:mapPixel(applyAlphaTreshold, outerX1,outerY1, outerX2-outerX1+1,outerY2-outerY1+1) -- @Speed
				end
			end
		end

		--
		-- Write output images and descriptors
		--
		for _, outDescr in ipairs(rbmfFile.outputDescriptors) do
			-- @Incomplete: Put characters in separate channels when rbmfFile.isColored is false.
			-- @Feature: Automatic kerning calculations?

			if outDescr.outlineWidth > 1 then
				errorLine("Only 1-pixel outlines are supported currently. (%d were specified)", outDescr.outlineWidth)
			end

			-- Figure out how tall the output image should be.
			local out_imageWidth  = 0
			local out_imageHeight = 0
			local x               = 1/0

			for _, glyphInfo in ipairs(glyphs) do
				-- :GlyphLayout
				local w = glyphInfo.x2 - glyphInfo.x1 + 1
				local h = in_lineHeight--glyphInfo.y2 - glyphInfo.y1 + 1

				local wPadded = w + 2*outDescr.outlineWidth + outDescr.glyphPaddingL + outDescr.glyphPaddingR
				local hPadded = h + 2*outDescr.outlineWidth + outDescr.glyphPaddingU + outDescr.glyphPaddingD

				if x+wPadded-1 > out_imageMaxWidth-outDescr.glyphSpacingH then
					x               = outDescr.glyphSpacingH
					out_imageHeight = out_imageHeight + hPadded + outDescr.glyphSpacingV
				end

				out_imageWidth = math.max(out_imageWidth, x+wPadded)
				x              = x + wPadded + outDescr.glyphSpacingH
			end

			out_imageWidth  = out_imageWidth  + outDescr.glyphSpacingH
			out_imageHeight = out_imageHeight + outDescr.glyphSpacingV

			assert(out_imageWidth  > 0)
			assert(out_imageHeight > 0)

			-- Even numbers are safer than odd, yo.
			out_imageWidth  = math.ceil(out_imageWidth  / 2) * 2
			out_imageHeight = math.ceil(out_imageHeight / 2) * 2

			local out_imageData        = LI.newImageData(out_imageWidth, out_imageHeight)
			local out_descriptorBuffer = {}

			table.insert(out_descriptorBuffer, F(
				'info face="" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=%d,%d outline=%d',
				in_lineHeight, outDescr.glyphSpacingH,outDescr.glyphSpacingV, outDescr.outlineWidth
			))
			for _, k in ipairs(outDescr.customValues) do
				local v = outDescr.customValues[k]
				table.insert(out_descriptorBuffer, F(" CUSTOM_%s=", k))
				table.insert(out_descriptorBuffer, v:find"^%-?%d*%.?%d+$" and v or F('"%s"', v))
			end
			table.insert(out_descriptorBuffer, "\n")

			table.insert(out_descriptorBuffer, F(
				-- @Incomplete: Support multiple pages when needed for big font sizes.
				'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0\n',
				in_lineHeight, in_lineHeight, out_imageWidth, out_imageHeight
			))

			table.insert(out_descriptorBuffer, F('page id=0 file="%s"\n', outDescr.filenameImage))

			-- Write glyphs.
			table.insert(out_descriptorBuffer, F('chars count=%d\n', #glyphs))

			-- out_imageData:mapPixel(function()  return 1, 0, 0, 1  end) -- DEBUG

			local x = 1/0
			local y = -(in_lineHeight + 2*outDescr.outlineWidth)

			for _, glyphInfo in ipairs(glyphs) do
				-- Similar code to :GlyphLayout.
				local w = glyphInfo.x2 - glyphInfo.x1 + 1
				local h = in_lineHeight--glyphInfo.y2 - glyphInfo.y1 + 1

				local wPadded = w + 2*outDescr.outlineWidth + outDescr.glyphPaddingL + outDescr.glyphPaddingR
				local hPadded = h + 2*outDescr.outlineWidth + outDescr.glyphPaddingU + outDescr.glyphPaddingD

				if x+wPadded-1 > out_imageMaxWidth-outDescr.glyphSpacingH then
					x = outDescr.glyphSpacingH
					y = y + hPadded + outDescr.glyphSpacingV
				end

				out_imageData:paste(in_imageData, x+outDescr.outlineWidth, y+outDescr.outlineWidth, glyphInfo.x1, glyphInfo.y1, w, h)

				-- Note that the outlines will overlap when text is rendered.  @Incomplete: This should probably be a setting.
				table.insert(out_descriptorBuffer, F(
					'char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15\n',
					glyphInfo.cp, x,y, wPadded,hPadded, w+outDescr.glyphSpacingH
				))

				x = x + wPadded + outDescr.glyphSpacingH
			end

			-- Add character outlines.
			-- Probably need to @Revise this algorithm. 2021-03-22
			-- @Incomplete: Use outDescr.outlineColor.
			if outDescr.outlineWidth > 0 then
				local w, h              = out_imageData:getDimensions()
				local readonlyImageData = LI.newImageData(w, h)

				readonlyImageData:paste(out_imageData, 0,0, 0,0, w,h)

				local function getAlpha(x, y)
					if x >= 0 and y >= 0 and x < w and y < h then
						local _, _, _, a = readonlyImageData:getPixel(x, y)
						return a
					else
						return 0
					end
				end

				local DIAGONAL_SIGNIFICANCE = .4

				out_imageData:mapPixel(function(x,y, r,g,b,a)
					local highestNearbyAlpha = math.max(
						--[[u ]] getAlpha(x,   y-1),
						--[[ur]] getAlpha(x+1, y-1)*DIAGONAL_SIGNIFICANCE,
						--[[ r]] getAlpha(x+1, y  ),
						--[[dr]] getAlpha(x+1, y+1)*DIAGONAL_SIGNIFICANCE,
						--[[d ]] getAlpha(x,   y+1),
						--[[dl]] getAlpha(x-1, y+1)*DIAGONAL_SIGNIFICANCE,
						--[[ l]] getAlpha(x-1, y  ),
						--[[ul]] getAlpha(x-1, y-1)*DIAGONAL_SIGNIFICANCE,
						a
					)

					if highestNearbyAlpha == 0 then
						-- do  return 1, 0, 0, 1  end -- DEBUG
						return 0, 0, 0, 0
					end

					r = r * a
					g = g * a
					b = b * a
					a = highestNearbyAlpha

					-- do  return 1, g, b, a  end -- DEBUG
					return r, g, b, a
				end)
			end

			-- Write kernings.
			local kerningPairs = {}

			for pair in pairs(rbmfFile.kernings) do
				table.insert(kerningPairs, pair)
			end

			if kerningPairs[1] then
				table.sort(kerningPairs)

				table.insert(out_descriptorBuffer, F('kernings count=%d\n', #kerningPairs))

				for _, pair in ipairs(kerningPairs) do
					local first, second = pair:match(F("(%s)(%s)", utf8.charpattern, utf8.charpattern))
					first               = utf8.codepoint(first)
					second              = utf8.codepoint(second)

					local offset = rbmfFile.kernings[pair]

					table.insert(out_descriptorBuffer, F('kerning first=%d second=%d amount=%d\n', first, second, offset))
				end
			end

			-- Save files.
			local dir = (out_directory ~= "" and out_directory or getDirectory(rbmfFile.path))
			if not connectToDirectory(dir) then
				errorLine("Could not access directory '%s'.", dir)
			end

			if outDescr.filenameImage ~= "" then
				printf("Writing image: %s", appendPath(dir, outDescr.filenameImage))
				local ok, err = out_imageData:encode("png", outDescr.filenameImage)
				if not ok then
					errorLine("Could not write font image '%s'. (%s)", outDescr.filenameImage, err)
				end
			end

			if outDescr.filenameDescriptor ~= "" then
				printf("Writing descriptor: %s", appendPath(dir, outDescr.filenameDescriptor))
				local ok, err = LF.write(outDescr.filenameDescriptor, table.concat(out_descriptorBuffer))
				if not ok then
					errorLine("Could not write font descriptor '%s'. (%s)", outDescr.filenameDescriptor, err)
				end
			end
		end--for rbmfFile.outputDescriptors
	end--for rbmfFiles

	--
	-- Write icons file
	--
	if out_iconsPath ~= "" then
		local out_iconsFile = assert(io.open(out_iconsPath, "wb"))

		for _, icon in ipairs(getIcons()) do
			local cp = getIconCodepoint(icon)
			out_iconsFile:write(F("%d %s\n", cp, icon))
		end

		out_iconsFile:close()
	end

	--
	-- All done!
	--
	local endTime = socket.gettime()

	print(CMD_SEPARATOR)
	if warningCount > 0 then
		printf("Completed with %d warning%s!", warningCount, (warningCount == 1 and "" or "s"))
	else
		print("Completed successfully!")
	end
	printf("Time:  %.3f seconds", endTime-startTime)
	printf("Icons: %d", getIconCount())
	print(CMD_SEPARATOR)
	print()

	return function()
		-- return 0 -- This sometimes crashes us for some reason. Is there a race condition somewhere or something? Who the hell knows, so we do the following instead...
		os.exit(0)
	end
end



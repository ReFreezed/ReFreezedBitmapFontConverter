--[[============================================================
--=
--=  Functions
--=
--=-------------------------------------------------------------
--=
--=  ReFreezed Bitmap Font converter
--=  by Marcus 'ReFreezed' Thunström
--=
--==============================================================

	addCodepoint
	addKerningPairs
	connectToDirectory
	errorf, warning, errorLine
	fileError, fileWarning, fileAssert
	findNextPixelOnX
	getDirectoryItems
	getFileContents, isFile, eachFilenameInDirectory
	getFilename, getDirectory, getBasename, appendPath
	getIconCodepoint, getIcons, getIconCount, setIconCodepoint, isCodepointInPua
	getImageContentBounds
	getUnicodeBlockName
	normalizePath
	parseBool, parseNumber, parseInt
	print, printf
	processPathTemplate
	S
	triml, trimr, trim

--============================================================]]

_G.F = string.format



-- addCodepoint( rbmfFile, row, cp, icon=nil )
function _G.addCodepoint(rbmfFile, row, cp, icon)
	local cpsOnRow           = rbmfFile.codepoints[row] or {}
	rbmfFile.codepoints[row] = cpsOnRow
	table.insert(cpsOnRow, cp)

	rbmfFile.codepointLines[cp] = rbmfFile.ln

	if icon then  table.insert(rbmfFile.icons, icon)  end

	rbmfFile.lastRow = math.max(rbmfFile.lastRow, row)
end



local function addKerningPair(rbmfFile, firstCp, secondCp, offset)
	local pair = utf8.char(firstCp, secondCp)

	if rbmfFile.kerningLines[pair] then
		fileWarning(
			rbmfFile, "Kerning for '%s' (codepoints %d and %d) is already defined (line %d). Replacing old value.\n",
			pair, firstCp, secondCp, rbmfFile.kerningLines[pair]
		)
	else
		rbmfFile.kerningLines[pair] = rbmfFile.ln
	end

	rbmfFile.kernings[pair] = offset
end

function _G.addKerningPairs(rbmfFile, firsts, seconds, offset, back)
	for _, firstCp in utf8.codes(firsts) do
		for _, secondCp in utf8.codes(seconds) do
			addKerningPair(rbmfFile, firstCp, secondCp, offset)
			if back then  addKerningPair(rbmfFile, secondCp, firstCp, offset)  end
		end
	end
end



function _G.triml(s)
	return (s:gsub("^ +", ""))
end

function _G.trimr(s)
	return (s:gsub(" +$", ""))
end

function _G.trim(s)
	return (s:gsub("^ +", ""):gsub(" +$", ""))
end



function _G.errorf(s, ...)
	error(F(s, ...), 2)
end

function _G.warning(s, ...)
	_G.warningCount = warningCount + 1
	io.stderr:write(F("Warning(%d): "..s, warningCount, ...), "\n")
end

function _G.errorLine(s, ...)
	if select("#", ...) > 0 then  s = F(s, ...)  end
	io.stderr:write("Error: ", s, "\n")
	os.exit(1)
end



function _G.fileError(info, s, ...)
	if info.ln > 0 then
		io.stderr:write(F("Error: %s:%d: "..s, getFilename(info.path), info.ln, ...), "\n\n")
	else
		io.stderr:write(F("Error: %s: "   ..s, getFilename(info.path),          ...), "\n\n")
	end
	os.exit(1)
end

function _G.fileWarning(info, s, ...)
	if info.ln > 0 then
		warning("%s:%d: "..s, getFilename(info.path), info.ln, ...)
	else
		warning("%s: "   ..s, getFilename(info.path),          ...)
	end
end

-- value1, ... = fileAssert( info, success, value1, ...  )
--               fileAssert( info, success, errorMessage )
function _G.fileAssert(info, ok, ...)
	if not ok then  fileError(info, "%s", (...))  end
	return ...
end



-- x|nil = findNextPixelOnX( image, x,y, r,g,b,a )
function _G.findNextPixelOnX(image, x,y, r0,g0,b0,a0)
	for x = x, image:getWidth()-1 do
		local r,g,b,a = image:getPixel(x, y)
		if r == r0 and g == g0 and b == b0 and a == a0 then
			return x
		end
	end
	return nil -- Pixel not found!
end



local function cmdCapture(cmd)
	local stream = assert(io.popen(cmd, "r"))
	local output = assert(stream:read"*a")
	stream:close()
	return output
end

function _G.getDirectoryItems(path)
	local dir = getDirectory(path)

	if not connectToDirectory(dir) then
		errorf("Cannot access directory '%s'.", dir)
	end

	return LF.getDirectoryItems(getFilename(path))
end



function _G.getFilename(path)
	return (path:gsub("^.*/", ""))
end

function _G.getDirectory(path)
	if not path:find("/", 1, true) then  return "."  end

	dir = path:gsub("/[^/]+$", "")

	if dir == "" or dir:find"^%a:$" then
		dir = dir.."/"
	end

	return dir
end

function _G.getBasename(filename)
	local basename = filename:gsub("%..*$", "")
	return basename ~= "" and basename or filename
end

function _G.appendPath(pathBase, pathToAppend)
	return (pathBase     == "" and pathToAppend)
	    or (pathToAppend == "" and pathBase)
	    or (pathToAppend:find"^/"   and pathToAppend)
	    or (pathToAppend:find"^%a:" and pathToAppend)
	    or (pathBase:find"/$" and pathBase..pathToAppend or pathBase.."/"..pathToAppend)
end



function _G.normalizePath(path)
	path = path:gsub("\\", "/"):gsub("/+$", "")

	if path == "" or path:find"^%a:" then
		path = path.."/"
	end

	return path
end



do
	local iconCps   = {}
	local iconCount = 0
	local nextPuaCp = 0xE000 -- Unicode PUA: U+E000-U+F8FF, U+F0000-U+FFFFD and U+100000-U+10FFFD (https://en.wikipedia.org/wiki/Private_Use_Areas)

	function _G.getIconCodepoint(icon)
		local cp = iconCps[icon]
		if cp then  return cp  end

		if     nextPuaCp == 0xF8FF   + 1 then  nextPuaCp = 0xF0000
		elseif nextPuaCp == 0xFFFFD  + 1 then  nextPuaCp = 0x100000
		elseif nextPuaCp == 0x10FFFD + 1 then  errorf("Too many icons! Maximum amount is %d.", (0xF8FF-0xE000+1 + 0xFFFFD-0xF0000+1 + 0x10FFFD-0x100000+1))
		end

		cp        = nextPuaCp
		nextPuaCp = nextPuaCp + 1

		iconCps[icon] = cp
		iconCount     = iconCount + 1

		return cp
	end

	function _G.getIcons()
		local icons = {}
		for icon in pairs(iconCps) do
			table.insert(icons, icon)
		end
		table.sort(icons)
		return icons
	end

	function _G.getIconCount()
		return iconCount
	end

	function _G.setIconCodepoint(icon, cp)
		if iconCps[icon] == cp then
			return
		elseif iconCps[icon] then
			errorf("Icon '%s' already has another codepoint. (new=%d, old=%d)", icon, cp, iconCps[icon])
		else
			iconCps[icon] = cp
			nextPuaCp     = math.max(nextPuaCp, cp+1)
		end
	end

	function _G.isCodepointInPua(cp)
		return (cp >= 0xE000 and cp <= 0xF8FF) or (cp >= 0xF0000 and cp <= 0xFFFFD) or (cp >= 0x100000 and cp <= 0x10FFFD)
	end
end



-- x1, x2, y1, y2 = getImageContentBounds( image, x1, y1, x2, y2, alphaThreshold )
-- Returns nil if the whole area is empty.
function _G.getImageContentBounds(image, x1, y1, x2, y2, threshold)
	local hasContent = false

	for y = y1, y2 do
		for x = x1, x2 do
			local _, _, _, a = image:getPixel(x, y)

			if a >= threshold then
				hasContent = true
				break
			end
		end

		if hasContent then  break  end
	end

	if not hasContent then  return nil  end

	local cx1 =  1/0
	local cx2 = -1/0
	local cy1 =  1/0
	local cy2 = -1/0

	for y = y1, y2 do
		for x = x1, x2 do
			local _, _, _, a = image:getPixel(x, y)

			if a >= threshold then
				cx1 = math.min(cx1, x)
				cx2 = math.max(cx2, x)
				cy1 = math.min(cy1, y)
				cy2 = math.max(cy2, y)
			end
		end
	end

	return cx1, cx2, cy1, cy2
end



function _G.getUnicodeBlockName(cp)
	for _, block in ipairs(require"unicodeBlocks") do
		if cp >= block.from and cp <= block.to then
			return block.name
		end
	end
	return "Unknown Block"
end



-- contents|nil, error = getFileContents( path )
function _G.getFileContents(path)
	local dir = getDirectory(path)

	if not connectToDirectory(dir) then
		return nil, F("Cannot access directory '%s'.", dir)
	end

	return LF.read(getFilename(path))
end

do
	local fileInfoDummy = {}

	function _G.isFile(path)
		return (
			connectToDirectory(getDirectory(path))
			and LF.getInfo(getFilename(path), "file", fileInfoDummy) ~= nil
		)
	end
end



function _G.parseBool(s)
	if s == "true" then
		return true, true
	elseif s == "false" then
		return true, false
	end
	return false, F("Expected a boolean - got '%s'.", s)
end

function _G.parseNumber(s)
	local n = tonumber(s)
	if n then  return true, n  end
	return false, F("Expected a number - got '%s'.", s)
end

function _G.parseInt(s)
	if not s:find"^%-?%d+$" then
		return false, F("Expected an integer - got '%s'.", s)
	end
	return true, tonumber(s)
end
function _G.parseInt2(s)
	local nStr1, nStr2 = s:match"^(%-?%d+) +(%-?%d+)$"
	if not nStr1 then
		return false, F("Expected 2 integers - got '%s'.", s)
	end
	return true, tonumber(nStr1), tonumber(nStr2)
end
function _G.parseInt4(s)
	local nStr1, nStr2, nStr3, nStr4 = s:match"^(%-?%d+) +(%-?%d+) +(%-?%d+) +(%-?%d+)$"
	if not nStr1 then
		return false, F("Expected 4 integers - got '%s'.", s)
	end
	return true, tonumber(nStr1), tonumber(nStr2), tonumber(nStr3), tonumber(nStr4)
end



do
	local _print     = print
	-- local logFile = nil

	function _G.print(...)
		_print(...)

		-- logFile = logFile or LF.newFile("log.txt", "a")
		-- for i = 1, select("#", ...) do
		-- 	if i > 1 then  logFile:write("\t")  end
		-- 	logFile:write((tostring(select(i, ...)):gsub("\r?\n", "\r\n")))
		-- end
		-- logFile:write("\r\n")
	end
end

function _G.printf(s, ...)
	print(F(s, ...))
end



do
	local currentDirectory = ""

	-- success = connectToDirectory( directory )
	function _G.connectToDirectory(dir)
		if dir == currentDirectory then  return true  end

		if not physfs.mountReadDirectory(dir, false) then  return false  end

		for _, path in ipairs(physfs.getSearchPaths()) do
			assert(physfs.unmountReadDirectory(path))
		end

		assert(physfs.mountReadDirectory(dir, false))
		assert(physfs.setWriteDirectory(dir))

		currentDirectory = dir
		return true
	end
end



function _G.processPathTemplate(rbmfFile, pathTemplate)
	return (pathTemplate:gsub("<(.-)>", function(var)
		if var == "basename" then
			return getBasename(getFilename(rbmfFile.path))
		else
			fileError(rbmfFile, "Unknown variable <%s> in path '%s'.", var, pathTemplate)
		end
	end))
end



-- text = S( array [, textSingle="", textMulti="s" ] )
function _G.S(t, textSingle, textMulti)
	return (#t == 1)
	   and (textSingle or "")
	   or  (textMulti  or "s")
end



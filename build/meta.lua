--[[============================================================
--=
--=  Metaprogram functions
--=
--=-------------------------------------------------------------
--=
--=  ReFreezed Bitmap Font converter
--=  by Marcus 'ReFreezed' Thunström
--=
--==============================================================

	convertTextFileEncoding, addBomToUft16File
	copyFile, copyFilesInDirectory
	execute, executeRequired
	F
	GET_IMAGE_DATA_POINTER, GET_PIXEL, SET_PIXEL, MAP_PIXEL, MAP_PIXEL_END
	getReleaseVersion
	isFile, isDirectory
	loadParams
	makeDirectory, makeDirectoryRecursive, removeDirectory, removeDirectoryRecursive
	readFile, writeFile, writeTextFile
	templateToLua
	templateToString, templateToStringUtf16
	toWindowsPath
	traverseDirectory
	utf16ToUtf8, utf8ToUtf16
	zipDirectory, zipFiles

--============================================================]]

_G.F = string.format



function _G.templateToLua(template, values)
	return (template:gsub("%$(%w+)", values))
end



function _G.GET_IMAGE_DATA_POINTER(imageDataIdent)
	local values = {imageData=imageDataIdent}
	__LUA(templateToLua("local $imageData_pointer = require'ffi'.cast('uint8_t *', $imageData:getFFIPointer())\n", values))
	__LUA(templateToLua("local $imageData_w       = $imageData:getWidth()\n", values))
end

-- GET_PIXEL( imageDataIdent, rIdent=nil,gIdent=nil,bIdent=nil,aIdent=nil, xCodeOrCoord,yCodeOrCoord [, reuseExistingIndex=false ] )
function _G.GET_PIXEL(imageDataIdent, rIdent,gIdent,bIdent,aIdent, x,y, reuseExistingIndex)
	if y == 0 and type(x) == "number" then
		local values = {
			imageData = imageDataIdent,
			r = rIdent, g = gIdent, b = bIdent, a = aIdent,
			i1 = toLua(4*x), i2=toLua(4*x+1), i3=toLua(4*x+2), i4=toLua(4*x+3),
			byteToFloat = toLua(1/255),
		}

		if rIdent then  __LUA(templateToLua("local $r = $imageData_pointer[$i1] * $byteToFloat\n", values))  end
		if gIdent then  __LUA(templateToLua("local $g = $imageData_pointer[$i2] * $byteToFloat\n", values))  end
		if bIdent then  __LUA(templateToLua("local $b = $imageData_pointer[$i3] * $byteToFloat\n", values))  end
		if aIdent then  __LUA(templateToLua("local $a = $imageData_pointer[$i4] * $byteToFloat\n", values))  end

	elseif ((rIdent and 1 or 0) + (gIdent and 1 or 0) + (bIdent and 1 or 0) + (aIdent and 1 or 0)) == 1 then
		if type(x) == "number" then  x = toLua(x)  end
		if type(y) == "number" then  y = toLua(y)  end

		local values = {
			imageData = imageDataIdent,
			r = rIdent, g = gIdent, b = bIdent, a = aIdent,
			x = x, y = y,
			byteToFloat = toLua(1/255),
		}

		if     rIdent then  __LUA(templateToLua("local $r = $imageData_pointer[4 * (($y)*$imageData_w + ($x))    ] * $byteToFloat\n", values))
		elseif gIdent then  __LUA(templateToLua("local $g = $imageData_pointer[4 * (($y)*$imageData_w + ($x)) + 1] * $byteToFloat\n", values))
		elseif bIdent then  __LUA(templateToLua("local $b = $imageData_pointer[4 * (($y)*$imageData_w + ($x)) + 2] * $byteToFloat\n", values))
		elseif aIdent then  __LUA(templateToLua("local $a = $imageData_pointer[4 * (($y)*$imageData_w + ($x)) + 3] * $byteToFloat\n", values))
		end

	else
		if type(x) == "number" then  x = toLua(x)  end
		if type(y) == "number" then  y = toLua(y)  end

		local values = {
			imageData = imageDataIdent,
			r = rIdent, g = gIdent, b = bIdent, a = aIdent,
			x = x, y = y,
			byteToFloat = toLua(1/255),
		}

		if not reuseExistingIndex then
			__LUA(templateToLua("local $imageData_cIndex = 4 * (($y)*$imageData_w + ($x))\n", values))
		end
		if rIdent then  __LUA(templateToLua("local $r = $imageData_pointer[$imageData_cIndex  ] * $byteToFloat\n", values))  end
		if gIdent then  __LUA(templateToLua("local $g = $imageData_pointer[$imageData_cIndex+1] * $byteToFloat\n", values))  end
		if bIdent then  __LUA(templateToLua("local $b = $imageData_pointer[$imageData_cIndex+2] * $byteToFloat\n", values))  end
		if aIdent then  __LUA(templateToLua("local $a = $imageData_pointer[$imageData_cIndex+3] * $byteToFloat\n", values))  end
	end
end

-- SET_PIXEL( imageDataIdent, xCodeOrCoord,yCodeOrCoord, rCodeOrValue=nil,gCodeOrValue=nil,bCodeOrValue=nil,aCodeOrValue=nil [, reuseExistingIndex=false ] )
function _G.SET_PIXEL(imageDataIdent, x,y, r,g,b,a, reuseExistingIndex)
	if type(r) == "number" then  r = F("%d", math.floor(r*255+.5))  elseif r then  r = F("math.floor((%s)*255+.5)", r)  end
	if type(g) == "number" then  g = F("%d", math.floor(g*255+.5))  elseif g then  g = F("math.floor((%s)*255+.5)", g)  end
	if type(b) == "number" then  b = F("%d", math.floor(b*255+.5))  elseif b then  b = F("math.floor((%s)*255+.5)", b)  end
	if type(a) == "number" then  a = F("%d", math.floor(a*255+.5))  elseif a then  a = F("math.floor((%s)*255+.5)", a)  end

	if y == 0 and type(x) == "number" then
		local values = {
			imageData = imageDataIdent,
			r = r, g = g, b = b, a = a,
			i1 = toLua(4*x), i2=toLua(4*x+1), i3=toLua(4*x+2), i4=toLua(4*x+3),
		}

		if r then  __LUA(templateToLua("$imageData_pointer[$i1] = $r\n", values))  end
		if g then  __LUA(templateToLua("$imageData_pointer[$i2] = $g\n", values))  end
		if b then  __LUA(templateToLua("$imageData_pointer[$i3] = $b\n", values))  end
		if a then  __LUA(templateToLua("$imageData_pointer[$i4] = $a\n", values))  end

	elseif ((r and 1 or 0) + (g and 1 or 0) + (b and 1 or 0) + (a and 1 or 0)) == 1 then
		if type(x) == "number" then  x = toLua(x)  end
		if type(y) == "number" then  y = toLua(y)  end

		local values = {
			imageData = imageDataIdent,
			r = r, g = g, b = b, a = a,
			x = x, y = y,
			byteToFloat = toLua(1/255),
		}

		if     r then  __LUA(templateToLua("$imageData_pointer[4 * (($y)*$imageData_w + ($x))    ] = $r\n", values))
		elseif g then  __LUA(templateToLua("$imageData_pointer[4 * (($y)*$imageData_w + ($x)) + 1] = $g\n", values))
		elseif b then  __LUA(templateToLua("$imageData_pointer[4 * (($y)*$imageData_w + ($x)) + 2] = $b\n", values))
		elseif a then  __LUA(templateToLua("$imageData_pointer[4 * (($y)*$imageData_w + ($x)) + 3] = $a\n", values))
		end

	else
		if type(x) == "number" then  x = toLua(x)  end
		if type(y) == "number" then  y = toLua(y)  end

		local values = {
			imageData = imageDataIdent,
			r = r, g = g, b = b, a = a,
			x = x, y = y,
		}

		if not reuseExistingIndex then
			__LUA(templateToLua("local $imageData_cIndex = 4 * (($y)*$imageData_w + ($x))\n", values))
		end
		if r then  __LUA(templateToLua("$imageData_pointer[$imageData_cIndex  ] = $r\n", values))  end
		if g then  __LUA(templateToLua("$imageData_pointer[$imageData_cIndex+1] = $g\n", values))  end
		if b then  __LUA(templateToLua("$imageData_pointer[$imageData_cIndex+2] = $b\n", values))  end
		if a then  __LUA(templateToLua("$imageData_pointer[$imageData_cIndex+3] = $a\n", values))  end
	end
end

function _G.MAP_PIXEL(imageDataIdent, xIdent,yIdent)
	if type(x) == "number" then  x = toLua(x)  end
	if type(y) == "number" then  y = toLua(y)  end

	local values = {
		imageData = imageDataIdent,
		x = xIdent, y = yIdent,
	}

	__LUA(templateToLua("for $imageData_i0 = 0, $imageData_w*$imageData:getHeight()-1 do\n", values))
	__LUA(templateToLua("local $x = $imageData_i0 % $imageData_w\n", values))
	__LUA(templateToLua("local $y = math.floor($imageData_i0 / $imageData_w)\n", values))
end

function _G.MAP_PIXEL_END()
	__LUA"end"
end



-- versionString, majorVersionString,minorVersionString,patchVersionString = getReleaseVersion( )
function _G.getReleaseVersion()
	local versionStr = readFile("build/version.txt")

	local major, minor, patch = versionStr:match"^(%d+)%.(%d+)%.(%d+)$"
	assert(major, versionStr)

	return versionStr, major,minor,patch
end



function _G.loadParams()
	local params = {
		dirLoveWin64 = "",
		dirLoveMacOs = "",
		path7z       = "",
		pathMagick   = "",
		pathPngCrush = "",
		pathRh       = "",
		pathIconv    = "",
	}

	local ln = 0

	for line in io.lines"local/params.ini" do
		ln = ln+1

		if not (line == "" or line:find"^#") then
			local k, v = line:match"^([%w_]+)%s*=%s*(.*)$"
			if not k then
				error(F("local/param.ini:%d: Bad line format: %s", ln, line))
			end

			if     k == "dirLoveWin64" then  params.dirLoveWin64 = v
			elseif k == "dirLoveMacOs" then  params.dirLoveMacOs = v
			elseif k == "path7z"       then  params.path7z       = v
			elseif k == "pathMagick"   then  params.pathMagick   = v
			elseif k == "pathPngCrush" then  params.pathPngCrush = v
			elseif k == "pathRh"       then  params.pathRh       = v
			elseif k == "pathIconv"    then  params.pathIconv    = v
			else   printf("Warning: params.ini:%d: Unknown param '%s'.", ln, k)  end
		end
	end

	assert(params.dirLoveWin64 ~= "", "local/param.ini: Missing param 'dirLoveWin64'.")
	assert(params.dirLoveMacOs ~= "", "local/param.ini: Missing param 'dirLoveMacOs'.")
	assert(params.path7z       ~= "", "local/param.ini: Missing param 'path7z'.")
	assert(params.pathMagick   ~= "", "local/param.ini: Missing param 'pathMagick'.")
	assert(params.pathPngCrush ~= "", "local/param.ini: Missing param 'pathPngCrush'.")
	assert(params.pathRh       ~= "", "local/param.ini: Missing param 'pathRh'.")
	assert(params.pathIconv    ~= "", "local/param.ini: Missing param 'pathIconv'.")

	return params
end



local function includeArgs(cmd, args)
	local cmdParts = {cmd:gsub("/", "\\"), unpack(args)}

	for i, cmdPart in ipairs(cmdParts) do
		if cmdPart == "" then
			cmdParts[i] = '""'
		elseif cmdPart:find(" ", 1, true) then
			cmdParts[i] = '"'..cmdPart..'"'
		end
	end

	return (
		cmdParts[1]:sub(1, 1) == '"'
		and '"'..table.concat(cmdParts, " ")..'"'
		or  table.concat(cmdParts, " ")
	)
end

-- exitCode = execute( command )
-- exitCode = execute( program, arguments )
function _G.execute(cmd, args)
	if args then
		cmd = includeArgs(cmd, args)
	end

	local exitCode = os.execute(cmd)
	return exitCode
end

-- executeRequired( command )
-- executeRequired( program, arguments )
function _G.executeRequired(cmd, args)
	if args then
		cmd = includeArgs(cmd, args)
	end

	local exitCode = os.execute(cmd)
	if exitCode ~= 0 then
		error(F("Got code %d from command: %s", exitCode, cmd))
	end
end



-- string = templateToString( template, values [, formatter ] )
-- string = formatter( string )
function _G.templateToString(s, values, formatter)
	return (s:gsub("${(%w+)}", function(k)
		local v = values[k]
		if not v     then  error(F("No value '%s'.", k))  end
		if formatter then  v = formatter(v)  end
		return v
	end))
end

-- string = templateToStringUtf16( params, template, values [, formatter ] )
-- string = formatter( string )
function _G.templateToStringUtf16(params, s, values, formatter)
	return (s:gsub("$%z{%z([%w%z]+)}%z", function(k)
		k       = utf16ToUtf8(params, k)
		local v = values[k]
		if not v     then  error(F("No value '%s'.", k))  end
		if formatter then  v = formatter(v)  end
		return utf8ToUtf16(params, v)
	end))
end



function _G.utf16ToUtf8(params, s)
	-- @Speed, OMG!!!
	writeFile("temp/encodingIn.txt", s)
	convertTextFileEncoding(params, "temp/encodingIn.txt", "temp/encodingOut.txt", "UTF-16LE", "UTF-8")
	return (readFile("temp/encodingOut.txt"))
end

function _G.utf8ToUtf16(params, s)
	-- @Speed, OMG!!!
	writeFile("temp/encodingIn.txt", s)
	convertTextFileEncoding(params, "temp/encodingIn.txt", "temp/encodingOut.txt", "UTF-8", "UTF-16LE")
	return (readFile("temp/encodingOut.txt"))
end



-- convertTextFileEncoding( params, inputPath, outputPath, fromEncoding, toEncoding [, addBom=false ] )
function _G.convertTextFileEncoding(params, inputPath, outputPath, fromEncoding, toEncoding, addBom)
	assert((inputPath ~= outputPath), inputPath)

	executeRequired(F([[""%s" -f %s -t %s "%s" > "%s""]], params.pathIconv, fromEncoding, toEncoding, inputPath, outputPath))

	if addBom then
		assert((toEncoding == "UTF-16LE"), toEncoding)
		addBomToUft16File(outputPath)
	end
end

function _G.addBomToUft16File(path) -- LE, specifically.
	local file     = assert(io.open(path, "r+b"))
	local contents = file:read"*a"
	file:seek("set", 0)
	file:write("\255\254", contents)
	file:close()
end



function _G.toWindowsPath(s)
	return (s:gsub("/", "\\"))
end



do
	-- Note: CWD matter!
	-- Note: To strip the path to folderToZip inside the resulting zip file, prepend "./".

	-- zipDirectory( params, zipFilePath, folderToZip [, append=false ] )
	function _G.zipDirectory(params, zipFilePath, folderToZip, append)
		if not append and isFile(zipFilePath) then
			assert(os.remove(zipFilePath))
		end
		executeRequired(params.path7z, {"a", "-tzip", zipFilePath, folderToZip})
	end

	-- zipFiles( params, zipFilePath, pathsToZip [, append=false ] )
	function _G.zipFiles(params, zipFilePath, pathsToZip, append)
		if not append and isFile(zipFilePath) then
			assert(os.remove(zipFilePath))
		end

		writeTextFile("temp/zipIncludes.txt", table.concat(pathsToZip, "\n").."\n")

		executeRequired(params.path7z, {"a", "-tzip", zipFilePath, "@temp/zipIncludes.txt"})
	end
end



function _G.readFile(path)
	local file     = assert(io.open(path, "rb"))
	local contents = file:read("*a")
	file:close()
	return contents
end

function _G.writeFile(path, contents)
	local file = assert(io.open(path, "wb"))
	file:write(contents)
	file:close()
end
function _G.writeTextFile(path, contents)
	local file = assert(io.open(path, "w"))
	file:write(contents)
	file:close()
end



function _G.copyFile(pathFrom, pathTo)
	writeFile(pathTo, readFile(pathFrom))
end

-- copyFilesInDirectory( fromDirectory, toDirectory [, filenamePattern ] )
function _G.copyFilesInDirectory(dirFrom, dirTo, filenamePattern)
	makeDirectoryRecursive(dirTo)

	for filename in lfs.dir(dirFrom) do
		if not filenamePattern or filename:find(filenamePattern) then
			local path = dirFrom.."/"..filename

			if isFile(path) then
				copyFile(path, dirTo.."/"..filename)
			end
		end
	end
end



function _G.makeDirectory(dir)
	if isDirectory(dir) then  return  end

	local ok, err = lfs.mkdir(dir)
	if not ok then
		error(F("Could not make directory '%s'. (%s)", dir, err))
	end
end
function _G.makeDirectoryRecursive(dir)
	if not isDirectory(dir) then
		executeRequired("MKDIR", {toWindowsPath(dir)})
	end
end

function _G.removeDirectory(dir)
	if not isDirectory(dir) then  return  end

	local ok, err = lfs.rmdir(dir)
	if not ok then
		error(F("Could not remove directory '%s'. (%s)", dir, err))
	end
end
function _G.removeDirectoryRecursive(dir)
	if isDirectory(dir) then
		executeRequired("RMDIR", {"/S", "/Q", toWindowsPath(dir)})
	end
end



do
	local function traverse(dir, cb)
		for filename in lfs.dir(dir) do
			if not (filename == "." or filename == "..") then
				local path = dir.."/"..filename

				local action = cb(path)
				if action == "stop" then  return "stop"  end

				if action ~= "ignore" and lfs.attributes(path, "mode") == "directory" then
					action = traverse(path, cb)
					if action == "stop" then  return "stop"  end
				end
			end
		end

		-- return "continue" -- Not needed.
	end

	-- traverseDirectory( directory, callback )
	-- [ "ignore"|"stop" = ] callback( path )
	function _G.traverseDirectory(dir, cb)
		traverse(dir, cb)
	end
end



function _G.isFile(path)
	return lfs.attributes(path, "mode") == "file"
end

function _G.isDirectory(path)
	return lfs.attributes(path, "mode") == "directory"
end




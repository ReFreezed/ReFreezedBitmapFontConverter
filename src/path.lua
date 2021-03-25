--[[============================================================
--=
--=  File path parsing module
--=  by Marcus 'ReFreezed' Thunström
--=
--==============================================================

	-- Functions:
	Path, Path.parse
	Path.clone
	Path.contains
	Path.getDirectory, Path.getFilename, Path.getDirectoryAndFilename
	Path.getRelativeTo
	Path.isEmpty
	Path.pop
	Path.prepend, Path.append
	Path.setFilename
	Path.toString, Path.toDirectory

	-- Values:
	Path.RELATIVE

--============================================================]]



local Path   = {}
Path.__index = Path

setmetatable(Path, {
	-- pathObj = Path( )
	-- pathObj = Path( path [, referencePath|referencePathObj=RELATIVE ] )
	__call = function(Path, path, referencePathObj)
		if path then
			return (Path.parse(path, referencePathObj))
		else
			return setmetatable({
				drive      = "", -- E.g. "C:" or "~".
				path       = {},
				isAbsolute = false,
			}, Path)
		end
	end,
})

function Path.clone(pathObj)
	return setmetatable({
		drive      = pathObj.drive,
		path       = {unpack(pathObj.path)},
		isAbsolute = pathObj.isAbsolute,
	}, Path)
end

Path.RELATIVE = Path()



local function clean(pathObj)
	-- Remove all "."
	for i = #pathObj.path, 1, -1 do
		if pathObj.path[i] == "." then  table.remove(pathObj.path, i)  end
	end

	-- Remove correct ".."
	local i = 1
	while pathObj.path[i] do
		if pathObj.path[i+1] == ".." and pathObj.path[i] ~= ".." then
			table.remove(pathObj.path, i+1)
			table.remove(pathObj.path, i)
			i = math.max(i-1, 1)
		else
			i = i+1
		end
	end

	-- Remove all incorrect ".."
	if pathObj.isAbsolute then
		while pathObj.path[1] == ".." do
			table.remove(pathObj.path, 1)
		end
	end
end



-- pathObj = parse( path [, referencePath|referencePathObj=RELATIVE ] )
-- Note: Network paths are not supported.
-- Paths like "C:foo.txt" are assumed to be mistyped and become "C:/foo.txt".
function Path.parse(path, referencePathObj)
	if type(referencePathObj) ~= "string" then
		referencePathObj = referencePathObj or Path.RELATIVE
	elseif referencePathObj == "" or referencePathObj == "." then
		referencePathObj = Path.RELATIVE
	else
		referencePathObj = Path.parse(referencePathObj)
	end

	local pathObj = Path()
	path          = path:gsub("\\", "/")

	local pathToSplit

	if path:find"^%a:" then
		local drive, rhs   = path:match"^(%a:)/?(.*)$"
		pathObj.drive      = drive:upper()
		pathObj.isAbsolute = true
		pathToSplit        = rhs

	elseif path:find"^~/" or path == "~" then
		pathObj.drive      = "~"
		pathObj.isAbsolute = true
		pathToSplit        = path:sub(3)

	elseif path:find"^/" then
		pathObj.drive      = referencePathObj.drive
		pathObj.isAbsolute = true
		pathToSplit        = path:sub(2)

	else
		pathObj.path       = {unpack(referencePathObj.path)}
		pathObj.drive      = referencePathObj.drive
		pathObj.isAbsolute = referencePathObj.isAbsolute
		pathToSplit        = path
	end

	for pathSegment in pathToSplit:gmatch"[^/]+" do
		table.insert(pathObj.path, pathSegment)
	end

	clean(pathObj)
	return pathObj
end



function Path.toString(pathObj)
	if not pathObj.isAbsolute then
		return (table.concat(pathObj.path, "/"))
	end
	return pathObj.drive .. "/" .. table.concat(pathObj.path, "/")
end

-- Same as toString() except the string is never empty and never ends with "/".
function Path.toDirectory(pathObj)
	local path = pathObj:toString()
	if path == ""    then  return "."        end
	if path:find"/$" then  return path.."."  end
	return path
end



-- pathObj|nil = getRelativeTo( path|pathObj, referencePath|referencePathObj )
function Path.getRelativeTo(pathObj, referencePathObj)
	if type(pathObj)          == "string" then  pathObj          = Path.parse(pathObj)           end
	if type(referencePathObj) == "string" then  referencePathObj = Path.parse(referencePathObj)  end

	if not (pathObj.isAbsolute and referencePathObj.isAbsolute) then  return nil  end
	if pathObj.drive ~= referencePathObj.drive                  then  return nil  end

	local minLen    = math.min(#pathObj.path, #referencePathObj.path)
	local firstDiff = minLen + 1

	for i = 1, minLen do
		if pathObj.path[i] ~= referencePathObj.path[i] then
			firstDiff = i
			break
		end
	end

	local result = Path()
	for i = firstDiff, #referencePathObj.path do  table.insert(result.path, "..")             end
	for i = firstDiff, #pathObj.path          do  table.insert(result.path, pathObj.path[i])  end

	return result
end



-- directory|nil = getDirectory( path|pathObj )
function Path.getDirectory(pathObj)
	if type(pathObj) == "string" then  pathObj = Path.parse(pathObj)  end

	local len      = #pathObj.path
	local filename = pathObj.path[len]

	if not filename then  return nil  end

	pathObj.path[len] = nil
	local dir         = pathObj:toDirectory()
	pathObj.path[len] = filename

	return dir
end

-- filename|nil = getFilename( path|pathObj )
function Path.getFilename(pathObj)
	if type(pathObj) == "string" then  pathObj = Path.parse(pathObj)  end
	return pathObj.path[#pathObj.path]
end

-- directory|nil, filename|nil = getDirectoryAndFilename( path|pathObj )
function Path.getDirectoryAndFilename(pathObj)
	if type(pathObj) == "string" then  pathObj = Path.parse(pathObj)  end

	local len      = #pathObj.path
	local filename = pathObj.path[len]

	if not filename then  return nil  end

	pathObj.path[len] = nil
	local dir         = pathObj:toDirectory()
	pathObj.path[len] = filename

	return dir, filename
end



function Path.setFilename(pathObj, filename)
	pathObj.path[math.max(#pathObj.path, 1)] = filename
end



-- success = prepend( pathObj, pathToPrepend|pathObjToPrepend )
function Path.prepend(pathObj, pathObjToPrepend)
	if pathObj.isAbsolute then  return false  end

	if type(pathObjToPrepend) == "string" then  pathObjToPrepend = Path.parse(pathObjToPrepend)  end

	pathObj.drive      = pathObjToPrepend.drive
	pathObj.isAbsolute = pathObjToPrepend.isAbsolute

	for i, pathSegment in ipairs(pathObjToPrepend.path) do
		table.insert(pathObj.path, i, pathSegment)
	end

	clean(pathObj)
	return true
end

-- success = append( pathObj, pathToAppend|pathObjToAppend )
function Path.append(pathObj, pathObjToAppend)
	if type(pathObjToAppend) == "string" then  pathObjToAppend = Path.parse(pathObjToAppend)  end

	if pathObjToAppend.isAbsolute then  return false  end

	for _, pathSegment in ipairs(pathObjToAppend.path) do
		table.insert(pathObj.path, pathSegment)
	end

	clean(pathObj)
	return true
end



function Path.isEmpty(pathObj)
	return not (pathObj.isAbsolute or pathObj.path[1])
end



-- pathSegment|nil = pop( pathObj )
function Path.pop(pathObj)
	return (table.remove(pathObj.path))
end



-- If both paths are relative then they are assumed to be relative to the same directory.
-- containsOrIsSame = contains( containerPath|containerPathObj, otherPath|otherPathObj )
function Path.contains(containerPathObj, otherPathObj)
	if type(containerPathObj) == "string" then  containerPathObj = Path.parse(containerPathObj)  end
	if type(otherPathObj)     == "string" then  otherPathObj     = Path.parse(otherPathObj)      end

	if containerPathObj.isAbsolute ~= otherPathObj.isAbsolute then  return false  end
	if containerPathObj.drive      ~= otherPathObj.drive      then  return false  end

	for i, pathSegment in ipairs(containerPathObj.path) do
		if pathSegment ~= otherPathObj.path[i] then  return false  end
	end

	return true
end



--[[ Tests!
local function printf(s, ...)
	print(s:format(...))
end

local DIRS = {
	-- Input                  Expected output
	"C:/foo/bar",             "C:/foo/bar",
	"c:..\\foo\\bar",         "C:/foo/bar",
	"/majestic/doggo/.",      "/majestic/doggo",
	"~/Only trees",           "~/Only trees",
	"My Game/src/",           "My Game/src",
	"./cutest/cat/..",        "cutest",
	"ceiling/cat/../..",      ".",
	"../almighty/cricket/..", "../almighty",
	"",                       ".",
	".",                      ".",
	"..",                     "..",
	"foo/../..",              "..",
	"C:/",                    "C:/.",
	"C/",                     "C",
	"C:foo",                  "C:/foo",
	"/",                      "/.",
	"~",                      "~/.",
}
local FILES = {
	-- Input                        Expected output
	"C:/foo/bar/a.txt",             "C:/foo/bar/a.txt",
	"c:..\\foo\\bar\\a.txt",        "C:/foo/bar/a.txt",
	"/majestic/doggo/./a.txt",      "/majestic/doggo/a.txt",
	"~/Only trees/a.txt",           "~/Only trees/a.txt",
	"./cutest/cat/../a.txt",        "cutest/a.txt",
	"ceiling/cat/../../a.txt",      "a.txt",
	"../almighty/cricket/../a.txt", "../almighty/a.txt",
	"",                             "",
	"a.txt",                        "a.txt",
	"./a.txt",                      "a.txt",
	"../a.txt",                     "../a.txt",
	"foo/../../a.txt",              "../a.txt",
	"C:/a.txt",                     "C:/a.txt",
	"C/a.txt",                      "C/a.txt",
	"C:foo/a.txt",                  "C:/foo/a.txt",
	"/a.txt",                       "/a.txt",
}
local RELATIVES = {
	-- Input            Reference     Expected output
	"C:/foo/o/bar.png", "C:/foo",     true,  "o/bar.png",
	"C:/foo/bar.png",   "C:/foo",     true,  "bar.png",
	"C:/foo/bar.png",   "C:/foo/cat", true,  "../bar.png",
	"C:/foo/bar.png",   "nope",       false, "",
	"nope.jpg",         "C:/foo",     false, "",
	"nope.jpg",         "nope",       false, "", -- Do we want the case of both paths being relative to be able to succeed?
}

for i = 1, #DIRS, 2 do
	local pathOut = Path(DIRS[i]):toDirectory()
	printf('DIR  IN   "%s"', DIRS[i])
	printf('DIR  OUT  "%s"', pathOut)
	printf('DIR  WANT "%s"', DIRS[i+1])
	assert(pathOut == DIRS[i+1])
	print("--------------------")
end
for i = 1, #FILES, 2 do
	local pathOut = Path(FILES[i]):toString()
	printf('FILE IN   "%s"', FILES[i])
	printf('FILE OUT  "%s"', pathOut)
	printf('FILE WANT "%s"', FILES[i+1])
	assert(pathOut == FILES[i+1])
	print("--------------------")
end
for i = 1, #RELATIVES, 4 do
	local path1      = Path(RELATIVES[i])
	local path2      = Path(RELATIVES[i+1])
	local pathOutObj = path1:getRelativeTo(path2)
	local pathOut    = pathOutObj and pathOutObj:toString() or ""
	printf('REL  IN   "%s"', RELATIVES[i])
	printf('REL  REF  "%s"', RELATIVES[i+1])
	printf('REL  OUT  "%s"', pathOut)
	printf('REL  WANT "%s"', RELATIVES[i+3])
	assert((pathOutObj ~= nil) == RELATIVES[i+2])
	if pathOutObj then  assert(pathOut == RELATIVES[i+3])  end
	print("--------------------")
end

assert(Path.contains("C:/foo", "C:/foo/dog.png" ) == true )
assert(Path.contains("C:/foo", "C:/dog.png"     ) == false)
assert(Path.contains("C:/foo", "C:/nope/dog.png") == false)

assert(Path.contains("foo",    "foo/dog.png"    ) == true )
assert(Path.contains("foo",    "dog.png"        ) == false)
assert(Path.contains("foo",    "nope/dog.png"   ) == false)

assert(Path.contains("C:/foo", "foo/dog.png"    ) == false)
assert(Path.contains("foo",    "C:/foo/dog.png" ) == false)

print("All tests passed!")
os.exit(2)
--]]



return Path

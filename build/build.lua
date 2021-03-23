--[[============================================================
--=
--=  Build script
--=
--=  Requires LuaFileSystem!
--=
--=-------------------------------------------------------------
--=
--=  ReFreezed Bitmap Font converter
--=  by Marcus 'ReFreezed' Thunström
--=
--============================================================]]

io.stdout:setvbuf("no")
io.stderr:setvbuf("no")
collectgarbage("stop")

print("Building...")
local buildStartTime = os.clock()

local DIR_HERE = debug.getinfo(1, "S").source:match"^@(.+)":gsub("\\", "/"):gsub("/?[^/]+$", ""):gsub("^$", ".")

local pp  = require"build.preprocess"
local lfs = require"lfs"

local devMode = false

--
-- Functions
--

local function copyFile(pathFrom, pathTo)
	local file = assert(io.open(pathFrom, "rb"))
	local s    = file:read("*a")
	file:close()

	local file = assert(io.open(pathTo, "wb"))
	file:write(s)
	file:close()
end

--
-- Parse args
--

for _, arg in ipairs(arg) do
	if arg == "--dev" then
		devMode = true
	else
		error("Unknown argument '"..arg.."'.")
	end
end

--
-- Metaprogram stuff
--

local metaEnv = pp.metaEnvironment

metaEnv.DEV = devMode

local chunk = loadfile"build/meta.lua"
setfenv(chunk, metaEnv)
chunk()

--
-- Build!
--

lfs.mkdir("srcgen")

for filename in lfs.dir("src") do
	local pathIn = "src/"..filename

	if filename:find"%.lua$" then
		copyFile(pathIn, "srcgen/"..filename)

	elseif filename:find"%.lua2p$" then
		local pathOut = (
			(filename == "conf.lua2p" and "conf.lua") or
			(filename == "main.lua2p" and "main.lua") or
			"srcgen/"..filename:gsub("%.lua2p$", ".lua")
		)

		pp.processFile{
			pathIn   = pathIn,
			pathOut  = pathOut,
			pathMeta = pathOut:gsub("%.%w+$", ".meta%0"),

			debug           = false,
			backtickStrings = true,
			canOutputNil    = false,

			onError = function(err)
				os.exit(1)
			end,
		}
	end
end

print(("Build completed in %.3f seconds."):format(os.clock()-buildStartTime))

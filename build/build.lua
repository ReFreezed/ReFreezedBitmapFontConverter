--[[============================================================
--=
--=  Build script
--=
--=  Requires LuaFileSystem!
--=  Preparing a release requires a lot more things!
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

local devMode   = false
local testMode  = false
local doRelease = false

--
-- Parse args
--

if arg[1] == "dev" then
	devMode = true

elseif arg[1] == "test" then
	devMode  = true
	testMode = true

elseif arg[1] == "release" then
	doRelease = true

elseif arg[1] then
	error("Unknown mode '"..arg.."'.")
end

assert(not (devMode and doRelease))

--
-- Metaprogram stuff
--

local metaEnv = pp.metaEnvironment

metaEnv.DEV  = devMode
metaEnv.TEST = testMode

metaEnv.lfs = lfs

local chunk = assert(loadfile"build/meta.lua")
setfenv(chunk, metaEnv)
chunk()

setmetatable(_G, {__index=metaEnv})

--
-- Build!
--

makeDirectory("srcgen")

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

printf("Build completed in %.3f seconds!", os.clock()-buildStartTime)

--
-- Prepare release
--

if doRelease then
	print("Preparing release...")

	local params = loadParams()

	local outputDirWin64     = "output/win64/ReFreezed Bitmap Font converter"
	local outputDirMacOs     = "output/macOs/ReFreezed Bitmap Font converter"
	local outputDirUniversal = "output/universal/ReFreezed Bitmap Font converter"

	local values
	do
		local versionStr, major,minor,patch = getReleaseVersion()

		values = {
			exeName         = "ReFreezedBitmapFontConverter",
			exePath         = outputDirWin64.."/ReFreezedBitmapFontConverter.exe",
			iconPath        = "temp/appIcon.ico",

			appName         = "ReFreezed Bitmap Font converter",
			appNameShort    = "RBMF converter", -- Should be less than 16 characters long.
			appNameInternal = "ReFreezed Bitmap Font converter",

			appVersion      = versionStr,
			appVersionMajor = major,
			appVersionMinor = minor,
			appVersionPatch = patch,
			appIdentifier   = "com.refreezed.rbmfconverter",

			companyName     = "",
			copyright       = os.date"Copyright %Y Marcus 'ReFreezed' Thunström",

			lovePath        = "temp/app.love",
			loveExeDir      = params.dirLoveWin64,
			loveExePath     = params.dirLoveWin64.."/lovec.exe",
			loveAppDir      = params.dirLoveMacOs,
			loveAppPath     = params.dirLoveMacOs.."/love.app",
			versionInfoPath = "temp/appInfo.res",
		}
	end

	makeDirectory("temp")

	--[=[
	do
		-- Create missing icon sizes.
		for _, it in ipairs{--[[16,]]24,32,48,64,128--[[,256]]} do
			executeRequired(params.pathMagick, {
				"gfx/appIcon256.png",
				"-resize", F("%dx%d", it, it),
				F("gfx/appIcon%d.png", it),
			})
		end

		-- Crush icon PNGs.
		-- @Incomplete: Crush all PNGs for release version!
		for {16,24,32,48,64,128,256} {
			executeRequired(params.pathPngCrush, {
				"-ow",          -- Overwrite (must be first).
				"-rem", "alla", -- Remove unnecessary chunks.
				"-reduce",      -- Lossless color reduction.
				"-warn",        -- No spam!
				F("gfx/appIcon%d.png", it),
			})
		}

		-- Create .ico.
		writeFile("temp/icons.txt", "\z
			gfx/appIcon16.png\n\z
			gfx/appIcon24.png\n\z
			gfx/appIcon32.png\n\z
			gfx/appIcon48.png\n\z
			gfx/appIcon64.png\n\z
			gfx/appIcon128.png\n\z
			gfx/appIcon256.png\n\z
		")

		executeRequired(params.pathMagick, {
			"@temp/icons.txt",
			values.iconPath,
		})
	end
	--]=]

	-- Make love. <3
	local filesToLove = {
		"conf.lua",
		"main.lua",
	}

	for _, dir in ipairs{--[["gfx",]]"srcgen"} do
		traverseDirectory(dir, function(path)
			if isFile(path) then
				local ext = path:match"[^.]+$"

				if ext == "psd" then
					-- print("- "..path)
				else
					-- print("+ "..path)
					table.insert(filesToLove, path)
				end

			-- elseif path == ? then
			-- 	return "ignore"
			end
		end)
	end

	os.remove(values.lovePath)
	zipFiles(params, values.lovePath, filesToLove)

	-- Windows.
	local PATH_RC_LOG = "temp/robocopy.log"
	os.remove(PATH_RC_LOG)

	do
		local outputDir = outputDirWin64

		-- Compile resource file.
		do
			local contents = readFile("build/appInfoTemplate.rc") -- UTF-16 LE BOM encoded.
			contents       = templateToStringUtf16(params, contents, values)
			writeFile("temp/appInfo.rc", contents)

			executeRequired(params.pathRh, {
				"-open",   "temp/appInfo.rc",
				"-save",   values.versionInfoPath,
				"-action", "compile",
				"-log",    "temp/rh.log", -- @Temp
				-- "-log",    "CONSOLE", -- Why doesn't this work? (And is it just in Sublime?)
			})
		end

		do
			local TEMPLATE_UPDATE_EXE = ([[
				[FILENAMES]
				Exe    = "${loveExePath}"
				SaveAs = "${exePath}"
				Log    = CONSOLE

				[COMMANDS]
				-delete ICONGROUP,,
				-delete VERSIONINFO,,
				-add "${versionInfoPath}", ,,
			]]):gsub("\t+", "")
			-- 	-add "${iconPath}", ICONGROUP,MAINICON,0
			-- ]]):gsub("\t+", "") -- @Incomplete: App icon!

			local contents = templateToString(TEMPLATE_UPDATE_EXE, values, toWindowsPath)
			writeTextFile("temp/updateExe.rhs", contents)
		end

		-- Create base for install directory using robocopy.
		-- Note: Because of robocopy's complex return codes we just trust that it's always successful.
		-- https://blogs.technet.microsoft.com/deploymentguys/2008/06/16/robocopy-exit-codes/
		execute("ROBOCOPY", {values.loveExeDir, outputDir, "/NOCOPY", "/PURGE",           "/E", "/LOG+:"..PATH_RC_LOG})
		execute("ROBOCOPY", {values.loveExeDir, outputDir, "*.dll", "/XF","OpenAL32.dll", "/E", "/LOG+:"..PATH_RC_LOG})

		-- Create exe.
		do
			executeRequired(params.pathRh, {
				"-script", "temp/updateExe.rhs",
			})

			local contentsLoveExe = readFile(values.exePath)
			local contentsLove    = readFile(values.lovePath)

			local file = assert(io.open(values.exePath, "wb"))
			file:write(contentsLoveExe)
			file:write(contentsLove)
			file:close()
		end

		-- Add remaining files.
		do
			copyFile("build/Changelog.txt", outputDir.."/_Changelog.txt")
			copyFile("build/README.txt",    outputDir.."/_README.txt")
		end
	end

	--[[ macOS.
	do
		local outputDir   = outputDirMacOs
		local contentsDir = F("%s/%s.app/Contents", outputDir, values.exeName)

		-- Create base for install directory using robocopy.
		makeDirectoryRecursive(contentsDir)
		makeDirectory(contentsDir.."/Frameworks")
		makeDirectory(contentsDir.."/MacOS")
		makeDirectory(contentsDir.."/Resources")

		execute("ROBOCOPY", {values.loveAppPath.."/Contents", contentsDir, "/NOCOPY", "/PURGE", "/E", "/LOG+:"..PATH_RC_LOG})
		removeDirectoryRecursive(contentsDir.."/_CodeSignature")

		execute("ROBOCOPY", {values.loveAppPath.."/Contents/Frameworks", contentsDir.."/Frameworks", "/E", "/LOG+:"..PATH_RC_LOG})
		execute("ROBOCOPY", {values.loveAppPath.."/Contents/MacOS",      contentsDir.."/MacOS",      "/E", "/LOG+:"..PATH_RC_LOG})

		-- Create .icns.
		assert(createIcns?("temp/appIcon.icns", {
			{path="gfx/appIcon16.png",  size=16},
			{path="gfx/appIcon32.png",  size=32},
			{path="gfx/appIcon64.png",  size=64},
			{path="gfx/appIcon128.png", size=128},
			{path="gfx/appIcon256.png", size=256},
		}))

		-- Create other files.
		local infoPlist = readFile("build/appInfoTemplate.plist")

		infoPlist = infoPlist:gsub("<!%-%-.-%-%->", "")  -- Remove comments.
		infoPlist = infoPlist:gsub(">%s+",          ">") -- Remove useless whitespace.
		infoPlist = infoPlist:gsub("%s+<",          "<") -- Remove useless whitespace.

		infoPlist = templateToString(infoPlist, values, function(s)
			return (s:gsub('[&<>"]', {
				["&"] = "&amp;",
				["<"] = "&lt;",
				[">"] = "&gt;",
				['"'] = "&quot;",
			}))
		end)

		writeFile(contentsDir.."/Info.plist", infoPlist)
		writeFile(contentsDir.."/PkgInfo",    "APPL????")

		-- Add remaining files.
		do
			copyFile(values.lovePath,       contentsDir.."/Resources/Game.love")
			copyFile("temp/appIcon.icns",   contentsDir.."/Resources/AppIcon.icns")
			copyFile("build/Changelog.txt", outputDir.."/_Changelog.txt")
			copyFile("build/README.txt",    outputDir.."/_README.txt")
		end
	end
	--]]

	-- Universal.
	do
		local outputDir = outputDirUniversal

		removeDirectoryRecursive(outputDir)
		makeDirectoryRecursive(outputDir)

		copyFile(values.lovePath,                F("%s/%s.love",                 outputDir, values.exeName))
		copyFile("build/Changelog.txt",          F("%s/_Changelog.txt",          outputDir))
		copyFile("build/README.txt",             F("%s/_README.txt",             outputDir))
		copyFile("build/README (universal).txt", F("%s/_README (universal).txt", outputDir))
	end

	-- Zip for distribution!
	zipDirectory(params, "output/ReFreezedBitmapFontConverter_"..values.appVersion.."_win64.zip",     "./"..outputDirWin64)
	-- zipDirectory(params, "output/ReFreezedBitmapFontConverter_"..values.appVersion.."_macos.zip",     "./"..outputDirMacOs)
	zipDirectory(params, "output/ReFreezedBitmapFontConverter_"..values.appVersion.."_universal.zip", "./"..outputDirUniversal)

	print("Release ready!")
end

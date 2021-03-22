--[[============================================================
--=
--=  PhysFS functionality through LÖVE
--=
--==============================================================

	getSearchPaths
	getWriteDirectory, setWriteDirectory
	mountReadDirectory, unmountReadDirectory

--============================================================]]

local physfs  = {}
local ffi     = require"ffi"
local initted = false
local loveLib



local function init()
	if initted then  return  end

	ffi.cdef[[
		bool         PHYSFS_mount         (const char *dir, const char *mountPoint, bool appendToPath);
		bool         PHYSFS_unmount       (const char *dir);
		char **      PHYSFS_getSearchPath (void);
		const char * PHYSFS_getWriteDir   (void);
		bool         PHYSFS_setWriteDir   (const char *dir);
	]]

	loveLib = (ffi.os == "Windows") and ffi.load"love" or ffi.C
	initted = true
end



-- directory|nil = getWriteDirectory()
function physfs.getWriteDirectory()
	init()

	local cDir = loveLib.PHYSFS_getWriteDir()
	if cDir == nil then  return nil  end

	return (ffi.string(cDir))
end

-- success = setWriteDirectory( directory )
function physfs.setWriteDirectory(dir)
	init()
	return (loveLib.PHYSFS_setWriteDir(dir))
end



-- success = mountReadDirectory( directory, append )
function physfs.mountReadDirectory(dir, append)
	init()
	return (loveLib.PHYSFS_mount(dir, nil, append))
end

-- success = unmountReadDirectory( directory )
function physfs.unmountReadDirectory(dir)
	init()
	return (loveLib.PHYSFS_unmount(dir))
end



function physfs.getSearchPaths()
	init()

	local paths  = {}
	local cPaths = loveLib.PHYSFS_getSearchPath()

	for i = 0, 2^52 do
		if cPaths[i] == nil then  break  end
		paths[i+1] = ffi.string(cPaths[i])
	end

	return paths
end



return physfs

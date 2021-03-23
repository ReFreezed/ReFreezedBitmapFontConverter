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

	templateToLua
	GET_IMAGE_DATA_POINTER, GET_PIXEL, SET_PIXEL, MAP_PIXEL, MAP_PIXEL_END

--============================================================]]



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
		local values = {
			imageData = imageDataIdent,
			r = rIdent, g = gIdent, b = bIdent, a = aIdent,
			x = x, y = y,
			byteToFloat = toLua(1/255),
		}

		if rIdent then  __LUA(templateToLua("local $r = $imageData_pointer[4 * (($y)*$imageData_w + ($x))    ] * $byteToFloat\n", values))  end
		if gIdent then  __LUA(templateToLua("local $g = $imageData_pointer[4 * (($y)*$imageData_w + ($x)) + 1] * $byteToFloat\n", values))  end
		if bIdent then  __LUA(templateToLua("local $b = $imageData_pointer[4 * (($y)*$imageData_w + ($x)) + 2] * $byteToFloat\n", values))  end
		if aIdent then  __LUA(templateToLua("local $a = $imageData_pointer[4 * (($y)*$imageData_w + ($x)) + 3] * $byteToFloat\n", values))  end

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

-- SET_PIXEL( imageDataIdent, xCodeOrCoord,yCodeOrCoord, rIdent,gIdent,bIdent,aIdent [, reuseExistingIndex=false ] )
function _G.SET_PIXEL(imageDataIdent, x,y, rIdent,gIdent,bIdent,aIdent, reuseExistingIndex)
	if y == 0 and type(x) == "number" then
		local values = {
			imageData = imageDataIdent,
			r = rIdent, g = gIdent, b = bIdent, a = aIdent,
			i1 = toLua(4*x), i2=toLua(4*x+1), i3=toLua(4*x+2), i4=toLua(4*x+3),
		}

		__LUA(templateToLua("$imageData_pointer[$i1] = math.floor(($r)*255+.5)\n", values))
		__LUA(templateToLua("$imageData_pointer[$i2] = math.floor(($g)*255+.5)\n", values))
		__LUA(templateToLua("$imageData_pointer[$i3] = math.floor(($b)*255+.5)\n", values))
		__LUA(templateToLua("$imageData_pointer[$i4] = math.floor(($a)*255+.5)\n", values))

	else
		if type(x) == "number" then  x = toLua(x)  end
		if type(y) == "number" then  y = toLua(y)  end

		local values = {
			imageData = imageDataIdent,
			r = rIdent, g = gIdent, b = bIdent, a = aIdent,
			x = x, y = y,
		}

		if not reuseExistingIndex then
			__LUA(templateToLua("local $imageData_cIndex = 4 * (($y)*$imageData_w + ($x))\n", values))
		end
		__LUA(templateToLua("$imageData_pointer[$imageData_cIndex  ] = math.floor(($r)*255+.5)\n", values))
		__LUA(templateToLua("$imageData_pointer[$imageData_cIndex+1] = math.floor(($g)*255+.5)\n", values))
		__LUA(templateToLua("$imageData_pointer[$imageData_cIndex+2] = math.floor(($b)*255+.5)\n", values))
		__LUA(templateToLua("$imageData_pointer[$imageData_cIndex+3] = math.floor(($a)*255+.5)\n", values))
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



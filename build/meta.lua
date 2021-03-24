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



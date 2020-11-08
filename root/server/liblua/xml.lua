local xml_lib = require "TinyXml"
local lua_util = require "lua_util"

local api = {}

function api.try_to_number(value)
	return tonumber(value) or value
end

function api.split_str(str,delim,func)
	local i = 0
	local j = 1
	local t = {}

	while i ~= nil do
		i = string.find(str,delim,j)
		if i ~= nil then
			local tmp_str = string.sub(str,j,i-1)
			if tmp_str ~= "" then
				if func then
					table.insert(t,func(tmp_str))
				else
					table.insert(t,tmp_str)
				end
			end
			j = i + 1
		else
			local tmp_str = string.sub(str,j)
			if tmp_str ~= "" then
				if func then
					table.insert(t,func(tmp_str))
				else
					table.insert(t,tmp_str)
				end
			end
		end
	end
	return t
end

function api.split_str_2_dict(str,delim,func)
	local t = api.split_str(str,delim,func)
	local t2 = {}
	for i = 1,#t,2 do
		local k = t[i]
		local v = t[i+1]
		if k and v then
			t2[k] = v
		end
	end
	return t2
end


function api.is_start_with_str(str,substr)
	local i,j = string.find(str,substr)
	return i == 1
end

function api.format_key_value(key,value)
	local key_len = #key
	if key_len > 2 then
		local prefix = string.sub(key,-2)
		local key2 = string.sub(key,0,-3)

		if prefix == "_i" then
			return key2,tonumber(value)
		elseif prefix == "_f" then
			return key2,tonumber(value)
		elseif prefix == "_s" then
			return key2,tostring(value)
		elseif prefix == "_l" then
			return key2,api.split_str(value,',',api.try_to_number)
		elseif prefix == "_k" then
			local tmp = api.split_str(value,',',api.try_to_number)
			local tmp2 = {}
			for _,k in pairs(tmp) do
				tmp2[k] = 1
			end
			return key2,tmp2
		elseif prefix == "_t" then
			local tmp = api.split_str(value,":")
			local sec = 0
			for i,v in pairs(tmp) do
				local t = tonumber(v)
				if t then
					sec = t + sec * 60
				end
			end
			return key2,sec
		elseif prefix == "_y" then
			local i = string.find(value,' ',1)
			if not i then
				return key2,os.time({year=2999,month=1,day=1,hour=1,min=0,sec=0})
			else
				local str_data = string.sub(value,1,i-1)
				local str_time = string.sub(value,i+1)
				local dd = api.split_str(str_data,'-',tonumber)
				local tt = api.split_str(str_time,':',tonumber)
				return key2,os.time({year=dd[1],month=dd[2],day=dd[3],hour=tt[1],min=tt[2],sec=tt[3]})
			end
		elseif prefix == "_m" then
			local tmp = api.split_str(value,',')
			local tmp2 = {}
			for _,v in pairs(tmp) do
				local tmp_ = api.split_str(v,':')
				local id = api.try_to_number(tmp_[1])
				local num = api.try_to_number(tmp_[2])
				tmp2[id] = num
			end
			return key2,tmp2
		elseif prefix == "_w" then
			local tmp = {}
			local tmp1 = api.split_str(value,";")
			for i,v in pairs(tmp1) do
				local tmp2 = api.split_str(v,',',api.try_to_number)
				table.insert(tmp,tmp2)
			end
			return key2,tmp
		else
			return key,api.try_to_number(value)
		end
	else
		return key,api.try_to_number(value)
	end
end

function api.find_attr_key(data)
	if type(data) ~= "table" then
		return nil
	end

	if data["id"] ~= nil then
		return data["id"]
	elseif data["key"] ~= nil then
		return data["key"]
	elseif data["name"] ~= nil then
		return data["name"]
	else
		return nil
	end

	return nil
end

function api.match_sperial_define(name)
	local key_len = #name
	if key_len > 2 then
		local prefix = string.sub(name,-2)
		if prefix == "_v" then
			return true
		end
	end

	return false
end

function api.format_sperial_key(name)
	local key_len = #name
	if key_len > 2 then
		local prefix = string.sub(name,-2)
		local key = string.sub(name,0,-3)

		if prefix == "_v" then
			return key
		end
	end

	return name
end

function api.parse_xml_node(xml_node)
	local data = {}
	local node_num = {}

	if xml_node.attr ~= nil and type(xml_node.attr) == "table" then
		for k,v in pairs(xml_node.attr) do
			local real_key,real_val = api.format_key_value(k,v)
			if real_key and real_val then
				data[real_key] = real_val
			end
		end
	end

	if #xml_node == 0 then
		return data
	end

	for i = 1,#xml_node do
		local v = xml_node[i]
		local node_name = v.name
		if node_name == nil then
			data = v
			break
		end
		local node_data = api.parse_xml_node(v)
		local node_key = api.find_attr_key(node_data)
		
		if api.match_sperial_define(node_name) then
			node_name = api.format_sperial_key(node_name)
			data[node_name] = data[node_name] or {}
			if node_key ~= nil then
				(data[node_name])[node_key] = node_data
			else
				table.insert(data[node_name],node_data)
			end
		else
			if data[node_name] == nil then
				if type(node_data) ~= "table" then
					local real_key,real_val = api.format_key_value(node_name,node_data)
					if real_key and real_val then
						data[real_key] = real_val
					end
				else
					data[node_name] = node_data
				end
				node_num[node_name] = 1
			else
				if node_num[node_name] == 1 then
					local last_node_data = data[node_name]
					local last_node_key = api.find_attr_key(last_node_data)
					data[node_name] = {}
					if last_node_key ~= nil then
						(data[node_name])[last_node_key] = last_node_data
					else
						table.insert(data[node_name],last_node_data)
					end
					node_num[node_name] = 2
				end
				if type(data[node_name]) == "table" then
					if node_key ~= nil then
						(data[node_name])[node_key] = node_data
					else
						table.insert(data[node_name],node_data)
					end
				end
			end
		end
	end
	return data
end


function api.parse_xml(file)
	local xml_data = xml_lib.LuaXML_ParseFile(file)
	return api.parse_xml_node(xml_data)
end

function api.parse_string(content)
	local xml_data = xml_lib.LuaXML_ParseString(content)
	return api.parse_xml_node(xml_data)
end

function api.to_timestamp(str)
	return xml_lib.to_timestamp(str)
end

return api

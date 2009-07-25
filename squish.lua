#!/usr/bin/env lua

local short_opts = { v = "verbose", vv = "very_verbose", o = "output", q = "quiet", qq = "very_quiet" }
local opts = {};

for _, opt in ipairs(arg) do
	if opt:match("^%-") then
		local name = opt:match("^%-%-?([^%s=]+)()")
		name = (short_opts[name] or name):gsub("%-+", "_");
		if name:match("^no_") then
			name = name:sub(4, -1);
			opts[name] = false;
		else
			opts[name] = opt:match("=(.*)$") or true;
		end
	else
		base_path = opt;
	end
end

if opts.very_verbose then opts.verbose = true; end
if opts.very_quiet then opts.quiet = true; end

local noprint = function () end
local print_err, print_info, print_verbose, print_debug = noprint, noprint, noprint, noprint;

if not opts.very_quiet then print_err = print; end
if not opts.quiet then print_info = print; end
if opts.verbose or opts.very_verbose then print_verbose = print; end
if opts.very_verbose then print_debug = print; end

local enable_debug = opts.enable_debug;

local modules, main_files, resources = {}, {}, {};

--  Functions to be called from squishy file  --

function Module(name)
	local i = #modules+1;
	modules[i] = { name = name, url = ___fetch_url };
	return function (path)
		modules[i].path = path;
	end
end

function Resource(name, path)
	local i = #resources+1;
	resources[i] = { name = name, path = path or name };
	return function (path)
		resources[i].path = path;
	end
end

function AutoFetchURL(url)
	___fetch_url = url;
end

function Main(fn)
	table.insert(main_files, fn);
end

function Output(fn)
	out_fn = fn;
end

function Option(name)
	if opts[name] == nil then
		opts[name] = true;
		return function (value)
			opts[name] = value;
		end
	else
		return function () end;
	end
end

function GetOption(name)
	return opts[name:gsub('%-', '_')];
end

-- -- -- -- -- -- -- --- -- -- -- -- -- -- -- --

base_path = (base_path or "."):gsub("/$", "").."/"
squishy_file = base_path .. "squishy";
out_fn = opts.output or "squished.out.lua";

local ok, err = pcall(dofile, squishy_file);

if not ok then
	print_err("Couldn't read squishy file: "..err);
	os.exit(1);
end

local fetch = {};
function fetch.filesystem(path)
	local f, err = io.open(path);
	if not f then return false, err; end
	
	local data = f:read("*a");
	f:close();
	
	return data;
end

function fetch.http(url)
	local http = require "socket.http";
	
	local body, status = http.request(url);
	if status == 200 then
		return body;
	end
	return false, "HTTP status code: "..tostring(status);
end

print_info("Writing "..out_fn.."...");
local f = io.open(out_fn, "w+");

if opts.executable then
	f:write("#!/usr/bin/env lua\n");
end

if enable_debug then
	f:write [[
	local function ___rename_chunk(chunk, name)
		if type(chunk) == "function" then
			chunk = string.dump(chunk);
		end
		local intsize = chunk:sub(8,8):byte();
		local b = { chunk:sub(13, 13+intsize-1):byte(1, intsize) };
		local oldlen = 0;
		for i = 1, #b do 
			oldlen = oldlen + b[i] * 2^((i-1)*8);
		end
		
		local newname = name.."\0";
		local newlen = #newname;
		
		local b = { };
		for i=1,intsize do
			b[i] = string.char(math.floor(newlen / 2^((i-1)*8)) % (2^(i*8)));
		end
		
		return loadstring(chunk:sub(1, 12)..table.concat(b)..newname
			..chunk:sub(13+intsize+oldlen, -1));
	end
	]];
end

print_verbose("Packing modules...");
for _, module in ipairs(modules) do
	local modulename, path = module.name, base_path..module.path;
	print_debug("Packing "..modulename.." ("..path..")...");
	local data, err = fetch.filesystem(path);
	if (not data) and module.url then
		print_debug("Fetching: ".. module.url:gsub("%?", module.path))
		data, err = fetch.http(module.url:gsub("%?", module.path));
	end
	if data then
		f:write("package.preload['", modulename, "'] = (function ()\n");
		f:write(data);
		f:write("end)\n");
		if enable_debug then
			f:write(string.format("package.preload[%q] = ___rename_chunk(package.preload[%q], %q);\n\n", 
				modulename, modulename, "@"..path));
		end
	else
		print_err("Couldn't pack module '"..modulename.."': "..err);
		os.exit(1);
	end
end

if #resources > 0 then
	print_verbose("Packing resources...")
	f:write("do local resources = {};\n");
	for _, resource in ipairs(resources) do
		local name, path = resource.name, resource.path;
		local res_file, err = io.open(base_path..path);
		if not res_file then
			print_err("Couldn't load resource: "..tostring(err));
			os.exit(1);
		end
		local data = res_file:read("*a");
		local maxequals = 0;
		data:gsub("(=+)", function (equals_string) maxequals = math.max(maxequals, #equals_string); end);
		
		f:write(("resources[%q] = ["):format(name), string.rep("=", maxequals+1), "[");
		f:write(data);
		f:write("]", string.rep("=", maxequals+1), "];");
	end
	f:write[[function require_resource(name) return resources[name] or error("resource '"..tostring(name).."' not found"); end end ]]
end

print_debug("Finalising...")
for _, fn in pairs(main_files) do
	local fin, err = io.open(base_path..fn);
	if not fin then
		print_err("Failed to open "..fn..": "..err);
		os.exit(1);
	else
		f:write((fin:read("*a"):gsub("^#.-\n", "")));
		fin:close();
	end
end

f:close();

print_info("OK!");

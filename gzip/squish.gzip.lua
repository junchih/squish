function gzip_file(infile_fn, outfile_fn)
	local infile, err = io.open(infile_fn);
	if not infile then
		print_err("Can't open input file for reading: "..tostring(err));
		return;
	end
	
	local outfile, err = io.open(outfile_fn..".gzipped", "w+");
	if not outfile then
		print_err("Can't open output file for writing: "..tostring(err));
		return;
	end
	
	local data = infile:read("*a");
	infile:close();
	
	local shebang, newdata = data:match("^(#.-\n)(.+)$");
	local code = newdata or data;
	if shebang then
		outfile:write(shebang)
	end

	local compressed = io.popen("gzip -c '"..infile_fn.."'");
	code = compressed:read("*a");

	local maxequals = 0;
	code:gsub("(=+)", function (equals_string) maxequals = math.max(maxequals, #equals_string); end);
	
	outfile:write(require_resource "gunzip.lua");
		
	outfile:write[[function _gunzip(data) local uncompressed = {};
	gunzip{input=data,output=function(b) table.insert(uncompressed, string.char(b)) end};
	return table.concat(uncompressed, ""); end ]];

	outfile:write [[return assert(loadstring(_gunzip]]
	outfile:write(string.format("%q", code));
	--outfile:write("[", string.rep("=", maxequals+1), "[", code, "]", string.rep("=", maxequals+1), "]");
	outfile:write(", '@", outfile_fn,"'))()");
	outfile:close();
	os.rename(outfile_fn..".gzipped", outfile_fn);
end

if opts.gzip then
	print_info("Gzipping "..out_fn.."...");
	gzip_file(out_fn, out_fn);
	print_info("OK!");
end

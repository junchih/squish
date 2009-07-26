
-- Not entirely sure that this is correct
-- (produces files twice the size of luac)
-- but it appears to work...

function compile_string(str, name)
	-- Strips debug info, if you're wondering :)
	local b=string.dump(assert(loadstring(str,name)))
	local x,y=string.find(b,str.."\0")
	if not (x and y) then return b; end -- No debug info sometimes?
	return string.sub(b,1,x-5).."\0\0\0\0"..string.sub(b, y+1, -1)
end

function compile_file(infile_fn, outfile_fn)
	local infile, err = io.open(infile_fn);
	if not infile then
		print_err("Can't open input file for reading: "..tostring(err));
		return;
	end
	
	local outfile, err = io.open(outfile_fn..".compiled", "w+");
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

	outfile:write(compile_string(code, outfile_fn));
	
	os.rename(outfile_fn..".compiled", outfile_fn);
end

if opts.compile then
	print_info("Compiling "..out_fn.."...");
	compile_file(out_fn, out_fn);
	print_info("OK!");
end

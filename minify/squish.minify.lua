local optlex = require "optlex"
local optparser = require "optparser"
local llex = require "llex"
local lparser = require "lparser"

local minify_defaults = {
	none = {};
	default = { "comments", "whitespace", "emptylines", "numbers", "locals" };
	basic = { "comments", "whitespace", "emptylines" };
	maximum = { "comments", "whitespace", "emptylines", "eols", "strings", "numbers", "locals", "entropy" };
	}
minify_defaults.full = minify_defaults.maximum;

for _, opt in ipairs(minify_defaults[opts.minify_level or "default"] or {}) do
	opts["minify_"..opt] = true;
end

local option = {
	["opt-locals"] = opts.minify_locals;
	["opt-comments"] = opts.minify_comments;
	["opt-entropy"] = opts.minify_entropy;
	["opt-whitespace"] = opts.minify_whitespace;
	["opt-emptylines"] = opts.minify_emptylines;
	["opt-eols"] = opts.minify_eols;
	["opt-strings"] = opts.minify_strings;
	["opt-numbers"] = opts.minify_numbers;
	}

local function die(msg)
  print_err("minify: "..msg); os.exit(1);
end

local function load_file(fname)
  local INF = io.open(fname, "rb")
  if not INF then die("cannot open \""..fname.."\" for reading") end
  local dat = INF:read("*a")
  if not dat then die("cannot read from \""..fname.."\"") end
  INF:close()
  return dat
end

local function save_file(fname, dat)
  local OUTF = io.open(fname, "wb")
  if not OUTF then die("cannot open \""..fname.."\" for writing") end
  local status = OUTF:write(dat)
  if not status then die("cannot write to \""..fname.."\"") end
  OUTF:close()
end


function minify(srcfl, destfl)
  local z = load_file(srcfl)
  llex.init(z)
  llex.llex()
  local toklist, seminfolist, toklnlist
    = llex.tok, llex.seminfo, llex.tokln
  if option["opt-locals"] then
    optparser.print = print  -- hack
    lparser.init(toklist, seminfolist, toklnlist)
    local globalinfo, localinfo = lparser.parser()
    optparser.optimize(option, toklist, seminfolist, globalinfo, localinfo)
  end
  optlex.print = print  -- hack
  toklist, seminfolist, toklnlist
    = optlex.optimize(option, toklist, seminfolist, toklnlist)
  local dat = table.concat(seminfolist)
  -- depending on options selected, embedded EOLs in long strings and
  -- long comments may not have been translated to \n, tack a warning
  if string.find(dat, "\r\n", 1, 1) or
     string.find(dat, "\n\r", 1, 1) then
    optlex.warn.mixedeol = true
  end
  -- save optimized source stream to output file
  save_file(destfl, dat)
end

if opts.minify ~= false then
	print_info("Minifying "..out_fn.."...");
	minify(out_fn, out_fn);
	print_info("OK!");
end

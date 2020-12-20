-- argument parsing library - a few different styles --

local args = {}

-- args.parse(...) -> table, table
-- STYLE: Classic (OpenOS)
-- Interprets '-abcd' as separate options
-- Interprets '--a=bcde' as is logical
-- Interprets '--a bcde' as option 'a', then argument 'bcde'
-- Stops parsing options after a '--'
function args.parse(...)
  local parse = table.pack(...)
  local pArgs, pOpts = {}, {}
  local doneWithOpts = false
  for i=1, parse.n, 1 do
    local arg = parse[i]
    if (arg:sub(1,1) ~= "-") or doneWithOpts then
      pArgs[#pArgs + 1] = arg
    else
      if arg == "--" then
        doneWithOpts = true
      elseif arg:sub(1,2) == "--" then
        local opt = arg:sub(3)
        local oopt, optarg = opt:match("(.-)=(.+)")
        oopt, optarg = oopt or opt, optarg or true
        pOpts[oopt] = optarg
      else -- arg[1] = "-"
        local opt = arg:sub(2)
        for c in opt:gmatch(".") do
          pOpts[c] = true
        end
      end
    end
  end
  return pArgs, pOpts
end

-- args.getopt(args, optstring) -> table, table
-- STYLE: GNU getopt, but one function call
-- EXTENSION: long option support, in the form '--opt=abc' or '--opt abc'.
--            long options are automatically parsed and are unaffected by the
--              optstring.
-- EXTENSION: 'o:;' allows '-o abc' alongside '-oabc'.
-- OMISSION: 'W;' does not allow '-Wfoo' -> '--foo'.
function args.getopt(args, optstring)
  checkArg(1, args, "table")
  checkArg(2, optstring, "string")
  local defs = {}
  local i = 0
  while i < #optstring do
    i = i + 1
    local c = optstring:sub(i, i)
    local n = optstring:sub(i+1,i+1)
    local N
    if n == ":" then N = optstring:sub(i+2,i+2) end
    defs[c] = {
      takesArg = n == ":",
      required = N ~= ":" and N ~= ";",
      canBeNext = N == ";" -- EXTENSION: spaced argument support for short opts
    }
    if N == ":" then
      i = i + 4
    elseif n == ":" then
      i = i + 3
    else
      i = i + 2
    end
  end
  local pArgs, pOpts = {}, {}
  local optNext = false
  for i=1, #args, 1 do
    local parse = args[i]
    if parse:sub(1,1) == "-" then
      if optNext then
        return nil, "expected argument for option `"..optNext.."'"
      end
      if parse:sub(1,2) == "--" then
        if parse == "--" then
          return nil, "malformed option `--'"
        end
        parse = parse:sub(3)
        local opt, arg = parse:match("(.-)=(.+)")
        opt = opt or parse
        if not arg then optNext = opt end
      else
        parse = parse:sub(2)
        local opt = parse:sub(1,1)
        if not defs[opt] then
          return nil, "unknown option `-"..opt.."'"
        end
        local def = defs[opt]
        if def.takesArg then
          if #parse == 1 then
            if def.required then
              if not def.canBeNext then
                return nil, "missed value for option `"..opt.."'"
              else
                optNext = opt
              end
            else
              pOpts[opt] = true
            end
          else
            local arg = parse:sub(2)
            pOpts[opt] = arg
          end
        elseif #parse > 1 then
          return nil, "bad usage of option `"..opt.."'"
        else
          pOpts[opt] = true
        end
      end
    else
      if optNext then
        pOpts[optNext] = parse
        optNext = false
      else
        pArgs[#pArgs + 1] = parse
      end
    end
  end
  return pArgs, pOpts
end

return args

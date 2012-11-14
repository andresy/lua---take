local take = package.loaded.take
local lang = {}

local function prepareflags(self, arg)
   local defines = take.table.imerge(arg.defines, self.defines, self.project.defines)
   local flags = take.table.imerge(arg.flags, self.flags, self.project.flags)
   local includes = take.table.imerge(arg.includes, self.includes, self.project.includes)
   for i=1,#defines do
      defines[i] = '-D' .. defines[i]
   end
   for i=1,#includes do
      includes[i] = '-I' .. includes[i]
   end
   flags = table.concat(flags, ' ')
   defines = table.concat(defines, ' ')
   includes = table.concat(includes, ' ')
   return defines, flags, includes
end

function lang.new(project)
   assert(project, 'project expected')
   local self = {project=project}
   setmetatable(self, {__index=lang})
   self.compiler = 'gcc'   
   self.flags = {'-O3'}
   return self
end

-- by default, output in takefiles/
function lang:outname(str)
   str = str:gsub('[^%.]+$', 'o')
   return str
end

function lang:islang(str)
   str = str:match('[^%.]+$')
   return str == 's'
end

function lang:trycompile(arg)
   assert(arg.code, 'code expected')
   local tmpname = os.tmpname()

   if arg.info then
      io.write(string.format('[trycompile: %s -- ', arg.info))
      io.flush()
   end

   local f = io.open(tmpname .. '.s', 'w')
   assert(f, 'could not create temporary file')
   f:write(arg.code)
   f:close()

   local success, msg, err = self:compile{src = tmpname .. '.s',
                                          dst = tmpname .. '.o',
                                          flags = arg.flags,
                                          defines = arg.defines,
                                          includes = arg.includes,
                                          quiet = true}

   os.remove(tmpname .. '.s')
   os.remove(tmpname .. '.o')
   os.remove(tmpname)

   if arg.info then
      print(success and 'passed]' or 'failed]')
   end

   return success, msg, err
end

function lang:preprocess(arg)
   assert(arg.code, 'code expected')
   local tmpname = os.tmpname()

   local f = io.open(tmpname .. '.s', 'w')
   assert(f, 'could not create temporary file')
   f:write(arg.code)
   f:close()

   local defines, flags, includes = prepareflags(self, arg)
   
   if arg.info then
      io.write(string.format('[preprocessing: %s -- ', arg.info))
   end

   local success, msg, err = take.os.execute{cmd=string.format('%s -E -P %s %s %s %s',
                                                               self.compiler,
                                                               tmpname .. '.s',
                                                               flags,
                                                               defines,
                                                               includes),
                                             quiet=true}
   
   os.remove(tmpname .. '.s')
   os.remove(tmpname)

   if arg.info then
      print(success and 'passed]' or 'failed]')
   end

   if not success then
      error(err)
   end

   return msg
end

-- below, self refers to project, not lang
-- bon, je peux le creer pour chaque projet, en fait --> self.proj
function lang:compile(arg)
   assert(arg.src, 'c source file missing')
   assert(take.paths.exists(arg.src), 'c source file does not exists')
   assert(arg.dst, 'o destination file missing')

   local defines, flags, includes = prepareflags(self, arg)

   local cmd = string.format('%s -o %s -c %s %s %s %s',
                             self.compiler,
                             arg.dst,
                             arg.src,
                             flags,
                             defines,
                             includes)

   if not arg.quiet and self.project.verbose then
      print(string.format('  %s', cmd))
   end

   local success, msg, err = take.os.execute{cmd=cmd,
                                             quiet=true}
   
   if not arg.quiet then
      if success then
         if self.project.verbose and msg:match('%S') then
            print(msg)
         end
      else
         error(err)
      end
   end

   return success, msg, err
end

function lang:opt()
   self.flags[1] = '-O3'
end

function lang:debug()
   self.flags[1] = '-g'
end

function lang:optdebug()
   self.flags[1] = '-O3 -g'
end

function lang:deps(name)
   return {name}
end

return lang

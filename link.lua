local take = package.loaded.take
local lang = {}

local function prepareflags(self, arg)
   local flags = take.table.imerge(arg.flags, self.flags, self.project.flags)
   local includes = take.table.imerge(arg.includes, self.includes, self.project.ldincludes)
   local libraries = take.table.imerge(arg.libraries, self.libraries, self.project.libraries)
   for i=1,#includes do
      includes[i] = '-L' .. includes[i]
   end
   for i=1,#libraries do
      if not take.paths.isabsolute(libraries[i]) then
         libraries[i] = '-l' .. libraries[i]
      end
   end
   flags = table.concat(take.table.imerge(flags, includes, libraries), ' ')
   return flags
end

function lang.new(project)
   assert(project, 'project expected')
   local self = {project=project, flags={}, includes={}, libraries={}}
   setmetatable(self, {__index=lang})
   if os.getenv('CC') then
      self.compiler = os.getenv('CC')
   elseif jit.os == 'Windows' then
      self.compiler = 'msvc' -- whatever
   else
      self.compiler = 'gcc'
   end
   return self
end

function lang.sharedflagssupply(target)
   target.flags = take.table.imerge(target.flags, {'-fPIC'})
end

function lang:basename(str, shared)
   str = take.paths.basename(str)
   if shared then
      if jit.os == 'Windows' then
         str = str:match('(.*)%.dll$')
      elseif jit.os == 'OSX' then
         str = str:match('^lib(.*)%.dylib$')
      else
         str = str:match('^lib(.*)%.so$')
      end
      return str
   else
      return str
   end
end

function lang:outname(str, shared)
   if shared then
      if jit.os == 'Windows' then
         return str .. '.dll'
      elseif jit.os == 'OSX' then
         return 'lib' .. str .. '.dylib'
      else
         return 'lib' .. str .. '.so'
      end
   else
      if jit.os == 'Windows' then
         return str .. '.exe'
      else
         return str
      end      
   end
end

function lang:islang(str)
   str = str:match('[^%.]+$')
   return str == 'o'
end

function lang:compile(arg)
   assert(arg.src, 'o source file(s) missing')
   local src = (type(arg.src) == 'string') and {arg.src} or arg.src
   for _,src in ipairs(src) do
      assert(take.paths.exists(src), string.format('o file <%s> does not exists', src))
   end
   assert(arg.dst, 'destination file missing')

   local flags = prepareflags(self, arg)

   local cmd = string.format('%s %s -o %s %s %s',
                             self.compiler,
                             arg.shared and '-shared' or '',
                             arg.dst,
                             table.concat(src, ' '),
                             flags)

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
end

function lang:debug()
end

function lang:optdebug()
end

return lang

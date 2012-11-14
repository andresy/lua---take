local take = {lang={}, project={}}
package.loaded.take = take

take.md5 = require 'take.md5'
take.os = require 'take.os'
take.paths = require 'take.paths'
take.table = require 'take.table'

take.lang.c = require 'take.lang-c'
take.lang.asm = require 'take.lang-s'
take.link = require 'take.link'

require 'take.utils'
require 'take.proglib'
require 'take.findlibrary'

take.srcdir = '.'
take.dstdir = take.paths.concat('takefiles')
take.paths.mkdir(take.dstdir)

function take.project:target(target)
   assert(type(target.name) == 'string', 'target must have a string as name')
   if self.targets[target.name] then
      error(string.format('target <%s> already exists', target.name))
   end
   target.deps = target.deps or {}
   target.needs = target.needs or {}
   target.md5 = {}
   target.project = self
   self.targets[target.name] = target
   self:loadmd5(target)

   -- needs that are targets
   local needdeps = {}
   for _,need in ipairs(target.needs) do
      if type(need) ~= 'function' then
         assert(type(need) == 'string', 'needs must be a table of functions or target names')
         assert(self.targets[need], string.format('needed <%s> is not a valid target', need))
         assert(self.targets[need].supply, string.format('<%s> does not supply anything', need))
         table.insert(needdeps, need)
      end
   end
   target.deps = take.table.imerge(target.deps, needdeps)

   return target
end

function take.project.processneeds(self, target)
   if target.needs then
      assert(type(target.needs) == 'table', 'needs must be a table')
      for _,needsupply in ipairs(target.needs) do
         needsupply = (type(needsupply) == 'function') and needsupply or self.targets[needsupply].supply
         needsupply(target)
      end
   end
end

function take.project:loadmd5(target)
   if take.paths.exists(target.name .. '.md5') then
      local f = io.open(target.name .. '.md5')
      if f then
         local txt = f:read('*all')
         f:close()
         for name, md5 in txt:gmatch('(.-)\n(.-)\n') do
            target.md5[name] = md5
         end
      end
   end
end

function take.project:savemd5(target)
   local f = io.open(target.name .. '.md5', 'w')
   assert(f, string.format('could not open file <%s> for writing', target.name .. '.md5'))
   for name, md5 in pairs(target.md5) do
      f:write(string.format('%s\n%s\n', name, md5))
   end
   f:close()
end

function take.project:buildtarget(name, done)
   if done[name] then
      return done[name]
   end

   local target = self.targets[name]

   -- check if dependencies are up-to-date
   local changeddeps = (#target.deps == 0) -- always build if no deps
   for _,name in ipairs(target.deps) do
      if self.targets[name] then
         local md5 = self:buildtarget(name, done)
         if not md5 or md5 ~= target.md5[name] then
            changeddeps = true
         end
      else
         local md5 = take.md5.file(name)
         if not md5 then
            error(string.format('no way to build <%s>', name))
         elseif md5 ~= target.md5[name] then
            changeddeps = true
         end
      end
   end

   -- check if the target was never built
   if not take.paths.exists(name) then
      changeddeps = true
   end

   -- build if necessary
   if changeddeps and target.build then
      take.paths.mkdir(take.paths.dirname(name))
      print(string.format('[take: building %s]', name))
      if self.verbose and target.info then
         print(string.format('  %s', target.info))
      end
      self:processneeds(target)
      target:build()

      -- check it was actually built
      if not take.paths.exists(name) then
         error(string.format('target <%s> was not build', name))
      end

      -- update deps md5
      for _,name in ipairs(target.deps) do
         target.md5[name] = take.md5.file(name)
      end
      self:savemd5(target)
   end

   if target.build then
      done[name] = take.md5.file(name)
   else
      done[name] = true
   end

   return done[name]
end

function take.project:build(arg)
   if not arg then
      arg = {}
      for name,_ in pairs(self.targets) do
         table.insert(arg, name)
      end
   end
   if type(arg) == 'string' then
      arg = {arg}
   end
   assert(type(arg) == 'table', 'nil, table or string expected')
   local done = {}
   for _,name in ipairs(arg) do
      self:buildtarget(name, done)
   end
   print('[take: done]')
end

function take.project.new(srcdir, dstdir)
   local self = {targets={}, lang={}}
   setmetatable(self, {__index=take.project})
   for k,v in pairs(take.lang) do
      self.lang[k] = v.new(self)
   end
   self.link = take.link.new(self)
   return self
end

function take.project:clean()
   for name,target in pairs(self.targets) do
      if target.build then
         print(string.format('[removing %s]', name))
         os.remove(name)
         print(string.format('[removing %s]', name .. '.md5'))
         os.remove(name .. '.md5')
      end
   end
end

return take

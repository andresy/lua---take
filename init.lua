local take = {lang={}, project={}}
package.loaded.take = take

take.md5 = require 'take.md5'
take.os = require 'take.os'
take.paths = require 'take.paths'
take.table = require 'take.table'

take.lang.c = require 'take.lang-c'
take.link = require 'take.link'

require 'take.proglib'

take.srcdir = '.'
take.dstdir = take.paths.concat('takefiles')
take.paths.mkdir(take.dstdir)

function take.project:target(target)
   assert(type(target.name) == 'string', 'target must have a string as name')
   if self.targets[target.name] then
      error(string.format('target <%s> already exists', target.name))
   end
   target.deps = target.deps or {}
   target.build = target.build or function() end
   target.md5 = {}
   target.project = self
   self.targets[target.name] = target
   return target
end

function take.project:loadmd5()
--    local f = io.open('takefiles/md5.txt')
--    if f then
--       local txt = txt:read('*all')
--       for name, md5 in txt:gmatch('([^\n]+)\n([^\n]+)\n') do
--          if not self.md5[name] then
--             self.md5[name] = md5
--          end
--       end
--    end
end

function take.project:buildtarget(name, done)
   local target = self.targets[name]

   -- check if dependencies are up-to-date
   local changeddeps = (#target.deps == 0) -- always build if no deps
   for _,name in ipairs(target.deps) do
      local md5 = take.md5.file(name)
      if not md5 or md5 ~= target.md5[name] then
         changeddeps = true
         if self.targets[name] then -- file is a target?
            self:buildtarget(name, done)
         elseif not md5 then -- file does not exist?
            error(string.format('no way to build <%s>', name))
         end
      end
   end

   -- check if up-to-date
   if changeddeps then
      if not done[name] then
         done[name] = true
         print(string.format('[take: building %s]', name))
         if self.verbose and target.info then
            print(string.format('  %s', target.info))
         end
         take.paths.mkdir(take.paths.dirname(name))
         target:build()
      end
   end

   -- update deps md5
   for _,name in ipairs(target.deps) do
      target.md5[name] = take.md5.file(name)
   end

   if not take.os.exists(name) then
      error(string.format('target <%s> was not build', name))
   end

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
      print(string.format('[removing %s]', name))
      os.remove(name)
   end
end

return take
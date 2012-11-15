local take = package.loaded.take

function take.project:install(arg)
   if not arg then
      return self:build('install')
   end

   assert(arg.src, 'missing src files')
   assert(arg.dst, 'missing dst path')
   assert(type(arg.src) == 'string' or type(arg.src) == 'table', 'src must be a string or a table of string')
   assert(type(arg.dst) == 'string', 'path must be a string')
   
   local src = (type(arg.src) == 'string') and {arg.src} or arg.src
   local dst = arg.dst

   local targets = {}
   for _,name in ipairs(src) do
      local mode
      if self.targets[name] and self.targets[name].lang == 'exe' then
         mode = '0755'
      else
         mode = '0644'
      end

--       if self.targets[name].supply.install then
--          self.targets[name].supply.install(self.targets[name], installname)
--       end

      local installname = take.paths.concat(take.installdir, dst, take.paths.basename(name))

      table.insert(targets, 
                   self:target{name=installname,
                               deps={name},
                               install=true,
                               md5file=take.paths.concat(take.dstdir, 'install',
                                                         take.paths.relative(take.paths.rootdir(), installname)) .. '.md5',
                               build=function(target)
                                        take.os.execute(string.format('install -m %s %s %s',
                                                                      mode,
                                                                      name,
                                                                      target.name))
                                     end}.name)
   end

   if self.targets.install then
      self.targets.install.deps = take.table.imerge(self.targets.install.deps, src)
   else
      self:target{name='install',
                  deps=targets}
   end

   return self.targets.install
end

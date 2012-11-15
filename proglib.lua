local take = package.loaded.take

local function proglib(self, arg, shared)
   assert(type(arg.name) == 'string', 'name missing')
   assert(type(arg.src) == 'string' or type(arg.src) == 'table', 'src missing')

   local src = (type(arg.src) == 'string') and {arg.src} or arg.src
   local osrc = {}
   
   for _,name in ipairs(src) do
      if name:match('%.o$') then
         table.insert(osrc, name)
      else
         local lang
         local ext
         for _ext,_lang in pairs(self.lang) do
            if _lang:islang(name) then
               ext = _ext
               lang = _lang
               break
            end
         end
         if not lang then
            error(string.format('unable to process file <%s> (unknown language)', name))
         end
         local needs = arg.needs
         if shared and lang.sharedflagssupply then -- should be called ld? what about ldexeflagssupply?
            needs = take.table.imerge(arg.needs, {lang.sharedflagssupply})
         end
         self:target{name=take.paths.concat(take.dstdir, lang:outname(name)),
                     deps=take.table.imerge(lang:deps(name), arg.deps),
                     lang=ext,
                     flags=arg[ext .. 'flags'],
                     needs=needs,
                     includes=arg.includes,
                     defines=arg.defines,
                     build=function(target)
                              lang:compile{src=name,
                                           dst=target.name,
                                           flags=target.flags,
                                           includes=target.includes,
                                           defines=target.defines}
                           end}
         table.insert(osrc, take.paths.concat(take.dstdir, lang:outname(name)))
      end
   end

   local needs = arg.needs
   if shared and self.link.sharedflagssupply then -- should be called ld? what about ldexeflagssupply?
      needs = take.table.imerge(arg.needs, {self.link.sharedflagssupply})
   end

   local target = self:target{name=take.paths.concat(take.dstdir, self.link:outname(arg.name, shared)),
                              deps=osrc,
                              default=arg.default,
                              lang= shared and 'ld' or 'ldexe',
                              needs=needs,
                              flags=arg.ldflags,
                              includes=arg.includes, -- (1) first this is wrong (2) now that i use absolute paths for libraries this should be removed
                              libraries=arg.libraries,
                              build=function(target)
                                       self.link:compile{src=target.deps,
                                                         dst=target.name,
                                                         flags=target.flags,
                                                         includes=target.includes,
                                                         libraries=target.libraries,
                                                         shared=shared}
                                    end}

   if shared then
      target.supply = function(self)
                         if self.lang == 'ld' or self.lang == 'ldexe' then
                            self.libraries = take.table.imerge(self.libraries, {target.name})
                         else
                            self.includes = take.table.imerge(self.includes, arg.includes)
                         end
                      end
   end

   return target
end

function take.project.library(self, arg)
   return proglib(self, arg, true)
end

function take.project.program(self, arg)
   return proglib(self, arg)
end


local take = package.loaded.take

-- NOTE: we could apply needs on all deps, instead. check is this would be ok.

function take.project.processneeds(self, target, ext)
   if target.needs then
      assert(type(target.needs) == 'table', 'needs must be a table')
      for _,neededtarget in ipairs(target.needs) do
         neededtarget = self.targets[neededtarget]
         if neededtarget.provides then
            assert(type(neededtarget.provides) == 'function', 'provides must be a function')
            neededtarget:provides(target, ext)
         end
      end
   end
end

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
         self:target{name=take.paths.concat(take.dstdir, lang:outname(name)),
                     deps=take.table.imerge(lang:deps(name), arg.deps, arg.needs),
                     needs=arg.needs,
                     includes=arg.includes,
                     defines=arg.defines,
                     build=function(target)
                              self:processneeds(target)
                              lang:compile{src=name,
                                           dst=target.name,
                                           flags=arg[ext .. 'flags'],
                                           includes=target.includes,
                                           defines=target.defines}
                           end}
         table.insert(osrc, take.paths.concat(take.dstdir, lang:outname(name)))
      end
   end

   return self:target{name=take.paths.concat(take.dstdir, self.link:outname(arg.name, shared)),
                      deps=osrc,
                      needs=arg.needs,
                      flags=arg.ldflags,
                      includes=arg.includes,
                      libraries=arg.libraries,
                      build=function(target)
                               self:processneeds(target, 'ld')
                               self.link:compile{src=target.deps,
                                                 dst=target.name,
                                                 flags=target.flags,
                                                 includes=target.includes,
                                                 libraries=target.libraries,
                                                 shared=shared}
                            end,
                      provides=function(target, totarget, langname)
                                  if langname == 'ld' then
                                     totarget.includes = take.table.imerge(totarget.includes, {take.paths.dirname(target.name)})
                                     totarget.libraries = take.table.imerge(totarget.libraries, {self.link:basename(target.name, shared)})
                                  else
                                     totarget.includes = take.table.imerge(totarget.includes, arg.includes)
                                  end
                               end}
end

function take.project.library(self, arg)
   return proglib(self, arg, true)
end

function take.project.program(self, arg)
   return proglib(self, arg)
end


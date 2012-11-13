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
         self:target{name=take.paths.concat(take.dstdir, lang:outname(name)),
                     deps=take.table.imerge(lang:deps(name), arg.deps),
                     build=function(target)
                              lang:compile{src=name,
                                           dst=target.name,
                                           flags=arg[ext .. 'flags'],
                                           includes=arg.includes,
                                           defines=arg.defines}
                           end}
         table.insert(osrc, take.paths.concat(take.dstdir, lang:outname(name)))
      end
   end

   return self:target{name=take.paths.concat(take.dstdir, self.link:outname(arg.name, shared)),
                      deps=osrc,
                      build=function(target)
                               self.link:compile{src=target.deps,
                                                 dst=target.name,
                                                 flags=arg.ldflags,
                                                 shared=shared}
                            end}
end

function take.project.library(self, arg)
   return proglib(self, arg, true)
end

function take.project.program(self, arg)
   return proglib(self, arg)
end


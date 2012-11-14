local take = package.loaded.take

function take.project:findlibrary(arg)
   local names = arg.names or arg.name
   assert(names, 'missing name(s)')
   if type(names) == 'string' then
      names = {names}
   end

   local paths = arg.paths
   if jit.os == 'OSX' then
      paths = take.table.imerge(paths, {'/usr/lib', '/usr/local/lib', '/opt/local/lib'})
      if os.getenv('DYLD_LIBRARY_PATH') then
         for path in os.getenv('DYLD_LIBRARY_PATH'):gmatch('[^%;]+') do
            table.insert(paths, path)
         end
      end
   else
      paths = take.table.imerge(paths, {'/usr/lib', '/usr/local/lib'})
      if os.getenv('LD_LIBRARY_PATH') then
         for path in os.getenv('LD_LIBRARY_PATH'):gmatch('[^%;]+') do
            table.insert(paths, path)
         end
      end
   end

   for _,name in ipairs(names) do
      for _,path in ipairs(paths) do
         local libname = take.paths.concat(path, take.utils.basename2lib(name))
         if take.paths.exists(libname) then
            return self:target{name=libname,
                               provides=function(target, totarget, langname)
                                           if langname == 'ld' then
                                              totarget.libraries = take.table.imerge(totarget.libraries, {target.name})
                                           end
                                        end}
         end
      end
   end

end

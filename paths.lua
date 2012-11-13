local paths = {}
local os = require 'take.os'

local ffi = require 'ffi'
ffi.cdef[[
  char *getcwd(char *, size_t);
  void free(void*);
]]

function paths.cwd()
   local path_ = ffi.C.getcwd(nil, 0)
   local path = ffi.string(path_)
   ffi.C.free(path_)
   return path
end

function paths.split(path)
   local res = {}
   path = path:match('/$') and path or (path .. '/')
   path = path:gsub('/+', '/')
   local res = {}
   for sub in path:gmatch('([^/]*/)') do
      table.insert(res, sub)
   end
   local lst = #res
   if res[lst] ~= './' and res[lst] ~= '../' and res[lst] ~= '/' then
      res[lst] = res[lst]:match('[^/]+')
   end
   return res
end

function paths.reduce(path)
   local isstr
   if type(path) == 'string' then
      path = paths.split(path)
      isstr = true
   end

   local lst = #path
   if path[lst] == '.' and path[lst] == '..' then
      path[lst] = path[lst] .. '/'
   end

   local i = 1
   while i <= #path do
      if path[i] == './' then
         table.remove(path, i)
      elseif path[i] == '../' then
         if path[i-1] then
            if path[i-1] == '/' then -- root?
               table.remove(path, i) -- ignore it (we could also have raised an error)
            elseif path[i-1] == '../' then -- could not reduce it before?
               i = i + 1
            else
               table.remove(path, i)
               table.remove(path, i-1)
               i = i - 1
            end
         else
            i = i + 1
         end
      else
         i = i + 1
      end
   end

   local lst = #path
   if path[lst]:match('[^/]+/') then
      path[lst] = path[lst]:match('[^/]+')
   end

   if isstr then
      return table.concat(path)
   else
      return path
   end
end

function paths.concat(...)
   local path = paths.cwd()
   for i=1,select('#', ...) do
      if select(i, ...):match('^/') then
         path = select(i, ...)
      else
         path = path .. '/' .. select(i, ...)
      end
   end
   return paths.reduce(path)
end

function paths.mkdir(name)
   if not os.execute{cmd=string.format('mkdir -p %s', name), quiet=true} then
      error(string.format('unable to create directory <%s>', name))
   end
end

function paths.dirname(path)
   if not path:match('^/') then
      path = paths.cwd() .. '/' .. path
   end
   path = paths.reduce(paths.split(path))
   table.remove(path)
   path = paths.reduce(path)
   return table.concat(path)
end

function paths.basename(path)
   if not path:match('^/') then
      path = paths.cwd() .. '/' .. path
   end
   path = paths.reduce(paths.split(path))
   return table.remove(path)
end

return paths

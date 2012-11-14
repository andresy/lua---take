local take = package.loaded.take

take.utils = {}

function take.utils.basename2lib(name)
   if jit.os == 'Windows' then
      return name .. '.dll'
   elseif jit.os == 'OSX' then
      return 'lib' .. name .. '.dylib'
   else
      return 'lib' .. name .. '.so'
   end
end

function take.utils.basename2exe(name)
   if jit.os == 'Windows' then
      return str .. '.exe'
   else
      return str
   end      
end

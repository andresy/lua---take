local _os = os
local os = {}
setmetatable(os, {__index=_os})

local ffi = require 'ffi'

function os.exists(filename)
   local f = io.open(filename)
   if f then
      f:close()
      return true
   end
   return false
end

function os.execute(arg)
   arg = (type(arg) == 'string') and {cmd=arg} or arg
   
   local tmpmsg = os.tmpname()
   local tmperr = os.tmpname()

   local cmd = string.format('%s > %s 2> %s', arg.cmd, tmpmsg, tmperr)
   local success = _os.execute(cmd)
   if type(success) == 'number' then
      success = (success == 0)
   end
   
   local fmsg = io.open(tmpmsg)
   local msg = ''
   if fmsg then
      msg = fmsg:read('*all')
      fmsg:close()
   end

   local ferr = io.open(tmperr)
   local err = ''
   if ferr then
      err = ferr:read('*all')
      ferr:close()
   end

   os.remove(tmpmsg)
   os.remove(tmperr)

   if not arg.quiet then
      if msg:match('%S+') then
         print(msg)
      end
      if not success then
         error(err)
      end
   end

   return success, msg, err
end

ffi.cdef[[
  int chdir(const char *path);
]]

function os.chdir(path)
   if ffi.C.chdir(path) ~= 0 then
      error('unable to change directory')
   end
end

return os
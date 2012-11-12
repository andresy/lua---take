local _table = table
local table = {}
setmetatable(table, {__index=_table})

function table.imerge(...)
   local tbl = {}
   for i=1,select('#', ...) do
      local tblsrc = select(i, ...)
      if tblsrc then
         assert(type(tblsrc) == 'table', 'table expected')
         for _,v in ipairs(tblsrc) do
            table.insert(tbl, v)
         end
      end
   end
   return tbl
end

return table

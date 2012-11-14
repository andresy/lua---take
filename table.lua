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

   -- remove duplicate values
   local uniq = {}
   local k = 0
   for _,v in ipairs(tbl) do
      if not uniq[v] then
         k = k + 1
         uniq[v] = k
      end
   end

   tbl = {}
   for v,k in pairs(uniq) do
      tbl[k] = v
   end

   return tbl
end

return table

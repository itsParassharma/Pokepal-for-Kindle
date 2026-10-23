-- Small UTF-8 helpers shared by Lua 5.1 and the standalone edition.
local U={}
function U.chars(text)
 if type(text)~="string" then return nil end
 local out={};local i=1
 while i<=#text do
  local a=text:byte(i);local n,cp
  if a<128 then n=1;cp=a
  elseif a>=194 and a<=223 then n=2;cp=a-192
  elseif a>=224 and a<=239 then n=3;cp=a-224
  elseif a>=240 and a<=244 then n=4;cp=a-240
  else return nil end
  for j=1,n-1 do local b=text:byte(i+j);if not b or b<128 or b>191 then return nil end;cp=cp*64+b-128 end
  if (n==2 and cp<128) or (n==3 and cp<2048) or (n==4 and cp<65536)
   or cp>1114111 or (cp>=55296 and cp<=57343) then return nil end
  -- Save lines and labels cannot contain controls or invisible direction changes.
  if cp<32 or (cp>=127 and cp<=159) or cp==8232 or cp==8233
   or (cp>=8203 and cp<=8207) or (cp>=8234 and cp<=8238) or (cp>=8294 and cp<=8297) or cp==65279 then return nil end
  out[#out+1]=text:sub(i,i+n-1);i=i+n
 end
 return out
end
function U.valid(text,limit)
 local c=U.chars(text)
 return c~=nil and #c>0 and #c<=limit and text:match("^%S")~=nil and text:match("%S$")~=nil
end
function U.pop(text) local c=U.chars(text) or {};table.remove(c);return table.concat(c) end
function U.take(text,n) local c=U.chars(text) or {};return table.concat(c,"",1,math.min(n,#c)) end
return U

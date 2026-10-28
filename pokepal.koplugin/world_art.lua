-- Crystal field sprites, converted once by tools/import_classic.py.
local A={}
function A.trainer(v,bb,x,y,facing,step,role,outfit)
 local name=role or (outfit==1 and "ranger" or outfit==2 and "champion" or "chris")
 v:classic(bb,"trainer-"..name.."-"..facing.."-"..(step or 0),x,y,32)
end
function A.pokemon(v,bb,id,x,y,facing,step)
 v:classic(bb,id.."-walk-"..(facing or "down").."-"..(step or 0),x,y,36)
end
return A

-- Original map tiles and trainer pixels, drawn by both existing renderers.
local A={}
local trainers={
 down={"...######...","..########..",".##########.","..#......#..","..#.#..#.#..","...#....#...","....####....","..########..",".#.######.#.",".#.######.#.","...######...","...##..##...","...##..##...","..###..###.."},
 up={"...######...","..########..",".##########.","..########..","..########..","...######...","....####....","..##....##..",".#.#.##.#.#.",".#.#.##.#.#.","...######...","...##..##...","...##..##...","..###..###.."},
 right={"....#####...","...#######..","...########.","...##...#...","...##.#.#...","....#...##..",".....###....","...######...","...##..###..","...##..###..","...######...","....##.##...","....##.##...","....###.###."},
}
function A.trainer(v,bb,x,y,facing,step,nurse,white)
 local rows=trainers[facing=="left" and "right" or facing] or trainers.down
 v:rect(bb,x+4,y+3,18,23,white)
 for ry,row in ipairs(rows) do
  if ry>=12 and step==1 then row=ry==14 and ".###....###." or ry==13 and "..##....##.." or row end
  if facing=="left" then row=row:reverse() end
  for rx=1,#row do if row:sub(rx,rx)=="#" then v:rect(bb,x+(rx-1)*2,y+(ry-1)*2,2,2) end end
 end
 if nurse then v:rect(bb,x+8,y+2,8,4,white);v:rect(bb,x+11,y,2,8,white) end
end
function A.tile(v,bb,t,x,y,colors)
 local white,gray,light=colors[1],colors[2],colors[3]
 v:rect(bb,x,y,44,44,white)
 if t=="T" then
  v:rect(bb,x+17,y+32,10,10);v:rect(bb,x+20,y+32,4,8,white)
  for _,r in ipairs({{11,2,22,5},{6,7,32,8},{2,15,40,14},{6,29,32,6}}) do v:rect(bb,x+r[1],y+r[2],r[3],r[4]) end
  v:rect(bb,x+11,y+8,18,3,gray);v:rect(bb,x+8,y+18,8,3,gray);v:rect(bb,x+26,y+24,9,3,gray)
 elseif t=="R" then
  v:rect(bb,x,y+2,44,42);v:rect(bb,x,y+4,44,37,gray)
  for r=0,3 do v:rect(bb,x,y+8+r*9,44,2);for c=0,2 do v:rect(bb,x+5+c*16+(r%2)*4,y+3+r*9,2,6) end end
 elseif t=="W" then
  v:rect(bb,x,y,44,44,light);v:rect(bb,x,y+40,44,4)
  v:outline(bb,x+8,y+9,28,23);v:rect(bb,x+21,y+9,2,23);v:rect(bb,x+8,y+20,28,2)
 elseif t=="H" or t=="B" then
  v:rect(bb,x,y,44,44,light);v:rect(bb,x+8,y+5,28,39);v:rect(bb,x+11,y+8,22,36,white)
  if t=="H" then v:rect(bb,x+20,y+14,5,16);v:rect(bb,x+15,y+19,15,5)
  else v.art.icon(v,bb,"boot",x+13,y+13,2) end
 elseif t=="~" then
  v:rect(bb,x,y,44,44,light)
  for r=0,2 do v:rect(bb,x+5+(r%2)*6,y+8+r*13,23,2,gray);v:rect(bb,x+28,y+5+r*13,8,2,gray) end
 elseif t=="C" then
  v:rect(bb,x+1,y+3,42,34,gray);v:outline(bb,x+1,y+3,42,34);v:rect(bb,x+3,y+8,38,2,white);v:rect(bb,x+3,y+29,38,2)
 elseif t=="=" then
  v:rect(bb,x,y,44,44,light)
  v:rect(bb,x+8,y+11,3,2,gray);v:rect(bb,x+31,y+32,3,2,gray)
 elseif t=="," then
  for _,p in ipairs({{7,9},{27,8},{15,29},{34,30}}) do
   v:rect(bb,x+p[1],y+p[2],2,7,gray);v:rect(bb,x+p[1]-3,y+p[2]+2,2,3,gray);v:rect(bb,x+p[1]+3,y+p[2]+2,2,3,gray)
  end
 else
  v:rect(bb,x+12,y+31,2,2,light);v:rect(bb,x+34,y+10,2,2,light)
 end
 if t=="D" or t=="N" then A.trainer(v,bb,x+10,y+7,"down",0,t=="N",white) end
end
return A

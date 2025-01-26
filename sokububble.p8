pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
level_defs={{
 name="bubbles",
 mapdef={27,0,7,7},
 ini_bubble=0
},{
 name="targets",
 mapdef={33,0,7,7},
 ini_bubble=0
},{
 name="intro 1",
 mapdef={0,0,8,8},
 ini_bubble=0
},{
 name="intro 2",
 mapdef={7,0,8,8},
 ini_bubble=0
},{
 name="corners",
 mapdef={14,0,8,8},
 ini_bubble=0
},{
 name="tiny",
 mapdef={21,0,7,7},
 ini_bubble=0
}}

--sprite flags
flag_player=0
flag_wall=1
flag_box=2
flag_tgt=3
flag_bub=4

colors={9,8,3,1}
colors[0]=0

function delta_rot(r1,r2)
 local d=r2-r1
 if d>180 then
  d-=360
 elseif d<=-180 then
  d+=360
 end
 return d
end

function box_color(si)
 return si\16-3
end

function tgt_color(si)
 local col=si%16
 if si==77 or col==8 then
  return -1
 end
 if col==5 then
  return si\16-3
 end
 return col-8
end

function bub_color(si)
 local col=si%16
 if col<=4 then
  return col
 else
  return si\16-3
 end
end

function box_at(x,y,state)
 for box in all(state.boxes) do
  if box:is_at(x,y) then
   return box
  end
 end
 return nil
end

--wrap coroutine with a name to
--facilitate debugging crashes
function cowrap(
 name,coroutine,...
)
 return {
  name=name,
  coroutine=cocreate(coroutine),
  args={...}
 }
end

--returns true when routine died
function coinvoke(wrapped_cr)
 local cr=wrapped_cr.coroutine
 if not coresume(
  cr,
  wrapped_cr.args
 ) then
  printh(
   "coroutine "
   ..wrapped_cr.name
   .." crashed"
  )
  while true do end
 end
 return costatus(cr)=="dead"
end

function no_draw()
end

function wait(steps)
 for i=1,steps do
  yield()
 end
end

function printbig(s,x0,y0,c)
 print(s,x0,y0,c)
 for y=4,0,-1 do
  local yd=y0+y*2
  for x=#s*4-1,0,-1 do
   local xd=x0+x*2
   rectfill(
    xd,yd,xd+1,yd+1,
    pget(x0+x,y0+y)
   )
  end
 end
end

function draw_dialog(txt,y)
 local hw=#txt*4+2
 rectfill(64-hw,y,63+hw,y+17,1)
 printbig(txt,67-hw,y+4,7)
end

function drop(obj,ymax,bounce)
 local a=0.03
 local v=0

 while true do
  v+=a
  obj.y+=v
  if obj.y>ymax then
   obj.y=ymax
   if v>0.5 and bounce then
    v=-v*0.5
    sfx(1)
   else
    return
   end
  end

  yield()
 end
end

function show_dialog_anim(args)
 local dialog=args[1]
 drop(dialog,54,true)
 wait(60)
 drop(dialog,128)
end

function show_dialog(txt)
 local dialog={y=-32}
 local anim=cowrap(
  "show_dialog",
  show_dialog_anim,
  dialog
 )
 anim.draw=function()
  draw_dialog(txt,dialog.y)
 end
 return anim
end

function level_done_anim(args)
 local dialog=args[1]
 wait(15)
 dialog.show=true
 sfx(4)
 wait(30)
 start_level(state.level.idx+1)
 yield() --allow anim swap
end

function animate_level_done()
 local dialog={show=false}
 local anim=cowrap(
  "level_done",
  level_done_anim,
  dialog
 )
 anim.draw=function()
  if dialog.show then
   draw_dialog("solved!",58)
  end
 end
 return anim
end

function retry_anim()
 sfx(2)
 wait(30)
 local idx=state.level.idx
 if state.view_all then
  --start completely afresh
  idx=1
 end
 start_level(idx)
 yield() --allow anim swap
end

function animate_retry()
 local anim=cowrap(
  "retry",retry_anim
 )
 anim.draw=no_draw
 return anim
end
-->8
box={}
function box:new(x,y,c)
 local o=setmetatable({},self)
 self.__index=self

 o.sx=x*8
 o.sy=y*8
 o.c=c

 return o
end

function box:is_at(x,y)
 return (
  self.sx==x*8 and self.sy==y*8
 )
end

function box:on_tgt(level)
 if (
  self.sx%8!=0 or self.sy%8!=0
 ) then
  return false
 end
 local tgt=level:tgt_at(
  self.sx\8,self.sy\8
 )
 return tgt==-1 or tgt==self.c
end

function box:_push(mov)
 self.sx+=mov.dx
 self.sy+=mov.dy
end
-->8
--player

player={}
function player:new(x,y)
 local o=setmetatable({},self)
 self.__index=self

 o.sx=x*8
 o.sy=y*8
 o.sd=0
 o.dx=0
 o.dy=0
 o.rot=180
 o.tgt_rot=nil
 o.retry_cnt=0

 return o
end

function player:_rotate(state)
 local drot=delta_rot(
  self.rot,self.tgt_rot
 )
 drot=max(min(drot,10),-10)

 self.rot=(self.rot+drot)%360
 if abs(drot)<1 then
  self.tgt_rot=nil
 end
end

function player:_forward(mov)
 self.sx+=mov.dx
 self.sy+=mov.dy
 self.sd=(
  self.sd+3+mov.dx+mov.dy
 )%3
end

function player:_backward(mov)
 self.sx-=mov.dx
 self.sy-=mov.dy
 self.sd=(
  self.sd+3-mov.dx-mov.dy
 )%3
end

function blocked_move_anim(args)
 local mov=args[1]
 local plyr=args[2]

 for i=1,mov.blocked do
  plyr:_forward(mov)
  yield()
 end

 sfx(1)
 yield()

 for i=1,mov.blocked do
  plyr:_backward(mov)
  yield()
 end
end

function plain_move_anim(args)
 local mov=args[1]
 local plyr=args[2]

 for i=1,8 do
  plyr:_forward(mov)
  if i!=8 then yield() end
 end
end

function push_move_anim(args)
 local mov=args[1]
 local plyr=args[2]

 local start=1
 if (
  plyr.sx%8!=0 or plyr.sy%8!=0
 ) then
  --continuing prev push move
  start=3
 end

 for i=start,10 do
  plyr:_forward(mov)
  if i>2 then
   mov.push_box:_push(mov)
  end
  if i!=10 then yield() end
 end

 if (
  plyr.movq!=nil
  and plyr.movq.blocked==0
  and plyr.movq.rot==plyr.rot
 ) then
  --continue into next move
  plyr:_start_queued_move(state)
  yield() --allow anim swap
 else
  --retreat after placing box
  for i=1,2 do
   plyr:_backward(mov)
   yield()
  end
 end
end

function player:_move(state)
 if coinvoke(self.mov.anim) then
  self.mov=nil
 end

 if (
  self.sx%8==0 and self.sy%8==0
 ) then
  local bub=state.level:bubble(
   self.sx\8,self.sy\8
  )
  if bub!=nil then
   state.bubble=bub
  end
 end
end

--checks if move is blocked
--if so, returns num pixels
--that player can move. returns
--zero otherwise
function player:_is_blocked(
 mov,state
)
 local x1=mov.tgt_x
 local y1=mov.tgt_y

 local lvl=state.level
 local ws=lvl:wall_size(x1,y1)
 if ws!=0 then
  return 5-ws\2
 end

 local box=box_at(x1,y1,state)
 if (
  box==nil
  and self.mov!=nil
  and self.mov.rot==mov.rot
 ) then
  --pushed box is not (always)
  --bound by box_at
  box=self.mov.push_box
 end

 if box!=nil then
  if box.c!=state.bubble then
   --cannot move this box color
   return 2
  end
  local x2=x1+mov.dx
  local y2=y1+mov.dy
  if (
   lvl:is_wall(x2,y2)
   or box_at(x2,y2,state)!=nil
  ) then
   --no room to push box
   return 2
  end
 end

 return 0
end

function player:_check_move(
 mov,state
)
 local x,y
 if self.mov!=nil then
  x=self.mov.tgt_x
  y=self.mov.tgt_y
 else
  x=self.sx\8
  y=self.sy\8
 end

 local x1=x+mov.dx
 local y1=y+mov.dy
 mov.tgt_x=x1
 mov.tgt_y=y1

 mov.blocked=self:_is_blocked(
  mov,state
 )
 if mov.blocked!=0 then
  mov.tgt_x=x
  mov.tgt_y=y
 end

 return mov
end

function player:_start_queued_move(
 state
)
 assert(self.movq!=nil)
 local mov=self.movq
 self.movq=nil

 mov.push_box=box_at(
  mov.tgt_x,mov.tgt_y,state
 )

 if mov.blocked!=0 then
  printh("starting blocked anim")
  mov.anim=cowrap(
   "blocked_move",
   blocked_move_anim,
   mov,self
  )
 elseif mov.push_box!=nil then
  printh("starting push anim")
  mov.anim=cowrap(
   "push_move",
   push_move_anim,
   mov,self
  )
 else
  printh("starting move anim")
  mov.anim=cowrap(
   "plain_move",
   plain_move_anim,
   mov,self
  )
 end

 self.mov=mov
 state.view_all=false

 if mov.rot!=self.rot then
  if (
   mov.rot%180==self.rot%180
  ) then
   --skip 180-turn
   self.rot=mov.rot
  else
   self.tgt_rot=mov.rot
  end
 end
end

function player:update(state)
 --allow player to queue a move
 local req_mov=nil
 if btnp(➡️) then
  req_mov={rot=90,dx=1,dy=0}
 elseif btnp(⬅️) then
  req_mov={rot=270,dx=-1,dy=0}
 elseif btnp(⬆️) then
  req_mov={rot=0,dx=0,dy=-1}
 elseif btnp(⬇️) then
  req_mov={rot=180,dx=0,dy=1}
 end
 if req_mov!=nil then
  self.movq=self:_check_move(
   req_mov,state
  )
 end

 --handle level retry
 if btn(❎) then
  self.retry_cnt+=1
  if self.retry_cnt>30 then
   state.anim=animate_retry()
  end
  return
 else
  self.retry_cnt=0
 end

 if (
  self.movq!=nil
  and self.mov==nil
 ) then
  self:_start_queued_move(state)
 end

 if self.tgt_rot then
  self:_rotate()
 elseif self.mov then
  self:_move(state)
 end
end

function player:draw(state)
 local lvl=state.level
 local subrot=self.rot%90
 local row=(self.rot%180)\90
 local si
 if subrot==0 then
  si=16+row*16+self.sd
 else
  local d=(subrot+15)\30
  if d==0 or d==3 then
   si=16+((row+d\3)%2)*16+self.sd
  else
   si=16+row*16+2+d
  end
 end

 local idx=state.bubble
 if self.retry_cnt>0 then
  idx=self.retry_cnt\2%#colors
 end
 pal(1,colors[idx])

 spr(
  si,
  lvl.sx0+self.sx,
  lvl.sy0+self.sy
 )
 pal()
end

-->8
--level

level={}
function level:new(
 lvl_index
)
 local o=setmetatable({},self)
 self.__index=self

	local lvl_def=level_defs[
	 lvl_index
	]
	o.idx=lvl_index
	o.name=lvl_def.name
 o.x0=lvl_def.mapdef[1]
 o.y0=lvl_def.mapdef[2]
 o.ncols=lvl_def.mapdef[3]
 o.nrows=lvl_def.mapdef[4]
 o.sx0=64-4*o.ncols
 o.sy0=64-4*o.nrows
 o.ini_bubble=lvl_def.ini_bubble

 return o
end

function level:_sprite(mx,my)
 return mget(
  self.x0+mx,self.y0+my
 )
end

function level:_cellhasflag(
 mx,my,flag
)
 return fget(
  self:_sprite(mx,my),flag
 )
end

function level:is_wall(x,y)
 return self:_cellhasflag(
  x,y,flag_wall
 )
end

function level:wall_size(x,y)
 local si=self:_sprite(x,y)
 if si==48 then
  return 8
 elseif si==49 then
  return 6
 else
  return 0
 end
end

function level:tgt_at(x,y)
 local si=self:_sprite(x,y)
 if fget(si,flag_tgt) then
  return tgt_color(si)
 end
 return nil
end

function level:bubble(x,y)
 local si=self:_sprite(x,y)
 if fget(si,flag_bub) then
  return bub_color(si)
 end
 return nil
end

function level:update_state(s)
 s.level=self
 s.bubble=self.ini_bubble
 s.view_all=true
 s.boxes={}
 s.box_cnt=0
 s.push_box=nil
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local si=self:_sprite(x,y)
   if fget(si,flag_player) then
    s.player=player:new(x,y)
   elseif fget(si,flag_box) then
    add(
     s.boxes,
     box:new(x,y,box_color(si))
    )
   end
  end
 end

 return s
end

function level:_draw_fixed(state)
 for x=0,self.ncols-1 do
  for y=0,self.nrows-1 do
   local si=self:_sprite(x,y)
   local dsi=0
   if fget(si,flag_wall) then
    dsi=si
   elseif fget(si,flag_tgt) then
    local c=tgt_color(si)
    local viz=(
     state.view_all
     or state.bubble==c
     or c==-1
    )
    if self:_box_on_tgt_at(
     x,y,state
    ) then
     dsi=viz and c*16+62 or 109
    elseif viz then
     dsi=si
    elseif fget(si,flag_bub) then
     c=bub_color(si)
     dsi=c*16+45
    else
     dsi=93
    end
   elseif fget(si,flag_bub) then
    local c=bub_color(si)
    dsi=c*16+54
   end
   if dsi!=0 then
    spr(
     dsi,
     self.sx0+x*8,
     self.sy0+y*8
    )
   end
  end
 end
end

function level:_draw_boxes(state)
 for box in all(state.boxes) do
  local si=125
  if (
   state.view_all
   or state.bubble==box.c
  ) then
   si=48+box.c*16
  end
  spr(
   si,
   self.sx0+box.sx,
   self.sy0+box.sy
  )
 end
end

function level:draw(state)
 pal(15,0)
 rectfill(
  self.sx0,
  self.sy0,
  self.sx0+8*self.ncols-1,
  self.sy0+8*self.nrows-1,
  5
 )
	self:_draw_fixed(state)
	self:_draw_boxes(state)
end

function level:_box_on_tgt_at(
 x,y,state
)
 for box in all(state.boxes) do
  if (
   box:is_at(x,y)
   and box:on_tgt(self)
  ) then
   return true
  end
 end

 return false
end

function level:is_done(state)
 local old_cnt=state.box_cnt
 state.box_cnt=0

 for box in all(state.boxes) do
  if box:on_tgt(self) then
   state.box_cnt+=1
  end
 end

 if state.box_cnt>old_cnt then
  sfx(3)
 end

 return state.box_cnt==#state.boxes
end

-->8
--main

function start_level(idx)
 local lvl=level:new(idx)
 state=lvl:update_state({})
 state.anim=show_dialog(
  lvl.name
 )
end

function _init()
 start_level(1)
end

function _draw()
 cls()
 state.level:draw(state)
 state.player:draw(state)

 if state.anim!=nil then
  state.anim.draw()
 end
end

function _update60()
 if state.anim then
  if coinvoke(state.anim) then
   state.anim=nil
  end
 else
  state.player:update(state)

  if state.level:is_done(state) then
   state.anim=animate_level_done()
  end
 end
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000040000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04111140041111400211112000411100002411000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04111140021111200411114002111110041111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02165120041651400416514004165114411651100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04155140041551400215512041155140011551140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04111140021111200411114001111120011111400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02111120041111400411114000111400001142000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000004000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000040000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04424420042442400244244000114200001114000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01111110011111100111111001111140011111200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01165110011651100116511001165114411651400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01155110011551100115511041155110041551140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01111110011111100111111004111110021111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04424420042442400244244000241100004111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000004000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6666666f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6555555f009999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6555555f094444200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6555555f094444200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6555555f094444200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6555555f094444200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6555555f002222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009990099900000000
00aaaa00099999900999999009999990099999900990099000000000044004400770077009900990088008800330033001100110077007709990099900000000
0a999940090000900900009009000090090000900900009000099000040990400709907009099090080990800309903001099010070000709900009900000000
0a9999400909909009088090090330900901109000000000009a9900009a9900009a9900009a9900009a9900009a9900009a9900000000000000000000000000
0a999940090990900908809009033090090110900000000000999900009999000099990000999900009999000099990000999900000000000000000000000000
0a999940090000900900009009000090090000900900009000099000040990400709907009099090080990800309903001099010070000709900009900000000
00444400099999900999999009999990099999900990099000000000044004400770077009900990088008800330033001100110077007709990099900000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009990099900000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008880088800000000
00eeee00088888800888888008888880088888800880088000000000044004400770077009900990088008800330033001100110044004408880088800000000
0e888820080000800800008008000080080000800800008000088000040880400708807009088090080880800308803001088010040000408800008800000000
0e888820080990800808808008033080080110800000000000898800008988000089880000898800008988000089880000898800000000000000000000000000
0e888820080990800808808008033080080110800000000000888800008888000088880000888800008888000088880000888800000000000000000000000000
0e888820080000800800008008000080080000800800008000088000040880400708807009088090080880800308803001088010040000408800008800000000
00222200088888800888888008888880088888800880088000000000044004400770077009900990088008800330033001100110044004408880088800000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008880088800000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444004443330033300000000
00bbbb00033333300333333003333330033333300330033000000000044004400770077009900990088008800330033001100110444004443330033300000000
0b333310030000300300003003000030030000300300003000033000040330400703307009033090080330800303303001033010440000443300003300000000
0b3333100309903003088030030330300301103000000000003b3300003b3300003b3300003b3300003b3300003b3300003b3300000000000000000000000000
0b333310030990300308803003033030030110300000000000333300003333000033330000333300003333000033330000333300000000000000000000000000
0b333310030000300300003003000030030000300300003000033000040330400703307009033090080330800303303001033010440000443300003300000000
00111100033333300333333003333330033333300330033000000000044004400770077009900990088008800330033001100110444004443330033300000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444004443330033300000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110011100000000
00dddd00011111100111111001111110011111100110011000000000044004400770077009900990088008800330033001100110009999001110011100000000
0d1111f0010000100100001001000010010000100100001000011000040110400701107009011090080110800301103001011010094444201100001100000000
0d1111f00109901001088010010330100101101000000000001d1100001d1100001d1100001d1100001d1100001d1100001d1100094444200000000000000000
0d1111f0010990100108801001033010010110100000000000111100001111000011110000111100001111000011110000111100094444200000000000000000
0d1111f0010000100100001001000010010000100100001000011000040110400701107009011090080110800301103001011010094444201100001100000000
00ffff00011111100111111001111110011111100110011000000000044004400770077009900990088008800330033001100110002222001110011100000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110011100000000
__gff__
0000000000000000000000000000000001010100000000000000000000000000010101000000000000000000000000000202000000000000000000000000000004141414140810181818181818080800041414141408101818181818180808000414141414081018181818181808080004141414140810181818181818020800
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
3030303030303030303030303030303030303030303030303030303030303030303030303030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
301075000000003010000000000030550000300065301000000000304d6000004d3066000055463000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3000400000504530000000000000300010600000003000600040003000660046403045600040003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3000006676000030000050006031303000567640003000506600563000001000003000001000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
300000564600003000006000000030005066460030300070004d4d3070760056003000700050653000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
306570000060003000005300655530000000700000300000764d48304d0000504d3076750000563000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3000000000550030560031005565304500300000753030303030303030303030303030303030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3030303030303030303030303030303030303030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001a05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001400001c05018050100501005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000295502d550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c72026730307403075000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

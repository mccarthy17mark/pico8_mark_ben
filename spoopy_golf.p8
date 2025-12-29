pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- spoopy (aka fun-scary) minigolf

--Class def'ns here

--Note to self: Screen is 16*16 tiles... 128*128 px
-- tiles are 8px*8px
-- the various draw shape functions (circ(),line()) are in terms of global map pixels (g)
-- for angles, 0 is right, 0.25 is up, sin is actually -sin: down is pos up is neg
 -- atan2(1,0) is right, and returns 0. atan2(0,-1) is up and returns 0.25, etc

vec2d = {}
vec2d.__index = vec2d

function vec2d.new(x,y)
 local self = setmetatable({},vec2d)
 self.x = x
 self.y = y
 return self
end

-- this makes vec2d(1,2) the same as vec2d.new(1,2)
setmetatable(vec2d, {__call = vec2d.new})

-- add two vectors
function vec2d.__add(a,b)
 return vec2d(a.x + b.x, a.y + b.y)
end

-- subtract two vectors
function vec2d.__sub(a,b)
 return vec2d(a.x - b.x, a.y - b.y)
end

-- multiply vector and scalar
function vec2d.__mul(a,b)
 return vec2d(a.x * b, a.y * b)
end

-- divide vector by scalar
function vec2d.__div(a,b)
 return vec2d(a.x / b, a.y / b)
end

-- Check if two vectors are equal
function vec2d.__eq(a,b)
 return (a.x == b.x and a.y == b.y)
end

-- negate a vector (unary minus)
function vec2d.__unm(a)
 return vec2d(-a.x, -a.y)
end

function vec2d.rotate(angle, pivot)
 -- angle is scalar, pivot is vec2d
 -- functions like this ought to not modify the original vector. If you want it modified, do:
  -- vec = vec.rotate(angle,pivot)
 local new_vec = self - pivot
 new_vec.x = new_vec.x*cos(angle) - new_vec.y*sin(angle)
 new_vec.y = new_vec.x*sin(angle) + new_vec.y*cos(angle)
 return new_vec + pivot
end

-- do we really need this?
function table_to_string(table)
 local str = ""
 for k,v in pairs(table) do
  str+=k.."="..v..", "
 end
 return str
end

function vec2d.to_string()
 return "("..self.x..","..self.y..")"
end

function vec2d.magnitude()
 return sqrt(self.x^2 + self.y^2)
end

function vec2d.angle()
 return atan2(self.x,self.y)
end

function vec2d.reflect(normal)
 -- 
 local angle_diff = normal.angle() - self.angle()
 if angle_diff < -0.5 then
  angle_diff += 1
 elseif angle_diff >0.5 then
  angle_diff -= 1
 end

 return self.rotate(2*angle_diff, vec2d(0,0))
end

box2d = {}
box2d.__index = box2d

function box2d.new(x,y,w,h)
 local self = setmetatable({},box2d)
 self.x = x
 self.y = y
 self.w = w
 self.h = h
 return self
end

setmetatable(box2d, {__call = box2d.new})

function box2d.contains(point)
 -- the edges of the box are (not?) included in the box
 if point.x >= self.x and point.x <= self.x+self.w and point.y >= self.y and point.y <= self.y + self.h then
  return true
 end
 return false
end

function box2d.centre()
 return vec2d((self.x+self.w)/2,(self.y+self.h)/2)
end

-->8
-- Utility functions here

-- The location of the camera, in pixels, relative to the global map
g_camera = vec2d(0,0)

-- s is a pixel location relative to a sprite
-- ss is a pixel location relative to the spritesheet
-- g is a pixel location relative to the global map
-- c is a pixel location relative to the camera
-- k refers to sprite number
-- everything with a 't' in it is a location in units of tiles

function s2ss(sprite_k, s)
 -- local row = flr(sprite_k / 16) -- starting at zero
 -- local column = sprite_k % 16 -- starting at zero
 -- return vec2d(s.x+column*8, s.y+row*8)

 -- this is marginally more optimized compared to above
 return vec2d(s.x+(sprite_k%16)*8,s.y+(flr(sprite_k / 16))*8)
end

function s2colour(sprite_k, s)
 local ss = s2ss(sprite_k, s)
 return sget(ss.x, ss.y)
end

function g2c(g)
 return g - g_camera
end

function c2g(c)
 return c + g_camera
end

function g2gt(g)
 return vec2d(flr(g.x/8), flr(g.y/8))
end

function gt2k(gt)
 return mget(gt.x, gt.y)
end

function g2k(g)
 return mget(flr(g.x/8),flr(g.y/8)) --same as gt2k(g2gt(g)) but fewer calls
end

function k2ss(k)
 return vec2d((k%16)*8,flr(k/16)*8)
end

function g2s(g)
 return vec2d(g.x%8,g.y%8)
end

function g2ss(g)
 local k = g2k(g)
 local s = g2s(g)
 return s2ss(k,s)
end

-->8

collision_colour = 5

ball = {g_pos=vec2d(64, 64), vel=vec2d(0,0)}

-- normals are in the following format:
-- key=sspx.to_string()
-- val=normal_dir (angle ranging 0-1, right=0, increasing counter-clockwise)
normals = {}

holes = {}
holes[1] = {gt_ball = vec2d(1,1), gt_cam = vec2d(0,0)}
holes[2] = {gt_ball = vec2d(19.5,5.5), gt_cam = vec2d(16,0)}

friction = 1 --todo check what's reasonable, let it be tile dependent (make a friction_k table)

function create_normals_for_circle(is_convex, outer_box, inner_box)
 local centre = outer_box.centre

 local multiplier
 if (is_convex) multiplier = 1 multiplier= -1

 for y = outer_box.y, outer_box.y + outer_box.h do
  for x = outer_box.x, outer_box.x + outer_box.w do
   local ipoint = vec2d(x,y)
   if not inner_box.contains(ipoint) then
    if sget(x,y) == collision_colour then
     local normal = atan2(multiplier*(x-centre.x),multiplier*(y-centre.y))
     add(normals,normal,ipoint.to_string())
    end
   end
  end
 end
end

function create_parallel_normals_for_single_sprite(k, angle)
 local top_left = k2ss(k)
 for y = top_left.y, top_left.y + 7 do
  for x = top_left.x, top_left.x + 7 do
   local point = vec2d(x,y)
   add(normals,angle,point.to_string())
  end
 end
end

function create_normals()
 -- the convex circle
 local outer_box = box2d(64,0,32,32)
 local inner_box = box2d(72,8,16,16)
 --local top_left_outer_box = vec2d(64,0)
 --local top_left_inner_box = vec2d(72,8)
 --local bottom_right_inner_box = vec2d(87,23)
 --local bottom_right_outer_box = vec2d(95,31)
 create_normals_for_circle(true, outer_box, inner_box)

 -- the concave circle
 outer_box = box2d(96,0,32,32)
 inner_box = box2d(104,8,16,16)
 -- local top_left_outer_box = vec2d(96,0)
 -- local top_left_inner_box = vec2d(104,8)
 -- local bottom_right_inner_box = vec2d(119,23)
 -- local bottom_right_outer_box = vec2d(127,31)
 create_normals_for_circle(false, outer_box, inner_box)

 create_parallel_normals_for_single_sprite(20,0.125)
 create_parallel_normals_for_single_sprite(21,0.375)
 create_parallel_normals_for_single_sprite(22,0.625)
 create_parallel_normals_for_single_sprite(23,0.875)

 create_parallel_normals_for_single_sprite(36,0)
 create_parallel_normals_for_single_sprite(37,0.25)
 create_parallel_normals_for_single_sprite(38,0.5)
 create_parallel_normals_for_single_sprite(39,0.75)

 create_parallel_normals_for_single_sprite(52,0)
 create_parallel_normals_for_single_sprite(53,0.25)
 create_parallel_normals_for_single_sprite(54,0.5)
 create_parallel_normals_for_single_sprite(55,0.75)
end

function read_input()
	local speed = 1
 if btnp(5) then
  ball.vel.x = speed*cos(shot_angle)
  ball.vel.y = speed*sin(shot_angle)
  ball_stopped = false
  shot_counter += 1
 elseif btn(0) then
  shot_angle -= 0.025
 elseif btn(1) then
  shot_angle += 0.025
 end

 -- prob pointless, but prevents edge-case overflow
 if shot_angle < -0.5 then
  shot_angle += 1
 elseif shot_angle > 0.5 then
  shot_angle -= 1
 end
end

function handle_tile_collision(k)
 if k == 18 then
  --we got it in a hole
 end
 return
end

function find_collision_pix(cur_pix, next_pix)
 if(cur_pix == next_pix) then
  return false, cur_pix
 end

 -- plan: start at cur_ball_pos and iterate pixel by pixel toward next_ball_pos
 -- When an offending pixel is first touched, that's our collide point
 -- do we can iterate our line by in(dec)rementing our x or y based on comparing to ratio=(next-cur).y/(next-cur).x
 -- Once we find collide point, we can ask the sprite (or sprite family) what the normal dir is
 -- Using the normal, we find the new direction via reflection
 -- We set this to the ball's new direction (prob no need to account for distance b/w collide point and cur, but it's doable)

 -- cur dir = atan2(next-cur .x, next-cur .y)
 -- = atan2(ball.dx,ball.dy)
 -- which is monotonic to ball.dy/ball.dx, except there's a div by zero

 -- This gives an "angle" from [0,1] of our ball
 local vel_dir = ball.vel.angle() --atan2(ball.vel.x, ball.vel.y)

  --this might be overkill
 local xdir, ydir
 if (ball.vel.x == 0) xdir=0 xdir=sgn(ball.vel.x)
 if (ball.vel.y == 0) ydir=0 ydir=sgn(ball.vel.y)

 -- make a single pixel move
 local check_pix = cur_pix
 --local last_check_pix = cur_pix
 if abs(ball.dx) > abs(ball.dy) then
  check_pix.x += xdir
 else
  check_pix.y += ydir
 end

 -- this is a debug variable
 local i=0

 while true do
  local k = g2k(check_pix)
  handle_tile_collision(k)

  -- check if the next pix is a collision space?
  normal_vec = normals[g2ss(check_pix).to_string()]
  if (normal_vec != nil) then
   -- we've collided
   ball.vel.reflect(normal_vec)
   return true, check_pix
  end

  -- make next move, only in the 4 cardinal directions, no diagonals
  -- compare the direction of the new vec to the original vec
  -- if the new vector is in more of a y direction, we want to move in the y direction which will bring it closer to the original vec
  -- we want to evaluate abs(cos(new_dir.angle)) > abs(cos(vel_dir.angle))
  -- but that's a lot of math. can just do abs(new_dir.y/new_dir.x) < abs(vel_dir.y/vel_dir.x)
  -- except then we divide by zero a bunch... we need to handle the .x=0 case, which is probably not worth it.
  local new_dir = next_pix - check_pix
  if abs(cos(new_dir.angle)) > abs(cos(vel_dir.angle)) then
   check_pix.x += xdir
  else
   check_pix.y += ydir
  end
  --check_pix_k = mget(check_pix.x/8, check_pix.y/8)
  if check_pix == next_pix then
   return false, check_pix
  end

 end

 if i>100 then
  assert(1==0,"check_pix="..check_pix.to_string()..", next_pix="..next_pix.to_string())
 else
  i+=1
 end

end

function handle_collisions(cur_pix, next_pix)
 --local next_pix_local = vec2d(next_pix.x % 8, next_pix.y % 8)

 local collided, coll_pix = find_collision_pix(cur_pix, next_pix)

 --if not collided, ignore coll_pix
 if not collided then
  return
 end

 -- apply friction
 local dist = (coll_pix - cur_pix).magnitude
 local vel_mag_1 = ball.vel.magnitude
 local interim_val = vel_mag_1^2 - 2*friction*dist
 -- will this ever happen? shouldn't next_pix being farther than cur_pix guarantee our updated vel > 0 ? 
 if interim_val < 0 then 
  ball_stopped = true
  ball.vel = {x=0, y=0}
  ball.pos = coll_pix
 else
  local vel_mag_2 = sqrt(interim_val)
  ball.vel *= vel_mag_2 / vel_mag_1
 end 

end

function collision(cur_pos, next_pos)
 -- have to round to see where it actually is
 local next_pix = vec2d(flr(next_pos.x*8), flr(next_pos.y*8))
 local next_pix_local = vec2d(next_pix.x % 8, next_pix.y % 8)

 next_pix_col = get_sprite_colour(next_pos.k, next_pix_local)

 -- If the next location is not a collision space, then there is no collision
 if next_pix_col == 5 then return end

 -- plan: start at cur_ball_pos and iterate pixel by pixel toward next_ball_pos
 -- When an offending pixel is first touched, that's our collide point
 -- do we can iterate our line by in(dec)rementing our x or y based on comparing to ratio=(next-cur).y/(next-cur).x
 -- Once we find collide point, we can ask the sprite (or sprite family) what the normal dir is
 -- Using the normal, we find the new direction via reflection
 -- We set this to the ball's new direction (prob no need to account for distance b/w collide point and cur, but it's doable)

 -- cur dir = atan2(next-cur .x, next-cur .y)
 -- = atan2(ball.dx,ball.dy)
 -- which is monotonic to ball.dy/ball.dx
 local dir = ball.dy/ball.dx

 --this might be overkill
 local xdir, ydir

 if (ball.dx == 0) xdir=0 xdir=sgn(ball.dx)
 if (ball.dy == 0) ydir=0 ydir=sgn(ball.dy)

 local check_pix = vec2d(flr(cur_pos.x*8), flr(cur_pos.y*8))

 if abs(ball.dx) > abs(ball.dy) then
  check_pix.x += xdir
 else
  check_pix.y += ydir
 end
 check_pix_k = mget(check_pix.x/8, check_pix.y/8)

 -- iterate along the path until we find a collision pixel
 while(get_sprite_colour(check_pix_k, vec2d(check_pix.x%8, check_pix.y%8))==5) do
  local new_dir = abs(next_pix.y-check_pix.y)/abs(next_pix.x-check_pix.x)
  -- these dirs, when abs, are the slopes. 
  -- If the new slope is of greater magnitude than the original slope, a y-move will decrease it, and vice versa 
  move_in_x = new_dir<abs(dir)
  if (move_in_x) check_pix.x += xdir check_pix.y += ydir
  check_pix_k = mget(check_pix.x/8, check_pix.y/8)
 end
 
 local normal_dir = get_normal_for_pix(check_pix)

 local new_ball_dir = get_reflected_dir(normal_dir, ball_dir)

 -- look for nearby collision pixels to calculate the normal
 -- These are the locations of the surrounding pixels in a counter-clockwise rotation, starting with right
 -- There's probably a smarter way to generate this, maybe w/ sin/cos?
 local eight_dirs_x = {1,1,0,-1,-1,-1,0,1}
 local eight_dirs_y = {0,-1,-1,-1,0,1,1,1} -- y is positive downward
 local last_point -- a number 1,3,5,7 = right,up,left,down
 if(move_in_x) then
  if(xdir>0) last_point=1 last_point=5
 else
  if(ydir>0) last_point=7 last_point=3
 end

 local collision_pix_clock
 local i = last_point+1;
 while(i!=last_point) do
  if(i>8) i-=8
  i_point = vec2d(check_pix.x+eight_dirs_x[i],check_pix.y+eight_dirs_y)
  if(get_sprite_colour(mget(check_pix.x/8, check_pix.y/8), vec2d(check_pix.x%8, check_pix.y%8))!=5) then
   collision_pix_clock = i
   break
  end
  i += 1
 end

 local collision_pix_counter_clock
 local i = last_point-1;
 while(i!=last_point) do
  if(i<1) i+=8
  i_point = vec2d(check_pix.x+eight_dirs_x[i],check_pix.y+eight_dirs_y)
  if(get_sprite_colour(mget(check_pix.x/8, check_pix.y/8), vec2d(check_pix.x%8, check_pix.y%8))!=5) then
   collision_pix_counter_clock = i
   break
  end
  i -= 1
 end

 local diff_clockwise = last_point - collision_pix_clock
 local diff_counterclockwise = last_point - collision_pix_counter_clock

 --local cur_pixel_local = vec2d(cur_ball_pos.x % 8, cur_ball_pos.y % 8)

end

function init_hole(num)
 ball.pos.x = holes[num].ball_x
 ball.y = holes[num].ball_y
 camera(holes[num].cam_x,holes[num].cam_y)
 ball.dx = 0
 ball.dy = 0
 ball_stopped = true
 -- we can add an offset here. Gets updated rarely, not once per frame
 shot_display.x = holes[num].cam_x + 1
 shot_display.y = holes[num].cam_y + 1
end

function update_ball_physics()
 -- apply movement
 ball.x += ball.vel.x
 ball.y += ball.vel.y
 -- apply friction
 -- each frame is supposedly constant time, we'll ignore dropped frames for now.
 -- friction is independent of speed, it's constant decelleration
 local vel_mag_1 = ball.vel.magnitude
 local vel_mag_2 = vel_mag_1 - friction
 if vel_mag_2 < 0 then 
  ball_stopped = true
  ball.vel = {x=0, y=0}
 else
  ball.vel *= vel_mag_2 / vel_mag_1
 end
end

function ball_update()
 --ball = {g_pos=vec2d(64, 64), vel=vec2d(0,0)}

 local cur_pos = ball.g_pos
 cur_pos.k = mget(cur_pos.x, cur_pos.y)

 local next_pos = ball.g_pos + ball.vel
 next_pos.k = mget(next_pos.x, next_pos.y)

 handle_collisions(cur_pos, next_pos)

 update_ball_physics()


end

function old_ball_update()
 local cur_pos = {x=ball.x + 0.5, y=ball.y + 0.5}
 cur_pos.k = mget(cur_pos.x, cur_pos.y)
 local next_pos = {x=ball.x+ball.dx, y=ball.y+ball.dy}
 next_pos.k = mget(next_pos.x, next_pos.y)

 -- let's phase out these vars
 local cur_tile = {x=flr(ball.x + 0.5), y=flr(ball.y + 0.5)}
 cur_tile.k = mget(cur_tile.x, cur_tile.y)
 local next_tile = {x=flr((ball.x + 0.5) + ball.dx), y=flr((ball.y + 0.5) + ball.dy)}
 next_tile.k = mget(next_tile.x , next_tile.y)

 -- check if hole
 if next_pos.k == 18 then
  if hole_num != #holes then
   hole_num += 1
   init_hole(hole_num)
  else
   win = true
  end
 end

 -- check if wall
 if next_pos.k == 17 then
  old_collision(cur_tile, next_tile)
 elseif fget(next_pos.k, 0) then
  collision(cur_pos, next_pos)
 end

 ball_angle = atan2(ball.dx, ball.dy)

 ball.x += ball.dx
 ball.y += ball.dy
 -- apply friction
 ball.dx *= (1 - friction)
 ball.dy *= (1 - friction)

 if sqrt(ball.dx^2+ball.dy^2) < 0.01 then
  ball.dx = 0
  ball.dy = 0
  ball_stopped = true
 else
  ball_stopped = false
 end

end

function _init()

 init_hole(1)
end

function _update()
 if not win then
  read_input()
 end
 if not ball_stopped then
  ball_update()
 end
end


-->8
-- all drawing-related functions are below
function draw_ball()

 ball.k_i = (ball.k_i+1)%4
 if ball_stopped == false  and ball.k_i == 0 then 
  if 1/8<=ball_angle and ball_angle < 3/8 then
   --up
   if ball.k>=32 then
    ball.k=(ball.k+1)%4 + 32
   else
    ball.k=32
   end
  elseif 3/8<=ball_angle and ball_angle < 5/8 then
   --left
   if ball.k>=48 then
    ball.k=(ball.k-1)%4 + 48
   else
    ball.k=48
   end
  elseif 5/8<=ball_angle and ball_angle < 7/8 then
   --down
   if ball.k>=32 then
    ball.k=(ball.k-1)%4 + 32
   else
    ball.k=32
   end
  else
   --right
   if ball.k>=48 then
    ball.k=(ball.k+1)%4 + 48
   else
    ball.k=48
   end
  end
 end
 
 spr(ball.k,ball.x,ball.y)
end

function draw_arrow()
 local colour = 7

 -- create a prototype arrow, facing right (angle=0), and rotate it

 --hole1 has ball.x=ball.y=8
 local centre = vec2d(ball.x + 4, ball.y + 4)
 local tip = vec2d(centre.x-8, centre.y):rotate(shot_angle,centre)
 local tail = vec2d(centre.x-16, centre.y):rotate(shot_angle,centre)  
 local lpoint = vec2d(centre.x-12, centre.y+2):rotate(shot_angle,centre)
 local rpoint = vec2d(centre.x-12, centre.y-2):rotate(shot_angle,centre)   

 -- draw the arrow

 line(tip.x, tip.y, tail.x, tail.y, colour)
 line(tip.x, tip.y, lpoint.x, lpoint.y, colour)
 line(tip.x, tip.y, rpoint.x, rpoint.y, colour)
 line(lpoint.x, lpoint.y, rpoint.x, rpoint.y, colour)

 --print("angle="..shot_angle,0,0)
 --print("tip=("..tip.x..","..tip.y.."), centre=("..centre.x..","..centre.y..")",0,8)
 --print("tip=-1*"..cos(shot_angle)..", -(-1)*"..sin(shot_angle),0,16)
end

function draw_display()
 rectfill(0, 0, 8*16, 8*2, 5)
 if win then
  print("winner!", holes[hole_num].cam_x + 8*8, holes[hole_num].cam_y+1, 7)
 end
 print(shot_display.text .. shot_counter, shot_display.x, shot_display.y, 7)
end

function _draw()
 cls()
 map()
 if not win then
  draw_ball()
  if ball_stopped then
   draw_arrow()
  end
 end

 draw_display()

end

-->8
--page 2
-->8
--page 3
__gfx__
57777775077777000707007000777770077777700777770007007070007777705555555555555566665555555555555544444444444444666644444444444444
77667667770077770777777077777777777777777777777707777770777700775555555555566644446665555555555544444444444666555566644444444444
67577757777707707777777707770077707770777700777077777777077077775555555556644444444446655555555544444444466555555555566444444444
67577757777777777707777707777777707770777777777077777077777777775555555664444444444444466555555544444446655555555555555664444444
67777577777777707077707777777777770777777777777777077707077777775555556444444444444444444655555544444465555555555555555556444444
77777777770077707077707707707777777777777777077077077707077700775555564444444444444444444465555544444655555555555555555555644444
57777775777777777777777777770077077777707700777777777777777777775555644444444444444444444446555544446555555555555555555555564444
56556565077777000777777000777770070700700777770007777770007777705556444444444444444444444444655544465555555555555555555555556444
55555555444444440505050555555555655555555555555664444444444444465556444400000000000000004444655544465555000000000000000055556444
555555554444444450666d5055557555465555555555556456444444444444655564444400000000000000004444465544655555000000000000000055555644
5555555544444444066766d575556755446555555555564455644444444446555564444400000000000000004444465544655555000000000000000055555644
5555555544444444567776d067555755444655555555644455564444444465555644444400000000000000004444446546555555000000000000000055555564
5555555544444444066766d555777765444465555556444455556444444655555644444400000000000000004444446546555555000000000000000055555564
5555555544444444566766d075766755444446555564444455555644446555555644444400000000000000004444446546555555000000000000000055555564
55555555444444440444440567555675444444655644444455555564465555556444444400000000000000004444444665555555000000000000000055555556
55555555444444445044405055555555444444466444444455555556655555556444444400000000000000004444444665555555000000000000000055555556
57777755076667000766670055766675555644444444444444446555555555556444444400000000000000004444444665555555000000000000000055555556
76557776777777767777777667777777555644444444444444446555555555556444444400000000000000004444444665555555000000000000000055555556
76775775777777707777777057775567555644444444444444446555555555555644444400000000000000004444446546555555000000000000000055555564
77777776777777767777777057777767555644444444444444446555666666665644444400000000000000004444446546555555000000000000000055555564
76777775777777707777777667777777555644446666666644446555444444445644444400000000000000004444446546555555000000000000000055555564
76557775777777707777777057757767555644445555555544446555444444445564444400000000000000004444465544655555000000000000000055555644
77777776777777767777777667775567555644445555555544446555444444445564444400000000000000004444465544655555000000000000000055555644
57666755076667000766670055777775555644445555555544446555444444445556444400000000000000004444655544465555000000000000000055556444
57777775077777700777777057777775666666666444444444444444444444465556444444444444444444444444655544465555555555555555555555556444
77667667777777777777777776676677444444446444444444444444444444465555644444444444444444444446555544446555555555555555555555564444
67577757777777777777777775777576444444446444444444444444444444465555564444444444444444444465555544444655555555555555555555644444
67577757777777777777777775777576444444446444444444444444444444465555556444444444444444444655555544444465555555555555555556444444
67777577777777777777777777577776444444446444444444444444444444465555555664444444444444466555555544444446655555555555555664444444
77777777777777777777777777777777444444446444444444444444444444465555555556644444444446655555555544444444466555555555566444444444
57777775077777700777777057777775444444446444444444444444444444465555555555566644446665555555555544444444444666555566644444444444
56556565070070700707007056565565444444446444444466666666444444465555555555555566665555555555555544444444444444666644444444444444
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000111111111100001111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001111363636363636361111000000000c0d0e0f110000110c0d0e0f110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00110c0d101010101010100e0f110000111c10101f110000111c12101f110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00111c1010101010101010101f1100003710131010351100112c101010350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0037101010101010101010101035000037101010102811111126101010350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0037101210101010101013101035000037101010103839363a3b101010350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0037101010101010101010101035000011141010101010101010101010350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00112c1010101010101010102f11000011111410101010101010101015110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00113c3d101010101010103e3f11000000001114101010101010101511110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000111134343434343434111100000000000011343434343434341111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

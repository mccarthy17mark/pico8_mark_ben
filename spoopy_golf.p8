pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- spoopy (aka fun-scary) minigolf
logfile = "log.txt"
printh("~~~~~spoopy_golf initialized~~~~~", logfile, true)

-- debug log functions
function trace(msg)
 printh("trace: " .. msg, logfile)
end

function debug(msg)
 printh("debug: " .. msg, logfile)
end

function info(msg)
 printh("info: " .. msg, logfile)
end

function error(msg)
 printh("error: " .. msg, logfile)
end

function fatal(msg)
 printh("fatal: " .. msg, logfile)
end


--class def'ns here

--note to self: screen is 16*16 tiles... 128*128 px
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
setmetatable(vec2d, {
 __call = function(cls, ...)
  return cls.new(...) -- Calls vec2d:new(...)
 end
})

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

-- check if two vectors are equal
function vec2d.__eq(a,b)
 return (a.x == b.x and a.y == b.y)
end

-- negate a vector (unary minus)
function vec2d.__unm(a)
 return vec2d(-a.x, -a.y)
end

function vec2d:rotate(angle, pivot)
 -- angle is scalar, pivot is vec2d
 -- functions like this ought to not modify the original vector. if you want it modified, do:
  -- vec = vec.rotate(angle,pivot)
 local temp = self - pivot
 local new_vec = vec2d(0,0)
 new_vec.x = temp.x*cos(angle) - temp.y*sin(angle)
 new_vec.y = temp.x*sin(angle) + temp.y*cos(angle)
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

function vec2d:to_string()
 return "("..self.x..","..self.y..")"
end

function vec2d:magnitude()
 return sqrt(self.x^2 + self.y^2)
end

function vec2d:dot(other)
 return self.x*other.x + self.y*other.y
end

function vec2d:normalized()
 local mag = self:magnitude()
 if mag == 0 then
  return vec2d(0,0)
 end
 return self / mag
end

function vec2d:angle()
 return atan2(self.x,self.y)
end

function vec2d:reflect(normal)
 trace("entering vec2d:reflect with self=" .. self:to_string() .. " and normal=" .. normal:to_string())
 -- r = d-2(d.n)n where d is the incoming vector (self) and n is the normal vector (normal)
 return self - normal * 2 * self:dot(normal) 
 
 -- local angle_diff = normal:angle() - self:angle()
 -- if angle_diff < -0.5 then
 --  angle_diff += 1
 -- elseif angle_diff >0.5 then
 --  angle_diff -= 1
 -- end

 -- return self:rotate(2*angle_diff, vec2d(0,0))
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

-- this is supposed to make box2d(1,2,3,4) the same as box2d.new(1,2,3,4)
setmetatable(box2d, {
 __call = function(cls, ...)
  return cls.new(...) -- Calls box2d:new(...)
 end
})

function box2d:contains(point)
 -- the edges of the box are (not?) included in the box
 if point.x >= self.x and point.x <= self.x+self.w and point.y >= self.y and point.y <= self.y + self.h then
  return true
 end
 return false
end

function box2d:centre()
 return vec2d((self.x+self.w)/2,(self.y+self.h)/2)
end

-->8
-- utility functions here

-- the location of the camera, in pixels, relative to the global map
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

function gt2g(gt)
 return gt*8
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

ball = {g_pos=vec2d(64, 64), vel=vec2d(0,0), k=48, k_i = 0}

-- normals are in the following format:
-- key=sspx.to_string()
-- val=normal_dir (angle ranging 0-1, right=0, increasing counter-clockwise)
normals = {}

holes = {}
holes[1] = {gt_ball = vec2d(7,7), gt_cam = vec2d(0,0)}
holes[2] = {gt_ball = vec2d(19,5), gt_cam = vec2d(16,0)}

friction = 0.1 --todo check what's reasonable, let it be tile dependent (make a friction_k table)
speed_multiplier_on_reflection = 0.75
shot_speed = 3
hole_num = 1

win = false

shot_display = {x=1, y=1, text = "stroke no: "}

shot_angle = 0
shot_counter = 0

function compute_normals_for_circle(is_convex, outer_box, inner_box)
 trace("entering compute_normals_for_circle with is_convex=" .. tostring(is_convex) .. ", outer_box=(" .. outer_box.x .. "," .. outer_box.y .. "," .. outer_box.w .. "," .. outer_box.h .. "), inner_box=(" .. inner_box.x .. "," .. inner_box.y .. "," .. inner_box.w .. "," .. inner_box.h .. ")")
 local centre = outer_box:centre()

 local multiplier
 if (is_convex) multiplier = 1 else multiplier= -1

 for y = outer_box.y, outer_box.y + outer_box.h do
  for x = outer_box.x, outer_box.x + outer_box.w do
   local ipoint = vec2d(x,y)
   if not inner_box:contains(ipoint) then
    if sget(x,y) == collision_colour then
     local normal_angle = atan2(multiplier*(x-centre.x),multiplier*(y-centre.y))
     normals[ipoint:to_string()] = normal_angle
     -- add only works for arrays with numerical indices
     --add(normals,normal,ipoint:to_string())
    end
   end
  end
 end
end

function compute_parallel_normals_for_single_sprite(k, angle)
 local top_left = k2ss(k)
 for y = top_left.y, top_left.y + 7 do
  for x = top_left.x, top_left.x + 7 do
   local point = vec2d(x,y)
   normals[point:to_string()] = angle
  end
 end
end

function compute_normals()
 trace("entering compute_normals")
 -- the convex circle
 local outer_box = box2d(64,0,32,32)
 local inner_box = box2d(72,8,16,16)
 --local top_left_outer_box = vec2d(64,0)
 --local top_left_inner_box = vec2d(72,8)
 --local bottom_right_inner_box = vec2d(87,23)
 --local bottom_right_outer_box = vec2d(95,31)
 
 compute_normals_for_circle(true, outer_box, inner_box)

 -- the concave circle
 outer_box = box2d(96,0,32,32)
 inner_box = box2d(104,8,16,16)
 -- local top_left_outer_box = vec2d(96,0)
 -- local top_left_inner_box = vec2d(104,8)
 -- local bottom_right_inner_box = vec2d(119,23)
 -- local bottom_right_outer_box = vec2d(127,31)
 compute_normals_for_circle(false, outer_box, inner_box)

 compute_parallel_normals_for_single_sprite(20,0.125)
 compute_parallel_normals_for_single_sprite(21,0.375)
 compute_parallel_normals_for_single_sprite(22,0.625)
 compute_parallel_normals_for_single_sprite(23,0.875)

 compute_parallel_normals_for_single_sprite(36,0)
 compute_parallel_normals_for_single_sprite(37,0.25)
 compute_parallel_normals_for_single_sprite(38,0.5)
 compute_parallel_normals_for_single_sprite(39,0.75)

 compute_parallel_normals_for_single_sprite(52,0)
 compute_parallel_normals_for_single_sprite(53,0.25)
 compute_parallel_normals_for_single_sprite(54,0.5)
 compute_parallel_normals_for_single_sprite(55,0.75)
end

function read_input()
 if btnp(5) then
  ball.vel.x = shot_speed*cos(shot_angle)
  ball.vel.y = shot_speed*sin(shot_angle)
  info("shot taken with angle " .. shot_angle .. " resulting in velocity " .. ball.vel:to_string())
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

function get_pixels_of_sprite(sprite_gpos)
 -- assume (g_x,g_y) is the top-left corner of the sprite in global pixel coordinates
 -- returns a list of all global pixel coordinates covered by the sprite
 -- we can extend this later to include non-8x8 square sprites
 local pixels = {}
 for j=0,7 do
  for i=0,7 do
   add(pixels,vec2d(sprite_gpos.x+i,sprite_gpos.y+j))
  end
 end
 return pixels
end

function ball_wall_collision_check(test_ball_g_pos)
 -- returns wall collision type or nil
 -- is it better to return a table or multiple values?
 local ball_pixels = get_pixels_of_sprite(test_ball_g_pos)
 for _,pix in pairs(ball_pixels) do
  local normal_angle = normals[g2ss(pix):to_string()]
  if normal_angle then
   local normal_vec = vec2d(cos(normal_angle), sin(normal_angle))  -- convert angle to vector
   -- not sure if pix is needed anymore, it represents first checked pixel that overlapped
   return {type="wall", pix=pix, normal=normal_vec}
  end
 end
 return nil
end

function collision_check_at_position(test_ball_g_pos)
 -- returns collision type or nil
 local test_ball_g_pos_centre = test_ball_g_pos + vec2d(4,4)
 local tile = g2k(test_ball_g_pos_centre)
 if tile == 18 then
  return {type="hole", pix=test_ball_g_pos_centre}
 end

 local wall_collision = ball_wall_collision_check(test_ball_g_pos)
 if wall_collision then
  return wall_collision
 end

 -- add more collision checks here as needed

 return nil
end

function collision_check_over_path(cur_pix, next_pix)

 -- leave function early if the ball isn't moving
 if cur_pix == next_pix then
  return nil
 end

 -- perform bresenham's line algorithm, iteratively checking for collisions at eatch pixel along the way
 local start = vec2d(flr(cur_pix.x), flr(cur_pix.y))
 local target = vec2d(flr(next_pix.x), flr(next_pix.y))
 local last_pix = start
 local dx = abs(target.x - start.x)
 local dy = abs(target.y - start.y)
 local sx = sgn(target.x - start.x)
 local sy = sgn(target.y - start.y)
 local err = dx - dy

 local check_pix = vec2d(start.x, start.y)

 while check_pix ~= target do
  -- move to next pixel along bresenham path
  if dx == 0 then
   check_pix.y += sy
  elseif dy == 0 then
   check_pix.x += sx
  else
   local e2 = err * 2
   if e2 > -dy then
    err -= dy
    check_pix.x += sx
   else
    err += dx
    check_pix.y += sy
   end
  end

  local collision = collision_check_at_position(check_pix)
  if collision then
   return collision
  end
 end

 return collision_check_at_position(check_pix)  -- check for collision at the final target pixel as well
end

function handle_ball_movement(cur_pix, move_vec)
 trace("entering handle_ball_movement with cur_pix=" .. cur_pix:to_string() .. " and move_vec=" .. move_vec:to_string())
 -- move ball along move_vec from cur_pix, handling collisions along the way
 -- return the ball's final position and any movement-ending collision info
 local current = cur_pix
 local remaining = move_vec

 while true do
  -- if the ball ran out of velocity, stop and return
  if remaining == vec2d(0,0) then
   trace("leaving handle_ball_movement with no remaining movement at " .. current:to_string())
   return nil, current
  end

  local next_pix = current + remaining
  local collision = collision_check_over_path(current, next_pix)
  -- if there was no collision, move the ball to the target and return
  if not collision then
   trace("leaving handle_ball_movement with no collision at " .. next_pix:to_string())
   return nil, next_pix
  end

  -- if we got here, a collision occurred and we should handle it
  -- if the ball hit the hole, immediately stop and return the hole change to be handled by the caller
  if collision.type == "hole" then
   ball_stopped = true
   ball.vel = vec2d(0, 0)
   trace("ball hit hole at " .. collision.pix:to_string())
   return collision, collision.pix

  -- if the ball hit a wall, reflect the remaining movement vector across the wall normal, and continue the loop to check for more collisions along the new path
  elseif collision.type == "wall" then
   -- last_pix should always be a safe pixel to place the ball on after the collision, since it's the last non-colliding pixel along the path.
   local travelled = (collision.last_pix - current):magnitude()
   local remaining_dist = (remaining:magnitude() - travelled) * speed_multiplier_on_reflection
   -- this should almost never happen, only if a high speed_multiplier_on_reflection leads to rounding down to zero
   if remaining_dist <= 0 then
    trace("eaving handle_ball_movement with no remaining movement after reflection at " .. collision.last_pix:to_string())
    return collision, collision.last_pix
   end
   trace("ball.vel before reflection: " .. ball.vel:to_string())
   trace("collision normal: " .. collision.normal:to_string())
   ball.vel = ball.vel:reflect(collision.normal)
   trace("ball.vel after reflection: " .. ball.vel:to_string())
   remaining = ball.vel:normalized() * remaining_dist
   current = collision.last_pix

  -- add more collision types here as needed
  else
   assert(false, "unknown collision type: " .. collision.type)
  end
 end
end

function update_ball_physics()
 trace("entering update_ball_physics with ball.vel=" .. ball.vel:to_string())
 -- apply friction only; movement is resolved before this
 local speed = ball.vel:magnitude()

 -- this check might be pointless, we really shouldn't be here if speed<=0
 if speed <= 0 then
  ball_stopped = true
  trace("leaving update_ball_physics with ball stopped due to non-positive speed")
  return
 end

 -- friction is constant force, so constant deceleration, so just a speed subtraction.
 local new_speed = speed - friction
 if new_speed <= 0 then
  ball_stopped = true
  ball.vel = vec2d(0, 0)
 else
  ball.vel = ball.vel * (new_speed / speed)
  -- the safest thing to do is check here if ball.vel.speed <= 0, but that's probably overkill
 end
 trace("leaving update_ball_physics with ball.vel=" .. ball.vel:to_string())
end

function ball_update()
 trace("entering ball_update with ball.g_pos=" .. ball.g_pos:to_string() .. " and ball.vel=" .. ball.vel:to_string())
 local cur_pos = ball.g_pos
 local collision_info, final_pos = handle_ball_movement(cur_pos, ball.vel)
 ball.g_pos = final_pos
 trace("ball moved to " .. ball.g_pos:to_string())

 if collision_info and collision_info.type == "hole" then
  trace("ball_update detected hole collision")
  hole_num += 1
  if hole_num > #holes then
   win = true
   return
  end
  init_hole(hole_num)
  return
 end

 if not ball_stopped then
  update_ball_physics()
 end
 trace("leaving ball_update with ball.g_pos=" .. ball.g_pos:to_string() .. " and ball.vel=" .. ball.vel:to_string())
end

function init_hole(num)
 trace("entering init_hole(" .. num .. ")")
 trace("hole data: gt_ball=" .. holes[num].gt_ball:to_string() .. ", gt_cam=" .. holes[num].gt_cam:to_string())
 ball.g_pos = gt2g(holes[num].gt_ball) -- convert from tile to global pixel coords
 camera(holes[num].gt_cam.x,holes[num].gt_cam.y)
 ball.vel = vec2d(0, 0)
 ball_stopped = true
 -- we can add an offset here. gets updated rarely, not once per frame
 shot_display.x = holes[num].gt_cam.x + 1
 shot_display.y = holes[num].gt_cam.y + 1
end

function _init()
 trace("entering _init")
 compute_normals()
 init_hole(1)
end

function _update()
 trace("entering _update")
 if not win then
  read_input()
 end
 if not ball_stopped then
  trace("ball position before update: " .. ball.g_pos:to_string())
  ball_update()
  trace("ball position after update: " .. ball.g_pos:to_string())
 end
end


-->8
-- all drawing-related functions are below
function draw_ball()

 ball.k_i = (ball.k_i+1)%4
 if ball_stopped == false  and ball.k_i == 0 then 
  local ball_angle = ball.vel:angle()
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
 trace("drawing ball at " .. ball.g_pos:to_string() .. " with sprite " .. ball.k)
 spr(ball.k,ball.g_pos.x,ball.g_pos.y)
end

function draw_arrow()
 local colour = 7

 -- create a prototype arrow, facing right (angle=0), and rotate it

 local centre = vec2d(ball.g_pos.x + 4, ball.g_pos.y + 4)
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
  print("winner!", holes[hole_num].gt_cam.x + 8*8, holes[hole_num].gt_cam.y+1, 7)
 end
 print(shot_display.text .. shot_counter, shot_display.x, shot_display.y, 7)
end

function _draw()
 trace("entering _draw")
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


dofile(minetest.get_modpath("carts_new").."/functions.lua")

--
-- Cart entity
--

local carts_new = {
	physical = false,
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "mesh",
	mesh = "cart.x",
	visual_size = {x=1, y=1},
	textures = {"cart.png"},
	pause = 0,
	driver = nil,
	velocity = {x=0, y=0, z=0},
	old_pos = nil,
	old_velocity = nil,
	pre_stop_dir = nil,
	MAX_V = 2, -- Limit of the velocity
}

function carts_new:on_rightclick(clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	if self.driver and clicker == self.driver then
		self.driver = nil
		clicker:set_detach()
	elseif not self.driver then
		self.driver = clicker
		clicker:set_attach(self.object, "", {x=0,y=5,z=0}, {x=0,y=0,z=0})
	end
end

function carts_new:on_activate(staticdata, dtime_s)
	self.object:set_armor_groups({immortal=1})
	if staticdata then
		local tmp = minetest.deserialize(staticdata)
		if tmp then
			self.velocity = tmp.velocity
		end
		if tmp and tmp.pre_stop_dir then
			self.pre_stop_dir = tmp.pre_stop_dir
		end
	end
	self.old_pos = self.object:getpos()
	self.old_velocity = self.velocity
end

function carts_new:get_staticdata()
	return minetest.serialize({
		velocity = self.velocity,
		pre_stop_dir = self.pre_stop_dir,
	})
end

-- Remove the cart if holding a tool or accelerate it
function carts_new:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	if not puncher or not puncher:is_player() then
		return
	end
	if puncher:get_player_control().sneak then
		self.object:remove()
		local inv = puncher:get_inventory()
		if minetest.setting_getbool("creative_mode") then
			if not inv:contains_item("main", "carts:cart") then
				inv:add_item("main", "carts:cart")
			end
		else
			inv:add_item("main", "carts:cart")
		end
		return
	end
	--sleep(1)
	
	if puncher == self.driver then
		return
	end
	
	local d = cart_func:velocity_to_dir(direction)
	local s = self.velocity
	if time_from_last_punch > tool_capabilities.full_punch_interval then
		time_from_last_punch = tool_capabilities.full_punch_interval
	end
	local f = 4*(time_from_last_punch/tool_capabilities.full_punch_interval)
	local v = {x=s.x+d.x*f, y=s.y, z=s.z+d.z*f}
	if math.abs(v.x) < 6 and math.abs(v.z) < 6 then
		self.velocity = v
	else
		if math.abs(self.velocity.x) < 6 and math.abs(v.x) >= 6 then
			self.velocity.x = 6*cart_func:get_sign(self.velocity.x)
		end
		if math.abs(self.velocity.z) < 6 and math.abs(v.z) >= 6 then
			self.velocity.z = 6*cart_func:get_sign(self.velocity.z)
		end
	end
	
end

-- Returns the direction as a unit vector
function carts_new:get_rail_direction(pos, dir)
print("get_rail_direction")
print("pos: "..pos.x..","..pos.y..","..pos.z)
print("dir: "..dir.x..","..dir.y..","..dir.z)

	local d = cart_func.v3:copy(dir)
	
	-- Check front
	d.y = 0
	local p = cart_func.v3:add(cart_func.v3:copy(pos), d)
	if cart_func:is_rail(p) then
		return d
	end
	
	-- Check downhill
	d.y = -1
	p = cart_func.v3:add(cart_func.v3:copy(pos), d)
	if cart_func:is_rail(p) then
		return d
	end
	
	-- Check uphill
	d.y = 1
	p = cart_func.v3:add(cart_func.v3:copy(pos), d)
	if cart_func:is_rail(p) then
		return d
	end
	d.y = 0
	
	-- Check left and right
	local view_dir
	local other_dir
	local a
	
	if d.x == 0 and d.z ~= 0 then
		view_dir = "z"
		other_dir = "x"
		if d.z < 0 then
			a = {1, -1}
		else
			a = {-1, 1}
		end
	elseif d.z == 0 and d.x ~= 0 then
		view_dir = "x"
		other_dir = "z"
		if d.x > 0 then
			a = {1, -1}
		else
			a = {-1, 1}
		end
	else
		return {x=0, y=0, z=0}
	end
	
	d[view_dir] = 0
	d[other_dir] = a[1]
	p = cart_func.v3:add(cart_func.v3:copy(pos), d)
	if cart_func:is_rail(p) then
		return d
	end
	d.y = -1
	p = cart_func.v3:add(cart_func.v3:copy(pos), d)
	if cart_func:is_rail(p) then
		return d
	end
	d.y = 0
	d[other_dir] = a[2]
	p = cart_func.v3:add(cart_func.v3:copy(pos), d)
	if cart_func:is_rail(p) then
		return d
	end
	d.y = -1
	p = cart_func.v3:add(cart_func.v3:copy(pos), d)
	if cart_func:is_rail(p) then
		return d
	end
	d.y = 0
	
	return {x=0, y=0, z=0}
end

function carts_new:calc_rail_direction(pos, vel)

	velocity = cart_func.v3:copy(vel)
	p = cart_func.v3:copy(pos)
print("calc_rail_direction")
print("p: "..p.x..","..p.y..","..p.z)
print("velocity: "..velocity.x..","..velocity.y..","..velocity.z)

if(cart_func.v3:equal(velocity, {x=0,y=0,z=0}))then
print("break calc_rail_direction")
return pos
end
dir = self:get_rail_direction(p, velocity)
step = cart_func.v3:round(dir)
print("rail_direction: "..step.x..","..step.y..","..step.z)
if(cart_func.v3:equal(step, {x=0,y=0,z=0}))then
return pos
end
local p2 = cart_func.v3:copy(pos)
to = cart_func.v3:copy(pos)

while cart_func:is_rail(p2) do
to = cart_func.v3:copy(p2)
p2 = cart_func.v3:add(p2, step)
end

print("to: "..to.x..","..to.y..","..to.z)

return to

end

function carts_new:on_step(dtime)
pos = self.object:getpos()
vel = self.velocity
print("on_step")
print("pos: "..pos.x..","..pos.y..","..pos.z)
print("vel: "..vel.x..","..vel.y..","..vel.z)

if(cart_func.v3:equal(vel, {x=0,y=0,z=0}))then
print("break on_step")
return pos
end
to = carts_new:calc_rail_direction(pos, vel)
if(cart_func.v3:equal(to, pos))then
print("break on_step, to")
return pos
end
self.object:moveto(to)

end



--
-- node and craft
--

minetest.register_entity("carts_new:cart", carts_new)


minetest.register_craftitem("carts_new:cart", {
	description = "Minecart v2",
	inventory_image = minetest.inventorycube("cart_top.png", "cart_side.png", "cart_side.png"),
	wield_image = "cart_side.png",
	
	on_place = function(itemstack, placer, pointed_thing)
		if not pointed_thing.type == "node" then
			return
		end
		if cart_func:is_rail(pointed_thing.under) then
			minetest.env:add_entity(pointed_thing.under, "carts_new:cart")
			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
		elseif cart_func:is_rail(pointed_thing.above) then
			minetest.env:add_entity(pointed_thing.above, "carts_new:cart")
			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
		end
	end,
})

minetest.register_craft({
	output = "carts_new:cart",
	recipe = {
		{"", "", ""},
		{"default:steel_ingot", "", "default:steel_ingot"},
		{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
	},
})

minetest.register_node("carts_new:rail", {
	description = "Rail",
	drawtype = "raillike",
	tiles = {"carts_rail.png", "carts_rail_curved.png", "carts_rail_t_junction.png", "carts_rail_crossing.png"},
	inventory_image = "carts_rail.png",
	wield_image = "carts_rail.png",
	paramtype = "light",
	is_ground_content = true,
	walkable = false,
	selection_box = {
		type = "fixed",
		-- but how to specify the dimensions for curved and sideways rails?
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	groups = {bendy=2,snappy=1,dig_immediate=2,attached_node=1,rail=1,connect_to_raillike=1},
})

minetest.register_node("carts_new:brakerail", {
	description = "Brake Rail",
	drawtype = "raillike",
	tiles = {"carts_rail_brk.png", "carts_rail_curved_brk.png", "carts_rail_t_junction_brk.png", "carts_rail_crossing_brk.png"},
	inventory_image = "carts_rail_brk.png",
	wield_image = "carts_rail_brk.png",
	paramtype = "light",
	is_ground_content = true,
	walkable = false,
	selection_box = {
		type = "fixed",
		-- but how to specify the dimensions for curved and sideways rails?
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	groups = {bendy=2,snappy=1,dig_immediate=2,attached_node=1,rail=1,connect_to_raillike=1},
	
})



minetest.register_craft({
	output = "carts_new:rail 2",
	recipe = {
		{"default:steel_ingot", "default:stick", "default:steel_ingot"},
		{"default:steel_ingot", "", "default:steel_ingot"},
		{"default:steel_ingot", "default:stick", "default:steel_ingot"},
	}
})

minetest.register_craft({
	output = "carts_new:brakerail 2",
	recipe = {
		{"default:steel_ingot", "default:stick", "default:steel_ingot"},
		{"default:steel_ingot", "default:coal_lump", "default:steel_ingot"},
		{"default:steel_ingot", "default:stick", "default:steel_ingot"},
	}
})


function print_r (t, indent, done)
  done = done or {}
  indent = indent or ''
  local nextIndent -- Storage for next indentation value
  for key, value in pairs (t) do
    if type (value) == "table" and not done [value] then
      nextIndent = nextIndent or
          (indent .. string.rep(' ',string.len(tostring (key))+2))
          -- Shortcut conditional allocation
      done [value] = true
      print (indent .. "[" .. tostring (key) .. "] => Table {");
      print  (nextIndent .. "{");
      print_r (value, nextIndent .. string.rep(' ',2), done)
      print  (nextIndent .. "}");
    else
      print  (indent .. "[" .. tostring (key) .. "] => " .. tostring (value).."")
    end
  end
end

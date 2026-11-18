-- SPDX-License-Identifier: GPL-3.0-or-later
local S = core.get_translator(core.get_current_modname())
local brick = "mcl_nether:nether_brick"
local basalt = "mcl_blackstone:basalt_polished"
local rail = "mcl_fences:nether_brick_fence"
local slab = "mcl_stairs:slab_nether_brick"
local lamp = "mcl_nether:glowstone"

mcl_expeditions.register("nether_ferry_piers", {
	title = S("Nether Ferry Piers"),
	environment = "lava",
	biomes = {"NetherWastes", "BasaltDeltas", "CrimsonForest", "WarpedForest", "SoulSandValley"},
	bounds = {min = vector.new(-14, -5, -5), max = vector.new(14, 6, 5)},
	build = function(ctx)
		for _, side in ipairs({-1, 1}) do
			local shore = side * 11
			ctx:fill(shore - 3, 0, -4, shore + 3, 0, 4, brick)
			for _, z in ipairs({-3, 3}) do
				ctx:fill(shore + side * 2, -5, z, shore + side * 2, 2, z, basalt)
				ctx:set(shore + side * 2, 3, z, lamp)
				ctx:fill(shore - 3, 1, z + z / math.abs(z), shore + 3, 1, z + z / math.abs(z), rail)
			end
			for z = -1, 1 do
				ctx:set(side * 8, 0, z, slab)
				ctx:set(side * 7, -1, z, slab, 20)
			end
			ctx:fill(shore - 2, 4, 2, shore + 2, 4, 4, brick)
			ctx:fill(shore, 1, 4, shore, 3, 4, basalt)
			ctx:set(shore, 3, 3, lamp)
		end
		for x = -4, 4, 4 do
			ctx:fill(x, -5, 3, x, 1, 3, basalt)
			ctx:set(x, 2, 3, lamp)
		end
		ctx:fill(11, 1, 1, 14, 4, 4, brick)
		ctx:fill(12, 1, 2, 13, 3, 3, "air")
		ctx:fill(11, 1, 2, 11, 2, 2, "air")
		ctx:set(13, 3, 3, lamp)
		ctx:sign(-10, 1, -2, S("Ferry crossing\nSaddle a strider\nFollow the lights"), 60)
		ctx:sign(10, 1, -2, S("Return pier\nFollow the lights"), 180)
		ctx:chest(-12, 1, 2, {
			"mcl_mobitems:saddle", "mcl_mobitems:warped_fungus_on_a_stick", "mcl_crimson:warped_fungus 2",
		})
		ctx:chest(12, 1, 2, {
			"mcl_nether:quartz " .. ctx.pr:next(4, 8), "mcl_core:gold_nugget " .. ctx.pr:next(4, 9),
		})
		if mcl_vars.mobs_spawn then
			ctx:spawn(-11, 1, 0, "mobs_mc:strider", {persistent = true})
			ctx:spawn(11, 1, 0, "mobs_mc:strider", {persistent = true})
		end
	end,
})

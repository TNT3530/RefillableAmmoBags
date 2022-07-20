local grabWhenFull = true;
local focusSupport = true;

local weaponAmmoInformation = {
	weaponsReady = 0,
	requireReset = 0,
	checkedForBag = false,
	bagIndex = -1
};

if RequiredScript == "lib/units/weapons/raycastweaponbase" then
	function RaycastWeaponBase:add_ammo(ratio, add_amount_override)
	
		if not weaponAmmoInformation.checkedForBag then
			for index, name in ipairs(managers.player:equipment_slots()) do
				if name == "ammo_bag" then
					weaponAmmoInformation.bagIndex = index;
				end
			end
			weaponAmmoInformation.checkedForBag = true;
		end
		
		if not weaponAmmoInformation[self.name_id] then
			weaponAmmoInformation[self.name_id] = {
				cache = 0,
				required = self:get_ammo_total() * (tweak_data.upgrades.ammo_bag_base + managers.player:upgrade_value_by_level("ammo_bag", "ammo_increase", 1)),
				half = false,
				quarter = false,
				three = false
			};
			--print("Registered Weapon Ammo");
		end
		
		if weaponAmmoInformation.requireReset > 0 then
			weaponAmmoInformation[self.name_id].cache = 0;
			weaponAmmoInformation[self.name_id].quarter = false;
			weaponAmmoInformation[self.name_id].half = false;
			weaponAmmoInformation[self.name_id].three = false;
			weaponAmmoInformation.requireReset = weaponAmmoInformation.requireReset - 1;
		end
		
		local function displayProgress(self)
			local percentage = weaponAmmoInformation[self.name_id].cache / weaponAmmoInformation[self.name_id].required;
			if (percentage >= 0.25) and (not weaponAmmoInformation[self.name_id].quarter) then
				managers.hud:show_hint({text = "Ammo Bag Progress: 25%"});
				weaponAmmoInformation[self.name_id].quarter = true;
			elseif (percentage >= 0.5) and (not weaponAmmoInformation[self.name_id].half) then
				managers.hud:show_hint({text = "Ammo Bag Progress: 50%"});
				weaponAmmoInformation[self.name_id].half = true;
			elseif (percentage >= 0.75) and (not weaponAmmoInformation[self.name_id].three) then
				managers.hud:show_hint({text = "Ammo Bag Progress: 75%"});
				weaponAmmoInformation[self.name_id].three = true;
			end
		end
	
		local function _add_ammo(ammo_base, ratio, add_amount_override)
			local multiplier_min = 1
			local multiplier_max = 1

			if ammo_base._ammo_data and ammo_base._ammo_data.ammo_pickup_min_mul then
				multiplier_min = ammo_base._ammo_data.ammo_pickup_min_mul
			else
				multiplier_min = managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1)
				multiplier_min = multiplier_min + managers.player:upgrade_value("player", "pick_up_ammo_multiplier_2", 1) - 1
				multiplier_min = multiplier_min + managers.player:crew_ability_upgrade_value("crew_scavenge", 0)
			end

			if ammo_base._ammo_data and ammo_base._ammo_data.ammo_pickup_max_mul then
				multiplier_max = ammo_base._ammo_data.ammo_pickup_max_mul
			else
				multiplier_max = managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1)
				multiplier_max = multiplier_max + managers.player:upgrade_value("player", "pick_up_ammo_multiplier_2", 1) - 1
				multiplier_max = multiplier_max + managers.player:crew_ability_upgrade_value("crew_scavenge", 0)
			end

			local add_amount = add_amount_override
			local picked_up = true

			if not add_amount then
				local rng_ammo = math.lerp(ammo_base._ammo_pickup[1] * multiplier_min, ammo_base._ammo_pickup[2] * multiplier_max, math.random())
				picked_up = rng_ammo > 0
				add_amount = math.max(0, math.round(rng_ammo))
			end

			add_amount = math.floor(add_amount * (ratio or 1));
			
			if ammo_base:get_ammo_max() == ammo_base:get_ammo_total() then
				if grabWhenFull and weaponAmmoInformation.bagIndex > -1 then
					weaponAmmoInformation[self.name_id].cache = weaponAmmoInformation[self.name_id].cache + add_amount;
					displayProgress(self);
					
					return true, 0;
				else
					return false, 0
				end
			else
				if focusSupport and (add_amount >= 2) and weaponAmmoInformation.bagIndex > -1 then
					local half_ammo = math.floor(add_amount / 2);
					
					weaponAmmoInformation[self.name_id].cache = weaponAmmoInformation[self.name_id].cache + half_ammo;
					add_amount = half_ammo;
				end
					
				local ammoToAdd = math.clamp(ammo_base:get_ammo_total() + add_amount, 0, ammo_base:get_ammo_max());
				
				local ammoOverflow = ammoToAdd - ammo_base:get_ammo_max();
				
				if weaponAmmoInformation.bagIndex > -1 then
					if ammoOverflow > 0 then
						weaponAmmoInformation[self.name_id].cache = weaponAmmoInformation[self.name_id].cache + ammoOverflow;
					end
				
					displayProgress(self);
				end
				
				ammo_base:set_ammo_total(ammoToAdd);
					
				return picked_up, add_amount;
			end
		end

		local picked_up, add_amount = nil
		picked_up, add_amount = _add_ammo(self, ratio, add_amount_override)

		if self.AKIMBO then
			local akimbo_rounding = self:get_ammo_total() % 2 + #self._fire_callbacks

			if akimbo_rounding > 0 then
				_add_ammo(self, nil, akimbo_rounding)
			end
		end

		for _, gadget in ipairs(self:get_all_override_weapon_gadgets()) do
			if gadget and gadget.ammo_base then
				local p, a = _add_ammo(gadget:ammo_base(), ratio, add_amount_override)
				picked_up = p or picked_up
				add_amount = add_amount + a
			end
		end

		--print("Weapon: " .. self.name_id);
		--print("Total Cache: " .. weaponAmmoInformation[self.name_id].cache);
		--print("Max Required Cache " .. weaponAmmoInformation[self.name_id].required);
		
		if weaponAmmoInformation[self.name_id].cache >= weaponAmmoInformation[self.name_id].required then
			weaponAmmoInformation.weaponsReady = weaponAmmoInformation.weaponsReady + 1;
		end
		
		if weaponAmmoInformation.weaponsReady > 2 then
			weaponAmmoInformation.weaponsReady = 0;
		end
		
		if (weaponAmmoInformation.weaponsReady == 2) then
			--print("Filling Bag");
			
			if weaponAmmoInformation.bagIndex > -1 then
				local equipment, index = managers.player:equipment_data_by_name("ammo_bag");
				local new_amount = Application:digest_value(equipment.amount[1], false) + 1;
				equipment.amount[1] = Application:digest_value(new_amount, true);
				
				local update_hud = false;

				if managers.player._equipment.selected_index and managers.player._equipment.selections[managers.player._equipment.selected_index].equipment ~= "ammo_bag" and Application:digest_value(managers.player._equipment.selections[managers.player._equipment.selected_index].amount[1], false) == 0 then
					managers.player._equipment.selected_index = index
					update_hud = true
				elseif _G.IS_VR then
					managers.player._equipment.selected_index = index
				end

				if update_hud and equipment then
					managers.hud:add_item({
						amount = Application:digest_value(equipment.amount[1], false),
						icon = equipment.icon
					})
					managers.player:update_deployable_equipment_amount_to_peers(equipment.equipment, new_amount)
				elseif managers.player._equipment.selected_index and managers.player._equipment.selections[managers.player._equipment.selected_index].equipment == sentry_type then
					managers.hud:set_item_amount(index, new_amount)
					managers.player:update_deployable_equipment_amount_to_peers(equipment.equipment, new_amount)
				end
				
				managers.hud:show_hint({text = "Filled Ammo Bag"})
			end
			
			weaponAmmoInformation.weaponsReady = 0;
			weaponAmmoInformation.requireReset = 2;
		end

		return picked_up, add_amount
	end
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

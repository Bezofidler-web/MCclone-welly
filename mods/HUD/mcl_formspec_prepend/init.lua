local pause_buttons = {
	"btn_continue", "btn_change_password", "btn_settings", "btn_sound",
	"btn_exit_menu", "btn_exit_os", "btn_respawn",
}
local pause_style = "style[" .. table.concat(pause_buttons, ",")
	.. ";border=false;bgimg=mcl_options_button.png;bgimg_middle=3;textcolor=#FFFFFF]"
for _, state in ipairs({ "hovered", "focused", "pressed" }) do
	pause_style = pause_style .. "style[" .. table.concat(pause_buttons, ":" .. state .. ",") .. ":" .. state
		.. ";bgimg=mcl_options_button_highlighted.png]"
end

core.register_on_joinplayer(function(player)
	player:set_formspec_prepend(mcl_vars.gui_nonbg .. mcl_vars.gui_bg_color .. mcl_vars.gui_bg_img .. pause_style)
end)

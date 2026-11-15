-- Minimal native Arch/Hyprland validation profile; full Omarchy is a later gate.
hl.monitor({ output = "DSI-1", mode = "preferred", position = "0x0", scale = 1.5 })
hl.monitor({ output = "Virtual-1", disabled = true })
hl.config({
  general = { gaps_in = 5, gaps_out = 10, border_size = 2 },
  decoration = { rounding = 8, blur = { enabled = false }, shadow = { enabled = false } },
  animations = { enabled = false },
  cursor = { no_hardware_cursors = 1 },
  xwayland = { enabled = false },
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
  debug = { disable_logs = false },
})
hl.on("hyprland.start", function()
  hl.exec_cmd("foot --title='Native Arch on SM-P613' /usr/local/bin/p613-desktop-proof")
end)

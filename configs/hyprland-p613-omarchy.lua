-- Keep the proven GPU/display profile and terminal, then start the real shell.
dofile('/etc/p613/hyprland-test.lua')
hl.config({ debug = { enable_stdout_logs = true, disable_logs = false } })
hl.on("hyprland.start", function()
  hl.exec_cmd("/usr/local/bin/p613-omarchy-session")
end)

-- Keep the tested base profile and expose startup failures in the RAM log.
dofile('/etc/p613/hyprland-test.lua')
hl.config({ debug = { enable_stdout_logs = true, disable_logs = false } })

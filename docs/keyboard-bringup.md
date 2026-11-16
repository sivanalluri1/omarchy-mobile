# Native on-screen keyboard experiment

The keyboard image extends the validated mobile profile with Arch's signed Squeekboard package, GTK 3, GSettings schemas, dconf, wtype and an explicit libbsd dependency. Revision 6 failed its first native startup because libbsd.so.0 was absent. Revision 7 checks Squeekboard's resolved libraries, the GTK fixture import and Hyprland config offline before packaging. Earlier tested images remain retained.

`p613-omarchy-session` sets the screen-keyboard-enabled setting and a US input source in the RAM user profile, starts Squeekboard on the private session D-Bus, and runs the Omarchy host. Its cleanup stops Squeekboard; the outer desktop test also stops the test user's processes. No systemd manager is started. The root launcher passes the upstream mobile profile's Wayland input-method environment explicitly because environment.d is not applied by this manual session. Portal/file-picker settings are not enabled as part of this keyboard test.

The mobile keyboard plugin reports visibility through omamobile-osk-watch and offers show/hide/toggle actions over sm.puri.OSK0. The image uses Squeekboard's stock layouts initially. Voice/clipboard/emoji action rows and language integration are not included in the initial validated scope.

`P613_EXPECT_OSK=1` makes the bounded desktop test require the keyboard's D-Bus Visible property and the plugin watcher, then check them periodically alongside the shell/mobile state. Visibility by itself does not establish typing. The Keyboard Test desktop entry opens a GTK entry that requests the known text `omarchy613` and Enter. It records only length, an expected-text match and Enter receipt in private RAM, rather than recording arbitrary typed content. The test can be launched through the same adapted GIO path as Foot.

Hardware results will be recorded after the native typing and visibility checks. Wi-Fi/audio/power services and current systemd compatibility remain separate work.

#!/usr/bin/env python3
"""On-tablet WPA2 test prompt. Credentials remain in the volatile user profile."""
import argparse
import hashlib
import json
from pathlib import Path
import os

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ssid', required=True)
a = p.parse_args()
ssid = a.ssid.encode('utf-8')
assert 1 <= len(ssid) <= 32
assert Path('/etc/p613-bringup').is_file()
assert os.getuid() == 1000
state = Path.home()/'.local/state/p613-wifi'
state.mkdir(parents=True, exist_ok=True, mode=0o700)
state.chmod(0o700)

window = Gtk.Window(title='Wi-Fi Connection Test')
window.set_default_size(520, 340)
window.set_border_width(24)
box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
window.add(box)
label = Gtk.Label(label=f'Connect to {a.ssid}\nEnter the Wi-Fi password below.\nCredentials are kept only in RAM.')
label.set_line_wrap(True)
box.pack_start(label, False, False, 0)
entry = Gtk.Entry()
entry.set_visibility(False)
entry.set_input_purpose(Gtk.InputPurpose.PASSWORD)
entry.set_placeholder_text('Wi-Fi password')
box.pack_start(entry, False, False, 0)
button = Gtk.Button(label='Connect')
box.pack_start(button, False, False, 0)
status = Gtk.Label(label='Ready for password')
status.set_line_wrap(True)
box.pack_start(status, False, False, 0)


def submit(*_):
    password = entry.get_text()
    if not 8 <= len(password) <= 63 or any(ord(c) < 32 or ord(c) > 126 for c in password):
        status.set_text('Use an 8–63 character WPA2 password.')
        return
    psk = hashlib.pbkdf2_hmac('sha1', password.encode(), ssid, 4096, 32).hex()
    password = None
    entry.set_text('')
    config = 'ctrl_interface=/run/p613-wpa\nupdate_config=0\nnetwork={\n'
    config += f'    ssid={ssid.hex()}\n    psk={psk}\n'
    config += '    key_mgmt=WPA-PSK\n    proto=RSN\n    pairwise=CCMP\n    group=CCMP\n}\n'
    temporary = state/'request.tmp'
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as stream:
        stream.write(config)
    temporary.replace(state/'request.conf')
    (state/'status.json').unlink(missing_ok=True)
    button.set_sensitive(False)
    status.set_text('Credentials ready. Waiting for connection test…')


def refresh():
    path = state/'status.json'
    if path.exists():
        try:
            data = json.loads(path.read_text())
            if data.get('state') == 'connected':
                status.set_text('Connected. Network test passed.')
            elif data.get('state') == 'failed':
                status.set_text('Connection failed. Check the password and try again.')
                button.set_sensitive(True)
        except (ValueError, OSError):
            pass
    return True


button.connect('clicked', submit)
entry.connect('activate', submit)
window.connect('destroy', Gtk.main_quit)
GLib.timeout_add_seconds(2, refresh)
window.show_all()
Gtk.main()

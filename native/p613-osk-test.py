#!/usr/bin/python3
"""A visible input fixture; record only a match against the requested test text."""
import json
import os
from pathlib import Path
os.environ['GDK_BACKEND']='wayland'
import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk

expected='omarchy613'
result={'length':0,'expected_text_match':False,'enter_received':False}
log=Path('/tmp/p613-osk-test-result.json')
window=Gtk.Window(title='Keyboard Test')
window.set_default_size(600,600)
window.connect('destroy',Gtk.main_quit)
box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=20)
box.set_border_width(24)
window.add(box)
label=Gtk.Label(label='Tap the field and type omarchy613, then press Enter.')
label.set_line_wrap(True)
box.pack_start(label,False,False,0)
entry=Gtk.Entry()
entry.set_placeholder_text('omarchy613')
entry.set_input_purpose(Gtk.InputPurpose.FREE_FORM)
box.pack_start(entry,False,False,0)
status=Gtk.Label(label='Waiting for input')
box.pack_start(status,False,False,0)
def save():
    log.write_text(json.dumps(result,indent=2)+'\n')
def changed(widget):
    text=widget.get_text()
    result.update(length=len(text),expected_text_match=text==expected,enter_received=False)
    status.set_text('Text matches' if result['expected_text_match'] else 'Typing…')
    save()
def activated(widget):
    result['enter_received']=True
    status.set_text('Text and Enter received' if result['expected_text_match'] else 'Enter received; check the text')
    save()
entry.connect('changed',changed)
entry.connect('activate',activated)
save()
window.show_all()
Gtk.main()

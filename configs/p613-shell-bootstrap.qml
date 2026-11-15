//@ pragma OmarchyLoadPatch
import QtQuick
import Quickshell
import Quickshell.Io

// Qt's old-kernel forkfd fallback must initialize in the parent before any
// startDetached() can initialize it inside a shared-memory vfork child.
ShellRoot {
  Process {
    command: ["/usr/bin/true"]
    running: true
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        console.error("P613_FORKFD_PRIME_FAILED", exitCode)
        Qt.quit()
        return
      }
      console.info("P613_FORKFD_PRIMED")
      host.active = true
    }
  }
  LazyLoader {
    id: host
    active: false
    source: "p613-upstream-shell.qml"
  }
}

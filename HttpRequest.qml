import QtQuick
import Quickshell.Io

// Bounded, fixed-host HTTPS transport. Destroying a request cancels its process.
QtObject {
  id: root
  required property string url
  signal finished(bool ok, string body)
  property Process process: Process {
    command: ["curl", "-fsS", "--max-time", "12", "--max-filesize", "262144", "--proto", "=https", root.url]
    running: true
    stdout: StdioCollector {
      id: output
      waitForEnd: true
    }
    onExited: code => root.finished(code === 0, output.text)
  }
}

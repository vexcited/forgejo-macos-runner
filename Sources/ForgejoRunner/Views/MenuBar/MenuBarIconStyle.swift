// how the menu bar mark shows the controller state, in the monochrome style of menu
// bar icons.
enum MenuBarIconStyle: Hashable {
  case stopped
  case listening
  case working
  case attention

  init(_ status: ControllerStatus) {
    switch status {
    case .stopped: self = .stopped
    case .waiting: self = .listening
    case .preparing, .running, .busy, .stopping: self = .working
    case .failed, .retrying: self = .attention
    }
  }
}

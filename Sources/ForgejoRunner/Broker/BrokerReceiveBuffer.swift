import Foundation

// bytes received on one connection, kept in a reference so appends do not copy.
final class BrokerReceiveBuffer {
  var data = Data()
}

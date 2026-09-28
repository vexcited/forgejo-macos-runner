import Foundation
import Network

// asks the router of the current network for its public address, over nat-pmp and
// then upnp, so no outside service learns when this mac starts a runner. only answers
// that come from the default gateway itself are used.
nonisolated enum RouterAddress {
  static func publicIPv4() async -> String? {
    guard let gateway = await defaultGateway() else { return nil }
    let natPMP = Task.detached(operation: { NATPMPLookup.publicIPv4(gateway: gateway) })
    if let address = await natPMP.value {
      return address
    }
    return await UPnPLookup.publicIPv4(gateway: gateway)
  }

  // the ipv4 default gateway of the current network path.
  static func defaultGateway() async -> String? {
    let monitor = NWPathMonitor()
    let answered = OneShot()
    return await withCheckedContinuation { continuation in
      monitor.pathUpdateHandler = { path in
        guard answered.claim() else { return }
        monitor.cancel()
        let gateway = path.gateways.lazy.compactMap { endpoint -> String? in
          guard case .hostPort(.ipv4(let address), _) = endpoint else { return nil }
          return address.rawValue.map(String.init).joined(separator: ".")
        }.first
        continuation.resume(returning: gateway)
      }
      monitor.start(queue: DispatchQueue(label: "com.vexcited.forgejo.runner.gateway"))
    }
  }
}

import Foundation
import GuestKit

// upnp internet gateway device: find it with ssdp, read its description and ask the
// wan connection service for its external address. every url must point at the
// gateway, so a device elsewhere on the lan cannot steer these requests.
nonisolated enum UPnPLookup {
  static func publicIPv4(gateway: String) async -> String? {
    let search = Task.detached(operation: { SSDPDiscovery.location(gateway: gateway) })
    guard let location = await search.value,
      isOnGateway(location, gateway: gateway)
    else { return nil }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 3
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.connectionProxyDictionary = [:]
    let session = URLSession(
      configuration: configuration, delegate: NoRedirects.shared, delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    guard let (data, response) = try? await session.data(from: location),
      (response as? HTTPURLResponse)?.statusCode == 200,
      let description = String(data: data.prefix(65_536), encoding: .utf8),
      let (serviceType, controlPath) = wanService(in: description),
      let control = URL(string: controlPath, relativeTo: location)?.absoluteURL,
      isOnGateway(control, gateway: gateway)
    else { return nil }
    var request = URLRequest(url: control)
    request.httpMethod = "POST"
    request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
    request.setValue("\"\(serviceType)#GetExternalIPAddress\"", forHTTPHeaderField: "SOAPAction")
    request.httpBody = Data(
      """
      <?xml version="1.0"?>
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
      <s:Body><u:GetExternalIPAddress xmlns:u="\(serviceType)"/></s:Body>
      </s:Envelope>
      """.utf8)
    guard let (reply, replyResponse) = try? await session.data(for: request),
      (replyResponse as? HTTPURLResponse)?.statusCode == 200,
      let body = String(data: reply.prefix(16_384), encoding: .utf8),
      let address = element("NewExternalIPAddress", in: body),
      SessionPreparation.isPublicIPv4(address)
    else { return nil }
    return address
  }

  private static func isOnGateway(_ url: URL, gateway: String) -> Bool {
    url.scheme == "http" && url.host() == gateway && url.user == nil
  }

  // the first wan connection service and its control url in a device description.
  private static func wanService(in description: String) -> (type: String, control: String)? {
    let services = description.components(separatedBy: "<service>").dropFirst()
    for service in services {
      guard let type = element("serviceType", in: service),
        type.hasPrefix("urn:schemas-upnp-org:service:WANIPConnection:")
          || type.hasPrefix("urn:schemas-upnp-org:service:WANPPPConnection:"),
        type.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || ":-.".contains($0)) }),
        let control = element("controlURL", in: service)
      else { continue }
      return (type, control)
    }
    return nil
  }

  private static func element(_ name: String, in text: String) -> String? {
    guard let start = text.range(of: "<\(name)>"),
      let end = text.range(of: "</\(name)>", range: start.upperBound..<text.endIndex)
    else { return nil }
    return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(
      in: .whitespacesAndNewlines)
  }
}

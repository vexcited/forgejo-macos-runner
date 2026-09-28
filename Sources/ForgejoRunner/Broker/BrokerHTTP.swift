import Foundation

// just enough http/1.1 for the broker: the CONNECT request of the proxy and the
// connect rpc posts the guest runner sends through the tunnel. anything unusual is
// rejected instead of interpreted, since the other end is an untrusted vm.
nonisolated enum BrokerHTTP {
  static let maximumHeadBytes = 16_384
  static let maximumBodyBytes = 16 * 1_048_576

  struct Request: Equatable {
    let method: String
    let target: String
    // lowercased names, a repeated header makes the request invalid.
    let headers: [String: String]
    let body: Data
  }

  enum ParseResult: Equatable {
    case incomplete
    case invalid
    case request(Request, consumed: Int)
  }

  private static let headTerminator = Data("\r\n\r\n".utf8)

  // parses one request from the start of the buffer, with its body unless headOnly.
  // buffers larger than any valid request are invalid rather than incomplete.
  static func parse(_ buffer: Data, headOnly: Bool = false) -> ParseResult {
    guard buffer.count <= maximumHeadBytes + maximumBodyBytes + headTerminator.count,
      let headEnd = buffer.range(of: headTerminator)
    else {
      return buffer.count > maximumHeadBytes ? .invalid : .incomplete
    }
    guard headEnd.lowerBound - buffer.startIndex <= maximumHeadBytes,
      let head = String(data: buffer[buffer.startIndex..<headEnd.lowerBound], encoding: .utf8)
    else { return .invalid }
    let lines = head.components(separatedBy: "\r\n")
    // no control character on any line, so nothing smuggles a line break or a nul.
    guard
      !lines.contains(where: { line in
        line.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7f }
      })
    else { return .invalid }
    let requestLine = lines[0].split(separator: " ", omittingEmptySubsequences: false)
    guard requestLine.count == 3, requestLine[2] == "HTTP/1.1" || requestLine[2] == "HTTP/1.0"
    else { return .invalid }
    var headers: [String: String] = [:]
    for line in lines.dropFirst() {
      guard let colon = line.firstIndex(of: ":") else { return .invalid }
      let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
      let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
      guard !name.isEmpty, headers[name] == nil else { return .invalid }
      headers[name] = value
    }
    let bodyStart = headEnd.upperBound
    let method = String(requestLine[0])
    let target = String(requestLine[1])
    if headOnly {
      return .request(
        Request(method: method, target: target, headers: headers, body: Data()),
        consumed: bodyStart - buffer.startIndex)
    }

    // connect sends unary calls with a length, so chunked bodies are never needed.
    guard headers["transfer-encoding"] == nil else { return .invalid }
    let length: Int
    if let value = headers["content-length"] {
      guard let parsed = Int(value), parsed >= 0, parsed <= maximumBodyBytes else {
        return .invalid
      }
      length = parsed
    } else {
      length = 0
    }
    guard buffer.endIndex - bodyStart >= length else { return .incomplete }
    return .request(
      Request(
        method: method, target: target, headers: headers,
        body: Data(buffer[bodyStart..<bodyStart + length])),
      consumed: bodyStart + length - buffer.startIndex)
  }

  static func response(
    status: Int, contentType: String? = nil, body: Data = Data(), close: Bool = false
  ) -> Data {
    var head = "HTTP/1.1 \(status) \(reason(for: status))\r\n"
    if let contentType {
      head += "Content-Type: \(contentType)\r\n"
    }
    head += "Content-Length: \(body.count)\r\n"
    head += close ? "Connection: close\r\n\r\n" : "Connection: keep-alive\r\n\r\n"
    return Data(head.utf8) + body
  }

  // a connect protocol error, which the runner reports with its code and message.
  static func connectError(status: Int, code: String, message: String) -> Data {
    let body = try? JSONSerialization.data(withJSONObject: ["code": code, "message": message])
    return response(status: status, contentType: "application/json", body: body ?? Data())
  }

  private static func reason(for status: Int) -> String {
    switch status {
    case 200: "OK"
    case 400: "Bad Request"
    case 403: "Forbidden"
    case 405: "Method Not Allowed"
    case 407: "Proxy Authentication Required"
    case 415: "Unsupported Media Type"
    case 502: "Bad Gateway"
    default: "Status"
    }
  }
}

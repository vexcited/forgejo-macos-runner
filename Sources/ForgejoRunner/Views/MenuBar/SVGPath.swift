import AppKit

// reads the absolute move, line, curve and close commands of an svg path.
nonisolated enum SVGPath {
  static func bezierPath(_ data: String) -> NSBezierPath {
    let path = NSBezierPath()
    var tokens = tokenize(data)[...]
    var command: Character = "M"
    var current = CGPoint.zero
    func number() -> CGFloat {
      guard case .number(let value) = tokens.popFirst() else { return 0 }
      return value
    }
    while let token = tokens.first {
      if case .command(let letter) = token {
        command = letter
        tokens.removeFirst()
        if letter == "Z" {
          path.close()
          continue
        }
      }
      switch command {
      case "M":
        current = CGPoint(x: number(), y: number())
        path.move(to: current)
        command = "L"
      case "L":
        current = CGPoint(x: number(), y: number())
        path.line(to: current)
      case "H":
        current.x = number()
        path.line(to: current)
      case "V":
        current.y = number()
        path.line(to: current)
      case "C":
        let first = CGPoint(x: number(), y: number())
        let second = CGPoint(x: number(), y: number())
        current = CGPoint(x: number(), y: number())
        path.curve(to: current, controlPoint1: first, controlPoint2: second)
      default:
        tokens.removeFirst()
      }
    }
    return path
  }

  private enum Token {
    case command(Character)
    case number(CGFloat)
  }

  private static func tokenize(_ data: String) -> [Token] {
    var tokens: [Token] = []
    var digits = ""
    func flush() {
      if let value = Double(digits) { tokens.append(.number(CGFloat(value))) }
      digits = ""
    }
    for character in data {
      if character.isLetter {
        flush()
        tokens.append(.command(character))
      } else if character == "-" && !digits.isEmpty {
        flush()
        digits = "-"
      } else if character.isNumber || character == "." || character == "-" {
        digits.append(character)
      } else {
        flush()
      }
    }
    flush()
    return tokens
  }
}

import Foundation

/// Turns a partially-streamed JSON object into a decodable, well-formed object by cutting
/// at the last structurally-closed boundary (`}` or `]`) and appending the closers for any
/// still-open brackets. Because it only cuts where an object/array element has *fully*
/// arrived, every value in the result is complete — no half-written strings or numbers —
/// so the lenient document decoders can render whatever has streamed so far.
public enum PartialJSONCompleter {
  /// Returns a complete JSON object string built from the completed portion of `raw`, or
  /// `nil` if no inner object/array has closed yet.
  public static func completedObject(from raw: String) -> String? {
    guard let start = raw.firstIndex(of: "{") else { return nil }
    let chars = Array(raw[start...])

    var stack: [Character] = []
    var inString = false
    var escaped = false
    var lastCutIndex: Int?
    var lastCutStack: [Character] = []

    for (index, character) in chars.enumerated() {
      if inString {
        if escaped {
          escaped = false
        } else if character == "\\" {
          escaped = true
        } else if character == "\"" {
          inString = false
        }
        continue
      }

      switch character {
      case "\"":
        inString = true
      case "{":
        stack.append("}")
      case "[":
        stack.append("]")
      case "}", "]":
        if !stack.isEmpty { stack.removeLast() }
        // A bracket just closed: everything up to here is a complete structure. Record it
        // as a safe cut point together with the brackets that remain open.
        lastCutIndex = index
        lastCutStack = stack
      default:
        break
      }
    }

    guard let cut = lastCutIndex else { return nil }
    var result = String(chars[0...cut])
    // Close the still-open brackets, innermost first.
    result.append(contentsOf: lastCutStack.reversed())
    return result
  }
}

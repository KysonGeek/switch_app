import Foundation

/// One key on the rendered keyboard.
struct KeyCap: Identifiable {
    let id = UUID()
    let label: String      // what we draw when no window is assigned
    let char: String       // lowercase character used for matching key presses
    var window: WindowInfo?
}

enum KeyboardLayout {

    // Visual rows (top to bottom): numbers, then the three letter rows.
    private static let numberRow = "1234567890"
    private static let topRow    = "qwertyuiop"
    private static let homeRow   = "asdfghjkl"
    private static let bottomRow = "zxcvbnm"

    /// Order in which discovered windows are bound to keys:
    /// home row → top row → bottom row → numbers (easiest-to-reach first).
    static let assignmentOrder: [String] =
        Array((homeRow + topRow + bottomRow + numberRow).map { String($0) })

    /// How many windows can be bound to keys (26 letters + 10 digits = 36).
    static var capacity: Int { assignmentOrder.count }

    /// The static keyboard skeleton (letters + numbers only), before windows are assigned.
    private static func skeleton() -> [[KeyCap]] {
        func row(_ chars: String) -> [KeyCap] {
            chars.map { c in
                KeyCap(label: String(c).uppercased(), char: String(c), window: nil)
            }
        }
        return [row(numberRow), row(topRow), row(homeRow), row(bottomRow)]
    }

    /// Build the keyboard with `windows` bound to keys following `assignmentOrder`.
    static func build(with windows: [WindowInfo]) -> [[KeyCap]] {
        var rows = skeleton()
        var mapping: [String: WindowInfo] = [:]
        for (i, win) in windows.enumerated() where i < assignmentOrder.count {
            mapping[assignmentOrder[i]] = win
        }
        for r in rows.indices {
            for c in rows[r].indices {
                if let win = mapping[rows[r][c].char] {
                    rows[r][c].window = win
                }
            }
        }
        return rows
    }
}

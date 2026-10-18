import Foundation

extension String {
    var sentenceCased: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst().lowercased()
    }
}

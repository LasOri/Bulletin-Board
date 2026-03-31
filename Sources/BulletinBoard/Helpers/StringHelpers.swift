// Foundation-free string helpers for Bulletin Board
// These replace Foundation's CharacterSet-based methods and URL utilities.

extension String {
    /// Split string by whitespace and newlines (replaces `components(separatedBy: .whitespacesAndNewlines)`)
    func splitByWhitespace() -> [String] {
        var result: [String] = []
        var current = ""
        for ch in self {
            if ch.isWhitespace || ch.isNewline {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }

    /// Trim punctuation from both ends (replaces `trimmingCharacters(in: .punctuationCharacters)`)
    func trimmingPunctuation() -> String {
        var s = self[...]
        while let first = s.first, first.isPunctuation { s = s.dropFirst() }
        while let last = s.last, last.isPunctuation { s = s.dropLast() }
        return String(s)
    }

    /// Case-insensitive findRange (replaces `range(of:options:.caseInsensitive)`)
    func findRangeIgnoringCase(of target: String) -> Range<String.Index>? {
        let lowerSelf = self.lowercased()
        let lowerTarget = target.lowercased()
        guard let range = lowerSelf.findRange(of: lowerTarget) else { return nil }
        // Map indices back to original string
        let startOffset = lowerSelf.distance(from: lowerSelf.startIndex, to: range.lowerBound)
        let endOffset = lowerSelf.distance(from: lowerSelf.startIndex, to: range.upperBound)
        let origStart = self.index(self.startIndex, offsetBy: startOffset)
        let origEnd = self.index(self.startIndex, offsetBy: endOffset)
        return origStart..<origEnd
    }

    /// Case-insensitive findRange starting from a given index
    func findRangeIgnoringCase(of target: String, from start: String.Index) -> Range<String.Index>? {
        let startOffset = self.distance(from: self.startIndex, to: start)
        let lowerSelf = self.lowercased()
        let lowerTarget = target.lowercased()
        let lowerStart = lowerSelf.index(lowerSelf.startIndex, offsetBy: startOffset)
        guard let range = lowerSelf.findRange(of: lowerTarget, from: lowerStart) else { return nil }
        let foundOffset = lowerSelf.distance(from: lowerSelf.startIndex, to: range.lowerBound)
        let endOffset = lowerSelf.distance(from: lowerSelf.startIndex, to: range.upperBound)
        let origStart = self.index(self.startIndex, offsetBy: foundOffset)
        let origEnd = self.index(self.startIndex, offsetBy: endOffset)
        return origStart..<origEnd
    }

    /// Percent-encode for URL query parameters (replaces `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)`)
    func percentEncodeForURL() -> String {
        var result = ""
        let allowed: Set<Character> = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=")
        for char in self {
            if allowed.contains(char) {
                result.append(char)
            } else {
                for byte in String(char).utf8 {
                    result += "%"
                    result += String(byte >> 4, radix: 16, uppercase: true)
                    result += String(byte & 0x0F, radix: 16, uppercase: true)
                }
            }
        }
        return result
    }

    /// Basic URL validation (replaces `URL(string:) != nil`)
    func isValidURL() -> Bool {
        hasPrefix("http://") || hasPrefix("https://")
    }

    /// Extract scheme and host from a URL string (replaces Foundation URL properties)
    func urlSchemeAndHost() -> (scheme: String, host: String)? {
        for prefix in ["https://", "http://"] {
            if self.hasPrefix(prefix) {
                let scheme = String(prefix.dropLast(3)) // "https" or "http"
                let rest = String(self.dropFirst(prefix.count))
                // Host is everything up to first / or end
                let host: String
                if let slashIdx = rest.firstIndex(of: "/") {
                    host = String(rest[rest.startIndex..<slashIdx])
                } else {
                    host = rest
                }
                guard !host.isEmpty else { return nil }
                return (scheme: scheme, host: host)
            }
        }
        return nil
    }
}

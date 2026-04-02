extension String {
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

    func trimmingPunctuation() -> String {
        var s = self[...]
        while let first = s.first, first.isPunctuation { s = s.dropFirst() }
        while let last = s.last, last.isPunctuation { s = s.dropLast() }
        return String(s)
    }

    func findRangeIgnoringCase(of target: String) -> Range<String.Index>? {
        let lowerSelf = self.lowercased()
        let lowerTarget = target.lowercased()
        guard let range = lowerSelf.findRange(of: lowerTarget) else { return nil }
        let startOffset = lowerSelf.distance(from: lowerSelf.startIndex, to: range.lowerBound)
        let endOffset = lowerSelf.distance(from: lowerSelf.startIndex, to: range.upperBound)
        let origStart = self.index(self.startIndex, offsetBy: startOffset)
        let origEnd = self.index(self.startIndex, offsetBy: endOffset)
        return origStart..<origEnd
    }

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

    func isValidURL() -> Bool {
        hasPrefix("http://") || hasPrefix("https://")
    }

    func strippingHTML() -> String {
        var result = ""
        result.reserveCapacity(count)
        var inTag = false
        for ch in self {
            if ch == "<" {
                inTag = true
            } else if ch == ">" {
                inTag = false
                result.append(" ")
            } else if !inTag {
                result.append(ch)
            }
        }
        result = result.replacingAll("&amp;", with: "&")
        result = result.replacingAll("&lt;", with: "<")
        result = result.replacingAll("&gt;", with: ">")
        result = result.replacingAll("&quot;", with: "\"")
        result = result.replacingAll("&#39;", with: "'")
        result = result.replacingAll("&nbsp;", with: " ")
        result = result.replacingAll("&#x2F;", with: "/")
        var collapsed = ""
        collapsed.reserveCapacity(result.count)
        var lastWasSpace = false
        for ch in result {
            if ch.isWhitespace || ch.isNewline {
                if !lastWasSpace {
                    collapsed.append(" ")
                    lastWasSpace = true
                }
            } else {
                collapsed.append(ch)
                lastWasSpace = false
            }
        }
        var s = collapsed[...]
        while s.first?.isWhitespace == true { s = s.dropFirst() }
        while s.last?.isWhitespace == true { s = s.dropLast() }
        return String(s)
    }

    func strippingURLs() -> String {
        let words = self.splitByWhitespace()
        var result: [String] = []
        for word in words {
            let lower = word.lowercased()
            if lower.hasPrefix("http://") || lower.hasPrefix("https://") ||
               lower.hasPrefix("www.") || lower.contains("://") {
                continue
            }
            if word.contains("/") && word.count > 15 {
                continue
            }
            result.append(word)
        }
        return result.joined(separator: " ")
    }

    func urlSchemeAndHost() -> (scheme: String, host: String)? {
        for prefix in ["https://", "http://"] {
            if self.hasPrefix(prefix) {
                let scheme = String(prefix.dropLast(3))
                let rest = String(self.dropFirst(prefix.count))
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

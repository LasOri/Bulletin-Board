enum InputSanitizer {

    static func sanitizeText(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(ch)
            }
        }
        return result
    }

    static func sanitizeURL(_ url: String) -> String {
        var trimmed = url
        while trimmed.first?.isWhitespace == true || trimmed.first?.isNewline == true {
            trimmed = String(trimmed.dropFirst())
        }
        while trimmed.last?.isWhitespace == true || trimmed.last?.isNewline == true {
            trimmed = String(trimmed.dropLast())
        }
        let lower = trimmed.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else {
            return "#"
        }
        return trimmed
    }
}

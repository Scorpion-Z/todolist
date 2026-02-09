import Foundation

struct QuickAddParseResult {
    let title: String
    let priority: TodoItem.Priority
    let dueDate: Date?
    let recognizedTokens: [String]
}

struct QuickAddParser {
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(calendar: Calendar = .current, nowProvider: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func parse(_ rawText: String) -> QuickAddParseResult {
        let normalized = rawText
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "。", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return QuickAddParseResult(title: "", priority: .medium, dueDate: nil, recognizedTokens: [])
        }

        var remainingTokens = tokenize(normalized)
        var recognizedTokens: [String] = []

        let priority = parsePriority(from: &remainingTokens, recognizedTokens: &recognizedTokens) ?? .medium

        let dueDate = parseDate(from: &remainingTokens, recognizedTokens: &recognizedTokens)

        let title = remainingTokens.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return QuickAddParseResult(
            title: title,
            priority: priority,
            dueDate: dueDate,
            recognizedTokens: recognizedTokens
        )
    }

    private func parsePriority(
        from tokens: inout [String],
        recognizedTokens: inout [String]
    ) -> TodoItem.Priority? {
        guard let index = tokens.firstIndex(where: { token in
            let lower = token.lowercased()
            return lower == "p1" || lower == "p2" || lower == "p3"
        }) else {
            return nil
        }

        let token = tokens.remove(at: index)
        recognizedTokens.append(token)

        switch token.lowercased() {
        case "p1":
            return .high
        case "p2":
            return .medium
        case "p3":
            return .low
        default:
            return nil
        }
    }

    private func parseDate(
        from tokens: inout [String],
        recognizedTokens: inout [String]
    ) -> Date? {
        guard let dateTokenIndex = tokens.firstIndex(where: isDateKeyword) else {
            return nil
        }

        let dateToken = tokens.remove(at: dateTokenIndex)
        recognizedTokens.append(dateToken)

        guard var date = resolveDate(from: dateToken) else {
            return nil
        }

        if let timeTokenIndex = tokens.firstIndex(where: isTimeToken) {
            let timeToken = tokens.remove(at: timeTokenIndex)
            recognizedTokens.append(timeToken)
            date = applyTime(timeToken, to: date) ?? date
        }

        return date
    }

    private func isDateKeyword(_ token: String) -> Bool {
        if token == "今天" || token == "明天" || token == "后天" || token == "下周" {
            return true
        }
        if token.hasPrefix("周") || token.hasPrefix("星期") {
            return weekdayNumber(from: token) != nil
        }
        if token.hasPrefix("下周") {
            return weekdayNumber(from: token) != nil
        }
        if shouldUseEnglishRules(for: token) {
            let lower = token.lowercased()
            if lower == "today" || lower == "tomorrow" || lower == "next_week" || lower == "day_after_tomorrow" {
                return true
            }
            if weekdayMatch(from: lower) != nil {
                return true
            }
        }
        return false
    }

    private func isTimeToken(_ token: String) -> Bool {
        let normalized = token.replacingOccurrences(of: "：", with: ":")
        let colonPattern = #"^([01]?\d|2[0-3]):([0-5]\d)$"#
        if normalized.range(of: colonPattern, options: .regularExpression) != nil {
            return true
        }
        let chinesePattern = #"^(上午|下午|晚上|中午)?([01]?\d|2[0-3])点(半|([0-5]?\d)分?)?$"#
        return normalized.range(of: chinesePattern, options: .regularExpression) != nil
    }

    private func resolveDate(from token: String) -> Date? {
        let now = nowProvider()

        if token == "今天" {
            return calendar.startOfDay(for: now)
        }

        if token == "明天", let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            return tomorrow
        }

        if token == "后天", let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now)) {
            return dayAfterTomorrow
        }

        if token == "下周", let nextWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) {
            return nextWeek
        }

        if shouldUseEnglishRules(for: token) {
            let lower = token.lowercased()
            if lower == "today" {
                return calendar.startOfDay(for: now)
            }
            if lower == "tomorrow", let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                return tomorrow
            }
            if lower == "day_after_tomorrow",
               let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now)) {
                return dayAfterTomorrow
            }
            if lower == "next_week", let nextWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) {
                return nextWeek
            }
        }

        guard let (targetWeekday, forceNextWeek) = weekdayMatch(from: token) else {
            return nil
        }

        let startToday = calendar.startOfDay(for: now)
        let currentWeekday = calendar.component(.weekday, from: startToday)
        var delta = (targetWeekday - currentWeekday + 7) % 7
        if forceNextWeek && delta == 0 {
            delta = 7
        }

        return calendar.date(byAdding: .day, value: delta, to: startToday)
    }

    private func weekdayNumber(from token: String) -> Int? {
        if shouldUseEnglishRules(for: token) {
            let trimmed = token.lowercased().replacingOccurrences(of: "next_", with: "")
            if let englishWeekday = englishWeekdayNumber(from: trimmed) {
                return englishWeekday
            }
        }

        let normalized = token.replacingOccurrences(of: "星期", with: "周")
        let trimmed = normalized.replacingOccurrences(of: "下周", with: "周")
        guard trimmed.count >= 2 else { return nil }
        let suffix = String(trimmed.dropFirst())

        switch suffix {
        case "一": return 2
        case "二": return 3
        case "三": return 4
        case "四": return 5
        case "五": return 6
        case "六": return 7
        case "日", "天": return 1
        default: return nil
        }
    }

    private func weekdayMatch(from token: String) -> (weekday: Int, forceNextWeek: Bool)? {
        let lower = token.lowercased()
        let isNextWeek = token.hasPrefix("下周") || lower.hasPrefix("next_")
        let weekdayToken = lower.hasPrefix("next_") ? String(lower.dropFirst(5)) : token
        guard let weekday = weekdayNumber(from: weekdayToken) else { return nil }
        return (weekday, isNextWeek)
    }

    private func applyTime(_ token: String, to date: Date) -> Date? {
        let normalized = token.replacingOccurrences(of: "：", with: ":")
        if normalized.contains(":") {
            let parts = normalized.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else {
                return nil
            }

            return calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: date
            )
        }

        guard let components = parseChineseTime(normalized) else {
            return nil
        }

        return calendar.date(
            bySettingHour: components.hour,
            minute: components.minute,
            second: 0,
            of: date
        )
    }

    private func parseChineseTime(_ token: String) -> (hour: Int, minute: Int)? {
        let pattern = #"^(上午|下午|晚上|中午)?([01]?\d|2[0-3])点(半|([0-5]?\d)分?)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: token, range: NSRange(token.startIndex..., in: token)) else {
            return nil
        }

        let periodRange = Range(match.range(at: 1), in: token)
        let hourRange = Range(match.range(at: 2), in: token)
        let minuteTokenRange = Range(match.range(at: 4), in: token)
        let halfRange = Range(match.range(at: 3), in: token)

        guard let hourRange,
              let hour = Int(token[hourRange]) else {
            return nil
        }

        var minute = 0
        if let halfRange, token[halfRange].contains("半") {
            minute = 30
        } else if let minuteTokenRange, let parsedMinute = Int(token[minuteTokenRange]) {
            minute = parsedMinute
        }

        var adjustedHour = hour
        if let periodRange {
            let period = token[periodRange]
            if (period == "下午" || period == "晚上") && hour < 12 {
                adjustedHour = hour + 12
            }
            if period == "中午", hour < 11 {
                adjustedHour = hour + 12
            }
            if period == "上午", hour == 12 {
                adjustedHour = 0
            }
        }

        return (adjustedHour, minute)
    }

    private func tokenize(_ text: String) -> [String] {
        let useEnglish = shouldUseEnglishRules(for: text)
        var spaced = text
        if useEnglish {
            spaced = applyEnglishPhraseSpacing(to: spaced)
        }

        var spacingPatterns = [
            #"(今天|明天|后天|下周[一二三四五六日天]?|周[一二三四五六日天]|星期[一二三四五六日天])"#,
            #"([01]?\d|2[0-3])[:：][0-5]\d"#,
            #"(上午|下午|晚上|中午)?([01]?\d|2[0-3])点(半|([0-5]?\d)分?)?"#
        ]

        if useEnglish {
            spacingPatterns.append(#"(?i)\b(today|tomorrow|next_week|day_after_tomorrow|mon(day)?|tue(s(day)?)?|wed(nesday)?|thu(r(s(day)?)?)?|fri(day)?|sat(urday)?|sun(day)?|next_(mon(day)?|tue(s(day)?)?|wed(nesday)?|thu(r(s(day)?)?)?|fri(day)?|sat(urday)?|sun(day)?))\b"#)
        }

        for pattern in spacingPatterns {
            spaced = spaced.replacingOccurrences(of: pattern, with: " $0 ", options: .regularExpression)
        }

        return spaced
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    private func shouldUseEnglishRules(for text: String) -> Bool {
        let localeIsEnglish = Locale.current.languageCode?.hasPrefix("en") ?? false
        let hasLatinLetters = text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
        return localeIsEnglish || hasLatinLetters
    }

    private func englishWeekdayNumber(from token: String) -> Int? {
        switch token {
        case "mon", "monday": return 2
        case "tue", "tues", "tuesday": return 3
        case "wed", "weds", "wednesday": return 4
        case "thu", "thur", "thurs", "thursday": return 5
        case "fri", "friday": return 6
        case "sat", "saturday": return 7
        case "sun", "sunday": return 1
        default: return nil
        }
    }

    private func applyEnglishPhraseSpacing(to text: String) -> String {
        var result = text
        result = replaceRegex(#"(?i)\bday\s+after\s+tomorrow\b"#, in: result, with: " day_after_tomorrow ")
        result = replaceRegex(#"(?i)\bnext\s+week\b"#, in: result, with: " next_week ")
        result = replaceRegex(
            #"(?i)\bnext\s+(mon(day)?|tue(s(day)?)?|wed(nesday)?|thu(r(s(day)?)?)?|fri(day)?|sat(urday)?|sun(day)?)\b"#,
            in: result,
            with: " next_$1 "
        )
        return result
    }

    private func replaceRegex(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}

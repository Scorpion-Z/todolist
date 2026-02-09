import Foundation

struct QuickAddParseResult {
    let title: String
    let priority: TodoItem.Priority
    let dueDate: Date?
    let repeatRule: TodoItem.RepeatRule
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
            return QuickAddParseResult(title: "", priority: .medium, dueDate: nil, repeatRule: .none, recognizedTokens: [])
        }

        var remainingTokens = tokenize(normalized)
        var recognizedTokens: [String] = []

        let priority = parsePriority(from: &remainingTokens, recognizedTokens: &recognizedTokens) ?? .medium
        let repeatRule = parseRepeatRule(from: &remainingTokens, recognizedTokens: &recognizedTokens) ?? .none
        let dueDate = parseDate(from: &remainingTokens, recognizedTokens: &recognizedTokens)

        let title = remainingTokens.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return QuickAddParseResult(
            title: title,
            priority: priority,
            dueDate: dueDate,
            repeatRule: repeatRule,
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

    private func parseRepeatRule(
        from tokens: inout [String],
        recognizedTokens: inout [String]
    ) -> TodoItem.RepeatRule? {
        guard let index = tokens.firstIndex(where: isRepeatToken) else {
            return nil
        }

        let token = tokens.remove(at: index)
        recognizedTokens.append(token)

        let normalized = token.lowercased().replacingOccurrences(of: "-", with: "_")
        switch normalized {
        case "每天", "daily", "everyday", "every_day":
            return .daily
        case "每周", "每星期", "weekly", "everyweek", "every_week":
            return .weekly
        case "每月", "monthly", "everymonth", "every_month":
            return .monthly
        default:
            return nil
        }
    }

    private func parseDate(
        from tokens: inout [String],
        recognizedTokens: inout [String]
    ) -> Date? {
        if let dateTokenIndex = tokens.firstIndex(where: isDateKeyword) {
            let dateToken = tokens.remove(at: dateTokenIndex)
            recognizedTokens.append(dateToken)

            guard var date = resolveDate(from: dateToken) else {
                return nil
            }

            if let impliedTimeToken = impliedTimeToken(for: dateToken) {
                date = applyTime(impliedTimeToken, to: date) ?? date
                recognizedTokens.append(impliedTimeToken)
                return date
            }

            if let timeTokenIndex = tokens.firstIndex(where: isTimeToken) {
                let timeToken = tokens.remove(at: timeTokenIndex)
                recognizedTokens.append(timeToken)
                date = applyTime(timeToken, to: date) ?? date
            }

            return date
        }

        // Time-only input, defaulting date to today.
        if let timeTokenIndex = tokens.firstIndex(where: isTimeToken) {
            let timeToken = tokens.remove(at: timeTokenIndex)
            recognizedTokens.append(timeToken)
            let today = calendar.startOfDay(for: nowProvider())
            return applyTime(timeToken, to: today)
        }

        return nil
    }

    private func isDateKeyword(_ token: String) -> Bool {
        if token == "今天" || token == "明天" || token == "后天" || token == "下周" || token == "今晚" || token == "今早" {
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
            if lower == "today"
                || lower == "tomorrow"
                || lower == "next_week"
                || lower == "day_after_tomorrow"
                || lower == "tonight"
                || lower == "this_morning"
                || lower == "this_evening" {
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
        if normalized.range(of: chinesePattern, options: .regularExpression) != nil {
            return true
        }

        if ["上午", "下午", "晚上", "中午", "早上", "今早", "今晚", "傍晚"].contains(normalized) {
            return true
        }

        let lower = normalized.lowercased()
        let ampmPattern = #"^([1-9]|1[0-2])(:[0-5]\d)?(am|pm)$"#
        if lower.range(of: ampmPattern, options: .regularExpression) != nil {
            return true
        }

        if ["morning", "afternoon", "evening", "tonight", "noon"].contains(lower) {
            return true
        }

        return false
    }

    private func isRepeatToken(_ token: String) -> Bool {
        let normalized = token.lowercased().replacingOccurrences(of: "-", with: "_")
        return [
            "每天", "每周", "每星期", "每月",
            "daily", "weekly", "monthly",
            "everyday", "every_day", "everyweek", "every_week", "everymonth", "every_month",
        ].contains(normalized)
    }

    private func resolveDate(from token: String) -> Date? {
        let now = nowProvider()

        if token == "今天" || token == "今晚" || token == "今早" {
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
            if lower == "today" || lower == "tonight" || lower == "this_morning" || lower == "this_evening" {
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

    private func impliedTimeToken(for dateToken: String) -> String? {
        switch dateToken.lowercased() {
        case "今晚", "tonight", "this_evening":
            return "evening"
        case "今早", "this_morning":
            return "morning"
        default:
            return nil
        }
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

        if normalized.contains(":") && normalized.lowercased().hasSuffix("am") == false && normalized.lowercased().hasSuffix("pm") == false {
            let parts = normalized.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else {
                return nil
            }

            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
        }

        if let ampm = parseEnglishAmPm(normalized) {
            return calendar.date(bySettingHour: ampm.hour, minute: ampm.minute, second: 0, of: date)
        }

        if let periodHour = timePeriodHour(for: normalized) {
            return calendar.date(bySettingHour: periodHour, minute: 0, second: 0, of: date)
        }

        guard let components = parseChineseTime(normalized) else {
            return nil
        }

        return calendar.date(bySettingHour: components.hour, minute: components.minute, second: 0, of: date)
    }

    private func parseEnglishAmPm(_ token: String) -> (hour: Int, minute: Int)? {
        let lower = token.lowercased()
        let pattern = #"^([1-9]|1[0-2])(?::([0-5]\d))?(am|pm)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let hourRange = Range(match.range(at: 1), in: lower),
              let periodRange = Range(match.range(at: 3), in: lower),
              let hourValue = Int(lower[hourRange]) else {
            return nil
        }

        let minute: Int
        if let minuteRange = Range(match.range(at: 2), in: lower), let parsedMinute = Int(lower[minuteRange]) {
            minute = parsedMinute
        } else {
            minute = 0
        }

        let period = String(lower[periodRange])
        var adjustedHour = hourValue % 12
        if period == "pm" {
            adjustedHour += 12
        }

        return (adjustedHour, minute)
    }

    private func timePeriodHour(for token: String) -> Int? {
        switch token.lowercased() {
        case "上午", "早上", "今早", "morning", "this_morning":
            return 9
        case "中午", "noon":
            return 12
        case "下午", "afternoon":
            return 15
        case "晚上", "今晚", "傍晚", "evening", "tonight", "this_evening":
            return 20
        default:
            return nil
        }
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
            #"(今天|明天|后天|今晚|今早|下周[一二三四五六日天]?|周[一二三四五六日天]|星期[一二三四五六日天])"#,
            #"([01]?\d|2[0-3])[:：][0-5]\d"#,
            #"([1-9]|1[0-2])(:[0-5]\d)?(am|pm|AM|PM)"#,
            #"(上午|下午|晚上|中午|早上|今早|今晚|傍晚)?([01]?\d|2[0-3])点(半|([0-5]?\d)分?)?"#,
            #"(每天|每周|每星期|每月)"#,
        ]

        if useEnglish {
            spacingPatterns.append(#"(?i)\b(today|tomorrow|next_week|day_after_tomorrow|tonight|this_morning|this_evening|morning|afternoon|evening|noon|daily|weekly|monthly|every_day|every_week|every_month|everyday|everyweek|everymonth|mon(day)?|tue(s(day)?)?|wed(nesday)?|thu(r(s(day)?)?)?|fri(day)?|sat(urday)?|sun(day)?|next_(mon(day)?|tue(s(day)?)?|wed(nesday)?|thu(r(s(day)?)?)?|fri(day)?|sat(urday)?|sun(day)?))\b"#)
        }

        for pattern in spacingPatterns {
            spaced = spaced.replacingOccurrences(of: pattern, with: " $0 ", options: .regularExpression)
        }

        return spaced
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    private func shouldUseEnglishRules(for text: String) -> Bool {
        let localeIsEnglish = Locale.current.language.languageCode?.identifier.hasPrefix("en") ?? false
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
        result = replaceRegex(#"(?i)\bthis\s+morning\b"#, in: result, with: " this_morning ")
        result = replaceRegex(#"(?i)\bthis\s+evening\b"#, in: result, with: " this_evening ")
        result = replaceRegex(#"(?i)\bevery\s+day\b"#, in: result, with: " every_day ")
        result = replaceRegex(#"(?i)\bevery\s+week\b"#, in: result, with: " every_week ")
        result = replaceRegex(#"(?i)\bevery\s+month\b"#, in: result, with: " every_month ")
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

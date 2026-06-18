import Foundation

/// Native LLM이 만든 raw 텍스트를 "캐릭터가 보낸 하나의 자연스러운 채팅 메시지"로 정리한다.
/// 선택지/예시/번호 목록/markdown/프롬프트 지시문이 섞이면 거절(reject)해서 Local fallback으로 넘긴다.
enum ConversationOutputSanitizer {
    enum RejectionReason: String {
        case empty
        case tooLong
        case containsNumberedList
        case containsListMarker
        case containsInstructionLeak
    }

    struct SanitizerError: Error {
        let reason: RejectionReason
    }

    private static let maxLength = 140

    /// 프롬프트 누출 / 메타 단어. 포함되면 거절.
    private static let instructionLeakWords = [
        "채팅 답장", "답장 예시", "예시", "후보", "선택지", "보기:",
        "답변:", "메시지:", "출력:", "조건:",
        "프롬프트", "FoundationModels", "시스템 메시지",
        "AI", "API", "LLM"
    ]

    static func sanitize(_ raw: String) throws -> String {
        print("[NativeLLM] sanitize=start")

        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw reject(.empty) }

        // 여러 줄이면 번호/불릿 목록 여부 검사 후 첫 번째 자연 문장만 사용한다.
        let lines = text
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let numberedLineCount = lines.filter { isNumberedLine($0) }.count
        if numberedLineCount >= 2 { throw reject(.containsNumberedList) }

        let bulletLineCount = lines.filter { isBulletLine($0) }.count
        if bulletLineCount >= 2 { throw reject(.containsListMarker) }

        text = firstMeaningfulLine(in: lines) ?? text

        text = stripMarkdown(text)
        text = stripLeadingMarkers(text)
        text = stripWrappingQuotes(text)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw reject(.empty) }

        if isNumberedLine(text) { throw reject(.containsNumberedList) }
        if isBulletLine(text) { throw reject(.containsListMarker) }

        for word in instructionLeakWords where text.localizedCaseInsensitiveContains(word) {
            throw reject(.containsInstructionLeak)
        }

        if text.count > maxLength { throw reject(.tooLong) }

        print("[NativeLLM] sanitize=success outputChars=\(text.count)")
        return text
    }

    private static func reject(_ reason: RejectionReason) -> SanitizerError {
        print("[NativeLLM] sanitize=reject reason=\(reason.rawValue)")
        return SanitizerError(reason: reason)
    }

    private static func isNumberedLine(_ line: String) -> Bool {
        line.range(of: "^\\s*\\d+\\s*[\\.\\):]", options: .regularExpression) != nil
    }

    private static func isBulletLine(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") || line.hasPrefix("· ")
    }

    private static func firstMeaningfulLine(in lines: [String]) -> String? {
        lines.first { line in
            !isNumberedLine(line) && !isBulletLine(line) && stripMarkdown(line).trimmingCharacters(in: .whitespaces).count > 1
        } ?? lines.first
    }

    private static func stripMarkdown(_ input: String) -> String {
        var text = input
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")
        text = text.replacingOccurrences(of: "`", with: "")
        text = text.replacingOccurrences(of: "#", with: "")
        text = text.replacingOccurrences(of: ">", with: "")
        // 남은 단일 강조 별/언더스코어
        text = text.replacingOccurrences(of: "*", with: "")
        return text
    }

    private static func stripLeadingMarkers(_ input: String) -> String {
        var text = input
        // 선두 번호/불릿
        text = text.replacingOccurrences(
            of: "^\\s*(\\d+\\s*[\\.\\):]|[-*•·])\\s*",
            with: "",
            options: .regularExpression
        )
        // "답변:", "메시지:" 같은 prefix
        text = text.replacingOccurrences(
            of: "^\\s*(답변|메시지|출력|캐릭터|대답)\\s*[:：]\\s*",
            with: "",
            options: .regularExpression
        )
        return text
    }

    private static func stripWrappingQuotes(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespaces)
        let pairs: [(Character, Character)] = [("\"", "\""), ("'", "'"), ("“", "”"), ("‘", "’"), ("「", "」"), ("『", "』")]
        for (open, close) in pairs where text.count >= 2 && text.first == open && text.last == close {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return text
    }
}

import Foundation

/// ChatView 말풍선에 들어가기 직전의 "표면(surface)" 정리기.
/// Native/Deterministic 어느 경로의 결과든 최종적으로 이걸 통과한다.
/// - "카엘:" 같은 캐릭터 이름 prefix를 제거한다(말풍선엔 캐릭터 이름이 들어가면 안 된다).
/// - 제거가 일어나면 로그를 남긴다.
enum ReplySurfaceSanitizer {
    struct Result {
        let text: String
        let didChange: Bool
        let removedPrefix: String?
    }

    /// 말풍선에 새어나오면 안 되는 화자 prefix 후보.
    private static let speakerPrefixes = [
        "카엘", "한아", "서윤", "로이", "로이야",
        "Kael", "Hana", "Seoyun", "Roi", "Roy",
        "Assistant", "assistant", "캐릭터", "대답", "답변", "메시지"
    ]

    private static let separators = [":", "：", " :", " ："]

    /// 동적 화자 prefix 제거를 위해 저장된 유저 이름(현재/이전)을 함께 받는다.
    /// 정적 캐릭터 이름 + 동적 유저 이름 + 일반 정규식("짧은단어:")까지 맨 앞에서만 제거한다.
    static func sanitize(_ raw: String, dynamicNames: [String] = []) -> Result {
        let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = original
        var removed: [String] = []

        let names = speakerPrefixes + dynamicNames.filter { !$0.isEmpty }

        var keepGoing = true
        while keepGoing {
            keepGoing = false
            for name in names {
                for sep in separators {
                    let prefix = name + sep
                    if text.hasPrefix(prefix) {
                        let before = text
                        text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        removed.append("\(name):")
                        keepGoing = true
                        print("[ReplySanitizer] removedDynamicPrefix=\"\(name):\" before=\"\(before)\" after=\"\(text)\"")
                    }
                }
            }
            // 정적/동적 이름으로 못 잡은 일반 "짧은단어:" prefix(맨 앞, 중간 콜론 제외) 제거.
            if !keepGoing, let range = leadingSpeakerPrefixRange(text) {
                let before = text
                let removedPart = String(text[range]).trimmingCharacters(in: .whitespaces)
                text = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                removed.append(removedPart)
                keepGoing = true
                print("[ReplySanitizer] removedDynamicPrefix=\"\(removedPart)\" before=\"\(before)\" after=\"\(text)\"")
            }
        }

        // prefix 제거로 본문이 비면 원문을 유지(빈 말풍선 방지).
        if text.isEmpty {
            return Result(text: original, didChange: false, removedPrefix: nil)
        }

        let didChange = text != original
        return Result(text: text, didChange: didChange, removedPrefix: removed.isEmpty ? nil : removed.joined())
    }

    /// 문장 맨 앞 "화자:" 형태(짧은 단어 + 콜론)를 감지한다. 중간 콜론은 제외.
    /// 정규식: ^[가-힣A-Za-z0-9_]{1,12}\s*[:：]\s*
    private static func leadingSpeakerPrefixRange(_ text: String) -> Range<String.Index>? {
        let pattern = "^[가-힣A-Za-z0-9_]{1,12}\\s*[:：]\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else { return nil }
        return range
    }
}

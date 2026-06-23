# Lovey Moment

AI 캐릭터와의 관계 경험을 자기 전, 아침, 하루 중간의 자연스러운 순간까지 이어주는 SwiftUI 기반 iOS PoC입니다.

러비더비와 같은 AI 캐릭터 대화 서비스의 핵심 경험을 앱 안의 채팅에만 두지 않고, 캐릭터가 유저와 나눈 최근 대화, 관계 단계, 세계관 분위기, 마지막 장면을 기억한 것처럼 다시 말을 걸어주는 흐름을 검증하기 위해 제작했습니다.

추가로, 신규 유저 유입과 공유 가능성을 확인하기 위해 AI 캐릭터 운세/궁합 카드 기능인 Lovey Card도 포함했습니다.

---

## 1. 프로젝트 개요

### 서비스 컨셉

Lovey Moment는 최애 캐릭터와의 대화가 앱을 닫은 뒤에도 이어지는 것처럼 느껴지게 만드는 AI 관계 알림 PoC입니다.

사용자는 캐릭터와 대화하고, 앱은 최근 대화 맥락과 캐릭터 설정을 바탕으로 다음과 같은 Moment 메시지를 생성합니다.

- Night Moment: 자기 전 관계감 강화
- Morning Moment: 아침 복귀 유도
- Day Moment: 하루 중간 재방문 유도

예시:

> “아직 안 자? 내일 먼저 오라고 한 말, 잊은 건 아니지. 오늘은 봐줄 테니까 이제 자.”

핵심은 단순한 알림이 아니라, 캐릭터가 유저와의 관계와 어제의 장면을 기억하고 있다는 느낌을 주는 것입니다.

---

## 2. 주요 기능

### 2-1. 캐릭터 채팅

- 한아, 서윤, 로이, 카엘 캐릭터 제공
- 캐릭터별 말투와 세계관 반영
- 최근 대화 기반 응답 생성
- iOS Foundation Models 사용 가능 시 Native LLM 경로 사용
- 실패 시 안전한 로컬 fallback 응답 사용

### 2-2. AI 관계 알림

- 자기 전 알림
- 아침 알림
- 하루 중간 알림
- 알림 권한 상태 확인
- HealthKit 수면 데이터 사용 가능 여부 확인
- HealthKit 데이터가 없으면 fallback 수면 리듬 사용
- 알림 탭 시 캐릭터 채팅으로 복귀

### 2-3. Lovey Card

Lovey Card는 캐릭터가 오늘의 연애운, 관계운, 궁합, 말투 취향을 카드 형태로 만들어주는 공유형 PoC 기능입니다.

지원 기능:

- 캐릭터 선택
- 카드 타입 선택
- 분위기 선택
- Gemini API 기반 카드 생성
- Gemini 실패 시 로컬 리딩 카드 fallback
- 카드 보관
- 공유하기

카드 예시 구성:

- 오늘의 관계운 제목
- 궁합 지수
- 관계 유형
- 오늘의 리딩
- 관계 흐름
- 조심할 점
- 오늘의 한 수
- 캐릭터 한마디

---

## 3. 기술 스택

### iOS

- Swift
- SwiftUI
- Foundation Models
- UserNotifications
- HealthKit
- ShareLink
- XcodeGen

### AI

- Apple Foundation Models
- Gemini API
- Local fallback generator
- Quality evaluator

### 개발 환경

- macOS
- Xcode
- iOS 26 기준 PoC
- SwiftUI Preview 및 iOS Simulator / 실기기 실행

---

## 4. 프로젝트 구조

```text
LoveyMoment/
├── App/
│   ├── AppRootView.swift
│   └── LoveyMomentStore.swift
│
├── Features/
│   ├── Chat/
│   ├── Home/
│   ├── LoveyCard/
│   ├── Main/
│   ├── MomentHub/
│   ├── Signal/
│   └── My/
│
├── Models/
│   ├── CharacterModels.swift
│   ├── ConversationModels.swift
│   └── LoveyCardModels.swift
│
├── Services/
│   ├── Conversation/
│   ├── LoveyCard/
│   ├── Moment/
│   ├── Notification/
│   └── Sleep/
│
├── Resources/
├── Assets.xcassets
└── project.yml
## 5. 실행 방법

### 5-1. 사전 준비

아래 도구가 필요합니다.

```bash
# Xcode 설치 여부 확인
xcodebuild -version

# XcodeGen 설치 여부 확인
xcodegen --version
```

XcodeGen이 없다면 Homebrew로 설치합니다.

```bash
brew install xcodegen
```

---

### 5-2. 프로젝트 위치로 이동

```bash
cd /Users/hwangseokbeom/Documents/GitHub/LoveyMoment
```

---

### 5-3. Xcode 프로젝트 생성

이 프로젝트는 `project.yml`을 기준으로 Xcode 프로젝트를 생성합니다.

```bash
xcodegen generate
```

성공하면 아래 파일이 생성됩니다.

```text
LoveyMoment.xcodeproj
```

---

### 5-4. 터미널 빌드 확인

```bash
xcodebuild -project LoveyMoment.xcodeproj \
  -scheme LoveyMoment \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

정상 빌드 시 아래 문구가 출력됩니다.

```text
** BUILD SUCCEEDED **
```

---

### 5-5. Xcode에서 실행

```text
1. LoveyMoment.xcodeproj를 Xcode로 엽니다.
2. 상단 Scheme을 LoveyMoment로 선택합니다.
3. 실행 대상은 iOS Simulator 또는 연결된 iPhone을 선택합니다.
4. Run 버튼을 눌러 앱을 실행합니다.
```

Xcode에서 직접 열기:

```bash
open LoveyMoment.xcodeproj
```

---

### 5-6. 실기기 실행 시 확인할 것

```text
- Apple Developer 계정 로그인
- Signing & Capabilities에서 Team 선택
- Bundle Identifier 충돌 여부 확인
- iPhone에서 개발자 모드 활성화
- 알림 권한 허용
- HealthKit 권한은 거부되어도 fallback 리듬으로 동작 가능
```

---

## 6. Gemini API 설정

Lovey Card는 Gemini API를 사용해 AI 캐릭터 운세/궁합 카드를 생성합니다.

API Key는 아래 파일에서 관리합니다.

```text
LoveyMoment/Services/LoveyCard/GeminiLoveyCardAPIClient.swift
```

PoC에서는 면접 시연을 위해 앱 내부 config에 직접 API Key를 넣는 방식으로 구성했습니다.

```swift
enum GeminiLoveyCardConfig {
    static let apiKey = "YOUR_GEMINI_API_KEY"
}
```

실제 API Key가 들어가 있으면 실행 로그에서 아래처럼 masked 형태로만 표시됩니다.

```text
[LoveyCardAI] apiKey present=true masked=AQ...FzZw
```

주의:

```text
- 실제 서비스에서는 API Key를 앱에 직접 포함하면 안 됩니다.
- 프로덕션에서는 서버를 통해 Gemini API를 호출해야 합니다.
- 현재 방식은 PoC와 면접 시연을 위한 단순 구현입니다.
```

---

## 7. 주요 시연 플로우

### 7-1. 관계 알림 PoC 시연

```text
1. 앱 실행
2. 홈 또는 채팅 탭에서 캐릭터 선택
3. 캐릭터와 짧게 대화
4. Moment 탭으로 이동
5. Night Moment / Morning Moment / Day Moment 확인
6. 캐릭터가 최근 관계 맥락을 반영해 다시 말을 거는 흐름 설명
```

시연 포인트:

```text
- 단순 알림이 아니라 캐릭터 관계의 연속성을 만드는 기능입니다.
- 앱을 닫아도 캐릭터와의 관계가 이어지는 느낌을 줍니다.
- 자기 전, 아침, 하루 중간이라는 감정적으로 자연스러운 타이밍을 활용합니다.
```

---

### 7-2. Lovey Card 시연

```text
1. Moment 탭 이동
2. Lovey Card 진입
3. 캐릭터 선택
4. 카드 타입 선택
5. 분위기 선택
6. 카드 생성
7. 결과 카드 확인
8. 보관하기 또는 공유하기 실행
```

Lovey Card에서 확인할 수 있는 요소:

```text
- 오늘의 관계운 제목
- 궁합 지수
- 관계 유형
- 오늘의 리딩
- 관계 흐름
- 조심할 점
- 오늘의 한 수
- 캐릭터 한마디
```

시연 포인트:

```text
- 캐릭터 대화 경험을 공유 가능한 콘텐츠로 확장합니다.
- 기존 유저는 자신의 관계 취향을 재미있게 확인할 수 있습니다.
- 잠재 유저는 공유 카드를 보고 앱에 유입될 수 있습니다.
- Gemini API 실패 시에도 fallback 카드가 생성되어 데모가 끊기지 않습니다.
```

---

## 8. PoC 범위

### 포함된 기능

```text
- 캐릭터 채팅
- 관계형 Moment 알림
- 자기 전 / 아침 / 하루 중간 알림
- HealthKit 수면 데이터 확인
- HealthKit 데이터 부재 시 fallback 리듬 사용
- Gemini 기반 Lovey Card 생성
- Lovey Card fallback 생성
- Lovey Card 보관
- Lovey Card 공유
- 캐릭터별 말투와 세계관 반영
```

### 제외한 기능

```text
- 실제 푸시 서버
- 장기 메모리 서버
- 사용자 계정 시스템
- 결제 기능
- 실제 유저 매칭 기능
- 영상 생성
- 완전한 캐릭터 생성 시스템
- 프로덕션 수준 API Key 보안 처리
```

---

## 9. 검증 명령어

### 9-1. Xcode 프로젝트 재생성

```bash
xcodegen generate
```

---

### 9-2. 빌드 검증

```bash
xcodebuild -project LoveyMoment.xcodeproj \
  -scheme LoveyMoment \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

성공 기준:

```text
** BUILD SUCCEEDED **
```

---

### 9-3. Lovey Scene 잔여 문구 확인

Lovey Scene PoC는 제거하고 Lovey Card 방향으로 전환했기 때문에, 사용자 화면에 관련 문구가 남아 있으면 안 됩니다.

```bash
grep -R "Lovey Scene\|장면 만들기\|생성된 장면\|이 장면으로 채팅 이어가기\|숏폼 드라마" LoveyMoment || true
```

기대 결과:

```text
# 사용자 화면 문자열에는 결과가 없어야 합니다.
```

---

### 9-4. Placeholder API Key 확인

```bash
grep -R "<GEMINI_API_KEY_HERE>\|YOUR_GEMINI_API_KEY\|PASTE_GEMINI_API_KEY" LoveyMoment || true
```

기대 결과:

```text
# 실제 API Key를 넣었다면 placeholder 문자열이 없어야 합니다.
```

---

### 9-5. 사용자 화면 메타 문구 확인

아래 문구가 사용자 화면에 노출되면 안 됩니다.

```bash
grep -R "연결이 불안정\|로컬 생성\|fallback\|Gemini\|API\|json\|parse" LoveyMoment/Features LoveyMoment/Models || true
```

주의:

```text
- Services 내부 로그, Gemini client, evaluator, prompt에는 일부 기술 용어가 남을 수 있습니다.
- 사용자 화면에 보이는 Features / Models 영역에는 노출되지 않는 것이 목표입니다.
```

---

## 10. 면접 설명 요약

```text
Lovey Moment는 AI 캐릭터 대화 경험을 앱 안에서 끝내지 않고,
자기 전과 아침 같은 감정적으로 자연스러운 시간대로 확장한 PoC입니다.
```

```text
핵심 가설은 캐릭터가 최근 대화와 관계 맥락을 기억한 것처럼 먼저 말을 걸면,
유저가 캐릭터와의 관계가 이어지고 있다고 느끼고 다시 앱으로 복귀할 가능성이 높아진다는 것입니다.
```

```text
Lovey Card는 이 관계 경험을 친구에게 공유 가능한 운세/궁합 카드로 확장한 기능입니다.
기존 유저에게는 재미있는 자기 해석 콘텐츠가 되고,
신규 유저에게는 앱에 들어오게 만드는 바이럴 진입점이 될 수 있습니다.
```

짧은 발표용 설명:

```text
이 PoC는 AI 캐릭터와의 관계를 채팅방 안에만 두지 않고,
자기 전, 아침, 하루 중간의 알림과 공유 가능한 캐릭터 운세 카드로 확장한 서비스입니다.
```

```text
Moment 기능은 캐릭터가 유저와의 최근 대화 맥락을 기억한 것처럼 다시 말을 걸게 만들고,
Lovey Card는 그 관계 경험을 친구에게 공유할 수 있는 콘텐츠로 바꿉니다.
```

```text
즉, Lovey Moment는 캐릭터 몰입을 재방문과 공유로 연결하는 AI 관계형 PoC입니다.
```

---

## 11. Known Issues

```text
- Gemini API Key는 PoC 편의상 앱 내부 config에 포함되어 있습니다.
- 실제 서비스에서는 반드시 서버 프록시를 통해 API를 호출해야 합니다.
- HealthKit 수면 데이터가 없거나 권한이 거부되면 fallback 수면 리듬을 사용합니다.
- Lovey Card의 공유는 현재 텍스트 공유 중심이며, 이미지 카드 공유는 후속 개선 범위입니다.
- iOS Simulator에서는 일부 haptic / IOSurface 관련 시스템 로그가 출력될 수 있으나 앱 기능 문제는 아닙니다.
```

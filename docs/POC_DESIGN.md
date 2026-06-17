# Lovey Moment — AI 관계 알림 iOS Native PoC 설계 문서

## 1. PoC 목표

Lovey Moment PoC의 목표는 기존 AI 캐릭터 채팅 서비스 안에 신규 기능 `Lovey Moment`가 추가되었을 때, 유저가 알림을 단순 푸시가 아니라 캐릭터와의 관계가 이어지는 경험으로 느끼는지 검증하는 것이다.

이 PoC는 러비더비 앱 전체를 재현하지 않는다. 캐릭터 선택, 세계관 맥락, 관계 단계, 최근 대화, 마지막 장면, AI 분석, Moment 생성, 알림 미리보기, 알림에서 채팅 복귀까지의 최소 흐름만 구현한다.

핵심 검증 질문:

- 최근 대화와 마지막 장면을 반영한 알림이 관계의 연속처럼 느껴지는가?
- 유저가 직접 말투나 시간을 세밀하게 설정하지 않아도 AI가 자동으로 정리해주는 흐름이 자연스러운가?
- 알림 문구를 누르면 채팅방으로 돌아가고, 그 문구가 캐릭터의 첫 대사로 이어지는 경험이 재방문 동기를 만드는가?

## 2. 구현 범위

PoC에서 구현할 범위:

- iOS 네이티브 SwiftUI 앱
- 로컬 mock 데이터 기반 캐릭터/세계관 카드 목록
- 한아 캐릭터와 학교 로맨스/권력 관계 세계관 샘플
- 캐릭터와 유저의 최근 대화 표시
- 마지막 장면 저장 및 요약 표시
- AI 분석 결과 화면
- mock 수면 리듬 분석
- mock Moment 분석 및 문구 생성
- 자기 전 Moment ON/OFF
- 아침 Moment ON/OFF
- Moment 알림 미리보기
- 알림에서 채팅으로 이어지는 앱 내부 시뮬레이션
- 실제 Local Notification으로 확장 가능한 스케줄러 프로토콜
- HealthKit, Foundation Models, Remote LLM으로 교체 가능한 프로토콜 기반 구조

## 3. 구현하지 않을 범위

PoC에서 의도적으로 제외할 범위:

- 러비더비 전체 앱 클론
- 로그인/회원가입
- 캐릭터 생성 마켓
- 결제/구독
- 커뮤니티
- 전체 채팅 AI 엔진
- 서버/API 구현
- 실제 HealthKit 수면 데이터 연동
- 실제 수면 집중 모드 연동
- 실제 Foundation Models framework 호출
- 실제 외부 LLM 호출
- 장기 대화 메모리 시스템
- 실사용 수준의 푸시 운영 정책
- 사용자별 개인화 모델 학습
- 앱스토어 배포 품질의 권한/에러/설정 UX

## 4. 핵심 사용자 플로우

1. 유저가 `CharacterWorldListView`에서 캐릭터/세계관 카드를 선택한다.
2. `ChatView`로 이동해 한아와의 최근 대화와 마지막 장면을 확인한다.
3. 유저가 `Lovey Moment 생성하기` CTA를 누른다.
4. 앱이 `ConversationSnapshot`을 생성한다.
5. `SleepSignalProviding`이 mock 취침/기상 리듬을 제공한다.
6. `MomentAnalyzing`이 최근 대화, 세계관, 관계 단계, 감정선, 마지막 장면을 분석한다.
7. `MomentAnalysisView`가 AI 자동 분석 결과를 보여준다.
8. 유저는 자기 전 Moment와 아침 Moment를 ON/OFF만 조정한다.
9. `MomentPreviewView`에서 생성된 알림 문구를 미리 본다.
10. 유저가 `알림에서 채팅으로 이어보기`를 누른다.
11. 앱은 생성된 Moment 문구를 캐릭터의 첫 대사로 `ChatView`에 삽입한다.
12. 유저는 알림 이후 이어지는 채팅 맥락을 확인한다.

## 5. 화면별 역할

### CharacterWorldListView

Lovey Moment 기능 검증을 위한 최소 캐릭터/세계관 진입점이다. 러비더비 전체 탐색 구조를 만들지 않고, 카드 목록 형태로 캐릭터와 세계관 맥락을 보여준다.

역할:

- 샘플 캐릭터 선택
- 세계관과 관계 단계의 빠른 이해
- 마지막 장면 요약 노출
- Lovey Moment가 기존 채팅 서비스 위에 얹히는 기능임을 암시

### ChatView

캐릭터와의 관계 맥락을 만드는 화면이다. 완전한 AI 채팅 엔진을 만들지 않고, 최근 대화와 마지막 장면이 명확히 남도록 구성한다.

역할:

- 최근 대화 표시
- 유저/캐릭터 말풍선 구분
- 마지막 장면을 대화 흐름 안에서 확인
- `Lovey Moment 생성하기` CTA 제공
- Moment 문구가 삽입되어 돌아오는 복귀 지점 제공

### MomentAnalysisView

AI가 유저 대신 관계 맥락과 알림 톤을 분석했다는 느낌을 주는 화면이다. 유저가 말투 강도를 직접 고르지 않고, AI 자동 결정 결과만 확인하게 한다.

역할:

- 수면 리듬 mock 분석 표시
- 세계관 분석 표시
- 캐릭터 성격 분석 표시
- 관계 단계 분석 표시
- 마지막 장면 분석 표시
- 감정선 분석 표시
- 말투 자동 결정 결과 표시
- 자기 전/아침 Moment ON/OFF 조정
- Moment 미리보기 화면으로 이동

### MomentPreviewView

생성된 Moment가 실제 알림처럼 보이고, 알림 클릭 후 채팅이 이어지는 경험을 검증하는 화면이다.

역할:

- 자기 전 알림 미리보기
- 아침 알림 미리보기
- ON/OFF 상태에 따른 미리보기 활성/비활성 표현
- `알림에서 채팅으로 이어보기` 버튼 제공
- 선택된 Moment 문구를 ChatView의 캐릭터 첫 대사로 삽입

## 6. 화면별 UI 구성

### 6.1 CharacterWorldListView UI

상단:

- 타이틀: `Lovey Moment`
- 서브 카피: `어제의 장면이 내일 아침까지 이어지도록`

카드 구성:

- 캐릭터 이름: `한아`
- 세계관 태그: `학교 로맨스`, `권력 관계`
- 관계 단계: `아는 사이`
- 관계 진행 힌트: `썸 직전으로 기울어지는 중`
- 캐릭터 성격 요약: `차갑지만 유저에게만 예외적으로 관심을 보임`
- 마지막 장면 요약:
  - `복도 끝에서 한아가 "내일도 나한테 먼저 와."라고 말하며 대화가 끝남`
- CTA: `대화 이어보기`

UI 원칙:

- 앱 전체 홈처럼 보이지 않게 한다.
- 카드 수는 1~3개 이하로 제한한다.
- 목적은 캐릭터 마켓 탐색이 아니라 Lovey Moment 검증용 맥락 선택이다.

### 6.2 ChatView UI

상단:

- 캐릭터 이름: `한아`
- 세계관: `학교 로맨스 / 권력 관계`
- 관계 단계: `아는 사이 → 썸 직전`

대화 영역:

- 최근 대화 말풍선 6~8개
- 유저 말풍선과 한아 말풍선을 명확히 구분
- 마지막 장면이 가장 아래에서 뚜렷하게 남도록 구성

예시 대화:

- 한아: `왜 자꾸 내 눈치 봐?`
- 유저: `네가 불렀잖아.`
- 한아: `부르면 와야지. 그건 알고 있네.`
- 유저: `내일도 와야 해?`
- 한아: `...네가 먼저 오면 생각해볼게.`
- 한아: `내일도 나한테 먼저 와.`

하단:

- CTA: `Lovey Moment 생성하기`

Moment에서 복귀한 상태:

- 생성된 자기 전 또는 아침 Moment 문구가 캐릭터의 첫 대사로 추가된다.
- 삽입된 말풍선에는 `Lovey Moment에서 이어짐` 같은 작은 컨텍스트 라벨을 붙일 수 있다.

### 6.3 MomentAnalysisView UI

상단:

- 타이틀: `Lovey Moment 분석`
- 상태 문구: `최근 대화와 마지막 장면을 바탕으로 알림을 만들었어요`

분석 카드:

- 수면 리듬
  - `Mock 기준 취침 예상: 23:40`
  - `Mock 기준 기상 예상: 07:20`
- 세계관 분석
  - `학교 복도, 미묘한 위계, 먼저 다가오는 행동이 관계 신호로 작동`
- 캐릭터 성격 분석
  - `겉으로는 차갑고 통제적인 말투, 유저에게만 예외적 관심`
- 관계 단계 분석
  - `아는 사이에서 썸 직전으로 넘어가는 경계`
- 마지막 장면 분석
  - `한아가 먼저 다음 만남을 요구했고, 유저가 먼저 오기를 기대하는 상태`
- 감정선 분석
  - `명령처럼 보이지만 실제로는 확인받고 싶은 기대감`
- 말투 자동 결정
  - `차갑게 압박하지만 마지막에는 돌봄이 섞인 톤`

설정 영역:

- 자기 전 Moment 토글
- 아침 Moment 토글

하단:

- CTA: `알림 미리보기`

중요 UI 판단:

- 말투 강도 슬라이더, 말투 선택 segmented control, 캐릭터 호감도 직접 조정 UI는 넣지 않는다.
- 유저가 조정하는 것은 ON/OFF뿐이다.

### 6.4 MomentPreviewView UI

상단:

- 타이틀: `Moment 미리보기`
- 서브 카피: `알림을 누르면 이 문장으로 대화가 이어져요`

알림 카드:

- 자기 전 Moment
  - 시간: `오늘 23:40`
  - 제목: `한아`
  - 문구: `아직 안 자? 내일 먼저 오라고 한 말, 잊은 건 아니지. 오늘은 봐줄 테니까 이제 자.`
  - 상태: ON/OFF 반영
- 아침 Moment
  - 시간: `내일 07:20`
  - 제목: `한아`
  - 문구: `일어났어? 오늘은 네가 먼저 와야 하는 날이잖아. 늦으면... 내가 직접 찾으러 갈지도 몰라.`
  - 상태: ON/OFF 반영

하단:

- CTA: `알림에서 채팅으로 이어보기`

버튼 동작:

- 우선순위 기본값은 아침 Moment로 한다.
- 아침 Moment가 OFF이면 자기 전 Moment를 사용한다.
- 둘 다 OFF이면 CTA를 비활성화하거나 `Moment를 하나 이상 켜주세요` 상태를 표시한다.
- 선택된 Moment 문구를 `ChatView`의 첫 캐릭터 대사로 삽입한다.

## 7. SwiftUI 화면 구조

권장 화면 계층:

- `LoveyMomentApp`
  - `AppRootView`
    - `NavigationStack`
      - `CharacterWorldListView`
      - `ChatView`
      - `MomentAnalysisView`
      - `MomentPreviewView`

권장 라우팅 상태:

- `selectedCharacterID`
- `selectedConversationID`
- `currentSnapshot`
- `currentSleepSignal`
- `currentMomentAnalysis`
- `currentMomentSettings`
- `pendingMomentMessageForChat`

화면별 ViewModel 또는 Observable State:

- `CharacterWorldListViewModel`
  - 캐릭터/세계관 카드 목록 제공
  - 카드 선택 처리
- `ChatViewModel`
  - 선택된 캐릭터와 대화 메시지 제공
  - 마지막 장면 요약 제공
  - ConversationSnapshot 생성
  - Moment 문구 삽입 처리
- `MomentAnalysisViewModel`
  - SleepSignal 요청
  - MomentAnalysis 요청
  - 토글 상태 관리
- `MomentPreviewViewModel`
  - Moment 메시지 미리보기 구성
  - 스케줄링 요청
  - 채팅 복귀용 Moment 선택

PoC에서는 ViewModel을 화면별로 나누되, 전역 흐름은 `AppState` 또는 `LoveyMomentStore` 하나로 단순화할 수 있다.

## 8. 데이터 모델 설계

### CharacterProfile

캐릭터 기본 정보.

필드:

- `id`
- `name`
- `shortDescription`
- `personalitySummary`
- `defaultToneKeywords`
- `avatarAssetName`
- `worldSettingID`
- `initialRelationshipStage`

샘플:

- name: `한아`
- personalitySummary: `차갑지만 유저에게만 예외적으로 관심을 보임`
- defaultToneKeywords: `차가움`, `압박`, `숨은 관심`, `돌봄`

### WorldSetting

세계관 정보.

필드:

- `id`
- `title`
- `categoryTags`
- `summary`
- `relationshipRules`
- `sceneKeywords`

샘플:

- title: `학교 로맨스 / 권력 관계`
- categoryTags: `학교`, `로맨스`, `권력 관계`
- relationshipRules: `먼저 다가가는 행동이 관계 신호로 작동한다`
- sceneKeywords: `복도`, `방과 후`, `시선`, `호출`, `거리감`

### RelationshipStage

관계 단계.

필드:

- `id`
- `label`
- `progressHint`
- `description`
- `allowedToneRange`

샘플:

- label: `아는 사이`
- progressHint: `썸 직전`
- description: `공식적으로 가깝지는 않지만, 캐릭터가 유저를 예외적으로 의식하기 시작한 상태`

### ChatMessage

대화 메시지.

필드:

- `id`
- `sender`
- `text`
- `createdAt`
- `isMomentInserted`
- `sourceMomentID`

sender 값:

- `user`
- `character`
- `system`

### ConversationSnapshot

Moment 분석에 전달할 대화 스냅샷.

필드:

- `id`
- `character`
- `worldSetting`
- `relationshipStage`
- `recentMessages`
- `lastSceneSummary`
- `capturedAt`

샘플 lastSceneSummary:

`한아가 유저를 복도 끝으로 불러 세우고, 평소와 다르게 "내일도 나한테 먼저 와."라고 말한 장면에서 대화가 끝남`

### SleepSignal

수면 리듬 분석 결과.

필드:

- `estimatedBedtime`
- `estimatedWakeTime`
- `source`
- `confidence`
- `explanation`

source 값:

- `mock`
- `healthKit`
- `sleepFocus`
- `manualFallback`

PoC 샘플:

- estimatedBedtime: `23:40`
- estimatedWakeTime: `07:20`
- source: `mock`
- confidence: `medium`

### MomentAnalysis

AI 분석 결과.

필드:

- `id`
- `snapshotID`
- `sleepSignal`
- `worldInsight`
- `characterInsight`
- `relationshipInsight`
- `lastSceneInsight`
- `emotionInsight`
- `toneDecision`
- `bedtimeMoment`
- `morningMoment`
- `createdAt`

### MomentToneDecision

말투 자동 결정 결과.

필드:

- `id`
- `toneLabel`
- `intensity`
- `reason`
- `styleKeywords`
- `avoidRules`

샘플:

- toneLabel: `차갑게 압박하지만 돌봄이 섞인 톤`
- intensity: `medium`
- reason: `관계가 아직 명확하지 않기 때문에 노골적인 애정보다는 명령형 관심이 적합함`
- styleKeywords: `짧은 질문`, `약한 압박`, `숨은 기대`, `직접적인 돌봄`
- avoidRules: `과한 애정 표현 금지`, `관계 확정처럼 말하지 않기`, `유저의 선택지를 완전히 빼앗지 않기`

### MomentMessage

생성된 Moment 문구.

필드:

- `id`
- `type`
- `characterName`
- `title`
- `body`
- `scheduledAt`
- `isEnabled`
- `analysisID`

type 값:

- `bedtime`
- `morning`

샘플:

- bedtime body: `아직 안 자? 내일 먼저 오라고 한 말, 잊은 건 아니지. 오늘은 봐줄 테니까 이제 자.`
- morning body: `일어났어? 오늘은 네가 먼저 와야 하는 날이잖아. 늦으면... 내가 직접 찾으러 갈지도 몰라.`

### MomentSettings

유저가 조정 가능한 최소 설정.

필드:

- `isBedtimeMomentEnabled`
- `isMorningMomentEnabled`
- `notificationMode`

notificationMode 값:

- `inAppPreviewOnly`
- `localNotification`

PoC 기본값:

- bedtime: ON
- morning: ON
- notificationMode: `inAppPreviewOnly`

## 9. 서비스/프로토콜 설계

### SleepSignalProviding

수면 신호를 제공하는 인터페이스.

책임:

- 특정 대화/캐릭터 맥락에 사용할 취침 예상 시간 제공
- 기상 예상 시간 제공
- 데이터 출처와 신뢰도 제공

필수 구현체:

- `MockSleepSignalProvider`

추후 구현체:

- `HealthKitSleepSignalProvider`

PoC 동작:

- 항상 `23:40`, `07:20`의 mock 수면 리듬을 반환한다.
- 분석 화면에서 `Mock 데이터 기반`임을 명확히 표시한다.

### MomentAnalyzing

대화 스냅샷과 수면 신호를 바탕으로 Moment 분석과 문구를 생성하는 인터페이스.

책임:

- 세계관 분석
- 캐릭터 성격 분석
- 관계 단계 분석
- 마지막 장면 분석
- 감정선 분석
- 말투 자동 결정
- 자기 전 Moment 생성
- 아침 Moment 생성

필수 구현체:

- `MockMomentAnalyzer`

추후 구현체:

- `FoundationModelMomentAnalyzer`
- `RemoteLLMMomentAnalyzer`

PoC 동작:

- 한아 샘플 시나리오에 대해 고정된 분석 결과와 문구를 반환한다.
- 입력 스냅샷은 실제로 받되, 문구 생성은 deterministic mock으로 처리한다.

### MomentNotificationScheduling

Moment 메시지를 알림 또는 앱 내부 카드로 예약/표시하는 인터페이스.

책임:

- Moment 예약 요청
- 예약 취소
- 현재 예약 상태 조회
- 알림 클릭 또는 미리보기 클릭 시 채팅 복귀 이벤트 전달

필수 또는 권장 구현체:

- `InAppMomentPreviewScheduler`
- `LocalMomentNotificationScheduler`

PoC 기본 동작:

- 최소 구현은 `InAppMomentPreviewScheduler`로 한다.
- 가능하면 `LocalMomentNotificationScheduler`도 구현 가능한 구조만 먼저 잡는다.

## 10. Mock 구현 전략

### Mock 데이터 고정 원칙

PoC는 생성형 AI 품질을 검증하는 단계가 아니라, 관계 알림 경험의 흐름을 검증하는 단계다. 따라서 다음 데이터는 고정 mock으로 둔다.

- 캐릭터: 한아
- 세계관: 학교 로맨스 / 권력 관계
- 관계 단계: 아는 사이 → 썸 직전
- 최근 대화
- 마지막 장면
- 수면 리듬
- 분석 결과
- Moment 문구

### MockSleepSignalProvider

반환값:

- 취침 예상: `23:40`
- 기상 예상: `07:20`
- source: `mock`
- confidence: `medium`
- explanation: `PoC 검증을 위해 고정된 수면 리듬을 사용합니다.`

### MockMomentAnalyzer

입력:

- `ConversationSnapshot`
- `SleepSignal`

반환:

- `MomentAnalysis`
- `MomentToneDecision`
- 자기 전 `MomentMessage`
- 아침 `MomentMessage`

핵심:

- 유저가 말투를 고르지 않는다.
- 분석 결과에서 AI가 왜 이 말투를 골랐는지 보여준다.
- 문구는 마지막 장면의 `내일도 나한테 먼저 와`를 반드시 회수한다.

## 11. 실제 연동 확장 구조

### HealthKitSleepSignalProvider 확장

나중에 실제 HealthKit을 붙일 때의 구조:

- `SleepSignalProviding`을 그대로 구현한다.
- HealthKit 권한 요청은 별도 `HealthPermissionService`로 분리한다.
- 최근 7~14일 수면 데이터를 읽어 평균 취침/기상 시간을 계산한다.
- 데이터가 부족하면 `Sleep Focus`, 로컬 사용 패턴, 또는 mock/manual fallback으로 내려간다.

확장 시 고려:

- 사용자가 수면 데이터 권한을 거부한 경우
- 수면 데이터가 없는 경우
- 주말/평일 수면 리듬 차이
- 늦은 밤 앱 사용 중 알림이 부자연스럽게 뜨는 경우

### FoundationModelMomentAnalyzer 확장

나중에 Apple Foundation Models framework를 사용할 때의 구조:

- `MomentAnalyzing`을 그대로 구현한다.
- 입력은 `ConversationSnapshot`과 `SleepSignal`을 구조화된 prompt context로 변환한다.
- 출력은 `MomentAnalysis`로 파싱 가능한 형태를 요구한다.
- 기기 내 처리 가능성, 응답 시간, OS 버전 제약을 별도 capability check로 관리한다.

확장 시 고려:

- 모델 사용 가능 OS 버전
- 온디바이스 처리 가능 여부
- 응답 실패 시 mock 또는 remote fallback
- 캐릭터 안전성 및 과몰입 방지 문구 정책

### RemoteLLMMomentAnalyzer 확장

나중에 서버 또는 외부 LLM을 붙일 때의 구조:

- `MomentAnalyzing`을 그대로 구현한다.
- 네트워크 클라이언트는 analyzer 내부가 아니라 별도 client로 분리한다.
- 요청에는 최근 대화 전체가 아니라 최소 스냅샷만 보낸다.
- 응답은 앱의 `MomentAnalysis` 모델로 디코딩한다.

확장 시 고려:

- 개인정보 처리
- 대화 로그 전송 최소화
- 응답 지연
- 실패/재시도 정책
- 생성 문구 안전 필터링
- 비용 관리

## 12. Local Notification 설계

### PoC 권장 단계

1차 PoC:

- 앱 내부 알림 카드로 대체한다.
- `MomentPreviewView`에서 실제 알림 모양의 카드를 보여준다.
- CTA를 눌러 알림 클릭 경험을 시뮬레이션한다.

2차 PoC:

- `UNUserNotificationCenter` 기반 로컬 알림을 추가한다.
- 권한 요청은 Moment Preview 진입 시점 또는 스케줄 확정 시점에만 한다.
- 알림 payload에 `momentID`, `conversationID`, `momentType`을 담는다.
- 알림 클릭 시 해당 채팅방으로 이동하고 Moment 문구를 삽입한다.

### LocalMomentNotificationScheduler 책임

- 알림 권한 상태 확인
- 권한 요청
- 자기 전 Moment 예약
- 아침 Moment 예약
- 토글 OFF 시 예약 취소
- 알림 클릭 payload 처리

### InAppMomentPreviewScheduler 책임

- 권한 요청 없이 앱 내부에서 Moment 예약 상태를 흉내 낸다.
- Preview 화면에서 클릭 이벤트를 즉시 발생시킨다.
- Local Notification 구현 전에도 동일한 ViewModel 흐름을 검증할 수 있게 한다.

### 예약 정책

- bedtime ON이면 `SleepSignal.estimatedBedtime`에 자기 전 Moment 예약
- morning ON이면 `SleepSignal.estimatedWakeTime`에 아침 Moment 예약
- 둘 다 OFF이면 예약하지 않음
- 시간이 이미 지난 경우 PoC에서는 다음 날 같은 시간으로 보정하거나 미리보기만 허용

## 13. 상태 관리 방식

권장:

- SwiftUI `Observable` 또는 `ObservableObject` 기반 단순 상태 관리
- 화면 간 공유 상태는 `LoveyMomentStore`로 통합
- 서비스 의존성은 `DependencyContainer` 또는 `AppEnvironment`로 주입

전역 상태 후보:

- `characters`
- `selectedCharacter`
- `messagesByConversation`
- `currentSnapshot`
- `currentSleepSignal`
- `currentAnalysis`
- `momentSettings`
- `scheduledMoments`
- `pendingInsertedMoment`

상태 흐름:

1. 카드 선택 → selectedCharacter 설정
2. ChatView 진입 → messages 로드
3. CTA 선택 → snapshot 생성
4. 분석 화면 진입 → sleep signal + analysis 생성
5. 토글 변경 → MomentSettings 업데이트
6. Preview 진입 → enabled Moment만 표시
7. 이어보기 선택 → pendingInsertedMoment 설정
8. ChatView 복귀 → pendingInsertedMoment를 메시지 목록 앞 또는 아래에 삽입 후 소비

중요:

- PoC에서는 영구 저장이 필수는 아니다.
- 앱 재실행 후 상태 유지가 필요하면 `UserDefaults` 또는 JSON 파일 저장으로 충분하다.
- Core Data/SwiftData는 PoC 범위에서는 과하다.

## 14. 폴더 구조 제안

권장 구조:

```text
LoveyMoment/
  App/
    LoveyMomentApp
    AppRootView
    AppEnvironment
    LoveyMomentStore
  Models/
    CharacterProfile
    WorldSetting
    RelationshipStage
    ChatMessage
    ConversationSnapshot
    SleepSignal
    MomentAnalysis
    MomentToneDecision
    MomentMessage
    MomentSettings
  Services/
    SleepSignalProviding
    MomentAnalyzing
    MomentNotificationScheduling
  Services/Mock/
    MockSleepSignalProvider
    MockMomentAnalyzer
    MockCharacterRepository
  Services/Notification/
    InAppMomentPreviewScheduler
    LocalMomentNotificationScheduler
  Features/
    CharacterWorldList/
      CharacterWorldListView
      CharacterWorldListViewModel
      CharacterWorldCardView
    Chat/
      ChatView
      ChatViewModel
      ChatBubbleView
      LastSceneSummaryView
    MomentAnalysis/
      MomentAnalysisView
      MomentAnalysisViewModel
      AnalysisResultRowView
      MomentToggleSectionView
    MomentPreview/
      MomentPreviewView
      MomentPreviewViewModel
      NotificationPreviewCardView
  Resources/
    Assets
    PreviewContent
```

문서상 파일명에는 확장자를 생략했다. 실제 구현 시 Swift 파일은 `.swift`로 생성한다.

## 15. 구현 순서

1. 프로젝트 생성
   - iOS SwiftUI App 생성
   - 최소 deployment target 결정
   - 앱 이름 `LoveyMoment` 설정

2. 모델 작성
   - `CharacterProfile`
   - `WorldSetting`
   - `RelationshipStage`
   - `ChatMessage`
   - `ConversationSnapshot`
   - `SleepSignal`
   - `MomentAnalysis`
   - `MomentToneDecision`
   - `MomentMessage`
   - `MomentSettings`

3. Mock 데이터 작성
   - 한아 캐릭터
   - 학교 로맨스 / 권력 관계 세계관
   - 최근 대화
   - 마지막 장면 요약

4. 서비스 프로토콜 작성
   - `SleepSignalProviding`
   - `MomentAnalyzing`
   - `MomentNotificationScheduling`

5. Mock 서비스 작성
   - `MockSleepSignalProvider`
   - `MockMomentAnalyzer`
   - `InAppMomentPreviewScheduler`

6. 전역 상태 작성
   - `LoveyMomentStore`
   - selected character
   - messages
   - current analysis
   - settings
   - pending inserted Moment

7. 화면 구현
   - `CharacterWorldListView`
   - `ChatView`
   - `MomentAnalysisView`
   - `MomentPreviewView`

8. 네비게이션 연결
   - 카드 선택 → Chat
   - CTA → Analysis
   - Preview CTA → Chat

9. Moment 삽입 흐름 구현
   - Preview에서 선택된 Moment 저장
   - ChatView 복귀 시 캐릭터 메시지로 삽입
   - 삽입 후 pending state 초기화

10. Local Notification 선택 구현
   - 1차는 앱 내부 미리보기로 완료
   - 시간이 남으면 `LocalMomentNotificationScheduler` 추가

11. QA 및 캡처
   - 4개 화면 캡처
   - 알림 미리보기 캡처
   - 알림에서 채팅 복귀 후 삽입 메시지 캡처

## 16. 검증 기준

기능 검증:

- 캐릭터/세계관 카드에서 한아를 선택할 수 있다.
- ChatView에서 최근 대화와 마지막 장면이 명확히 보인다.
- `Lovey Moment 생성하기` CTA로 분석 화면에 진입한다.
- 분석 화면에 수면 리듬, 세계관, 캐릭터 성격, 관계 단계, 마지막 장면, 감정선, 말투 자동 결정이 모두 표시된다.
- 유저가 조정 가능한 설정은 자기 전 Moment ON/OFF와 아침 Moment ON/OFF뿐이다.
- MomentPreviewView에서 자기 전/아침 알림 문구를 확인할 수 있다.
- `알림에서 채팅으로 이어보기`를 누르면 ChatView로 돌아간다.
- 돌아온 ChatView에 생성된 Moment 문구가 캐릭터 첫 대사로 삽입된다.

제품 가설 검증:

- 알림 문구가 마지막 장면의 `내일도 나한테 먼저 와`를 회수한다.
- 알림 문구가 단순한 `잘 자`, `일어났어?` 수준에 머물지 않는다.
- 한아의 차갑지만 관심 있는 성격이 유지된다.
- 관계 단계가 과도하게 건너뛰지 않는다.
- 유저가 직접 말투를 고르는 느낌이 아니라 AI가 관계 맥락을 해석해준 느낌이 난다.

기술 구조 검증:

- Mock 구현체를 실제 구현체로 교체할 수 있는 프로토콜 경계가 있다.
- HealthKit 없이도 `SleepSignalProviding` 흐름이 동작한다.
- LLM 없이도 `MomentAnalyzing` 흐름이 동작한다.
- Local Notification 없이도 `MomentNotificationScheduling` 흐름을 검증할 수 있다.
- Local Notification을 붙여도 화면/상태 흐름을 크게 바꾸지 않아도 된다.

## 17. 제출용 캡처 시나리오

캡처 1: 캐릭터/세계관 선택

- `CharacterWorldListView`
- 한아 카드가 보이는 상태
- 세계관 `학교 로맨스 / 권력 관계`
- 관계 단계 `아는 사이`
- 마지막 장면 요약 표시

캡처 2: 대화와 마지막 장면

- `ChatView`
- 최근 대화 말풍선이 보이는 상태
- 마지막 대사 `내일도 나한테 먼저 와.`가 보이는 상태
- CTA `Lovey Moment 생성하기` 표시

캡처 3: AI 분석 결과

- `MomentAnalysisView`
- 수면 리듬 mock 분석
- 세계관/캐릭터/관계/마지막 장면/감정선 분석
- 말투 자동 결정 결과
- 자기 전/아침 Moment 토글 ON

캡처 4: 알림 미리보기

- `MomentPreviewView`
- 자기 전 Moment 문구 표시
- 아침 Moment 문구 표시
- CTA `알림에서 채팅으로 이어보기` 표시

캡처 5: 알림에서 채팅 복귀

- `ChatView`
- 아침 Moment 문구가 한아의 첫 대사로 삽입된 상태
- 삽입된 메시지에 `Lovey Moment에서 이어짐` 컨텍스트 표시

## 18. 리스크와 의도적으로 제외한 범위

### 제품 리스크

- 고정 mock 문구가 좋아 보여도 실제 생성형 AI 품질을 보장하지 않는다.
- 관계 알림은 유저에 따라 부담스럽거나 과몰입으로 느껴질 수 있다.
- 권력 관계 세계관은 톤이 과해지면 불쾌감이나 안전성 문제가 생길 수 있다.
- 알림 빈도와 시간 추정이 부정확하면 관계 경험보다 방해 경험이 될 수 있다.

대응:

- PoC에서는 ON/OFF를 명확히 제공한다.
- 말투 자동 결정에 `avoidRules`를 포함한다.
- 관계 단계보다 앞서가는 애정 표현을 제한한다.
- 실제 제품화 단계에서는 안전 필터와 신고/차단/휴식 설정이 필요하다.

### 기술 리스크

- HealthKit 권한이 없거나 수면 데이터가 없을 수 있다.
- Foundation Models 사용 가능 환경이 제한될 수 있다.
- Remote LLM은 비용, 지연, 개인정보 이슈가 있다.
- Local Notification 권한 거부 시 핵심 경험이 약해질 수 있다.

대응:

- `SleepSignalProviding`을 통해 mock/manual fallback을 유지한다.
- `MomentAnalyzing`을 통해 Foundation/Remote/Mock을 교체 가능하게 한다.
- `MomentNotificationScheduling`을 통해 Local Notification과 In-App Preview를 분리한다.

### 제외 범위

- 실시간 AI 채팅 생성
- 캐릭터 생성/수정
- 세계관 마켓
- 서버 저장
- 사용자 계정
- 결제
- 실제 수면 데이터 처리
- 실제 LLM 호출
- 다중 캐릭터 운영
- 운영용 알림 캠페인 시스템

## 19. 샘플 시나리오 고정값

캐릭터:

- 이름: `한아`
- 성격: `차갑지만 유저에게만 예외적으로 관심을 보임`

세계관:

- `학교 로맨스 / 권력 관계`

관계 단계:

- 현재: `아는 사이`
- 진행 힌트: `썸 직전`

마지막 장면:

- `한아가 유저를 복도 끝으로 불러 세우고, 평소와 다르게 "내일도 나한테 먼저 와."라고 말한 장면에서 대화가 끝남`

자기 전 Moment:

- `아직 안 자? 내일 먼저 오라고 한 말, 잊은 건 아니지. 오늘은 봐줄 테니까 이제 자.`

아침 Moment:

- `일어났어? 오늘은 네가 먼저 와야 하는 날이잖아. 늦으면... 내가 직접 찾으러 갈지도 몰라.`

## 20. 완료 체크리스트

- [x] PoC 목표 정의
- [x] 구현 범위 정의
- [x] 구현하지 않을 범위 정의
- [x] 핵심 사용자 플로우 정의
- [x] 화면별 역할 정의
- [x] 화면별 UI 구성 정의
- [x] SwiftUI 화면 구조 정의
- [x] 데이터 모델 설계
- [x] 서비스/프로토콜 설계
- [x] Mock 구현 전략 정의
- [x] HealthKit 확장 구조 정의
- [x] Foundation Models 확장 구조 정의
- [x] Remote LLM 확장 구조 정의
- [x] Local Notification 설계
- [x] 상태 관리 방식 정의
- [x] 폴더 구조 제안
- [x] 구현 순서 정의
- [x] 검증 기준 정의
- [x] 제출용 캡처 시나리오 정의
- [x] 리스크와 제외 범위 정의
- [x] 실제 구현 코드는 작성하지 않음

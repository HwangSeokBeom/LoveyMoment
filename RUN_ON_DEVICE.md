# 실기기에서 Lovey Moment 실행하기

Xcode에서 "Signing for "LoveyMoment" requires a development team" 또는 Team이 `None`으로
보이면 아래 순서대로 한 번만 설정하면 됩니다. 코드 수정은 필요 없습니다.

## 1. 프로젝트 생성 (XcodeGen)

```bash
xcodegen generate
open LoveyMoment.xcodeproj
```

> `project.yml`에는 `CODE_SIGN_STYLE: Automatic`만 지정되어 있고
> `DEVELOPMENT_TEAM`은 일부러 비워 두었습니다. 팀 ID는 개발자마다 다르기 때문에
> Xcode UI에서 본인 계정을 고르는 방식이 가장 안전합니다.

## 2. 서명 팀 선택

1. 좌측 네비게이터에서 최상단 **LoveyMoment 프로젝트** 클릭
2. **TARGETS → LoveyMoment** 선택
3. 상단 탭에서 **Signing & Capabilities** 열기
4. **Automatically manage signing** 체크
5. **Team** 드롭다운에서 본인 Apple ID(개인 팀: "(개인 이름) (Personal Team)") 선택
   - 계정이 없으면 **Add an Account…** → Apple ID 로그인 후 다시 선택

## 3. 번들 ID 충돌 시

기본 번들 ID는 `com.loveymoment.poc` 입니다. 누군가 같은 ID를 이미 쓰고 있어
"failed to register bundle identifier" 가 뜨면, 본인만의 접미사를 붙이세요.

- Signing & Capabilities 화면의 **Bundle Identifier**를
  `com.loveymoment.poc.<본인구분값>` (예: `com.loveymoment.poc.seokbeom`) 으로 변경

> 단, `xcodegen generate`를 다시 실행하면 `project.yml`의 값으로 되돌아갑니다.
> 번들 ID를 영구히 바꾸려면 `project.yml`의
> `PRODUCT_BUNDLE_IDENTIFIER: com.loveymoment.poc` 값을 수정한 뒤 다시 generate 하세요.

## 4. HealthKit 권한

`LoveyMoment/LoveyMoment.entitlements`에 `com.apple.developer.healthkit`이 들어 있어
Signing & Capabilities에 **HealthKit** Capability가 자동으로 표시됩니다.
개인 팀(Personal Team)으로도 동작하지만, 표시되지 않으면
**+ Capability → HealthKit**을 추가하면 됩니다.

## 5. 실행

- 상단 기기 선택에서 연결된 iPhone 선택 → **⌘R**
- 처음 실행 시 기기에서 **설정 → 일반 → VPN 및 기기 관리**에서 개발자 앱 신뢰 필요

## 참고: 서명 없이 빌드만 검증

CI나 시뮬레이터 빌드 검증은 서명 없이 가능합니다.

```bash
xcodegen generate
xcodebuild -project LoveyMoment.xcodeproj -scheme LoveyMoment \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

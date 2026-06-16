# Logit 배포 플랜

## Context

Flutter 앱 "Logit" (현 `time_tracker`)을 처음으로 공개 배포하는 작업.
두 스토어 모두 계정 없음. Android 먼저, iOS 나중. MVP/베타 수준으로 Play Console Internal Testing 시작.
CI/CD는 Codemagic 사용.

---

## Phase 1: Android 배포 (지금 시작)

### 1-1. 코드에서 앱 이름 변경: "Logit"
- `src/android/app/src/main/AndroidManifest.xml` → `android:label="Logit"`
- `src/ios/Runner/Info.plist` → `CFBundleDisplayName` → `Logit`

### 1-2. Google Play Console 등록
- https://play.google.com/console/signup
- Google 계정으로 로그인 → 개발자 계정 생성 → **$25 등록비 결제**
- 앱 생성: 이름 "Logit", 패키지명 `com.haram8009.time_tracker`

### 1-3. Android Keystore 생성

```bash
keytool -genkey -v \
  -keystore ~/upload-keystore.jks \
  -alias logit \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```

> **중요**: 비밀번호 안전한 곳에 저장. 잃어버리면 앱 업데이트 불가.
> `upload-keystore.jks` 파일 백업 필수. Git에 절대 커밋 금지.

### 1-4. Codemagic 설정

1. https://codemagic.io 가입 (GitHub 계정으로)
2. 이 레포 연결
3. Dashboard → Code signing → Android → keystore 업로드 + alias/비밀번호 입력
4. 프로젝트 루트에 `codemagic.yaml` 생성

### 1-5. codemagic.yaml

파일 위치: 레포 루트 `/codemagic.yaml` (src 바깥)

```yaml
workflows:
  android-internal:
    name: Android Internal Testing
    environment:
      flutter: stable
      android_signing:
        - upload-keystore       # Codemagic 대시보드에서 설정한 이름
    scripts:
      - cd src && flutter pub get
      - cd src && flutter test
      - cd src && flutter build appbundle --release
    artifacts:
      - src/build/app/outputs/bundle/release/*.aab
    publishing:
      google_play:
        credentials: $GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
        track: internal
```

### 1-6. Play Console → Google Service Account 연결

- Play Console → Setup → API access → Google Cloud Console에서 서비스 계정 생성
- JSON 키 다운로드 → Codemagic 환경변수 `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`에 붙여넣기

### 1-7. 첫 빌드 & 업로드

- Codemagic에서 `android-internal` 워크플로 실행
- Play Console Internal Testing 트랙에 자동 업로드
- 테스터 이메일 추가 → 링크 공유

---

## Phase 2: iOS TestFlight (나중에)

1. **Apple Developer Program 등록**: $99/년 (apple.com/kr/developer)
2. **App Store Connect에 앱 생성**: Bundle ID `com.haram8009.timeTracker`
3. **Codemagic iOS workflow 추가**: 인증서/프로비저닝 프로파일 업로드
4. **TestFlight 내부 테스터 초대**

---

## 검증

1. `flutter build appbundle --release` 로컬 빌드 성공 확인
2. Codemagic 빌드 로그 에러 없이 완료
3. Play Console Internal Testing 트랙에 AAB 파일 확인
4. 테스터 계정으로 앱 설치 + 기본 기능 동작

---

## 체크리스트

- [x] `AndroidManifest.xml` + `Info.plist` 앱 이름 → `Logit`
- [x] Google Play Console 등록 ($25)
- [x] `keytool`로 keystore 생성 + 백업
- [x] Codemagic 가입 + 레포 연결
- [x] `codemagic.yaml` 작성
- [ ] Play Console ↔ Google Service Account 연결
- [ ] 첫 번째 Internal Testing 빌드 실행

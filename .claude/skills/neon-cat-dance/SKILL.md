---
name: neon-cat-dance
description: 반려동물(고양이, 강아지) 사진과 레퍼런스 댄스 영상으로 반려동물이 그 춤을 추는 9:16 세로 숏폼을 만든다. fal MCP의 Kling Motion Control로 레퍼런스 동작을 반려동물에게 옮기고, ffmpeg로 세로 편집과 네온 자막까지 마친다. A2O LITE 'NEON' 인트로 안무 프리셋과 반려묘 '후추' 프로필이 들어 있다. 반려동물 춤 영상, 댄스 챌린지 패러디, 릴스나 틱톡용 펫 영상, 모션 컨트롤, "후추로 NEON 영상 만들어 줘" 같은 요청이면 스킬 이름을 말하지 않아도 이 스킬을 쓴다.
---

# neon-cat-dance

반려동물 사진과 레퍼런스 댄스 영상을 받아, 반려동물이 그 춤을 추는 세로 숏폼 mp4를 만든다.

흐름: 0 사전 점검 → 1 입력 → 2 레퍼런스 정리 → 3 캐릭터 이미지 → 4 Motion Control → 5 검수 → 6 마무리 편집 → 7 전달

작업 폴더는 현재 디렉터리 아래 `neon-cat/YYYY-MM-DD_<이름>/` 로 만들고 그 안에 `input/ ref/ keyframe/ render/ final/` 을 둔다. 중간 결과를 남겨 두어야 다시 할 때 돈이 드는 호출을 반복하지 않는다.

스크립트 경로는 이 스킬 폴더 기준 `scripts/` 다. 처음 쓸 때 `chmod +x scripts/*.sh` 를 해 둔다.

## 0. 사전 점검

- **fal MCP**: 도구 목록에 fal 도구가 있는지 본다. 없으면 여기서 멈추고 사용자에게 연결 방법을 안내한다. 다른 도구로 흉내 내거나 결과를 지어내지 않는다.
  ```
  claude mcp add --transport http --scope user fal https://mcp.fal.ai/mcp-relay
  ```
  실행한 뒤 `/mcp` → `fal` 선택 → 브라우저에서 로그인. 새 세션부터 도구가 잡힌다. fal 계정에 크레딧이 있어야 생성이 된다.
- **ffmpeg**: `ffmpeg -version`. 없으면 macOS는 `brew install ffmpeg`.
- **perl**: 자막 크기 계산에 쓴다. macOS에는 기본으로 있다.

## 1. 입력

- **반려동물 사진**: 여러 장 받는다. `pets/<이름>.md` 프로필이 있으면 먼저 읽는다(후추는 `pets/huchu.md`). 프로필이 없으면 사진을 보고 같은 형식으로 새로 쓰고, 사용자 확인을 받은 뒤 저장한다. 다음부터는 외형 설명을 다시 맞출 필요가 없다.
- **레퍼런스 영상**: 사용자가 직접 저장한 파일(화면 녹화 등)만 쓴다. 링크만 받으면 화면 녹화로 저장해 달라고 부탁한다. 인스타그램은 로그인하지 않으면 내려받기가 자주 막히고, 남의 게시물을 긁어 오는 건 약관 문제도 있다.
- **프리셋**: A2O LITE 'NEON'이면 `references/a2o-lite-neon.md` 를 읽는다. 곡 정보는 거기 있는 것과 사용자가 알려 준 것만 쓴다.

## 2. 레퍼런스 정리

Claude는 영상을 직접 재생할 수 없다. 대신 프레임 격자 이미지를 만들어 Read로 본다.

1. `scripts/contact_sheet.sh -i input/<원본> -o ref/sheet_full.png` 로 전체 흐름을 본다. 칸마다 시점(초)이 찍혀 있다.
2. 쓸 구간의 시작초와 끝초를 시트에서 찾아 사용자에게 확인받는다. 화면 녹화라면 상단 상태바와 하단 UI 높이(px)도 가늠한다.
3. 인물이 여럿이면 누구를 따라갈지 정해서 그 사람만 남긴다. 기준 인물이 하나여야 동작이 섞이지 않는다.
   ```
   scripts/prep_reference.sh -i input/<원본> -s <시작초> -e <끝초> -o ref/ref.mp4 [-t 위px -b 아래px | -c 폭:높이:x:y]
   ```
   오디오는 이 단계에서 뺀다. Motion Control은 레퍼런스 오디오를 결과에 그대로 싣는 게 기본값이고, 화면 녹화 음원이 들어간 영상은 업로드할 때 음소거되기 쉽다.
4. `ref/ref.mp4` 로 시트를 다시 뽑아 동작을 시점별로 한 줄씩 정리한다(몸 방향, 앞발과 뒷발, 고개). 킬링 파트가 몇 초에 있는지 적어 둔다.

## 3. 캐릭터 이미지

결과 품질이 가장 크게 갈리는 단계다. Motion Control은 이미지 속 몸의 구조(어깨, 팔꿈치, 다리)를 읽어서 동작을 입힌다. 옆으로 앉은 고양이 사진은 어깨가 몸통에 묻혀 실패하고, 정면으로 선 사진은 성공했다는 사례가 있다(PicLumen, Kling 2.6 Motion Control 고양이 실험). 장모종은 털 때문에 관절이 더 안 보인다.

- 정면이고, 서 있거나 앞발이 몸에서 떨어져 관절이 보이는 사진이 있으면 그대로 쓴다.
- 없으면 fal 이미지 편집 모델로 직립 키프레임을 먼저 만든다. 모델 ID는 자주 바뀌니 fal에서 image edit 모델을 검색하고, 참조 이미지를 여러 장 받는 모델을 고른다. 전신 사진과 정면 얼굴 사진을 같이 넣는다.
- 배경도 이 단계에서 네온 무대로 만든다. 결과 영상의 겉모습이 이 이미지를 따라가는 것으로 보인다[추정]. 첫 결과에서 확인하고, 아니면 이 줄을 고친다.

키프레임 프롬프트(`{APPEARANCE}` 는 프로필의 영어 설명):

```
The same cat as in the reference photos, standing upright on its hind legs in a dance-ready pose, full body visible from ear tips to hind paws, facing the camera. Front paws raised slightly away from the body so the shoulders and elbows are clearly readable. Keep the cat's identity exactly: {APPEARANCE}. Setting: a dark stage at night with hot pink and electric blue neon light strips behind the cat and light haze. Neon rim light only on the fur edges; the cat's real fur color stays unchanged. Photorealistic, cinematic, vertical 9:16, no text, no people.
```

만든 이미지는 원본 사진과 나란히 보고 털색, 얼굴 마스크, 눈 색, 귀 모양이 프로필과 다르면 다시 만든다. 사용자가 OK하면 `keyframe/` 에 저장한다.

## 4. Motion Control

- **모델**: fal에서 `kling motion control` 을 검색한다. 2026-10 기준으로 확인된 엔드포인트는 `fal-ai/kling-video/v3/standard/motion-control` 와 `fal-ai/kling-video/v3/pro/motion-control` 이다. standard로 먼저 시험하고, 결과가 괜찮으면 pro로 최종본을 뽑는다. 비용 차이 때문이다.
- **호출 전에 매번**: 스키마를 조회해서 파라미터 이름을 확인한다(버전마다 바뀔 수 있다). 가격도 확인해서 "이번 호출에 대략 얼마"를 사용자에게 말하고 승인을 받는다. 실패하면 자동 재시도는 한 번까지만 하고, 그다음은 사용자에게 묻는다.
- **주요 입력**: `image_url`(3단계 이미지), `video_url`(`ref/ref.mp4`), `character_orientation`. 춤은 `video` 로 둔다. 레퍼런스의 방향을 따라가고 최대 30초까지 된다. `image` 는 최대 10초다.
- **로컬 파일을 URL로**: fal MCP에 업로드 도구가 있으면 그걸 쓴다. 없으면 `pip install fal-client` 후 `python3 -c "import fal_client; print(fal_client.upload_file('ref/ref.mp4'))"` 를 쓴다(환경변수 `FAL_KEY` 필요). 둘 다 안 되면 사용자에게 묻는다.
- **프롬프트 입력이 있으면**:
  ```
  A {APPEARANCE_SHORT} cat dancing on a neon-lit stage, following the reference choreography with smooth, confident moves, including a clean spin on one hind leg. Keep the cat's exact fur color, markings and face from the reference image. No humans, no text.
  ```
- 결과는 `render/standard_v1.mp4`, `render/pro_v1.mp4` 처럼 모델과 버전을 붙여 저장한다.

## 5. 검수

`scripts/contact_sheet.sh -i render/<결과> -o render/<결과>_sheet.png -r 4` 로 시트를 만들어 직접 본다.

| 확인할 것 | 문제가 보이면 |
|---|---|
| 털색, 얼굴 마스크, 눈 색이 프로필과 같은가 | 3단계 이미지를 바꾼다 |
| 사람 얼굴, 손가락, 옷이 섞였는가 | 결과를 버린다. 레퍼런스를 더 좁게 자르고 다시 한다 |
| 킬링 파트에서 몸이 녹거나 다리가 늘어나는가 | 구간을 짧게 자르거나 pro로 다시 한다 |

레퍼런스 속 인물은 실존 인물이다. NEON 프리셋은 멤버 대부분이 미성년자라서, 사람 흔적이 남은 결과는 쓰지 않는다. 시트를 사용자에게 보여 주고 다음 단계로 갈지 묻는다.

## 6. 마무리 편집

1. 자막 파일 `final/captions.txt` 를 만든다. 한 줄에 `시작초|끝초|문구`. 시점은 사용자에게 받은 후렴과 킬링 파트 위치를 기준으로 잡는다.
2. 세로 맞춤과 자막:
   ```
   scripts/finish_vertical.sh -i render/<최종> -o final/<이름>_neon.mp4 -c final/captions.txt
   ```
   9:16이 아니면 같은 영상을 흐리게 깔아 빈 곳을 채운다. 자막은 글자 수에 맞춰 크기가 자동으로 줄어든다. 기본은 무음이고, 소리 있는 미리보기가 필요하면 `-k` 를 붙인다.
3. 자막이 있는 시점의 프레임을 몇 장 뽑아 잘림이나 겹침이 없는지 확인한다.

## 7. 전달

- 최종 파일 경로, 쓴 모델, 알 수 있다면 실제 과금액을 알려 준다.
- 사용자가 할 일을 안내한다: 인스타 릴스나 틱톡 앱의 음악 목록에서 음원을 붙이고, 자막 시점이 음원과 맞는지 확인한다.
- 작업 폴더는 그대로 둔다. 다음에 자막만 바꾸거나 pro로 다시 뽑을 때 쓴다.

## 원칙

- 반려동물 외형은 프로필이 기준이다. 예뻐 보이게 고치지 않는다.
- 레퍼런스 인물에게서는 동작만 빌린다.
- 돈이 드는 호출은 매번 승인을 받는다.
- 곡 정보, 모델 파라미터, 가격은 추측하지 않는다. 사용자나 fal 스키마에서 확인한다.

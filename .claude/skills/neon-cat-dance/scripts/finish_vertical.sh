#!/usr/bin/env bash
# 생성된 영상을 1080x1920 세로로 맞추고 네온 자막을 입혀 업로드용 mp4로 내보낸다.
# 비율이 9:16이 아니면 같은 영상을 흐리게 깔아 빈 곳을 채운다(검은 띠보다 릴스에서 자연스럽다).
# 사용법: finish_vertical.sh -i 입력.mp4 -o 출력.mp4 [-c 자막.txt] [-f 폰트경로] [-k]
#   자막.txt 한 줄 형식: 시작초|끝초|문구     예) 3.0|5.5|미혼앤비혼
#   -k 를 주면 오디오를 유지한다(기본은 무음: 음원은 인스타나 틱톡 앱 음악 목록에서 붙인다)
set -euo pipefail

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

in="" out="" captions="" font="" keep_audio=0
while getopts "i:o:c:f:kh" opt; do
  case "$opt" in
    i) in="$OPTARG" ;;
    o) out="$OPTARG" ;;
    c) captions="$OPTARG" ;;
    f) font="$OPTARG" ;;
    k) keep_audio=1 ;;
    *) usage ;;
  esac
done
[[ -z "$in" || -z "$out" ]] && usage
[[ -f "$in" ]] || { echo "입력 파일 없음: $in" >&2; exit 1; }

# 한글이 들어가는 폰트를 찾는다: macOS 기본 폰트 우선, 없으면 fontconfig
if [[ -z "$font" ]]; then
  for f in "/System/Library/Fonts/AppleSDGothicNeo.ttc" "/Library/Fonts/AppleGothic.ttf"; do
    [[ -f "$f" ]] && { font="$f"; break; }
  done
fi
if [[ -z "$font" ]] && command -v fc-match >/dev/null; then
  font=$(fc-match -f '%{file}' ':lang=ko' 2>/dev/null || true)
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

base="[0:v]split=2[bg][fg];\
[bg]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=20:2,eq=brightness=-0.15[bgb];\
[fg]scale=1080:1920:force_original_aspect_ratio=decrease[fgs];\
[bgb][fgs]overlay=(W-w)/2:(H-h)/2,fps=30"

# 문구는 파일로 넘겨야 쉼표, 콜론, 따옴표가 필터 문법과 충돌하지 않는다
draw=""
if [[ -n "$captions" ]]; then
  [[ -f "$captions" ]] || { echo "자막 파일 없음: $captions" >&2; exit 1; }
  [[ -n "$font" ]] || { echo "한글 폰트를 찾지 못했습니다. -f 로 지정해 주세요" >&2; exit 1; }
  n=0
  while IFS='|' read -r s e text || [[ -n "${s:-}" ]]; do
    [[ -z "${s// }" || "${s:0:1}" == "#" ]] && continue
    n=$((n + 1))
    printf '%s' "$text" > "$work/cap$n.txt"
    # 한글은 1em, 영문과 기호는 0.6em으로 어림해 화면 폭(여백 빼고 960px)에 들어가게 크기를 줄인다
    size=$(printf '%s' "$text" | perl -CSD -ne 'chomp; my $w = 0;
      for my $c (split //) { $w += ord($c) > 0x2E80 ? 1.0 : 0.6 }
      my $s = $w > 0 ? int(960 / $w) : 88; $s = 88 if $s > 88; $s = 40 if $s < 40; print $s')
    draw+=",drawtext=fontfile='${font}':textfile='$work/cap$n.txt':fontsize=${size}:fontcolor=white\
:borderw=7:bordercolor=0xFF2EC4@0.85:shadowcolor=0x2E9BFF@0.9:shadowx=0:shadowy=6\
:x=(w-text_w)/2:y=h*0.72:enable='between(t,${s},${e})'"
  done < "$captions"
fi

audio_opts=(-an)
if [[ $keep_audio -eq 1 ]]; then
  audio_opts=(-map "0:a?" -c:a aac -b:a 192k)
fi

mkdir -p "$(dirname "$out")"
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$in" \
  -filter_complex "${base}${draw},format=yuv420p[v]" \
  -map "[v]" "${audio_opts[@]}" \
  -c:v libx264 -preset medium -crf 18 -profile:v high -movflags +faststart \
  "$out"

ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate:format=duration \
  -of default=noprint_wrappers=1 "$out"
echo "완료: $out"

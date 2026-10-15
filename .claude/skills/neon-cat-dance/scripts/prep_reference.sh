#!/usr/bin/env bash
# 레퍼런스 댄스 영상을 Motion Control 입력용으로 정리한다.
# - 지정 구간만 자르고, 화면 녹화의 상단바나 하단 UI를 잘라내고, 오디오를 뺀다.
#   (Kling Motion Control은 레퍼런스 오디오를 결과에 그대로 싣는 게 기본값이라, 음원은 앱에서 따로 붙인다)
# 사용법: prep_reference.sh -i 입력.mp4 -s 시작초 -e 끝초 -o 출력.mp4 [-t 위쪽px] [-b 아래쪽px] [-c 폭:높이:x:y]
#   -c 를 주면 -t/-b 대신 그 영역만 남긴다(2인 안무에서 한 명만 남길 때)
set -euo pipefail

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

in="" start="" end="" out="" top=0 bottom=0 box=""
while getopts "i:s:e:o:t:b:c:h" opt; do
  case "$opt" in
    i) in="$OPTARG" ;;
    s) start="$OPTARG" ;;
    e) end="$OPTARG" ;;
    o) out="$OPTARG" ;;
    t) top="$OPTARG" ;;
    b) bottom="$OPTARG" ;;
    c) box="$OPTARG" ;;
    *) usage ;;
  esac
done
[[ -z "$in" || -z "$start" || -z "$end" || -z "$out" ]] && usage
[[ -f "$in" ]] || { echo "입력 파일 없음: $in" >&2; exit 1; }

dur=$(awk -v s="$start" -v e="$end" 'BEGIN { d = e - s; if (d <= 0) exit 1; printf "%.3f", d }') \
  || { echo "끝초가 시작초보다 커야 합니다" >&2; exit 1; }
if awk -v d="$dur" 'BEGIN { exit !(d > 30) }'; then
  echo "경고: ${dur}초. Motion Control은 character_orientation=video 기준 최대 30초입니다." >&2
fi

if [[ -n "$box" ]]; then
  crop="crop=${box}"
else
  crop="crop=iw:ih-${top}-${bottom}:0:${top}"
fi
# libx264는 폭과 높이가 짝수여야 받는다
vf="${crop},scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=30,format=yuv420p"

mkdir -p "$(dirname "$out")"
ffmpeg -hide_banner -loglevel error -y \
  -ss "$start" -i "$in" -t "$dur" \
  -vf "$vf" -an \
  -c:v libx264 -preset medium -crf 18 -movflags +faststart \
  "$out"

ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate:format=duration \
  -of default=noprint_wrappers=1 "$out"
echo "완료: $out"

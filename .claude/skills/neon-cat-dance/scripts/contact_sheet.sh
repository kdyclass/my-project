#!/usr/bin/env bash
# 영상에서 일정 간격으로 프레임을 뽑아 한 장짜리 격자 이미지로 만든다.
# Claude가 영상을 직접 볼 수 없으니, 이 이미지를 Read로 열어 동작 흐름이나 결과 품질을 확인한다.
# 사용법: contact_sheet.sh -i 입력.mp4 -o 시트.png [-r 초당프레임수, 기본 2] [-c 열 수, 기본 6]
set -euo pipefail

usage() { sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

in="" out="" rate=2 cols=6
while getopts "i:o:r:c:h" opt; do
  case "$opt" in
    i) in="$OPTARG" ;;
    o) out="$OPTARG" ;;
    r) rate="$OPTARG" ;;
    c) cols="$OPTARG" ;;
    *) usage ;;
  esac
done
[[ -z "$in" || -z "$out" ]] && usage
[[ -f "$in" ]] || { echo "입력 파일 없음: $in" >&2; exit 1; }

dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
frames=$(awk -v d="$dur" -v r="$rate" 'BEGIN { n = int(d * r); if (n < 1) n = 1; print n }')
rows=$(( (frames + cols - 1) / cols ))

mkdir -p "$(dirname "$out")"
# 각 칸 왼쪽 위에 시점(초)을 찍어 두면 "몇 초에 턴이 나오는지"를 바로 읽을 수 있다
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$in" \
  -vf "fps=${rate},scale=240:-2,drawtext=text='%{pts\:hms}':x=6:y=6:fontsize=16:fontcolor=white:box=1:boxcolor=black@0.6,tile=${cols}x${rows}:padding=4:color=black" \
  -frames:v 1 "$out"
echo "완료: $out (${frames}칸, ${cols}x${rows})"

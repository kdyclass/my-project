#!/usr/bin/env bash
# AI 생성 없이 사진만으로 네온 무드 세로 티저(1080x1920, 무음)를 만든다.
# 사진마다 천천히 줌을 주고, 핑크와 블루 네온 톤, 네온 테두리, 컷 전환 때 핑크 플래시를 얹는다.
# 사용법: photo_teaser.sh -p 구성.txt -o 출력.mp4 [-c 자막.txt] [-g 네온 세기 0에서1, 기본 0.7]
#   구성.txt 한 줄 형식: 사진경로|초|움직임(in 또는 out)|감마(선택, 기본 1.0)   예) input/night.jpg|3|in|1.3
#   자막.txt 형식은 finish_vertical.sh 와 같다(시작초|끝초|문구)
set -euo pipefail

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

plan="" out="" captions="" tone=0.7
while getopts "p:o:c:g:h" opt; do
  case "$opt" in
    p) plan="$OPTARG" ;;
    o) out="$OPTARG" ;;
    c) captions="$OPTARG" ;;
    g) tone="$OPTARG" ;;
    *) usage ;;
  esac
done
[[ -z "$plan" || -z "$out" ]] && usage
[[ -f "$plan" ]] || { echo "구성 파일 없음: $plan" >&2; exit 1; }

here="$(cd "$(dirname "$0")" && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# 아이폰 사진은 EXIF 회전값이 있어 그대로 넣으면 눕는 경우가 있고, HEIC는 ffmpeg가 못 읽을 수 있다.
# 그래서 먼저 똑바로 세운 JPG로 바꿔 둔다.
normalize() {
  local src="$1" dst="$2"
  if python3 -c "import PIL" 2>/dev/null; then
    python3 - "$src" "$dst" <<'PY' && return 0
import sys
from PIL import Image, ImageOps
try:
    import pillow_heif
    pillow_heif.register_heif_opener()
except ImportError:
    pass
im = ImageOps.exif_transpose(Image.open(sys.argv[1])).convert("RGB")
# 밤에 찍은 어두운 사진도 다른 컷과 밝기가 비슷해지게 명암 폭을 펴 준다(색감은 유지)
im = ImageOps.autocontrast(im, cutoff=1, preserve_tone=True)
im.save(sys.argv[2], quality=95)
PY
  fi
  if command -v sips >/dev/null; then
    sips -s format jpeg "$src" --out "$dst" >/dev/null && return 0
  fi
  cp "$src" "$dst"
}

# 가운데는 투명하고 가장자리로 갈수록 밝아지는 마스크. 네온 빛을 가장자리에만 번지게 해서
# 반려동물 털색은 그대로 두고 무대 조명 느낌만 낸다.
ffmpeg -nostdin -hide_banner -loglevel error -y -f lavfi -i "color=c=black:s=1080x1920:d=1" \
  -vf "format=gray,geq=lum='255*clip((hypot((X-W/2)/(W/2),(Y-H/2)/(H/2))-0.55)/0.65,0,1)'" \
  -frames:v 1 "$work/edge_mask.png"
# 같은 모양으로 가장자리를 어둡게 깎는 마스크. 밝은 배경 위에 네온을 비추면 뿌옇게 날아가서,
# 먼저 가장자리를 밤 무대처럼 눌러 둔 뒤 빛을 얹는다.
ffmpeg -nostdin -hide_banner -loglevel error -y -f lavfi -i "color=c=black:s=1080x1920:d=1" \
  -vf "format=gray,geq=lum='255*(1-0.6*clip((hypot((X-W/2)/(W/2),(Y-H/2)/(H/2))-0.45)/0.6,0,1))'" \
  -frames:v 1 "$work/edge_dark.png"

n=0
: > "$work/list.txt"
while IFS='|' read -r photo secs motion gamma || [[ -n "${photo:-}" ]]; do
  [[ -z "${photo// }" || "${photo:0:1}" == "#" ]] && continue
  [[ -f "$photo" ]] || { echo "사진 없음: $photo" >&2; exit 1; }
  n=$((n + 1))
  normalize "$photo" "$work/p$n.jpg"
  frames=$(awk -v s="$secs" 'BEGIN { printf "%d", s * 30 }')
  if [[ "${motion:-in}" == "out" ]]; then
    zoom="1.15-0.15*on/${frames}"
  else
    zoom="1+0.15*on/${frames}"
  fi

  # 2배 크기에서 줌을 계산해야 줌팬 특유의 떨림이 줄어든다
  # 4번째 칸(감마)은 어두운 사진을 밝힐 때만 쓴다. 1.0이 원본, 1.3 정도면 밤 사진이 살아난다
  gamma="${gamma:-1.0}"

  ffmpeg -nostdin -hide_banner -loglevel error -y \
    -i "$work/p$n.jpg" \
    -f lavfi -i "gradients=s=1080x1920:r=30:d=${secs}:c0=0xFF2EC4:c1=0x2E9BFF:nb_colors=2:speed=0.015:x0=0:y0=0:x1=1080:y1=1920" \
    -f lavfi -i "color=c=black:s=1080x1920:r=30:d=${secs}" \
    -loop 1 -framerate 30 -t "$secs" -i "$work/edge_mask.png" \
    -loop 1 -framerate 30 -t "$secs" -i "$work/edge_dark.png" \
    -filter_complex "\
[0:v]scale=2160:3840:force_original_aspect_ratio=increase,crop=2160:3840,\
zoompan=z='${zoom}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=1080x1920:fps=30,\
eq=gamma=${gamma}:contrast=1.04:saturation=1.05,setsar=1,format=gbrp[lit];\
[4:v]format=gbrp[dark];\
[lit][dark]blend=all_mode=multiply,format=gbrp[base];\
[1:v]format=gbrp[grad];\
[3:v]format=gbrp[mask];\
[grad][mask]blend=all_mode=multiply,format=gbrp[edgeglow];\
[base][edgeglow]blend=all_mode=screen:all_opacity=${tone},format=gbrp[toned];\
[2:v]drawbox=x=36:y=36:w=1008:h=1848:color=0xFF2EC4:t=10,drawbox=x=58:y=58:w=964:h=1804:color=0x2E9BFF:t=6,split[sharp][soft];\
[soft]gblur=sigma=18[glow];\
[sharp][glow]blend=all_mode=lighten,format=gbrp[frame];\
[toned][frame]blend=all_mode=screen,\
eq=brightness='0.025*sin(2*PI*t*2)':eval=frame,\
fade=t=in:st=0:d=0.25:color=0xFF2EC4,format=yuv420p[v]" \
    -map "[v]" -frames:v "$frames" -an \
    -c:v libx264 -preset medium -crf 18 "$work/seg$n.mp4"
  echo "file '$work/seg$n.mp4'" >> "$work/list.txt"
done < "$plan"

[[ $n -gt 0 ]] || { echo "구성 파일에 사진이 없습니다" >&2; exit 1; }

ffmpeg -nostdin -hide_banner -loglevel error -y -f concat -safe 0 -i "$work/list.txt" -c copy "$work/joined.mp4"

if [[ -n "$captions" ]]; then
  "$here/finish_vertical.sh" -i "$work/joined.mp4" -o "$out" -c "$captions"
else
  "$here/finish_vertical.sh" -i "$work/joined.mp4" -o "$out"
fi

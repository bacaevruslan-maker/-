bash scripts/setup.sh
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

command -v python3 >/dev/null 2>&1 || { echo 'Нужен Python 3 в образе окружения.' >&2; exit 1; }

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo -n "$@"
  else
    echo 'Нет прав установки. Добавьте FFmpeg и fonts-dejavu-core в образ окружения.' >&2
    return 1
  fi
}

need_packages=0
command -v ffmpeg >/dev/null 2>&1 || need_packages=1
command -v ffprobe >/dev/null 2>&1 || need_packages=1
if ! command -v fc-match >/dev/null 2>&1; then
  need_packages=1
elif ! fc-match 'DejaVu Sans' --format='%{family}\n' | grep -q 'DejaVu Sans'; then
  need_packages=1
fi

if [ "$need_packages" -eq 1 ]; then
  command -v apt-get >/dev/null 2>&1 || { echo 'Нет apt-get. Установите FFmpeg, Fontconfig и DejaVu Sans средствами вашего образа.' >&2; exit 1; }
  run_as_root apt-get update
  run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ffmpeg fontconfig fonts-dejavu-core
fi

python3 - <<'PY'
import json
import pathlib
import subprocess

config = json.loads(pathlib.Path('config/reels.json').read_text(encoding='utf-8'))
for name in ('input', 'output', 'temporary'):
    pathlib.Path(config['paths'][name]).mkdir(parents=True, exist_ok=True)
encoders = subprocess.run(['ffmpeg', '-hide_banner', '-encoders'], check=True, capture_output=True, text=True).stdout
filters = subprocess.run(['ffmpeg', '-hide_banner', '-filters'], check=True, capture_output=True, text=True).stdout
for codec in (config['video_codec'], config['audio_codec']):
    if not any(len(line.split()) > 1 and line.split()[1] == codec for line in encoders.splitlines()):
        raise SystemExit(f'В FFmpeg отсутствует кодировщик: {codec}')
if not any(len(line.split()) > 1 and line.split()[1] == 'subtitles' for line in filters.splitlines()):
    raise SystemExit('Нужен FFmpeg с фильтром subtitles (libass).')
subprocess.run(['ffprobe', '-version'], check=True, stdout=subprocess.DEVNULL)
print('Базовые инструменты монтажа готовы: Python, FFmpeg, FFprobe, H.264/AAC, субтитры.')
print('Распознавание речи и загрузка модели проверяются отдельно перед монтажом.')
PY

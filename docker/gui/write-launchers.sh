#!/bin/bash
set -euo pipefail
install -d -o sysop -g sysop \
  /home/sysop/Desktop \
  /home/sysop/.local/share/applications \
  /home/sysop/.config/autostart \
  /home/sysop/bin

write_desktop() {
  local id="$1" name="$2" comment="$3" bin="$4"
  local file="/home/sysop/.local/share/applications/${id}.desktop"
  cat >"$file" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=${name}
Comment=${comment}
Exec=/home/sysop/bin/sc-launch ${bin}
Icon=applications-science
Terminal=false
Categories=Science;Geoscience;SeisComP;
StartupNotify=true
EOF
  chmod 755 "$file"
  cp "$file" "/home/sysop/Desktop/${id}.desktop"
}

write_desktop scconfig "scconfig" "Configure modules, stations and bindings" scconfig
write_desktop scmv "scmv" "Map view" scmv
write_desktop scmvx "scmvx" "Map view (scmvx)" scmvx
write_desktop scrttv "scrttv" "Real-time waveform viewer" scrttv
write_desktop scolv "scolv" "Event analysis" scolv
write_desktop scesv "scesv" "Event summary" scesv
write_desktop scheli "scheli" "Helicorder" scheli
write_desktop scqcv "scqcv" "Quality control" scqcv
write_desktop scmm "scmm" "Messaging-system monitor" scmm

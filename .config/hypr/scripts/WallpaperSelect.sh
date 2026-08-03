#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026) – Wallpaper Select Fix v3 (rofi array)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================

# WALLPAPERS PATH
terminal=kitty
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"

if [[ -f "$SCRIPTSDIR/WallpaperCmd.sh" ]]; then
    . "$SCRIPTSDIR/WallpaperCmd.sh"
fi

: "${WWW_CMD:=swww}"
: "${WWW_DAEMON:=swww-daemon}"
: "${WWW_DAEMON_ARGS:=(--format xrgb)}"

wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper"
wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_base"

iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"
iDIRi="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"

FPS=60
TYPE="any"
DURATION=2
BEZIER=".43,1.19,1,.4"
if [[ "$WWW_CMD" == "swww" || "$WWW_CMD" == "awww" ]]; then
  SWWW_PARAMS=(--transition-fps "$FPS" --transition-type "$TYPE" --transition-duration "$DURATION" --transition-bezier "$BEZIER")
else
  SWWW_PARAMS=()
fi

if ! command -v bc &>/dev/null; then
  notify-send -i "$iDIR/error.png" "bc missing" "Install package bc first"
  exit 1
fi

rofi_theme="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config-wallpaper.rasi"

# ---------- robust monitor detection ----------
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
if [[ -z "$focused_monitor" ]]; then
  focused_monitor=$(hyprctl monitors -j | jq -r '.[0].name')
  notify-send -i "$iDIR/error.png" "No focused monitor" "Using fallback: $focused_monitor"
fi
if [[ -z "$focused_monitor" ]]; then
  notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Could not detect any monitor"
  exit 1
fi

per_monitor_wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current_${focused_monitor}"
per_monitor_wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/.current_wallpaper_${focused_monitor}"
per_monitor_wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_base_${focused_monitor}"

scale_factor=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale // 1')
monitor_height=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height // 1080')
if [[ -z "$scale_factor" || "$scale_factor" == "0" ]]; then scale_factor=1; fi

icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc)
adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
rofi_override="element-icon{size:${adjusted_icon_size}%;}"

# Use an ARRAY for the rofi command to avoid "No such file" error
rofi_cmd=(rofi -i -show -dmenu -config "$rofi_theme" -theme-str "$rofi_override")

kill_wallpaper_for_video() { pkill -f "mpvpaper.*$focused_monitor" 2>/dev/null; }
kill_wallpaper_for_image() { pkill -f "mpvpaper.*$focused_monitor" 2>/dev/null; }

# ---------- collect wallpapers ----------
mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
  -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o \
  -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) -print0 2>/dev/null)

if [[ ${#PICS[@]} -eq 0 ]]; then
  notify-send -i "$iDIR/error.png" "No wallpapers found" "Add images/videos to $wallDIR"
  exit 1
fi

RANDOM_PIC="${PICS[$((RANDOM % ${#PICS[@]}))]}"
RANDOM_PIC_NAME="$(basename "$RANDOM_PIC")"

CURRENT_MON_PIC_PATH=$("$WWW_CMD" query 2>/dev/null | grep "$focused_monitor" | awk '{print $NF}')
if [[ -z "$CURRENT_MON_PIC_PATH" ]]; then
  if [[ -L "$wallpaper_link" ]]; then
    CURRENT_MON_PIC_PATH="$(readlink -f "$wallpaper_link")"
  elif [[ -f "$wallpaper_link" ]]; then
    CURRENT_MON_PIC_PATH="$wallpaper_link"
  elif [[ -f "$wallpaper_current" ]]; then
    CURRENT_MON_PIC_PATH="$wallpaper_current"
  fi
fi
CURRENT_MON_PIC_NAME=$(basename "$CURRENT_MON_PIC_PATH" 2>/dev/null)

# ---------- associative array for full paths ----------
declare -A wallpaper_paths

menu() {
  IFS=$'\n' sorted_options=($(sort <<<"${PICS[*]}"))
  wallpaper_paths=()

  # Random entry
  printf "%s\x00icon\x1f%s\n" "Random: $RANDOM_PIC_NAME" "$RANDOM_PIC"
  wallpaper_paths["Random: $RANDOM_PIC_NAME"]="$RANDOM_PIC"

  # Current entry
  if [[ -n "$CURRENT_MON_PIC_PATH" ]]; then
    local current_label="Current: $CURRENT_MON_PIC_NAME"
    printf "%s\x00icon\x1f%s\n" "$current_label" "$CURRENT_MON_PIC_PATH"
    wallpaper_paths["$current_label"]="$CURRENT_MON_PIC_PATH"
  fi

  for pic_path in "${sorted_options[@]}"; do
    pic_name=$(basename "$pic_path")
    wallpaper_paths["$pic_name"]="$pic_path"

    if [[ "$pic_name" =~ \.gif$ ]]; then
      cache_gif_image="$HOME/.cache/gif_preview/${pic_name}.png"
      if [[ ! -f "$cache_gif_image" ]]; then
        mkdir -p "$HOME/.cache/gif_preview"
        magick "$pic_path[0]" -resize 1920x1080 "$cache_gif_image" 2>/dev/null || continue
      fi
      printf "%s\x00icon\x1f%s\n" "$pic_name" "$cache_gif_image"
    elif [[ "$pic_name" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
      cache_preview_image="$HOME/.cache/video_preview/${pic_name}.png"
      if [[ ! -f "$cache_preview_image" ]]; then
        mkdir -p "$HOME/.cache/video_preview"
        ffmpeg -v error -y -i "$pic_path" -ss 00:00:01.000 -vframes 1 "$cache_preview_image" 2>/dev/null || continue
      fi
      printf "%s\x00icon\x1f%s\n" "$pic_name" "$cache_preview_image"
    else
      printf "%s\x00icon\x1f%s\n" "$pic_name" "$pic_path"
    fi
  done
}

# ---------- startup config modifier ----------
modify_startup_config() {
  local selected_file="$1"
  local startup_config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/Startup_Apps.conf"
  [[ ! -f "$startup_config" ]] && return 0

  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm)$ ]]; then
    sed -i '/^\s*exec-once\s*=\s*\$scriptsDir\/WallpaperDaemon\.sh\s*$/s/^/\#/' "$startup_config"
    sed -i '/^\s*exec-once\s*=\s*swww-daemon\s*--format\s*xrgb\s*$/s/^/\#/' "$startup_config"
    sed -i '/^\s*#\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^#\s*//;' "$startup_config"
    selected_file="${selected_file/#$HOME/\$HOME}"
    sed -i "s|^\$livewallpaper=.*|\$livewallpaper=\"$selected_file\"|" "$startup_config"
  else
    sed -i '/^\s*#\s*exec-once\s*=\s*\$scriptsDir\/WallpaperDaemon\.sh\s*$/s/^\s*#\s*//;' "$startup_config"
    sed -i '/^\s*#\s*exec-once\s*=\s*swww-daemon\s*--format\s*xrgb\s*$/s/^\s*#\s*//;' "$startup_config"
    sed -i '/^\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^/\#/' "$startup_config"
  fi
}

# ---------- apply image / video ----------
apply_image_wallpaper() {
  local image_path="$1"
  kill_wallpaper_for_image

  if ! pgrep -x "$WWW_DAEMON" >/dev/null; then
    "$WWW_DAEMON" "${WWW_DAEMON_ARGS[@]}" &
    for _ in {1..30}; do
      "$WWW_CMD" query >/dev/null 2>&1 && break
      sleep 0.1
    done
  fi

  local resize_mode="$(wallpaper_resize_mode "$image_path" "$focused_monitor")"
  if ! "$WWW_CMD" img -o "$focused_monitor" --resize "$resize_mode" "$image_path" "${SWWW_PARAMS[@]}"; then
    sleep 0.2
    "$WWW_CMD" img -o "$focused_monitor" --resize "$resize_mode" "$image_path" "${SWWW_PARAMS[@]}" || {
      notify-send -i "$iDIR/error.png" "Wallpaper error" "Failed to set wallpaper"
      return 1
    }
  fi

  mkdir -p "$(dirname "$per_monitor_wallpaper_current")" "$(dirname "$per_monitor_wallpaper_link")"
  ln -sf "$image_path" "$per_monitor_wallpaper_link" || true
  cp -f "$image_path" "$per_monitor_wallpaper_current" || true
  mkdir -p "$(dirname "$per_monitor_wallpaper_base")"
  cp -f "$image_path" "$per_monitor_wallpaper_base" || true
  cp -f "$image_path" "$wallpaper_base" || true

  "$SCRIPTSDIR/WallustSwww.sh" "$image_path" || notify-send -i "$iDIR/error.png" "Wallust failed" "Theme not refreshed"
  sleep 0.5
  "$SCRIPTSDIR/Refresh.sh"
  sleep 0.3
}

apply_video_wallpaper() {
  local video_path="$1"
  command -v mpvpaper &>/dev/null || {
    notify-send -i "$iDIR/error.png" "mpvpaper missing" "Install mpvpaper first"
    return 1
  }
  kill_wallpaper_for_video
  mpvpaper "$focused_monitor" -o "load-scripts=no no-audio --loop" "$video_path" &
}

# ---------- main (no pipe, array rofi) ----------
main() {
  local tmp_menu
  tmp_menu=$(mktemp) || { notify-send -i "$iDIR/error.png" "Error" "Could not create temp file"; exit 1; }
  menu > "$tmp_menu"

  choice=$("${rofi_cmd[@]}" < "$tmp_menu")
  rm -f "$tmp_menu"

  [[ -z "$choice" ]] && exit 0

  choice="$(echo -n "$choice" | xargs)"
  RANDOM_PIC_NAME="$(echo -n "$RANDOM_PIC_NAME" | xargs)"

  if [[ -n "${wallpaper_paths[$choice]}" ]]; then
    selected_file="${wallpaper_paths[$choice]}"
  elif [[ -n "$CURRENT_MON_PIC_PATH" && "$choice" == "Current: $CURRENT_MON_PIC_NAME" ]]; then
    selected_file="$CURRENT_MON_PIC_PATH"
  elif [[ "$choice" == "Random: $RANDOM_PIC_NAME" ]]; then
    selected_file="$RANDOM_PIC"
  elif [[ -f "$choice" ]]; then
    selected_file="$choice"
  else
    notify-send -i "$iDIR/error.png" "File not found" "$choice"
    exit 1
  fi

  modify_startup_config "$selected_file"

  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
    apply_video_wallpaper "$selected_file"
  else
    apply_image_wallpaper "$selected_file"
  fi
}

# ---------- launch ----------
if pidof rofi >/dev/null; then
  pkill rofi
  sleep 0.2
fi
main

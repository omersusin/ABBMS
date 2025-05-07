#!/system/bin/sh
# Android Battery Monitoring System
# Version: 1.0.0
# License: MIT
# Author: AI assisted, created by Omer
# Description: Terminal-based interface for monitoring battery and thermal status of Android devices

# Strict mode for error handling
# set -euo pipefail

# Script version
VERSION="1.0.0"

# Default values
REFRESH_RATE=5
LOG_DIR="$HOME/bbms/logs"
LOG_FORMAT="csv"
LANGUAGE="en"
THEME="dark"
VIEW_MODE="detailed"
LOGGING_ENABLED=0
TERMINAL_WIDTH=80
TERMINAL_HEIGHT=24
START_LIVE=0  # Initialize START_LIVE variable

# Check if tput is installed
if ! command -v tput >/dev/null 2>&1; then
  echo "tput not found. Attempting to install..."

  # Try installing via Termux's package manager
  if command -v pkg >/dev/null 2>&1; then
    pkg update -y && pkg install ncurses -y
  elif command -v apt >/dev/null 2>&1; then
    apt update && apt install ncurses-bin -y
  else
    echo "Could not find a supported package manager to install 'tput'." >&2
    exit 1
  fi

  # Recheck after install
  if ! command -v tput >/dev/null 2>&1; then
    echo "Installation failed or 'tput' still not available." >&2
    exit 1
  fi

  echo "tput successfully installed."
fi


# Battery data storage
declare -A BATTERY_INFO=(
  [capacity]=0
  [temp]=0
  [voltage_now]=0
  [current_now]=0
  [charge_full_design]=0
  [charge_full]=0
  [charge_now]=0
  [cycle_count]=0
  [status]="Unknown"
  [health]="Unknown"
  [technology]="Unknown"
  [present]=0
  [power_mw]=0
  [health_percent]=0
  [path]=""
)

# Thermal data
declare -A THERMAL_ZONES=()
declare -a THERMAL_ZONE_NAMES=()
declare -a THERMAL_ZONE_TEMPS=()
declare -a THERMAL_ZONE_PATHS=()
declare -a THERMAL_ZONE_TRENDS=()
declare -a PREVIOUS_TEMPS=()

# Initialize the active color scheme
# Aktif renk şeması
declare -gA COLORS=()

# Color definitions
declare -A COLORS_DARK=(
  [RESET]="\033[0m"
  [BOLD]="\033[1m"
  [DIM]="\033[2m"
  [HEADER]="\033[1;36m"  # Bold Cyan
  [SUCCESS]="\033[1;32m" # Bold Green
  [WARNING]="\033[1;33m" # Bold Yellow
  [DANGER]="\033[1;31m"  # Bold Red
  [INFO]="\033[1;34m"    # Bold Blue
  [NORMAL]="\033[1;37m"  # Bold White
  [BATTERY_LOW]="\033[1;31m"  # Red
  [BATTERY_MID]="\033[1;33m"  # Yellow
  [BATTERY_HIGH]="\033[1;32m" # Green
  [THERMAL_NORMAL]="\033[1;32m" # Green
  [THERMAL_HIGH]="\033[1;33m"   # Yellow
  [THERMAL_VERY_HIGH]="\033[1;31m" # Red
  [THERMAL_CRITICAL]="\033[1;5;31m" # Flashing Red
  [BORDER]="\033[1;36m"   # Cyan
  [MENU_ITEM]="\033[1;37m" # White
  [MENU_NUMBER]="\033[1;33m" # Yellow
  [BAR_FILL]="\033[1;32m"  # Green
  [BAR_EMPTY]="\033[1;30m" # Gray
)

# First copy the dark theme as default
for key in "${!COLORS_DARK[@]}"; do
  COLORS["$key"]="${COLORS_DARK[$key]}"
done

declare -A COLORS_LIGHT=(
  [RESET]="\033[0m"
  [BOLD]="\033[1m"
  [DIM]="\033[2m"
  [HEADER]="\033[1;34m"  # Kalın Koyu Mavi
  [SUCCESS]="\033[1;32m" # Kalın Yeşil
  [WARNING]="\033[1;33m" # Kalın Sarı
  [DANGER]="\033[1;31m"  # Kalın Kırmızı
  [INFO]="\033[1;34m"    # Kalın Mavi
  [NORMAL]="\033[1;30m"  # Kalın Siyah
  [BATTERY_LOW]="\033[1;31m"  # Kırmızı
  [BATTERY_MID]="\033[1;33m"  # Sarı
  [BATTERY_HIGH]="\033[1;32m" # Yeşil
  [THERMAL_NORMAL]="\033[1;32m" # Yeşil
  [THERMAL_HIGH]="\033[1;33m"   # Sarı
  [THERMAL_VERY_HIGH]="\033[1;31m" # Kırmızı
  [THERMAL_CRITICAL]="\033[1;5;31m" # Yanıp sönen kırmızı
  [BORDER]="\033[1;34m"   # Mavi
  [MENU_ITEM]="\033[1;30m" # Siyah
  [MENU_NUMBER]="\033[1;33m" # Sarı
  [BAR_FILL]="\033[1;32m"  # Yeşil
  [BAR_EMPTY]="\033[1;37m" # Açık Gri
)

# Gruvbox tema
declare -A COLORS_GRUVBOX=(
  [RESET]="\033[0m"
  [BOLD]="\033[1m"
  [DIM]="\033[2m"
  [HEADER]="\033[1;38;5;214m"  # Bold Orange
  [SUCCESS]="\033[1;38;5;142m" # Bold Green
  [WARNING]="\033[1;38;5;214m" # Bold Orange
  [DANGER]="\033[1;38;5;167m"  # Bold Red
  [INFO]="\033[1;38;5;109m"    # Bold Blue
  [NORMAL]="\033[1;38;5;223m"  # Bold Fg
  [BATTERY_LOW]="\033[1;38;5;167m"  # Red
  [BATTERY_MID]="\033[1;38;5;214m"  # Orange
  [BATTERY_HIGH]="\033[1;38;5;142m" # Green
  [THERMAL_NORMAL]="\033[1;38;5;142m" # Green
  [THERMAL_HIGH]="\033[1;38;5;214m"   # Orange
  [THERMAL_VERY_HIGH]="\033[1;38;5;167m" # Red
  [THERMAL_CRITICAL]="\033[1;5;38;5;167m" # Flashing Red
  [BORDER]="\033[1;38;5;109m"   # Blue
  [MENU_ITEM]="\033[1;38;5;223m" # Fg
  [MENU_NUMBER]="\033[1;38;5;214m" # Orange
  [BAR_FILL]="\033[1;38;5;142m"  # Green
  [BAR_EMPTY]="\033[1;38;5;237m" # Gray
)

# Nord tema
declare -A COLORS_NORD=(
  [RESET]="\033[0m"
  [BOLD]="\033[1m"
  [DIM]="\033[2m"
  [HEADER]="\033[1;38;5;74m"  # Nord Blue
  [SUCCESS]="\033[1;38;5;114m" # Nord Green
  [WARNING]="\033[1;38;5;179m" # Nord Yellow
  [DANGER]="\033[1;38;5;203m"  # Nord Red
  [INFO]="\033[1;38;5;68m"    # Nord Frost
  [NORMAL]="\033[1;38;5;252m"  # Nord Snow Storm
  [BATTERY_LOW]="\033[1;38;5;203m"  # Red
  [BATTERY_MID]="\033[1;38;5;179m"  # Yellow
  [BATTERY_HIGH]="\033[1;38;5;114m" # Green
  [THERMAL_NORMAL]="\033[1;38;5;114m" # Green
  [THERMAL_HIGH]="\033[1;38;5;179m"   # Yellow
  [THERMAL_VERY_HIGH]="\033[1;38;5;203m" # Red
  [THERMAL_CRITICAL]="\033[1;5;38;5;203m" # Flashing Red
  [BORDER]="\033[1;38;5;74m"   # Blue
  [MENU_ITEM]="\033[1;38;5;252m" # Snow Storm
  [MENU_NUMBER]="\033[1;38;5;179m" # Yellow
  [BAR_FILL]="\033[1;38;5;114m"  # Green
  [BAR_EMPTY]="\033[1;38;5;59m" # Dark Gray
)

# Dracula tema
declare -A COLORS_DRACULA=(
  [RESET]="\033[0m"
  [BOLD]="\033[1m"
  [DIM]="\033[2m"
  [HEADER]="\033[1;38;5;141m"  # Dracula Purple
  [SUCCESS]="\033[1;38;5;84m" # Dracula Green
  [WARNING]="\033[1;38;5;228m" # Dracula Yellow
  [DANGER]="\033[1;38;5;203m"  # Dracula Red
  [INFO]="\033[1;38;5;117m"    # Dracula Cyan
  [NORMAL]="\033[1;38;5;253m"  # Dracula Foreground
  [BATTERY_LOW]="\033[1;38;5;203m"  # Red
  [BATTERY_MID]="\033[1;38;5;228m"  # Yellow
  [BATTERY_HIGH]="\033[1;38;5;84m" # Green
  [THERMAL_NORMAL]="\033[1;38;5;84m" # Green
  [THERMAL_HIGH]="\033[1;38;5;228m"   # Yellow
  [THERMAL_VERY_HIGH]="\033[1;38;5;203m" # Red
  [THERMAL_CRITICAL]="\033[1;5;38;5;203m" # Flashing Red
  [BORDER]="\033[1;38;5;141m"   # Purple
  [MENU_ITEM]="\033[1;38;5;253m" # Foreground
  [MENU_NUMBER]="\033[1;38;5;212m" # Pink
  [BAR_FILL]="\033[1;38;5;84m"  # Green
  [BAR_EMPTY]="\033[1;38;5;59m" # Comment
)

# Terminal boyutlarını güncelle
# Update terminal dimensions
update_terminal_size() {
  if command -v stty &>/dev/null; then
    read -r TERMINAL_HEIGHT TERMINAL_WIDTH < <(stty size 2>/dev/null || echo "24 80")
  else
    TERMINAL_WIDTH=80
    TERMINAL_HEIGHT=24
  fi
}

# Temizleme ve çıkış
cleanup() {
  tput cnorm  # Show cursor again
  tput sgr0   # Reset colors
  
  # Konfigürasyonu kaydet
  save_config
  
  echo -e "\nAndroid Battery Monitoring System closed."
  exit 0
}

# Hata yakalama
error_handler() {
  local line="$1"
  local command="$2"
  echo -e "${COLORS[DANGER]}Hata satır $line: $command${COLORS[RESET]}" >&2
  cleanup
}

# Terminalden çıkıldığında çalışacak
trap cleanup EXIT INT TERM
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap 'update_terminal_size; clear; show_menu' WINCH

# Temayı seç
set_theme() {
  local theme="$1"
  if [[ "$theme" == "light" ]]; then
    THEME="light"
    # Copy all elements from COLORS_LIGHT to COLORS
    declare -gA COLORS
    for key in "${!COLORS_LIGHT[@]}"; do
      COLORS["$key"]="${COLORS_LIGHT[$key]}"
    done
  elif [[ "$theme" == "gruvbox" ]]; then
    THEME="gruvbox"
    # Copy all elements from COLORS_GRUVBOX to COLORS
    declare -gA COLORS
    for key in "${!COLORS_GRUVBOX[@]}"; do
      COLORS["$key"]="${COLORS_GRUVBOX[$key]}"
    done
  elif [[ "$theme" == "nord" ]]; then
    THEME="nord"
    # Copy all elements from COLORS_NORD to COLORS
    declare -gA COLORS
    for key in "${!COLORS_NORD[@]}"; do
      COLORS["$key"]="${COLORS_NORD[$key]}"
    done
  elif [[ "$theme" == "dracula" ]]; then
    THEME="dracula"
    # Copy all elements from COLORS_DRACULA to COLORS
    declare -gA COLORS
    for key in "${!COLORS_DRACULA[@]}"; do
      COLORS["$key"]="${COLORS_DRACULA[$key]}"
    done
  else
    THEME="dark"
    # Copy all elements from COLORS_DARK to COLORS
    declare -gA COLORS
    for key in "${!COLORS_DARK[@]}"; do
      COLORS["$key"]="${COLORS_DARK[$key]}"
    done
  fi
}

# İlerleme çubuğu çizimi
# Draw progress bar
draw_bar() {
  local current="$1"
  local max="$2"
  local width="$3"
  local char_full="█"
  local char_empty="░"
  
  local filled=$(( (current * width) / max ))
  local bar=""
  
  # Pil seviyesine göre renk
  # Color based on battery level
  local color="${COLORS[BAR_FILL]}"
  if (( current < 20 )); then
    color="${COLORS[BATTERY_LOW]}"
  elif (( current < 50 )); then
    color="${COLORS[BATTERY_MID]}"
  else
    color="${COLORS[BATTERY_HIGH]}"
  fi

  # Doldurulmuş kısım
  # Filled part
  bar="${color}"
  for (( i=0; i<filled; i++ )); do
    bar+="$char_full"
  done
  
  # Boş kısım
  # Empty part
  bar+="${COLORS[BAR_EMPTY]}"
  for (( i=filled; i<width; i++ )); do
    bar+="$char_empty"
  done
  
  bar+="${COLORS[RESET]}"
  echo -e "$bar"
}

# Kutu çizimi
draw_box() {
  local title="$1"
  local width=$((TERMINAL_WIDTH - 4))
  local title_len=${#title}
  local padding=$(( (width - title_len) / 2 ))
  
  # Üst çizgi
  echo -ne "${COLORS[BORDER]}┌"
  for ((i=0; i<width; i++)); do
    echo -ne "─"
  done
  echo -e "┐${COLORS[RESET]}"
  
  # Başlık
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]}"
  printf "%${padding}s" ""
  echo -ne "${COLORS[HEADER]}${title}${COLORS[RESET]}"
  printf "%$((width - title_len - padding))s" ""
  echo -e "${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Başlık altındaki çizgi
  echo -ne "${COLORS[BORDER]}├"
  for ((i=0; i<width; i++)); do
    echo -ne "─"
  done
  echo -e "┤${COLORS[RESET]}"
}

# Kutu kapanışı
close_box() {
  local width=$((TERMINAL_WIDTH - 4))
  echo -ne "${COLORS[BORDER]}└"
  for ((i=0; i<width; i++)); do
    echo -ne "─"
  done
  echo -e "┘${COLORS[RESET]}"
}

# Dosya oku veya varsayılan değer kullan
read_file_or_default() {
  local file="$1"
  local default="$2"
  
  if [[ -f "$file" ]]; then
    cat "$file" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# Pil yolunu bul
find_battery_path() {
  local battery_path=""
  
  # Standart Android pil dizinlerini kontrol et
  for dir in /sys/class/power_supply/*; do
    if [[ -d "$dir" ]]; then
      # Gerçek bir pil mi kontrol et (present=1 veya type=Battery)
      if [[ -f "$dir/present" && "$(cat "$dir/present" 2>/dev/null)" == "1" ]]; then
        if [[ -f "$dir/capacity" || -f "$dir/charge_now" || -f "$dir/energy_now" ]]; then
          battery_path="$dir"
          break
        fi
      elif [[ -f "$dir/type" && "$(cat "$dir/type" 2>/dev/null)" == "Battery" ]]; then
        if [[ -f "$dir/capacity" || -f "$dir/charge_now" || -f "$dir/energy_now" ]]; then
          battery_path="$dir"
          break
        fi
      fi
    fi
  done
  
  echo "$battery_path"
}

# Pil bilgisini topla
get_battery_info() {
  local battery_path="${BATTERY_INFO[path]}"
  
  # Pil yolu yoksa bul
  if [[ -z "$battery_path" ]]; then
    battery_path=$(find_battery_path)
    BATTERY_INFO[path]="$battery_path"
  fi
  
  # Pil bulunamadı
  if [[ -z "$battery_path" ]]; then
    echo "Pil bulunamadı. Cihaz pil içeriyor mu?" >&2
    return 1
  fi
  
  # Temel pil verilerini oku
  BATTERY_INFO[capacity]=$(read_file_or_default "$battery_path/capacity" "0")
  BATTERY_INFO[present]=$(read_file_or_default "$battery_path/present" "0")
  BATTERY_INFO[status]=$(read_file_or_default "$battery_path/status" "Unknown")
  BATTERY_INFO[health]=$(read_file_or_default "$battery_path/health" "Unknown")
  BATTERY_INFO[technology]=$(read_file_or_default "$battery_path/technology" "Unknown")
  
  # Sıcaklık (milli-Celsius'dan Celsius'a dönüştür)
  local temp_raw=$(read_file_or_default "$battery_path/temp" "0")
  BATTERY_INFO[temp]=$(echo "scale=1; $temp_raw / 10" | bc)
  
  # Voltaj (micro-volt'dan volt'a dönüştür)
  local voltage_raw=$(read_file_or_default "$battery_path/voltage_now" "0")
  BATTERY_INFO[voltage_now]=$(echo "scale=2; $voltage_raw / 1000000" | bc)
  
  # Akım (micro-amper'den amper'e dönüştür)
  local current_raw=$(read_file_or_default "$battery_path/current_now" "0")
  # Bazı cihazlar negative akım için farklı dosya kullanabilir
  if [[ "$current_raw" == "0" ]]; then
    current_raw=$(read_file_or_default "$battery_path/BatteryAverageCurrent" "0")
  fi
  BATTERY_INFO[current_now]=$(echo "scale=3; $current_raw / 1000000" | bc)
  
  # Tasarım kapasitesi (micro-amper-saat'ten mili-amper-saat'e dönüştür)
  local design_capacity_raw=$(read_file_or_default "$battery_path/charge_full_design" "0")
  if [[ "$design_capacity_raw" == "0" ]]; then
    design_capacity_raw=$(read_file_or_default "$battery_path/energy_full_design" "0")
  fi
  BATTERY_INFO[charge_full_design]=$(echo "scale=0; $design_capacity_raw / 1000" | bc)
  
  # Tam kapasitesi
  local full_capacity_raw=$(read_file_or_default "$battery_path/charge_full" "0")
  if [[ "$full_capacity_raw" == "0" ]]; then
    full_capacity_raw=$(read_file_or_default "$battery_path/energy_full" "0")
  fi
  BATTERY_INFO[charge_full]=$(echo "scale=0; $full_capacity_raw / 1000" | bc)
  
  # Şu anki şarj
  local current_charge_raw=$(read_file_or_default "$battery_path/charge_now" "0")
  if [[ "$current_charge_raw" == "0" ]]; then
    current_charge_raw=$(read_file_or_default "$battery_path/energy_now" "0")
  fi
  BATTERY_INFO[charge_now]=$(echo "scale=0; $current_charge_raw / 1000" | bc)
  
  # Çevrim sayısı
  BATTERY_INFO[cycle_count]=$(read_file_or_default "$battery_path/cycle_count" "0")
  
  # Güç hesaplama (miliwatt)
  local voltage=$(echo "${BATTERY_INFO[voltage_now]}" | sed 's/,/./g')
  local current=$(echo "${BATTERY_INFO[current_now]}" | sed 's/,/./g')
  BATTERY_INFO[power_mw]=$(echo "scale=1; $voltage * $current * 1000" | bc | awk '{printf "%.1f", $1}')
  
  # Sağlık yüzdesi
  if [[ "${BATTERY_INFO[charge_full_design]}" != "0" ]]; then
    local health_percent=$(echo "scale=0; 100 * ${BATTERY_INFO[charge_full]} / ${BATTERY_INFO[charge_full_design]}" | bc)
    # 100%'den fazla olmamalı
    if (( health_percent > 100 )); then
      health_percent=100
    fi
    BATTERY_INFO[health_percent]="$health_percent"
  else
    BATTERY_INFO[health_percent]="0"
  fi
}

# Termal bilgi topla
get_thermal_info() {
  # Önceki sıcaklıkları kaydet (trend için)
  PREVIOUS_TEMPS=("${THERMAL_ZONE_TEMPS[@]}")
  
  # Dizileri temizle
  THERMAL_ZONE_NAMES=()
  THERMAL_ZONE_TEMPS=()
  THERMAL_ZONE_PATHS=()
  THERMAL_ZONE_TRENDS=()
  
  # Trend sembolleri: artıyor ▲, azalıyor ▼, sabit ▬
  
  # Tüm termal bölgeleri bul
  for zone_path in /sys/class/thermal/thermal_zone*; do
    if [[ -d "$zone_path" ]]; then
      # Bölge tipi ve sıcaklık
      local zone_type=$(read_file_or_default "$zone_path/type" "unknown")
      local temp_raw=$(read_file_or_default "$zone_path/temp" "0")
      
      # Sıcaklığı C'ye dönüştür (genellikle milli-Celsius)
      local temp=$(echo "scale=1; $temp_raw / 1000" | bc)
      
      # Dizilere ekle
      THERMAL_ZONE_NAMES+=("$zone_type")
      THERMAL_ZONE_TEMPS+=("$temp")
      THERMAL_ZONE_PATHS+=("$zone_path")
      
      # Trend hesapla
      local trend="▬" # Varsayılan: sabit
      local zone_index=${#THERMAL_ZONE_TEMPS[@]}
      zone_index=$((zone_index - 1))
      
      # Önceki ölçüm varsa karşılaştır
      if [[ -n "${PREVIOUS_TEMPS[$zone_index]:-}" ]]; then
        local prev_temp="${PREVIOUS_TEMPS[$zone_index]}"
        if (( $(echo "$temp > $prev_temp + 0.5" | bc -l) )); then
          trend="▲"
        elif (( $(echo "$temp < $prev_temp - 0.5" | bc -l) )); then
          trend="▼"
        fi
      fi
      
      THERMAL_ZONE_TRENDS+=("$trend")
    fi
  done
}

# En sıcak bölgeyi bul
get_hottest_zone() {
  local max_temp=0
  local max_index=0
  
  for ((i=0; i<${#THERMAL_ZONE_TEMPS[@]}; i++)); do
    local temp="${THERMAL_ZONE_TEMPS[$i]}"
    if (( $(echo "$temp > $max_temp" | bc -l) )); then
      max_temp="$temp"
      max_index="$i"
    fi
  done
  
  echo "$max_index"
}

# Sıcaklık değerine göre renk belirle
get_temp_color() {
  local temp="$1"
  local color="${COLORS[THERMAL_NORMAL]}"
  
  if (( $(echo "$temp >= 50" | bc -l) )); then
    color="${COLORS[THERMAL_CRITICAL]}"
  elif (( $(echo "$temp >= 45" | bc -l) )); then
    color="${COLORS[THERMAL_VERY_HIGH]}"
  elif (( $(echo "$temp >= 40" | bc -l) )); then
    color="${COLORS[THERMAL_HIGH]}"
  fi
  
  echo "$color"
}

# Pil durumunu göster
show_battery_status() {
  local display_mode="${1:-}"
  
  clear
  
  # Veri güncelleme
  get_battery_info
  get_thermal_info
  
  draw_box "Android Battery Monitoring System"
  
  local width=$((TERMINAL_WIDTH - 8))
  local bar_width=$((width - 10))
  
  # Pil seviyesi ve çubuk
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  
  local capacity="${BATTERY_INFO[capacity]}"
  local capacity_color="${COLORS[NORMAL]}"
  if (( capacity < 20 )); then
    capacity_color="${COLORS[BATTERY_LOW]}"
  elif (( capacity < 50 )); then
    capacity_color="${COLORS[BATTERY_MID]}"
  else
    capacity_color="${COLORS[BATTERY_HIGH]}"
  fi
  
  echo -ne "Battery: ${capacity_color}${capacity}%${COLORS[RESET]} "
  echo -ne "$(draw_bar "$capacity" 100 "$bar_width")"
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Durum bilgisi
  local status="${BATTERY_INFO[status]}"
  local status_color="${COLORS[NORMAL]}"
  case "$status" in
    "Charging") 
      status="Charging"
      status_color="${COLORS[SUCCESS]}"
      ;;
    "Discharging") 
      status="Discharging"
      status_color="${COLORS[WARNING]}"
      ;;
    "Full") 
      status="Full"
      status_color="${COLORS[SUCCESS]}"
      ;;
    "Not charging") 
      status="Not charging"
      status_color="${COLORS[WARNING]}"
      ;;
    *) 
      status="Unknown"
      status_color="${COLORS[NORMAL]}"
      ;;
  esac
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "Status: ${status_color}${status}${COLORS[RESET]}"
  
  # Sağlık bilgisi
  local health_percent="${BATTERY_INFO[health_percent]}"
  local health_color="${COLORS[SUCCESS]}"
  if (( health_percent < 60 )); then
    health_color="${COLORS[DANGER]}"
  elif (( health_percent < 80 )); then
    health_color="${COLORS[WARNING]}"
  fi
  
  printf "%*s" $((width - 18 - ${#status})) ""
  echo -ne "Health: ${health_color}${health_percent}%${COLORS[RESET]} "
  echo -e "${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Şarj hızı ve kalan süre tahmini (yeni eklenen)
  local current="${BATTERY_INFO[current_now]}"
  local charging_speed=$(get_charging_speed "$current" "$status")
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "Charging Type: ${charging_speed} | "
  
  local charge_full="${BATTERY_INFO[charge_full]}"
  local est_time=$(estimate_remaining_time "$capacity" "$charge_full" "$current" "$status")
  if [[ -n "$est_time" ]]; then
    echo -ne "Estimated: ${est_time}"
  else
    echo -ne "Estimated: ${COLORS[NORMAL]}N/A${COLORS[RESET]}"
  fi
  
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Detay modu "minimal" değilse daha fazla bilgi göster
  if [[ "$VIEW_MODE" != "minimal" ]]; then
    # Sıcaklık, Voltaj, Akım bilgisi
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    
    local temp="${BATTERY_INFO[temp]}"
    local temp_color="$(get_temp_color "$temp")"
    echo -ne "Temperature: ${temp_color}${temp}°C${COLORS[RESET]} | "
    
    local voltage="${BATTERY_INFO[voltage_now]}"
    echo -ne "Voltage: ${COLORS[INFO]}${voltage}V${COLORS[RESET]} | "
    
    echo -ne "Current: ${COLORS[INFO]}${current}A${COLORS[RESET]} | "
    
    local power="${BATTERY_INFO[power_mw]}"
    echo -ne "Power: ${COLORS[INFO]}${power}mW${COLORS[RESET]}"
    
    printf "%*s" $((width - 75)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    # Döngü sayısı ve teknoloji
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    
    local cycle_count="${BATTERY_INFO[cycle_count]}"
    local cycle_color="${COLORS[NORMAL]}"
    if (( cycle_count > 800 )); then
      cycle_color="${COLORS[DANGER]}"
    elif (( cycle_count > 500 )); then
      cycle_color="${COLORS[WARNING]}"
    fi
    
    if [[ "$cycle_count" != "0" ]]; then
      echo -ne "Cycle Count: ${cycle_color}${cycle_count}${COLORS[RESET]} | "
    fi
    
    local technology="${BATTERY_INFO[technology]}"
    if [[ "$technology" != "Unknown" ]]; then
      echo -ne "Technology: ${COLORS[INFO]}${technology}${COLORS[RESET]}"
    fi
    
    printf "%*s" $((width - 45)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  fi
  
  # Eğer detaylı görünüm ise termal özeti göster
  if [[ "$VIEW_MODE" == "detayli" || "$VIEW_MODE" == "detailed" || "$VIEW_MODE" == "debug" ]]; then
    # Çizgi
    echo -ne "${COLORS[BORDER]}├"
    for ((i=0; i<width; i++)); do
      echo -ne "─"
    done
    echo -e "┤${COLORS[RESET]}"
    
    # Termal özeti
    if (( ${#THERMAL_ZONE_NAMES[@]} > 0 )); then
      local hottest_index=$(get_hottest_zone)
      local hottest_name="${THERMAL_ZONE_NAMES[$hottest_index]}"
      local hottest_temp="${THERMAL_ZONE_TEMPS[$hottest_index]}"
      local hottest_trend="${THERMAL_ZONE_TRENDS[$hottest_index]}"
      local temp_color=$(get_temp_color "$hottest_temp")
      
      echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
      echo -ne "Hottest Zone: ${COLORS[INFO]}${hottest_name}${COLORS[RESET]} | "
      echo -ne "Temperature: ${temp_color}${hottest_temp}°C ${hottest_trend}${COLORS[RESET]}"
      
      printf "%*s" $((width - 40 - ${#hottest_name})) ""
      echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    fi
  fi
  
  # Debug mod ise daha fazla teknik detay
  if [[ "$VIEW_MODE" == "debug" ]]; then
    # Pil yolu
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "Battery Path: ${COLORS[DIM]}${BATTERY_INFO[path]}${COLORS[RESET]}"
    printf "%*s" $((width - 19 - ${#BATTERY_INFO[path]})) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    # Bazı ham değerler
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "Raw Values: "
    echo -ne "charge_full_design=${BATTERY_INFO[charge_full_design]}, "
    echo -ne "charge_full=${BATTERY_INFO[charge_full]}, "
    echo -ne "charge_now=${BATTERY_INFO[charge_now]}"
    printf "%*s" $((width - 80)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  fi
  
  close_box
  
  if [[ "$display_mode" == "static" ]]; then
    echo -e "\n$(get_translation "PRESS_KEY")..."
    read -n 1 -s
  fi
}

# Termal durumu göster
show_thermal_status() {
  clear
  
  # Veri güncelleme
  get_thermal_info
  
  draw_box "Android Thermal Status"
  
  local width=$((TERMINAL_WIDTH - 8))
  local bar_width=20
  
  if (( ${#THERMAL_ZONE_NAMES[@]} == 0 )); then
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[WARNING]}No thermal zones found!${COLORS[RESET]}"
    printf "%*s" $((width - 25)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  else
    local hottest_index=$(get_hottest_zone)
    
    # Tablo başlığı
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[BOLD]}Zone Name"
    printf "%-20s" " "
    echo -ne "Temperature  Trend    Temperature Bar${COLORS[RESET]}"
    printf "%*s" $((width - 65)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    # Tablo çizgisi
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[DIM]}"
    
    # Draw the line using characters instead of seq
    for ((i=0; i<29; i++)); do
      echo -ne "─"
    done
    
    for ((i=0; i<10; i++)); do
      echo -ne "─"
    done
    
    for ((i=0; i<8; i++)); do
      echo -ne "─"
    done
    
    for ((i=0; i<20; i++)); do
      echo -ne "─"
    done
    
    echo -ne "${COLORS[RESET]}"
    printf "%*s" $((width - 72)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    # Her bölge için bilgi göster
    for ((i=0; i<${#THERMAL_ZONE_NAMES[@]}; i++)); do
      local zone_name="${THERMAL_ZONE_NAMES[$i]}"
      local temp="${THERMAL_ZONE_TEMPS[$i]}"
      local trend="${THERMAL_ZONE_TRENDS[$i]}"
      local temp_color=$(get_temp_color "$temp")
      
      echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
      
      # Bölge adı, en sıcaksa vurgula
      if [[ "$i" == "$hottest_index" ]]; then
        echo -ne "${COLORS[WARNING]}${zone_name}${COLORS[RESET]}"
      else
        echo -ne "${zone_name}"
      fi
      
      printf "%-$((29 - ${#zone_name}))s" " "
      
      # Sıcaklık ve trend
      echo -ne "${temp_color}${temp}°C${COLORS[RESET]}"
      printf "%-$((10 - ${#temp} - 2))s" " "
      
      echo -ne "${temp_color}${trend}${COLORS[RESET]}"
      printf "%-$((8 - ${#trend}))s" " "
      
      # Sıcaklık çubuğu
      local bar_fill=0
      # Convert temperature to integer value for bar calculation
      local temp_int=$(printf "%.0f" "$temp")
      bar_fill=$(( temp_int * bar_width / 100 ))
      if (( bar_fill > bar_width )); then
        bar_fill=$bar_width
      fi
      
      echo -ne "${temp_color}"
      for ((j=0; j<bar_fill; j++)); do
        echo -ne "█"
      done
      echo -ne "${COLORS[RESET]}"
      
      for ((j=bar_fill; j<bar_width; j++)); do
        echo -ne "░"
      done
      
      printf "%*s" $((width - 72 - bar_width)) ""
      echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    done
  fi
  
  close_box
  
  echo -e "\n$(get_translation "PRESS_KEY")..."
  read -n 1 -s
}

# Loglama dizinini oluştur
create_log_dir() {
  if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR" 2>/dev/null || {
      echo "Loglama dizini oluşturulamadı: $LOG_DIR" >&2
      LOG_DIR="$HOME"
      echo "Loglama dizini olarak $HOME kullanılacak" >&2
    }
  fi
}

# Tarih/saat formatı için fonksiyon
get_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Yeni log dosyası oluştur
create_log_file() {
  local timestamp=$(date "+%Y%m%d_%H%M%S")
  local log_file="${LOG_DIR}/battery_log_${timestamp}.${LOG_FORMAT}"
  
  create_log_dir
  
  # CSV başlık
  if [[ "$LOG_FORMAT" == "csv" ]]; then
    echo "timestamp,capacity,status,health,health_percent,temp,voltage,current,power,cycle_count" > "$log_file"
  
  # JSON başlık
  elif [[ "$LOG_FORMAT" == "json" ]]; then
    echo "{\"logs\": [" > "$log_file"
  
  # TXT başlık
  elif [[ "$LOG_FORMAT" == "txt" ]]; then
    echo "Android Pil İzleme Sistemi Log Dosyası" > "$log_file"
    echo "Başlangıç: $(get_timestamp)" >> "$log_file"
    echo "----------------------------------------" >> "$log_file"
  fi
  
  echo "$log_file"
}

# Log kaydı
log_battery_info() {
  local log_file="$1"
  local timestamp=$(get_timestamp)
  
  # Log dosyası yoksa oluştur
  if [[ ! -f "$log_file" ]]; then
    log_file=$(create_log_file)
  fi
  
  # CSV formatında kayıt
  if [[ "$LOG_FORMAT" == "csv" ]]; then
    echo "$timestamp,${BATTERY_INFO[capacity]},${BATTERY_INFO[status]},${BATTERY_INFO[health]},${BATTERY_INFO[health_percent]},${BATTERY_INFO[temp]},${BATTERY_INFO[voltage_now]},${BATTERY_INFO[current_now]},${BATTERY_INFO[power_mw]},${BATTERY_INFO[cycle_count]}" >> "$log_file"
  
  # JSON formatında kayıt (düzgün JSON için son kayıtta virgül olmamalı)
  elif [[ "$LOG_FORMAT" == "json" ]]; then
    # Dosya boyutunu kontrol et
    local file_size=$(wc -c < "$log_file")
    
    # Başlangıç: { "logs": [ den büyükse virgül ekle
    if (( file_size > 11 )); then
      # Son } kaldır, virgül ekle
      truncate -s -2 "$log_file"
      echo "," >> "$log_file"
    fi
    
    {
      echo "  {"
      echo "    \"timestamp\": \"$timestamp\","
      echo "    \"capacity\": ${BATTERY_INFO[capacity]},"
      echo "    \"status\": \"${BATTERY_INFO[status]}\","
      echo "    \"health\": \"${BATTERY_INFO[health]}\","
      echo "    \"health_percent\": ${BATTERY_INFO[health_percent]},"
      echo "    \"temp\": ${BATTERY_INFO[temp]},"
      echo "    \"voltage\": ${BATTERY_INFO[voltage_now]},"
      echo "    \"current\": ${BATTERY_INFO[current_now]},"
      echo "    \"power\": ${BATTERY_INFO[power_mw]},"
      echo "    \"cycle_count\": ${BATTERY_INFO[cycle_count]}"
      echo "  }"
      echo "]}"
    } >> "$log_file"
  
  # TXT formatında kayıt
  elif [[ "$LOG_FORMAT" == "txt" ]]; then
    {
      echo "Zaman: $timestamp"
      echo "Pil Seviyesi: ${BATTERY_INFO[capacity]}%"
      echo "Durum: ${BATTERY_INFO[status]}"
      echo "Sağlık: ${BATTERY_INFO[health]} (${BATTERY_INFO[health_percent]}%)"
      echo "Sıcaklık: ${BATTERY_INFO[temp]}°C"
      echo "Voltaj: ${BATTERY_INFO[voltage_now]}V"
      echo "Akım: ${BATTERY_INFO[current_now]}A"
      echo "Güç: ${BATTERY_INFO[power_mw]}mW"
      echo "Döngü Sayısı: ${BATTERY_INFO[cycle_count]}"
      echo "----------------------------------------"
    } >> "$log_file"
  fi
  
  echo "$log_file"
}

# Teknik bilgileri göster
show_technical_info() {
  clear
  
  draw_box "$(get_translation "TECHNICAL_INFO")"
  
  local width=$((TERMINAL_WIDTH - 8))
  
  # Kernel bilgisi
  local kernel_info="$(uname -s) $(uname -r)"
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[HEADER]}${kernel_info}${COLORS[RESET]}"
  printf "%*s" $((width - ${#kernel_info} - 1)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Cihaz modeli ve kod adı
  local model_text="$(get_translation "DEVICE_MODEL"): ${DEVICE_MODEL}"
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "DEVICE_MODEL"): ${COLORS[INFO]}${DEVICE_MODEL}${COLORS[RESET]}"
  printf "%*s" $((width - ${#model_text} - 1)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  local codename_text="$(get_translation "DEVICE_CODENAME"): ${DEVICE_CODENAME}"
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "DEVICE_CODENAME"): ${COLORS[INFO]}${DEVICE_CODENAME}${COLORS[RESET]}"
  printf "%*s" $((width - ${#codename_text} - 1)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Pil modeli
  local battery_text="$(get_translation "BATTERY_MODEL"): ${BATTERY_MODEL}"
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "BATTERY_MODEL"): ${COLORS[INFO]}${BATTERY_MODEL}${COLORS[RESET]}"
  printf "%*s" $((width - ${#battery_text} - 1)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Pil teknolojisi ve diğer bilgiler
  local tech_text="$(get_translation "Technology"): ${BATTERY_INFO[technology]}"
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "Technology"): ${COLORS[INFO]}${BATTERY_INFO[technology]}${COLORS[RESET]}"
  printf "%*s" $((width - ${#tech_text} - 1)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  close_box
  
  echo -e "\n$(get_translation "PRESS_KEY")..."
  read -n 1 -s
}

# Pil ipuçlarını göster
show_battery_tips() {
  clear
  
  # Pil verilerini güncelle
  get_battery_info
  
  draw_box "Battery Optimization Tips"
  
  local width=$((TERMINAL_WIDTH - 8))
  
  # Bağlamsal uyarılar kontrolü
  local has_temp_warning=0
  local has_health_warning=0
  local temp="${BATTERY_INFO[temp]}"
  local health_percent="${BATTERY_INFO[health_percent]}"
  local cycle_count="${BATTERY_INFO[cycle_count]}"
  
  if (( $(echo "$temp >= 45" | bc -l) )); then
    has_temp_warning=1
  fi
  
  if (( health_percent < 60 || cycle_count > 800 )); then
    has_health_warning=1
  fi
  
  # Bağlamsal uyarılar gösterimi
  if (( has_temp_warning == 1 )); then
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[DANGER]}⚠️  WARNING: Battery temperature is too high (${temp}°C)!${COLORS[RESET]}"
    printf "%*s" $((width - 55)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    if (( health_percent < 60 )); then
      echo -ne "${COLORS[DIM]}Pil sağlığınız: ${health_percent}% (Kritik düzeyde düşük)${COLORS[RESET]}"
    else
      echo -ne "${COLORS[DIM]}Döngü sayınız: ${cycle_count} (Yüksek)${COLORS[RESET]}"
    fi
    printf "%*s" $((width - 50)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[DIM]}Kalibrasyon veya pil değişimi düşünebilirsiniz.${COLORS[RESET]}"
    printf "%*s" $((width - 50)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "─────────────────────────────────────────────────────────────"
    printf "%*s" $((width - 60)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  fi
  
  # Temel Kullanım ve Şarj İpuçları
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[HEADER]}1. Temel Kullanım ve Şarj${COLORS[RESET]}"
  printf "%*s" $((width - 27)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Ekran parlaklığını gözünüzü yormayacak, konforlu bir seviyeye ayarlayın."
  printf "%*s" $((width - 77)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Pil seviyesini ideal olarak %20-%85 aralığında tutmaya çalışın."
  printf "%*s" $((width - 67)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Sertifikalı veya orijinal şarj adaptörlerini kullanın."
  printf "%*s" $((width - 58)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Yavaş şarjı (düşük akım) tercih edin (aceleniz yoksa)."
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Sıcaklık Yönetimi İpuçları
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "─────────────────────────────────────────────────────────────"
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[HEADER]}2. Sıcaklık Yönetimi${COLORS[RESET]}"
  printf "%*s" $((width - 24)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Telefonun tekrarlayan şekilde aşırı ısınmasından kaçının."
  printf "%*s" $((width - 64)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Doğrudan güneş ışığı veya çok sıcak ortamlardan uzak tutun."
  printf "%*s" $((width - 66)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Isıyı hapseden kılıflardan kaçının veya çıkarın."
  printf "%*s" $((width - 53)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Şarj sırasında serin yüzeye koyun."
  printf "%*s" $((width - 40)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Uygulama ve Arka Plan İşlemleri
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "─────────────────────────────────────────────────────────────"
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[HEADER]}3. Uygulama ve Arka Plan İşlemleri${COLORS[RESET]}"
  printf "%*s" $((width - 39)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Uygulamaların arka plan aktivitelerini ve izinlerini kontrol edin/kısıtlayın."
  printf "%*s" $((width - 79)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Arka plan yenilemeyi sadece kritik uygulamalar için açık tutun."
  printf "%*s" $((width - 67)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Tüm uygulamalar için pil optimizasyonunu etkinleştirin."
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Sistem ve Bağlantı
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "─────────────────────────────────────────────────────────────"
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[HEADER]}4. Sistem ve Bağlantı${COLORS[RESET]}"
  printf "%*s" $((width - 24)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Kullanılmayan Wi-Fi, Bluetooth, NFC, Konum'u kapatın."
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Mümkünse 5G yerine 4G kullanın."
  printf "%*s" $((width - 35)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "• Animasyonları azaltın/kapatın."
  printf "%*s" $((width - 33)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  close_box
  
  echo -e "\nMenü'ye dönmek için herhangi bir tuşa basın..."
  read -n 1 -s
}

# Pil sağlık tanılama
show_battery_diagnostics() {
  clear
  
  # Pil verilerini güncelle
  get_battery_info
  
  draw_box "Battery Health Diagnostics"
  
  local width=$((TERMINAL_WIDTH - 8))
  
  # Pil seviyesi ve çubuk
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  
  local capacity="${BATTERY_INFO[capacity]}"
  local capacity_color="${COLORS[NORMAL]}"
  if (( capacity < 20 )); then
    capacity_color="${COLORS[BATTERY_LOW]}"
  elif (( capacity < 50 )); then
    capacity_color="${COLORS[BATTERY_MID]}"
  else
    capacity_color="${COLORS[BATTERY_HIGH]}"
  fi
  
  echo -ne "Current Battery Level: ${capacity_color}${capacity}%${COLORS[RESET]}"
  printf "%*s" $((width - 30 - ${#capacity})) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Durum bilgisi
  local status="${BATTERY_INFO[status]}"
  local status_color="${COLORS[NORMAL]}"
  case "$status" in
    "Charging") 
      status="Charging"
      status_color="${COLORS[SUCCESS]}"
      ;;
    "Discharging") 
      status="Discharging"
      status_color="${COLORS[WARNING]}"
      ;;
    "Full") 
      status="Full"
      status_color="${COLORS[SUCCESS]}"
      ;;
    "Not charging") 
      status="Not charging"
      status_color="${COLORS[WARNING]}"
      ;;
    *) 
      status="Unknown"
      status_color="${COLORS[NORMAL]}"
      ;;
  esac
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "Charging Status: ${status_color}${status}${COLORS[RESET]}"
  printf "%*s" $((width - 27 - ${#status})) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Şarj hızı ve kalan süre tahmini (yeni eklenen)
  local current="${BATTERY_INFO[current_now]}"
  local charging_speed=$(get_charging_speed "$current" "$status")
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "Charging Type: ${charging_speed} | "
  
  local charge_full="${BATTERY_INFO[charge_full]}"
  local est_time=$(estimate_remaining_time "$capacity" "$charge_full" "$current" "$status")
  if [[ -n "$est_time" && "$est_time" != "Unknown" ]]; then
    echo -ne "Estimated: ${est_time}"
  else
    echo -ne "Estimated: ${COLORS[NORMAL]}N/A${COLORS[RESET]}"
  fi
  
  printf "%*s" $((width - 65)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Sağlık değerlendirmesi
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "─────────────────────────────────────────────────────────────"
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[HEADER]}Health Assessment${COLORS[RESET]}"
  printf "%*s" $((width - 18)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Kapasite Değerlendirmesi
  local health_percent="${BATTERY_INFO[health_percent]}"
  local health_color="${COLORS[SUCCESS]}"
  local health_desc="Excellent"
  
  if (( health_percent < 60 )); then
    health_color="${COLORS[DANGER]}"
    health_desc="Critical (Replacement Recommended)"
  elif (( health_percent < 80 )); then
    health_color="${COLORS[WARNING]}"
    health_desc="Poor"
  elif (( health_percent < 90 )); then
    health_color="${COLORS[WARNING]}"
    health_desc="Good"
  fi
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "Battery Capacity: ${health_color}${health_percent}% (${health_desc})${COLORS[RESET]}"
  printf "%*s" $((width - 28 - ${#health_percent} - ${#health_desc})) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  
  # Döngü Sayısı Değerlendirmesi
  local cycle_count="${BATTERY_INFO[cycle_count]}"
  local cycle_color="${COLORS[SUCCESS]}"
  local cycle_desc="Low Usage"
  
  if (( cycle_count > 800 )); then
    cycle_color="${COLORS[DANGER]}"
    cycle_desc="Very High (Replacement Advised)"
  elif (( cycle_count > 500 )); then
    cycle_color="${COLORS[WARNING]}"
    cycle_desc="High"
  elif (( cycle_count > 300 )); then
    cycle_color="${COLORS[INFO]}"
    cycle_desc="Normal"
  fi
  
  if [[ "$cycle_count" != "0" ]]; then
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "Cycle Count: ${cycle_color}${cycle_count} (${cycle_desc})${COLORS[RESET]}"
    printf "%*s" $((width - 23 - ${#cycle_count} - ${#cycle_desc})) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  fi
  
  # Sıcaklık Değerlendirmesi
  local temp="${BATTERY_INFO[temp]}"
  local temp_color="$(get_temp_color "$temp")"
  local temp_desc="Normal"
  
  if (( $(echo "$temp >= 50" | bc -l) )); then
    temp_desc="Critical (Shutdown Recommended!)"
  elif (( $(echo "$temp >= 45" | bc -l) )); then
    temp_desc="Very High"
  elif (( $(echo "$temp >= 40" | bc -l) )); then
    temp_desc="High"
  elif (( $(echo "$temp <= 10" | bc -l) )); then
    temp_color="${COLORS[WARNING]}"
    temp_desc="Very Low"
  fi
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "Battery Temperature: ${temp_color}${temp}°C (${temp_desc})${COLORS[RESET]}"
  printf "%*s" $((width - 32 - ${#temp} - ${#temp_desc})) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Genel Değerlendirme
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "─────────────────────────────────────────────────────────────"
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[HEADER]}Overall Assessment${COLORS[RESET]}"
  printf "%*s" $((width - 20)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  
  local overall_color="${COLORS[SUCCESS]}"
  local overall_text="Your battery is in good condition and working normally."
  
  if (( health_percent < 60 || cycle_count > 800 || $(echo "$temp >= 50" | bc -l) )); then
    overall_color="${COLORS[DANGER]}"
    overall_text="Your battery is in critical condition! Immediate action/replacement may be needed."
  elif (( health_percent < 80 || cycle_count > 500 || $(echo "$temp >= 45" | bc -l) )); then
    overall_color="${COLORS[WARNING]}"
    overall_text="Your battery appears to have issues. Taking precautions is recommended."
  fi
  
  echo -ne "${overall_color}${overall_text}${COLORS[RESET]}"
  printf "%*s" $((width - ${#overall_text})) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  close_box
  
  echo -e "\n$(get_translation "PRESS_KEY")..."
  read -n 1 -s
}

# Dil çevirisine yeni eklemeleri yapıyorum
get_translation() {
  local key="$1"
  local result=""
  
  if [[ "$LANGUAGE" == "tr" ]]; then
    case "$key" in
      "SETTINGS") result="Ayarlar" ;;
      "CURRENT_STATUS") result="Anlık Durum" ;;
      "LIVE_MONITORING") result="Canlı İzleme Başlat" ;;
      "BATTERY_TIPS") result="Pil İpuçları" ;;
      "BATTERY_DIAGNOSTICS") result="Pil Tanılama" ;;
      "THERMAL_STATUS") result="Termal Durum" ;;
      "TECHNICAL_INFO") result="Teknik Bilgiler" ;;
      "LANGUAGE") result="Dil" ;;
      "ABOUT") result="Hakkında" ;;
      "EXIT") result="Çıkış" ;;
      "BACK") result="Geri" ;;
      "SELECT_OPTION") result="Bir seçenek seçin" ;;
      "PRESS_KEY") result="Menüye dönmek için herhangi bir tuşa basın" ;;
      "ENABLE") result="Aç" ;;
      "DISABLE") result="Kapat" ;;
      "ENABLED") result="Açık" ;;
      "DISABLED") result="Kapalı" ;;
      "LOGGING") result="Loglama" ;;
      "SET_LOG_DIR") result="Log Dizinini Ayarla" ;;
      "SELECT_LOG_FORMAT") result="Log Formatını Seç" ;;
      "SET_REFRESH_RATE") result="Yenileme Aralığını Ayarla" ;;
      "SELECT_VIEW_MODE") result="Görünüm Modunu Seç" ;;
      "SELECT_COLOR_THEME") result="Renk Temasını Seç" ;;
      "RETURN_MAIN_MENU") result="Ana Menüye Dön" ;;
      "VERSION") result="Versiyon" ;;
      "LICENSE") result="Lisans" ;;
      "CONFIG_DIR") result="Konfigürasyon Dizini" ;;
      "LOG_DIR") result="Log Dizini" ;;
      "ABOUT_TEXT1") result="Bu uygulama, Android cihazlardaki pil durumu, sağlığı ve termal bilgileri" ;;
      "ABOUT_TEXT2") result="gerçek zamanlı olarak izlemenizi sağlar. Şarj modellerini takip eder," ;;
      "ABOUT_TEXT3") result="pil sorunlarını tanılar ve pil performansını optimize eder. Ömer SÜSİN tarafından geliştirilmiştir." ;;
      "Charging") result="Şarj Oluyor" ;;
      "Discharging") result="Deşarj Oluyor" ;;
      "Not charging") result="Şarj Olmuyor" ;;
      "Full") result="Dolu" ;;
      "Unknown") result="Bilinmiyor" ;;
      "Fast Charging") result="Hızlı Şarj" ;;
      "Normal Charging") result="Normal Şarj" ;;
      "Slow Charging") result="Yavaş Şarj" ;;
      "High Power Usage") result="Yüksek Güç Kullanımı" ;;
      "Medium Power Usage") result="Orta Güç Kullanımı" ;;
      "Low Power Usage") result="Düşük Güç Kullanımı" ;;
      "Not Charging") result="Şarj Olmuyor" ;;
      "to full") result="tam doluma" ;;
      "remaining") result="kaldı" ;;
      "Your battery is in good condition and working normally.") result="Piliniz iyi durumda ve normal çalışıyor." ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="Pilinizde sorunlar görünüyor. Önlem almanız önerilir." ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="Piliniz kritik durumda! Acil müdahale/değişim gerekebilir." ;;
      "Consider battery calibration or replacement.") result="Pil kalibrasyonu veya değişimi düşünebilirsiniz.${COLORS[RESET]}" ;;
      "Excellent") result="Mükemmel" ;;
      "Good") result="İyi" ;;
      "Poor") result="Zayıf" ;;
      "Critical (Replacement Recommended)") result="Kritik (Değişim Önerilir)" ;;
      "Normal") result="Normal" ;;
      "High") result="Yüksek" ;;
      "Very High") result="Çok Yüksek" ;;
      "Critical") result="Kritik" ;;
      "Low Usage") result="Düşük Kullanım" ;;
      "Normal") result="Normal" ;;
      "High") result="Yüksek" ;;
      "Very High (Replacement Advised)") result="Çok Yüksek (Değişim Önerilir)" ;;
      "Optimal") result="Optimal" ;;
      "Battery Temperature") result="Pil Sıcaklığı" ;;
      "Hottest Zone") result="En Sıcak Bölge" ;;
      "Temperature") result="Sıcaklık" ;;
      "Voltage") result="Voltaj" ;;
      "Current") result="Akım" ;;
      "Power") result="Güç" ;;
      "Health") result="Sağlık" ;;
      "Cycle Count") result="Döngü Sayısı" ;;
      "Technology") result="Teknoloji" ;;
      "Battery Path") result="Pil Yolu" ;;
      "Raw Values") result="Ham Değerler" ;;
      "Estimated") result="Tahmini" ;;
      "Charging Type") result="Şarj Tipi" ;;
      "Battery Optimization Tips") result="Pil Optimizasyon İpuçları" ;;
      "Battery Health Diagnostics") result="Pil Sağlık Tanılama" ;;
      "WARNING: Battery temperature is too high") result="UYARI: Pil sıcaklığı çok yüksek" ;;
      "Reduce screen brightness to a comfortable level") result="Ekran parlaklığını konforlu bir seviyeye ayarlayın" ;;
      "Keep battery level ideally between 20-85%") result="Pil seviyesini ideal olarak %20-%85 aralığında tutmaya çalışın." ;;
      "Use certified or original charging adapters") result="Sertifikalı veya orijinal şarj adaptörlerini kullanın." ;;
      "Prefer slow charging (low current) when not in a hurry") result="Aceleniz yoksa yavaş şarjı (düşük akım) tercih edin (aceleniz yoksa)." ;;
      "Avoid battery getting repeatedly hot") result="Pilin tekrarlayan şekilde aşırı ısınmasından kaçının" ;;
      "Keep away from direct sunlight or very hot environments") result="Doğrudan güneş ışığı veya çok sıcak ortamlardan uzak tutun." ;;
      "Avoid using heat-trapping cases or remove them") result="Isıyı hapseden kılıflardan kaçının veya çıkarın." ;;
      "Place on cool surface while charging") result="Şarj sırasında serin yüzeye koyun." ;;
      "Health Assessment") result="Sağlık Değerlendirmesi" ;;
      "Overall Assessment") result="Genel Değerlendirme" ;;
      "DEVICE_MODEL") result="Cihaz Modeli" ;;
      "DEVICE_CODENAME") result="Cihaz Kod Adı" ;;
      "BATTERY_MODEL") result="Pil Modeli" ;;
      "ITERATION") result="İterasyon" ;;
      "REFRESH") result="Yenileme" ;;
      "PRESS_CTRL_C_EXIT") result="Çıkmak ve ana menüye dönmek için CTRL+C'ye basın" ;;
      "MONITORING_STOPPED") result="İzleme durdu. Ana menüye dönülüyor..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "ru" ]]; then
    case "$key" in
      "SETTINGS") result="Настройки" ;;
      "CURRENT_STATUS") result="Текущее состояние" ;;
      "LIVE_MONITORING") result="Начать мониторинг" ;;
      "BATTERY_TIPS") result="Советы по батарее" ;;
      "BATTERY_DIAGNOSTICS") result="Диагностика батареи" ;;
      "THERMAL_STATUS") result="Тепловой статус" ;;
      "TECHNICAL_INFO") result="Техническая информация" ;;
      "LANGUAGE") result="Язык" ;;
      "ABOUT") result="О программе" ;;
      "EXIT") result="Выход" ;;
      "BACK") result="Назад" ;;
      "SELECT_OPTION") result="Выберите опцию" ;;
      "PRESS_KEY") result="Нажмите любую клавишу для возврата в меню" ;;
      "ENABLE") result="Включить" ;;
      "DISABLE") result="Отключить" ;;
      "ENABLED") result="Включено" ;;
      "DISABLED") result="Отключено" ;;
      "LOGGING") result="Журналирование" ;;
      "SET_LOG_DIR") result="Настроить директорию журнала" ;;
      "SELECT_LOG_FORMAT") result="Выбрать формат журнала" ;;
      "SET_REFRESH_RATE") result="Настроить частоту обновления" ;;
      "SELECT_VIEW_MODE") result="Выбрать режим просмотра" ;;
      "SELECT_COLOR_THEME") result="Выбрать цветовую тему" ;;
      "RETURN_MAIN_MENU") result="Вернуться в главное меню" ;;
      "VERSION") result="Версия" ;;
      "LICENSE") result="Лицензия" ;;
      "CONFIG_DIR") result="Директория конфигурации" ;;
      "LOG_DIR") result="Директория журнала" ;;
      "ABOUT_TEXT1") result="Это приложение позволяет отслеживать состояние батареи, здоровье и тепловую" ;;
      "ABOUT_TEXT2") result="информацию устройств Android в реальном времени. Оно отслеживает модели зарядки," ;;
      "ABOUT_TEXT3") result="диагностирует проблемы с батареей и оптимизирует производительность. Разработано Ömer SÜSİN." ;;
      "Charging") result="Заряжается" ;;
      "Discharging") result="Разряжается" ;;
      "Not charging") result="Не заряжается" ;;
      "Full") result="Полная" ;;
      "Unknown") result="Неизвестно" ;;
      "Fast Charging") result="Быстрая зарядка" ;;
      "Normal Charging") result="Обычная зарядка" ;;
      "Slow Charging") result="Медленная зарядка" ;;
      "High Power Usage") result="Высокий расход энергии" ;;
      "Medium Power Usage") result="Средний расход энергии" ;;
      "Low Power Usage") result="Низкий расход энергии" ;;
      "Not Charging") result="Не заряжается" ;;
      "to full") result="до полной зарядки" ;;
      "remaining") result="осталось" ;;
      "Your battery is in good condition and working normally.") result="Ваша батарея в хорошем состоянии и работает нормально." ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="У вашей батареи, похоже, есть проблемы. Рекомендуется принять меры предосторожности." ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="Ваша батарея в критическом состоянии! Может потребоваться немедленное действие/замена." ;;
      "Consider battery calibration or replacement.") result="Рассмотрите возможность калибровки или замены батареи." ;;
      "Excellent") result="Отлично" ;;
      "Good") result="Хорошо" ;;
      "Poor") result="Плохо" ;;
      "Critical (Replacement Recommended)") result="Критическое (Рекомендуется замена)" ;;
      "Normal") result="Нормальный" ;;
      "High") result="Высокий" ;;
      "Very High") result="Очень высокий" ;;
      "Critical") result="Критический" ;;
      "Low Usage") result="Низкое использование" ;;
      "Normal") result="Нормальный" ;;
      "High") result="Высокий" ;;
      "Very High (Replacement Advised)") result="Очень высокий (Рекомендуется замена)" ;;
      "Optimal") result="Оптимальный" ;;
      "Battery Temperature") result="Температура батареи" ;;
      "Hottest Zone") result="Самая горячая зона" ;;
      "Temperature") result="Температура" ;;
      "Voltage") result="Напряжение" ;;
      "Current") result="Ток" ;;
      "Power") result="Мощность" ;;
      "Health") result="Здоровье" ;;
      "Cycle Count") result="Количество циклов" ;;
      "Technology") result="Технология" ;;
      "Battery Path") result="Путь к батарее" ;;
      "Raw Values") result="Исходные значения" ;;
      "Estimated") result="Расчетное" ;;
      "Charging Type") result="Тип зарядки" ;;
      "Battery Optimization Tips") result="Советы по оптимизации батареи" ;;
      "Battery Health Diagnostics") result="Диагностика состояния батареи" ;;
      "WARNING: Battery temperature is too high") result="ПРЕДУПРЕЖДЕНИЕ: Температура батареи слишком высокая" ;;
      "Reduce screen brightness to a comfortable level") result="Уменьшите яркость экрана до комфортного уровня" ;;
      "Keep battery level ideally between 20-85%") result="Поддерживайте уровень заряда батареи в идеале между 20-85%" ;;
      "Use certified or original charging adapters") result="Используйте сертифицированные или оригинальные зарядные устройства" ;;
      "Prefer slow charging (low current) when not in a hurry") result="Предпочитайте медленную зарядку (низкий ток), когда не спешите" ;;
      "Avoid battery getting repeatedly hot") result="Избегайте повторяющегося перегрева батареи" ;;
      "Keep away from direct sunlight or very hot environments") result="Держите вдали от прямых солнечных лучей или очень горячих мест" ;;
      "Avoid using heat-trapping cases or remove them") result="Избегайте использования чехлов, задерживающих тепло, или снимайте их" ;;
      "Place on cool surface while charging") result="Размещайте на прохладной поверхности во время зарядки" ;;
      "Health Assessment") result="Оценка состояния" ;;
      "Overall Assessment") result="Общая оценка" ;;
      "DEVICE_MODEL") result="Модель устройства" ;;
      "DEVICE_CODENAME") result="Кодовое имя устройства" ;;
      "BATTERY_MODEL") result="Модель батареи" ;;
      "ITERATION") result="Итерация" ;;
      "REFRESH") result="Обновление" ;;
      "PRESS_CTRL_C_EXIT") result="Нажмите CTRL+C для выхода и возврата в главное меню" ;;
      "MONITORING_STOPPED") result="Мониторинг остановлен. Возвращение в главное меню..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "zh" ]]; then
    case "$key" in
      "SETTINGS") result="设置" ;;
      "CURRENT_STATUS") result="当前状态" ;;
      "LIVE_MONITORING") result="开始实时监控" ;;
      "BATTERY_TIPS") result="电池使用技巧" ;;
      "BATTERY_DIAGNOSTICS") result="电池诊断" ;;
      "THERMAL_STATUS") result="热状态" ;;
      "TECHNICAL_INFO") result="技术信息" ;;
      "LANGUAGE") result="语言" ;;
      "ABOUT") result="关于" ;;
      "EXIT") result="退出" ;;
      "BACK") result="返回" ;;
      "SELECT_OPTION") result="选择一个选项" ;;
      "PRESS_KEY") result="按任意键返回菜单" ;;
      "ENABLE") result="启用" ;;
      "DISABLE") result="禁用" ;;
      "ENABLED") result="已启用" ;;
      "DISABLED") result="已禁用" ;;
      "LOGGING") result="日志记录" ;;
      "SET_LOG_DIR") result="设置日志目录" ;;
      "SELECT_LOG_FORMAT") result="选择日志格式" ;;
      "SET_REFRESH_RATE") result="设置刷新率" ;;
      "SELECT_VIEW_MODE") result="选择查看模式" ;;
      "SELECT_COLOR_THEME") result="选择颜色主题" ;;
      "RETURN_MAIN_MENU") result="返回主菜单" ;;
      "VERSION") result="版本" ;;
      "LICENSE") result="许可证" ;;
      "CONFIG_DIR") result="配置目录" ;;
      "LOG_DIR") result="日志目录" ;;
      "ABOUT_TEXT1") result="此应用程序允许您实时监控Android设备的电池状态、健康状况" ;;
      "ABOUT_TEXT2") result="和热信息。它可以跟踪充电模式，诊断电池问题，并" ;;
      "ABOUT_TEXT3") result="优化电池性能，提供详细分析。由Ömer SÜSİN开发。" ;;
      "Charging") result="充电中" ;;
      "Discharging") result="放电中" ;;
      "Not charging") result="未充电" ;;
      "Full") result="满电" ;;
      "Unknown") result="未知" ;;
      "Fast Charging") result="快速充电" ;;
      "Normal Charging") result="正常充电" ;;
      "Slow Charging") result="慢速充电" ;;
      "High Power Usage") result="高功耗" ;;
      "Medium Power Usage") result="中功耗" ;;
      "Low Power Usage") result="低功耗" ;;
      "Not Charging") result="未充电" ;;
      "to full") result="充满电" ;;
      "remaining") result="剩余" ;;
      "Your battery is in good condition and working normally.") result="您的电池状况良好，正常工作。" ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="您的电池似乎有问题。建议采取预防措施。" ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="您的电池电量不足！可能需要立即采取行动或更换。" ;;
      "Consider battery calibration or replacement.") result="考虑电池校准或更换。" ;;
      "Excellent") result="优秀" ;;
      "Good") result="良好" ;;
      "Poor") result="较差" ;;
      "Critical (Replacement Recommended)") result="关键（建议更换）" ;;
      "Normal") result="正常" ;;
      "High") result="高" ;;
      "Very High") result="很高" ;;
      "Critical") result="临界" ;;
      "Low Usage") result="低使用率" ;;
      "Normal") result="正常" ;;
      "High") result="高" ;;
      "Very High (Replacement Advised)") result="很高（建议更换）" ;;
      "Optimal") result="最佳" ;;
      "Battery Temperature") result="电池温度" ;;
      "Hottest Zone") result="最热区域" ;;
      "Temperature") result="温度" ;;
      "Voltage") result="电压" ;;
      "Current") result="电流" ;;
      "Power") result="功率" ;;
      "Health") result="健康" ;;
      "Cycle Count") result="循环次数" ;;
      "Technology") result="技术" ;;
      "Battery Path") result="电池路径" ;;
      "Raw Values") result="原始值" ;;
      "Estimated") result="估计" ;;
      "Charging Type") result="充电类型" ;;
      "Battery Optimization Tips") result="电池优化技巧" ;;
      "Battery Health Diagnostics") result="电池健康诊断" ;;
      "WARNING: Battery temperature is too high") result="警告：电池温度过高" ;;
      "Reduce screen brightness to a comfortable level") result="将屏幕亮度降低到舒适水平" ;;
      "Keep battery level ideally between 20-85%") result="理想情况下，将电池电量保持在20-85%之间" ;;
      "Use certified or original charging adapters") result="使用认证或原装充电适配器" ;;
      "Prefer slow charging (low current) when not in a hurry") result="不着急时，更倾向于慢速充电（低电流）" ;;
      "Avoid battery getting repeatedly hot") result="避免电池反复变热" ;;
      "Keep away from direct sunlight or very hot environments") result="远离阳光直射或非常热的环境" ;;
      "Avoid using heat-trapping cases or remove them") result="避免使用隔热外壳或将其移除" ;;
      "Place on cool surface while charging") result="充电时放在凉爽的表面上" ;;
      "Health Assessment") result="健康评估" ;;
      "Overall Assessment") result="整体评估" ;;
      "DEVICE_MODEL") result="设备型号" ;;
      "DEVICE_CODENAME") result="设备代号" ;;
      "BATTERY_MODEL") result="电池型号" ;;
      "ITERATION") result="迭代" ;;
      "REFRESH") result="刷新" ;;
      "PRESS_CTRL_C_EXIT") result="按CTRL+C退出并返回主菜单" ;;
      "MONITORING_STOPPED") result="监控已停止。正在返回主菜单..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "ja" ]]; then
    case "$key" in
      "SETTINGS") result="設定" ;;
      "CURRENT_STATUS") result="現在の状態" ;;
      "LIVE_MONITORING") result="ライブモニタリングを開始" ;;
      "BATTERY_TIPS") result="バッテリーのヒント" ;;
      "BATTERY_DIAGNOSTICS") result="バッテリー診断" ;;
      "THERMAL_STATUS") result="熱状態" ;;
      "TECHNICAL_INFO") result="技術情報" ;;
      "LANGUAGE") result="言語" ;;
      "ABOUT") result="アプリについて" ;;
      "EXIT") result="終了" ;;
      "BACK") result="戻る" ;;
      "SELECT_OPTION") result="オプションを選択してください" ;;
      "PRESS_KEY") result="メニューに戻るには任意のキーを押してください" ;;
      "ENABLE") result="有効化" ;;
      "DISABLE") result="無効化" ;;
      "ENABLED") result="有効" ;;
      "DISABLED") result="無効" ;;
      "LOGGING") result="ログ記録" ;;
      "SET_LOG_DIR") result="ログディレクトリの設定" ;;
      "SELECT_LOG_FORMAT") result="ログフォーマットの選択" ;;
      "SET_REFRESH_RATE") result="リフレッシュレートの設定" ;;
      "SELECT_VIEW_MODE") result="表示モードの選択" ;;
      "SELECT_COLOR_THEME") result="カラーテーマの選択" ;;
      "RETURN_MAIN_MENU") result="メインメニューに戻る" ;;
      "VERSION") result="バージョン" ;;
      "LICENSE") result="ライセンス" ;;
      "CONFIG_DIR") result="設定ディレクトリ" ;;
      "LOG_DIR") result="ログディレクトリ" ;;
      "ABOUT_TEXT1") result="このアプリケーションはAndroidデバイスのバッテリー状態、健康状態と熱情報を" ;;
      "ABOUT_TEXT2") result="リアルタイムでモニタリングすることができます。充電パターンを追跡し、" ;;
      "ABOUT_TEXT3") result="バッテリーの問題を診断し、バッテリーのパフォーマンスを最適化します。Ömer SÜSİNによって開発されました。" ;;
      "Charging") result="充電中" ;;
      "Discharging") result="放電中" ;;
      "Not charging") result="未充電" ;;
      "Full") result="満電" ;;
      "Unknown") result="不明" ;;
      "Fast Charging") result="高速充電" ;;
      "Normal Charging") result="通常充電" ;;
      "Slow Charging") result="低速充電" ;;
      "High Power Usage") result="高消費電力" ;;
      "Medium Power Usage") result="中消費電力" ;;
      "Low Power Usage") result="低消費電力" ;;
      "Not Charging") result="未充電" ;;
      "to full") result="満充電に" ;;
      "remaining") result="残り" ;;
      "Your battery is in good condition and working normally.") result="あなたのバッテリーは良好な状態で、正常に動作しています。" ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="あなたのバッテリーに問題があるようです。予防措置を講じることをお勧めします。" ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="あなたのバッテリーが危険な状態です！直ちに対応するか、交換することをお勧めします。" ;;
      "Consider battery calibration or replacement.") result="バッテリーの校正または交換を検討してください。" ;;
      "Excellent") result="優秀" ;;
      "Good") result="良好" ;;
      "Poor") result="不良" ;;
      "Critical (Replacement Recommended)") result="重要（交換を推奨）" ;;
      "Normal") result="正常" ;;
      "High") result="高い" ;;
      "Very High") result="非常に高い" ;;
      "Critical") result="危機的" ;;
      "Low Usage") result="低使用" ;;
      "Normal") result="通常" ;;
      "High") result="高い" ;;
      "Very High (Replacement Advised)") result="非常に高い（交換推奨）" ;;
      "Optimal") result="最適" ;;
      "Battery Temperature") result="バッテリー温度" ;;
      "Hottest Zone") result="最も熱いゾーン" ;;
      "Temperature") result="温度" ;;
      "Voltage") result="電圧" ;;
      "Current") result="電流" ;;
      "Power") result="電力" ;;
      "Health") result="健康状態" ;;
      "Cycle Count") result="サイクル回数" ;;
      "Technology") result="テクノロジー" ;;
      "Battery Path") result="バッテリーパス" ;;
      "Raw Values") result="生の値" ;;
      "Estimated") result="推定" ;;
      "Charging Type") result="充電タイプ" ;;
      "Battery Optimization Tips") result="バッテリー最適化のヒント" ;;
      "Battery Health Diagnostics") result="バッテリー健康診断" ;;
      "WARNING: Battery temperature is too high") result="警告：バッテリー温度が高すぎます" ;;
      "Reduce screen brightness to a comfortable level") result="画面の明るさを快適なレベルに下げる" ;;
      "Keep battery level ideally between 20-85%") result="バッテリーレベルを理想的には20-85%の間に保つ" ;;
      "Use certified or original charging adapters") result="認証済みまたは純正の充電アダプターを使用する" ;;
      "Prefer slow charging (low current) when not in a hurry") result="急いでない場合は低速充電（低電流）を優先する" ;;
      "Avoid battery getting repeatedly hot") result="バッテリーが繰り返し熱くなることを避ける" ;;
      "Keep away from direct sunlight or very hot environments") result="直射日光や非常に暑い環境から遠ざける" ;;
      "Avoid using heat-trapping cases or remove them") result="熱を閉じ込めるケースの使用を避けるか取り外す" ;;
      "Place on cool surface while charging") result="充電中は涼しい表面に置く" ;;
      "Health Assessment") result="健康評価" ;;
      "Overall Assessment") result="総合評価" ;;
      "DEVICE_MODEL") result="デバイスのモデル" ;;
      "DEVICE_CODENAME") result="デバイスのコードネーム" ;;
      "BATTERY_MODEL") result="バッテリーのモデル" ;;
      "ITERATION") result="繰り返し" ;;
      "REFRESH") result="更新" ;;
      "PRESS_CTRL_C_EXIT") result="CTRL+Cを押して終了し、メインメニューに戻る" ;;
      "MONITORING_STOPPED") result="モニタリングが停止しました。メインメニューに戻ります..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "ptbr" ]]; then
    case "$key" in
      "SETTINGS") result="Configurações" ;;
      "CURRENT_STATUS") result="Estado Atual" ;;
      "LIVE_MONITORING") result="Iniciar Monitoramento em Tempo Real" ;;
      "BATTERY_TIPS") result="Dicas de Bateria" ;;
      "BATTERY_DIAGNOSTICS") result="Diagnóstico da Bateria" ;;
      "THERMAL_STATUS") result="Estado Térmico" ;;
      "TECHNICAL_INFO") result="Informações Técnicas" ;;
      "LANGUAGE") result="Idioma" ;;
      "ABOUT") result="Sobre" ;;
      "EXIT") result="Sair" ;;
      "BACK") result="Voltar" ;;
      "SELECT_OPTION") result="Selecione uma opção" ;;
      "PRESS_KEY") result="Pressione qualquer tecla para voltar ao menu" ;;
      "ENABLE") result="Habilitar" ;;
      "DISABLE") result="Desabilitar" ;;
      "ENABLED") result="Habilitado" ;;
      "DISABLED") result="Desabilitado" ;;
      "LOGGING") result="Registro" ;;
      "SET_LOG_DIR") result="Definir Diretório de Logs" ;;
      "SELECT_LOG_FORMAT") result="Selecionar Formato de Log" ;;
      "SET_REFRESH_RATE") result="Definir Taxa de Atualização" ;;
      "SELECT_VIEW_MODE") result="Selecionar Modo de Visualização" ;;
      "SELECT_COLOR_THEME") result="Selecionar Tema de Cores" ;;
      "RETURN_MAIN_MENU") result="Retornar ao Menu Principal" ;;
      "VERSION") result="Versão" ;;
      "LICENSE") result="Licença" ;;
      "CONFIG_DIR") result="Diretório de Configuração" ;;
      "LOG_DIR") result="Diretório de Logs" ;;
      "ABOUT_TEXT1") result="Esta aplicação permite monitorar o estado, saúde da bateria e informações" ;;
      "ABOUT_TEXT2") result="térmicas de dispositivos Android em tempo real. Rastreia padrões de carregamento," ;;
      "ABOUT_TEXT3") result="diagnostica problemas da bateria e otimiza o desempenho com análises detalhadas. Desenvolvido por Ömer SÜSİN." ;;
      "Charging") result="Carregando" ;;
      "Discharging") result="Descarregando" ;;
      "Not charging") result="Não carregando" ;;
      "Full") result="Cheio" ;;
      "Unknown") result="Desconhecido" ;;
      "Fast Charging") result="Carregamento Rápido" ;;
      "Normal Charging") result="Carregamento Normal" ;;
      "Slow Charging") result="Carregamento Lento" ;;
      "High Power Usage") result="Uso de Potência Elevado" ;;
      "Medium Power Usage") result="Uso de Potência Médio" ;;
      "Low Power Usage") result="Uso de Potência Baixo" ;;
      "Not Charging") result="Não carregando" ;;
      "to full") result="para cheio" ;;
      "remaining") result="restante" ;;
      "Your battery is in good condition and working normally.") result="Sua bateria está em boas condições e funcionando normalmente." ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="Parece que sua bateria tem problemas. É recomendável tomar medidas preventivas." ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="Sua bateria está em condição crítica! Pode ser necessário tomar medidas urgentes/substituir." ;;
      "Consider battery calibration or replacement.") result="Considere a calibração da bateria ou a substituição." ;;
      "Excellent") result="Excelente" ;;
      "Good") result="Bom" ;;
      "Poor") result="Ruim" ;;
      "Critical (Replacement Recommended)") result="Crítico (Recomenda-se substituição)" ;;
      "Normal") result="Normal" ;;
      "High") result="Alta" ;;
      "Very High") result="Muito Alta" ;;
      "Critical") result="Crítica" ;;
      "Low Usage") result="Baixa Utilização" ;;
      "Normal") result="Normal" ;;
      "High") result="Alta" ;;
      "Very High (Replacement Advised)") result="Muito Alta (Recomenda-se substituição)" ;;
      "Optimal") result="Ótima" ;;
      "Battery Temperature") result="Temperatura da Bateria" ;;
      "Hottest Zone") result="Zona Mais Quente" ;;
      "Temperature") result="Temperatura" ;;
      "Voltage") result="Tensão" ;;
      "Current") result="Corrente" ;;
      "Power") result="Potência" ;;
      "Health") result="Saúde" ;;
      "Cycle Count") result="Número de Ciclos" ;;
      "Technology") result="Tecnologia" ;;
      "Battery Path") result="Caminho da Bateria" ;;
      "Raw Values") result="Valores Brutos" ;;
      "Estimated") result="Estimado" ;;
      "Charging Type") result="Tipo de Carga" ;;
      "Battery Optimization Tips") result="Dicas de Otimização da Bateria" ;;
      "Battery Health Diagnostics") result="Diagnóstico da Saúde da Bateria" ;;
      "WARNING: Battery temperature is too high") result="AVISO: A temperatura da bateria está muito alta" ;;
      "Reduce screen brightness to a comfortable level") result="Reduza o brilho da tela para um nível confortável" ;;
      "Keep battery level ideally between 20-85%") result="Mantenha o nível da bateria idealmente entre 20-85%" ;;
      "Use certified or original charging adapters") result="Use adaptadores de carregamento certificados ou originais" ;;
      "Prefer slow charging (low current) when not in a hurry") result="Prefira carregamento lento (baixa corrente) quando não estiver com pressa" ;;
      "Avoid battery getting repeatedly hot") result="Evite que a bateria fique repetidamente quente" ;;
      "Keep away from direct sunlight or very hot environments") result="Mantenha longe da luz solar direta ou ambientes muito quentes" ;;
      "Avoid using heat-trapping cases or remove them") result="Evite usar capas que retêm calor ou remova-as" ;;
      "Place on cool surface while charging") result="Coloque em superfície fria durante o carregamento" ;;
      "Health Assessment") result="Avaliação da Saúde" ;;
      "Overall Assessment") result="Avaliação Geral" ;;
      "DEVICE_MODEL") result="Modelo do Dispositivo" ;;
      "DEVICE_CODENAME") result="Código de Identificação do Dispositivo" ;;
      "BATTERY_MODEL") result="Modelo da Bateria" ;;
      "ITERATION") result="Iteração" ;;
      "REFRESH") result="Atualização" ;;
      "PRESS_CTRL_C_EXIT") result="Pressione CTRL+C para sair e voltar ao menu principal" ;;
      "MONITORING_STOPPED") result="Monitoramento parado. Retornando ao menu principal..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "es" ]]; then
    case "$key" in
      "SETTINGS") result="Ajustes" ;;
      "CURRENT_STATUS") result="Estado Actual" ;;
      "LIVE_MONITORING") result="Iniciar Monitoreo en Vivo" ;;
      "BATTERY_TIPS") result="Consejos de Batería" ;;
      "BATTERY_DIAGNOSTICS") result="Diagnóstico de Batería" ;;
      "THERMAL_STATUS") result="Estado Térmico" ;;
      "TECHNICAL_INFO") result="Información Técnica" ;;
      "LANGUAGE") result="Idioma" ;;
      "ABOUT") result="Acerca de" ;;
      "EXIT") result="Salir" ;;
      "BACK") result="Volver" ;;
      "SELECT_OPTION") result="Seleccione una opción" ;;
      "PRESS_KEY") result="Pulse cualquier tecla para volver al menú" ;;
      "ENABLE") result="Activar" ;;
      "DISABLE") result="Desactivar" ;;
      "ENABLED") result="Activado" ;;
      "DISABLED") result="Desactivado" ;;
      "LOGGING") result="Registro" ;;
      "SET_LOG_DIR") result="Establecer Directorio de Registros" ;;
      "SELECT_LOG_FORMAT") result="Seleccionar Formato de Registro" ;;
      "SET_REFRESH_RATE") result="Establecer Tasa de Actualización" ;;
      "SELECT_VIEW_MODE") result="Seleccionar Modo de Visualización" ;;
      "SELECT_COLOR_THEME") result="Seleccionar Tema de Color" ;;
      "RETURN_MAIN_MENU") result="Volver al Menú Principal" ;;
      "VERSION") result="Versión" ;;
      "LICENSE") result="Licencia" ;;
      "CONFIG_DIR") result="Directorio de Configuración" ;;
      "LOG_DIR") result="Directorio de Logs" ;;
      "ABOUT_TEXT1") result="Esta aplicación le permite monitorear el estado, salud de la batería e información" ;;
      "ABOUT_TEXT2") result="térmica de dispositivos Android en tiempo real. Rastrea patrones de carga," ;;
      "ABOUT_TEXT3") result="diagnostica problemas de batería y optimiza el rendimiento con análisis detallados. Desarrollado por Ömer SÜSİN." ;;
      "Charging") result="Cargando" ;;
      "Discharging") result="Descargando" ;;
      "Not charging") result="Sin carga" ;;
      "Full") result="Completo" ;;
      "Unknown") result="Desconocido" ;;
      "Fast Charging") result="Carga Rápida" ;;
      "Normal Charging") result="Carga Normal" ;;
      "Slow Charging") result="Carga Lenta" ;;
      "High Power Usage") result="Uso de Potencia Elevado" ;;
      "Medium Power Usage") result="Uso de Potencia Media" ;;
      "Low Power Usage") result="Uso de Potencia Bajo" ;;
      "Not Charging") result="Sin carga" ;;
      "to full") result="para completarse" ;;
      "remaining") result="restante" ;;
      "Your battery is in good condition and working normally.") result="Su batería está en buenas condiciones y funciona normalmente." ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="Parece que su batería tiene problemas. Se recomienda tomar medidas preventivas." ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="Su batería está en condición crítica! Puede ser necesario tomar medidas urgentes/sustituir." ;;
      "Consider battery calibration or replacement.") result="Considere la calibración de la batería o la sustitución." ;;
      "Excellent") result="Excelente" ;;
      "Good") result="Bueno" ;;
      "Poor") result="Malo" ;;
      "Critical (Replacement Recommended)") result="Crítico (Recomendación de Sustitución)" ;;
      "Normal") result="Normal" ;;
      "High") result="Alto" ;;
      "Very High") result="Muy Alto" ;;
      "Critical") result="Crítico" ;;
      "Low Usage") result="Bajo Uso" ;;
      "Normal") result="Normal" ;;
      "High") result="Alto" ;;
      "Very High (Replacement Advised)") result="Muy Alto (Recomendación de Sustitución)" ;;
      "Optimal") result="Óptimo" ;;
      "Battery Temperature") result="Temperatura de la Batería" ;;
      "Hottest Zone") result="Zona Más Cálida" ;;
      "Temperature") result="Temperatura" ;;
      "Voltage") result="Tensión" ;;
      "Current") result="Corriente" ;;
      "Power") result="Potencia" ;;
      "Health") result="Salud" ;;
      "Cycle Count") result="Número de Ciclos" ;;
      "Technology") result="Tecnología" ;;
      "Battery Path") result="Ruta de la Batería" ;;
      "Raw Values") result="Valores Brutos" ;;
      "Estimated") result="Estimado" ;;
      "Charging Type") result="Tipo de Carga" ;;
      "Battery Optimization Tips") result="Consejos de Optimización de la Batería" ;;
      "Battery Health Diagnostics") result="Diagnóstico de la Salud de la Batería" ;;
      "WARNING: Battery temperature is too high") result="AVISO: La temperatura de la batería es muy alta" ;;
      "Reduce screen brightness to a comfortable level") result="Reduzca el brillo de la pantalla a un nivel cómodo" ;;
      "Keep battery level ideally between 20-85%") result="Mantenga el nivel de la batería idealmente entre 20-85%" ;;
      "Use certified or original charging adapters") result="Use adaptadores de carga certificados o originales" ;;
      "Prefer slow charging (low current) when not in a hurry") result="Prefiera cargar lentamente (baja corriente) cuando no esté apurado" ;;
      "Avoid battery getting repeatedly hot") result="Evite que la batería se caliente repetidamente" ;;
      "Keep away from direct sunlight or very hot environments") result="Manténgase lejos de la luz solar directa o de ambientes muy calientes" ;;
      "Avoid using heat-trapping cases or remove them") result="Evite usar capas que retienen calor o quítense" ;;
      "Place on cool surface while charging") result="Coloque en una superficie fresca mientras se carga" ;;
      "Health Assessment") result="Evaluación de la Salud" ;;
      "Overall Assessment") result="Evaluación General" ;;
      "DEVICE_MODEL") result="Modelo del Dispositivo" ;;
      "DEVICE_CODENAME") result="Código de Identificación del Dispositivo" ;;
      "BATTERY_MODEL") result="Modelo de la Batería" ;;
      "ITERATION") result="Iteración" ;;
      "REFRESH") result="Actualización" ;;
      "PRESS_CTRL_C_EXIT") result="Presione CTRL+C para salir y volver al menú principal" ;;
      "MONITORING_STOPPED") result="Monitoreo detenido. Volviendo al menú principal..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "it" ]]; then
    case "$key" in
      "SETTINGS") result="Impostazioni" ;;
      "CURRENT_STATUS") result="Stato Attuale" ;;
      "LIVE_MONITORING") result="Avvia Monitoraggio in Tempo Reale" ;;
      "BATTERY_TIPS") result="Suggerimenti Batteria" ;;
      "BATTERY_DIAGNOSTICS") result="Diagnostica Batteria" ;;
      "THERMAL_STATUS") result="Stato Termico" ;;
      "TECHNICAL_INFO") result="Informazioni Tecniche" ;;
      "LANGUAGE") result="Lingua" ;;
      "ABOUT") result="Informazioni" ;;
      "EXIT") result="Uscita" ;;
      "BACK") result="Indietro" ;;
      "SELECT_OPTION") result="Seleziona un'opzione" ;;
      "PRESS_KEY") result="Premi un tasto qualsiasi per tornare al menu" ;;
      "ENABLE") result="Abilita" ;;
      "DISABLE") result="Disabilita" ;;
      "ENABLED") result="Abilitato" ;;
      "DISABLED") result="Disabilitato" ;;
      "LOGGING") result="Registrazione" ;;
      "SET_LOG_DIR") result="Imposta Directory dei Log" ;;
      "SELECT_LOG_FORMAT") result="Seleziona Formato di Log" ;;
      "SET_REFRESH_RATE") result="Imposta Tasso di Aggiornamento" ;;
      "SELECT_VIEW_MODE") result="Seleziona Modalità di Visualizzazione" ;;
      "SELECT_COLOR_THEME") result="Seleziona Tema di Colore" ;;
      "RETURN_MAIN_MENU") result="Torna al Menu Principale" ;;
      "VERSION") result="Versione" ;;
      "LICENSE") result="Licenza" ;;
      "CONFIG_DIR") result="Directory di Configurazione" ;;
      "LOG_DIR") result="Directory dei Log" ;;
      "ABOUT_TEXT1") result="Questo programma consente di monitorare lo stato, la salute della batteria e le" ;;
      "ABOUT_TEXT2") result="informazioni termiche dei dispositivi Android in tempo reale. Traccia i modelli di ricarica," ;;
      "ABOUT_TEXT3") result="diagnostica i problemi della batteria e ottimizza le prestazioni con analisi dettagliate. Sviluppato da Ömer SÜSİN." ;;
      "Charging") result="Carica" ;;
      "Discharging") result="Scarica" ;;
      "Not charging") result="Non carica" ;;
      "Full") result="Piena" ;;
      "Unknown") result="Sconosciuto" ;;
      "Fast Charging") result="Carica Rapida" ;;
      "Normal Charging") result="Carica Normale" ;;
      "Slow Charging") result="Carica Lenta" ;;
      "High Power Usage") result="Uso di Potenza Elevato" ;;
      "Medium Power Usage") result="Uso di Potenza Media" ;;
      "Low Power Usage") result="Uso di Potenza Basso" ;;
      "Not Charging") result="Non carica" ;;
      "to full") result="fino a piena" ;;
      "remaining") result="rimanente" ;;
      "Your battery is in good condition and working normally.") result="La tua batteria è in buone condizioni e funziona normalmente." ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="Sembra che la tua batteria abbia problemi. È consigliabile prendere precauzioni." ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="La tua batteria è in condizione critica! Potrebbe essere necessario prendere provvedimenti urgenti/sostituire." ;;
      "Consider battery calibration or replacement.") result="Considerare la calibrazione della batteria o la sostituzione." ;;
      "Excellent") result="Eccellente" ;;
      "Good") result="Buono" ;;
      "Poor") result="Scarso" ;;
      "Critical (Replacement Recommended)") result="Critico (Sostituzione Raccomandata)" ;;
      "Normal") result="Normale" ;;
      "High") result="Alto" ;;
      "Very High") result="Molto Alto" ;;
      "Critical") result="Critico" ;;
      "Low Usage") result="Basso Uso" ;;
      "Normal") result="Normale" ;;
      "High") result="Alto" ;;
      "Very High (Replacement Advised)") result="Molto Alto (Sostituzione Raccomandata)" ;;
      "Optimal") result="Ottimale" ;;
      "Battery Temperature") result="Temperatura della Batteria" ;;
      "Hottest Zone") result="Zona Più Calda" ;;
      "Temperature") result="Temperatura" ;;
      "Voltage") result="Tensione" ;;
      "Current") result="Corrente" ;;
      "Power") result="Potenza" ;;
      "Health") result="Stato Sanitario" ;;
      "Cycle Count") result="Numero di Cicli" ;;
      "Technology") result="Tecnologia" ;;
      "Battery Path") result="Percorso della Batteria" ;;
      "Raw Values") result="Valori Grezzi" ;;
      "Estimated") result="Stimato" ;;
      "Charging Type") result="Tipo di Carica" ;;
      "Battery Optimization Tips") result="Suggerimenti di Ottimizzazione della Batteria" ;;
      "Battery Health Diagnostics") result="Diagnostica della Salute della Batteria" ;;
      "WARNING: Battery temperature is too high") result="AVVISO: La temperatura della batteria è troppo alta" ;;
      "Reduce screen brightness to a comfortable level") result="Abbassare il livello di luminosità della schermata a un livello confortevole" ;;
      "Keep battery level ideally between 20-85%") result="Mantenere il livello della batteria idealmente tra il 20-85%" ;;
      "Use certified or original charging adapters") result="Usare adattatori di carica certificati o originali" ;;
      "Prefer slow charging (low current) when not in a hurry") result="Preferire il caricamento lento (bassa corrente) quando non si è in fretta" ;;
      "Avoid battery getting repeatedly hot") result="Evitare che la batteria si riscaldi ripetutamente" ;;
      "Keep away from direct sunlight or very hot environments") result="Allontanarsi dalla luce solare diretta o dagli ambienti molto caldi" ;;
      "Avoid using heat-trapping cases or remove them") result="Evitare l'uso di cappotti che impediscono il riscaldamento o rimuoverli" ;;
      "Place on cool surface while charging") result="Collocare su una superficie fresca durante il caricamento" ;;
      "Health Assessment") result="Valutazione della Salute" ;;
      "Overall Assessment") result="Valutazione Generale" ;;
      "DEVICE_MODEL") result="Modello del Dispositivo" ;;
      "DEVICE_CODENAME") result="Codice di Identificazione del Dispositivo" ;;
      "BATTERY_MODEL") result="Modello della Batteria" ;;
      "ITERATION") result="Iterazione" ;;
      "REFRESH") result="Aggiornamento" ;;
      "PRESS_CTRL_C_EXIT") result="Premere CTRL+C per uscire e tornare al menu principale" ;;
      "MONITORING_STOPPED") result="Monitoraggio interrotto. Ritorno al menu principale..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "fr" ]]; then
    case "$key" in
      "SETTINGS") result="Paramètres" ;;
      "CURRENT_STATUS") result="État Actuel" ;;
      "LIVE_MONITORING") result="Démarrer la Surveillance en Direct" ;;
      "BATTERY_TIPS") result="Conseils de Batterie" ;;
      "BATTERY_DIAGNOSTICS") result="Diagnostics de Batterie" ;;
      "THERMAL_STATUS") result="État Thermique" ;;
      "TECHNICAL_INFO") result="Informations Techniques" ;;
      "LANGUAGE") result="Langue" ;;
      "ABOUT") result="À Propos" ;;
      "EXIT") result="Quitter" ;;
      "BACK") result="Retour" ;;
      "SELECT_OPTION") result="Sélectionnez une option" ;;
      "PRESS_KEY") result="Appuyez sur n'importe quelle touche pour revenir au menu" ;;
      "ENABLE") result="Activer" ;;
      "DISABLE") result="Désactiver" ;;
      "ENABLED") result="Activé" ;;
      "DISABLED") result="Désactivé" ;;
      "LOGGING") result="Journalisation" ;;
      "SET_LOG_DIR") result="Configurer le Répertoire des Logs" ;;
      "SELECT_LOG_FORMAT") result="Sélectionner le Format de Log" ;;
      "SET_REFRESH_RATE") result="Configurer le Taux de Rafraîchissement" ;;
      "SELECT_VIEW_MODE") result="Sélectionner le Mode d'Affichage" ;;
      "SELECT_COLOR_THEME") result="Sélectionner le Thème de Couleurs" ;;
      "RETURN_MAIN_MENU") result="Retourner au Menu Principal" ;;
      "VERSION") result="Version" ;;
      "LICENSE") result="Licence" ;;
      "CONFIG_DIR") result="Répertoire de Configuration" ;;
      "LOG_DIR") result="Répertoire des Logs" ;;
      "ABOUT_TEXT1") result="Cette application permet de surveiller l'état, la santé de la batterie et les" ;;
      "ABOUT_TEXT2") result="informations thermiques des appareils Android en temps réel. Elle suit les modèles de charge," ;;
      "ABOUT_TEXT3") result="diagnostique les problèmes de batterie et optimise les performances avec des analyses détaillées. Développé par Ömer SÜSİN." ;;
      "Charging") result="Chargement" ;;
      "Discharging") result="Décharge" ;;
      "Not charging") result="Pas de charge" ;;
      "Full") result="Plein" ;;
      "Unknown") result="Inconnu" ;;
      "Fast Charging") result="Chargement Rapide" ;;
      "Normal Charging") result="Chargement Normal" ;;
      "Slow Charging") result="Chargement Lent" ;;
      "High Power Usage") result="Utilisation de Puissance Élevée" ;;
      "Medium Power Usage") result="Utilisation de Puissance Moyenne" ;;
      "Low Power Usage") result="Utilisation de Puissance Faible" ;;
      "Not Charging") result="Pas de charge" ;;
      "to full") result="pour plein" ;;
      "remaining") result="restant" ;;
      "Your battery is in good condition and working normally.") result="Votre batterie est en bon état et fonctionne normalement." ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="Il semble que votre batterie ait des problèmes. Il est conseillé de prendre des mesures préventives." ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="Votre batterie est en condition critique! Une action urgente/remplacement peut être nécessaire." ;;
      "Consider battery calibration or replacement.") result="Considérez la calibration de la batterie ou la remplacement." ;;
      "Excellent") result="Excellent" ;;
      "Good") result="Bon" ;;
      "Poor") result="Mauvais" ;;
      "Critical (Replacement Recommended)") result="Critique (Remplacement Recommandé)" ;;
      "Normal") result="Normal" ;;
      "High") result="Haut" ;;
      "Very High") result="Très Haut" ;;
      "Critical") result="Critique" ;;
      "Low Usage") result="Faible Utilisation" ;;
      "Normal") result="Normal" ;;
      "High") result="Haut" ;;
      "Very High (Replacement Advised)") result="Très Haut (Remplacement Recommandé)" ;;
      "Optimal") result="Optimal" ;;
      "Battery Temperature") result="Température de la Batterie" ;;
      "Hottest Zone") result="Zone la Plus Chaude" ;;
      "Temperature") result="Température" ;;
      "Voltage") result="Tension" ;;
      "Current") result="Courant" ;;
      "Power") result="Puissance" ;;
      "Health") result="Santé" ;;
      "Cycle Count") result="Nombre de Cycles" ;;
      "Technology") result="Technologie" ;;
      "Battery Path") result="Chemin de la Batterie" ;;
      "Raw Values") result="Valeurs Brutes" ;;
      "Estimated") result="Estimation" ;;
      "Charging Type") result="Type de Charge" ;;
      "Battery Optimization Tips") result="Conseils d'Optimisation de la Batterie" ;;
      "Battery Health Diagnostics") result="Diagnostic de la Santé de la Batterie" ;;
      "WARNING: Battery temperature is too high") result="AVIS: La température de la batterie est trop élevée" ;;
      "Reduce screen brightness to a comfortable level") result="Réduisez le niveau de luminosité de l'écran à un niveau confortable" ;;
      "Keep battery level ideally between 20-85%") result="Maintenez le niveau de la batterie idéalement entre 20-85%" ;;
      "Use certified or original charging adapters") result="Utilisez des adaptateurs de charge certifiés ou originaux" ;;
      "Prefer slow charging (low current) when not in a hurry") result="Préférez le chargement lent (faible courant) lorsque vous n'êtes pas pressé" ;;
      "Avoid battery getting repeatedly hot") result="Évitez que la batterie se réchauffe répétitivement" ;;
      "Keep away from direct sunlight or very hot environments") result="Éloignez-vous de la lumière solaire directe ou des environnements très chauds" ;;
      "Avoid using heat-trapping cases or remove them") result="Évitez d'utiliser des casques qui rétiennent la chaleur ou enlevez-les" ;;
      "Place on cool surface while charging") result="Placez-le sur une surface froide pendant le chargement" ;;
      "Health Assessment") result="Évaluation de la Santé" ;;
      "Overall Assessment") result="Évaluation Générale" ;;
      "DEVICE_MODEL") result="Modèle de l'Appareil" ;;
      "DEVICE_CODENAME") result="Code Identifiant de l'Appareil" ;;
      "BATTERY_MODEL") result="Modèle de la Batterie" ;;
      "ITERATION") result="Itération" ;;
      "REFRESH") result="Mise à jour" ;;
      "PRESS_CTRL_C_EXIT") result="Appuyez sur CTRL+C pour quitter et revenir au menu principal" ;;
      "MONITORING_STOPPED") result="Surveillance arrêtée. Retour au menu principal..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "de" ]]; then
    case "$key" in
      "SETTINGS") result="Einstellungen" ;;
      "CURRENT_STATUS") result="Aktueller Status" ;;
      "LIVE_MONITORING") result="Live-Überwachung Starten" ;;
      "BATTERY_TIPS") result="Akku-Tipps" ;;
      "BATTERY_DIAGNOSTICS") result="Akku-Diagnose" ;;
      "THERMAL_STATUS") result="Thermischer Status" ;;
      "TECHNICAL_INFO") result="Technische Informationen" ;;
      "LANGUAGE") result="Sprache" ;;
      "ABOUT") result="Über" ;;
      "EXIT") result="Beenden" ;;
      "BACK") result="Zurück" ;;
      "SELECT_OPTION") result="Wählen Sie eine Option" ;;
      "PRESS_KEY") result="Drücken Sie eine beliebige Taste, um zum Menü zurückzukehren" ;;
      "ENABLE") result="Aktivieren" ;;
      "DISABLE") result="Deaktivieren" ;;
      "ENABLED") result="Aktiviert" ;;
      "DISABLED") result="Deaktiviert" ;;
      "LOGGING") result="Protokollierung" ;;
      "SET_LOG_DIR") result="Protokollverzeichnis Festlegen" ;;
      "SELECT_LOG_FORMAT") result="Protokollformat Auswählen" ;;
      "SET_REFRESH_RATE") result="Aktualisierungsrate Festlegen" ;;
      "SELECT_VIEW_MODE") result="Anzeigemodus Auswählen" ;;
      "SELECT_COLOR_THEME") result="Farbthema Auswählen" ;;
      "RETURN_MAIN_MENU") result="Zurück zum Hauptmenü" ;;
      "VERSION") result="Version" ;;
      "LICENSE") result="Lizenz" ;;
      "CONFIG_DIR") result="Konfigurationsverzeichnis" ;;
      "LOG_DIR") result="Protokollverzeichnis" ;;
      "ABOUT_TEXT1") result="Diese Anwendung ermöglicht es Ihnen, den Batteriestatus, die Batterielebensdauer und thermische" ;;
      "ABOUT_TEXT2") result="Informationen von Android-Geräten in Echtzeit zu überwachen. Sie verfolgt Lademuster," ;;
      "ABOUT_TEXT3") result="diagnostiziert Batterieprobleme und optimiert die Batterieleistung mit detaillierten Analysen. Entwickelt von Ömer SÜSİN." ;;
      "Charging") result="Laden" ;;
      "Discharging") result="Entladen" ;;
      "Not charging") result="Nicht laden" ;;
      "Full") result="Voll" ;;
      "Unknown") result="Unbekannt" ;;
      "Fast Charging") result="Schnell laden" ;;
      "Normal Charging") result="Normal laden" ;;
      "Slow Charging") result="Langsam laden" ;;
      "High Power Usage") result="Hohe Leistungsaufnahme" ;;
      "Medium Power Usage") result="Mittlere Leistungsaufnahme" ;;
      "Low Power Usage") result="Niedrige Leistungsaufnahme" ;;
      "Not Charging") result="Nicht laden" ;;
      "to full") result="voll" ;;
      "remaining") result="verbleibend" ;;
      "Your battery is in good condition and working normally.") result="Ihr Akku ist in gutem Zustand und läuft normal." ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="Es scheint, dass Ihr Akku Probleme hat. Es wird empfohlen, Vorsichtsmaßnahmen zu ergreifen." ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="Ihr Akku ist in kritischem Zustand! Es wird empfohlen, sofort zu handeln oder zu ersetzen." ;;
      "Consider battery calibration or replacement.") result="Überlegen Sie die Kalibrierung oder das Ersetzen des Akkus." ;;
      "Excellent") result="Ausgezeichnet" ;;
      "Good") result="Gut" ;;
      "Poor") result="Schlecht" ;;
      "Critical (Replacement Recommended)") result="Kritisch (Ersetzung empfohlen)" ;;
      "Normal") result="Normal" ;;
      "High") result="Hoch" ;;
      "Very High") result="Sehr hoch" ;;
      "Critical") result="Kritisch" ;;
      "Low Usage") result="Niedrige Nutzung" ;;
      "Normal") result="Normal" ;;
      "High") result="Hoch" ;;
      "Very High (Replacement Advised)") result="Sehr hoch (Ersetzung empfohlen)" ;;
      "Optimal") result="Optimal" ;;
      "Battery Temperature") result="Akku-Temperatur" ;;
      "Hottest Zone") result="Heißeste Zone" ;;
      "Temperature") result="Temperatur" ;;
      "Voltage") result="Spannung" ;;
      "Current") result="Strom" ;;
      "Power") result="Leistung" ;;
      "Health") result="Gesundheit" ;;
      "Cycle Count") result="Anzahl der Zyklen" ;;
      "Technology") result="Technologie" ;;
      "Battery Path") result="Akku-Pfad" ;;
      "Raw Values") result="Rohwerte" ;;
      "Estimated") result="Geschätzt" ;;
      "Charging Type") result="Ladetyp" ;;
      "Battery Optimization Tips") result="Tipps zur Akkuoptimierung" ;;
      "Battery Health Diagnostics") result="Akku-Gesundheitsdiagnose" ;;
      "WARNING: Battery temperature is too high") result="WARNUNG: Akkutemperatur ist zu hoch" ;;
      "Reduce screen brightness to a comfortable level") result="Reduzieren Sie die Bildschirmhelligkeit auf ein angenehmes Niveau" ;;
      "Keep battery level ideally between 20-85%") result="Halten Sie den Akkustand idealerweise zwischen 20-85%" ;;
      "Use certified or original charging adapters") result="Verwenden Sie zertifizierte oder originale Ladeadapter" ;;
      "Prefer slow charging (low current) when not in a hurry") result="Bevorzugen Sie langsames Laden (niedriger Strom), wenn Sie nicht in Eile sind" ;;
      "Avoid battery getting repeatedly hot") result="Vermeiden Sie, dass der Akku wiederholt heiß wird" ;;
      "Keep away from direct sunlight or very hot environments") result="Halten Sie es von direktem Sonnenlicht oder sehr heißen Umgebungen fern" ;;
      "Avoid using heat-trapping cases or remove them") result="Vermeiden Sie hitzeabsorbierende Hüllen oder entfernen Sie diese" ;;
      "Place on cool surface while charging") result="Legen Sie es während des Ladens auf eine kühle Oberfläche" ;;
      "Health Assessment") result="Gesundheitsbewertung" ;;
      "Overall Assessment") result="Gesamtbewertung" ;;
      "DEVICE_MODEL") result="Gerätemodell" ;;
      "DEVICE_CODENAME") result="Geräte-Codename" ;;
      "BATTERY_MODEL") result="Batterie-Modell" ;;
      "ITERATION") result="Iteration" ;;
      "REFRESH") result="Aktualisierung" ;;
      "PRESS_CTRL_C_EXIT") result="Drücken Sie CTRL+C, um zu beenden und zum Hauptmenü zurückzukehren" ;;
      "MONITORING_STOPPED") result="Überwachung gestoppt. Rückkehr zum Hauptmenü..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "hi" ]]; then
    case "$key" in
      "SETTINGS") result="सेटिंग्स" ;;
      "CURRENT_STATUS") result="वर्तमान स्थिति" ;;
      "LIVE_MONITORING") result="लाइव मॉनिटरिंग शुरू करें" ;;
      "BATTERY_TIPS") result="बैटरी टिप्स" ;;
      "BATTERY_DIAGNOSTICS") result="बैटरी डायग्नोस्टिक्स" ;;
      "THERMAL_STATUS") result="थर्मल स्थिति" ;;
      "TECHNICAL_INFO") result="तकनीकी जानकारी" ;;
      "LANGUAGE") result="भाषा" ;;
      "ABOUT") result="के बारे में" ;;
      "EXIT") result="बाहर निकलें" ;;
      "BACK") result="वापस" ;;
      "SELECT_OPTION") result="एक विकल्प चुनें" ;;
      "PRESS_KEY") result="मेनू पर वापस जाने के लिए किसी भी कुंजी दबाएं" ;;
      "ENABLE") result="सक्षम करें" ;;
      "DISABLE") result="अक्षम करें" ;;
      "ENABLED") result="सक्षम" ;;
      "DISABLED") result="अक्षम" ;;
      "LOGGING") result="लॉगिंग" ;;
      "SET_LOG_DIR") result="लॉग डायरेक्टरी सेट करें" ;;
      "SELECT_LOG_FORMAT") result="लॉग फॉर्मेट सेट करें" ;;
      "SET_REFRESH_RATE") result="रीफ्रेश दर सेट करें" ;;
      "SELECT_VIEW_MODE") result="व्यू मोड चुनें" ;;
      "SELECT_COLOR_THEME") result="रंग थीम चुनें" ;;
      "RETURN_MAIN_MENU") result="मुख्य मेनू पर वापस जाएं" ;;
      "VERSION") result="संस्करण" ;;
      "LICENSE") result="लाइसेंस" ;;
      "CONFIG_DIR") result="कॉन्फ़िगरेशन डायरेक्टरी" ;;
      "LOG_DIR") result="लॉग डायरेक्टरी" ;;
      "ABOUT_TEXT1") result="यह एप्लिकेशन आपको एंड्रॉइड डिवाइस की बैटरी स्थिति, स्वास्थ्य और थर्मल" ;;
      "ABOUT_TEXT2") result="तथ्य रियल-टाइम में मॉनिटर करने की अनुमति देता है। यह चार्जिंग पैटर्न का पता लगाता है," ;;
      "ABOUT_TEXT3") result="बैटरी समस्याओं का निदान करता है और विस्तृत विश्लेषण के साथ बैटरी प्रदर्शन को अनुकूलित करता है। Ömer SÜSİN द्वारा विकसित।" ;;
      "Charging") result="चार्ज हो रहा है" ;;
      "Discharging") result="डिस्चार्ज हो रहा है" ;;
      "Not charging") result="चार्ज नहीं हो रहा है" ;;
      "Full") result="फुल" ;;
      "Unknown") result="अज्ञात" ;;
      "Fast Charging") result="तीव्र चार्जिंग" ;;
      "Normal Charging") result="सामान्य चार्जिंग" ;;
      "Slow Charging") result="धीमी चार्जिंग" ;;
      "High Power Usage") result="उच्च शक्ति उपयोग" ;;
      "Medium Power Usage") result="मध्यम शक्ति उपयोग" ;;
      "Low Power Usage") result="निम्न शक्ति उपयोग" ;;
      "Not Charging") result="चार्ज नहीं हो रहा है" ;;
      "to full") result="पूर्ण चार्ज करने के लिए" ;;
      "remaining") result="शेष" ;;
      "Your battery is in good condition and working normally.") result="आपकी बैटरी अच्छी स्थिति में है और सामान्य रूप में काम कर रही है।" ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="आपकी बैटरी में कुछ समस्याएं हैं। उपचार लेने की सलाह दी जाती है।" ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="आपकी बैटरी विशेष रूप में है! तुरंत कार्य करने या बदलने की आवश्यकता है।" ;;
      "Consider battery calibration or replacement.") result="बैटरी कैलिब्रेशन या बदलने की विचार करें।" ;;
      "Excellent") result="शानदार" ;;
      "Good") result="अच्छा" ;;
      "Poor") result="खराब" ;;
      "Critical (Replacement Recommended)") result="क्रिटिकल (बदलने की सलाह दी गई)" ;;
      "Normal") result="सामान्य" ;;
      "High") result="उच्च" ;;
      "Very High") result="बहुत उच्च" ;;
      "Critical") result="क्रिटिकल" ;;
      "Low Usage") result="निम्न उपयोग" ;;
      "Normal") result="सामान्य" ;;
      "High") result="उच्च" ;;
      "Very High (Replacement Advised)") result="बहुत उच्च (बदलने की सलाह दी गई)" ;;
      "Optimal") result="सर्वोत्तम" ;;
      "Battery Temperature") result="बैटरी तापमान" ;;
      "Hottest Zone") result="सबसे गर्म क्षेत्र" ;;
      "Temperature") result="तापमान" ;;
      "Voltage") result="वोल्टेज" ;;
      "Current") result="करंट" ;;
      "Power") result="पावर" ;;
      "Health") result="स्वास्थ्य" ;;
      "Cycle Count") result="साइकिल काउंट" ;;
      "Technology") result="टेक्नोलॉजी" ;;
      "Battery Path") result="बैटरी पाथ" ;;
      "Raw Values") result="रॉ वैल्यूज" ;;
      "Estimated") result="अनुमानित" ;;
      "Charging Type") result="चार्जिंग प्रकार" ;;
      "Battery Optimization Tips") result="बैटरी अनुकूलन युक्तियाँ" ;;
      "Battery Health Diagnostics") result="बैटरी स्वास्थ्य निदान" ;;
      "WARNING: Battery temperature is too high") result="चेतावनी: बैटरी का तापमान बहुत अधिक है" ;;
      "Reduce screen brightness to a comfortable level") result="स्क्रीन की चमक को आरामदायक स्तर तक कम करें" ;;
      "Keep battery level ideally between 20-85%") result="बैटरी स्तर को आदर्श रूप से 20-85% के बीच रखें" ;;
      "Use certified or original charging adapters") result="प्रमाणित या मूल चार्जिंग एडाप्टर का उपयोग करें" ;;
      "Prefer slow charging (low current) when not in a hurry") result="जब जल्दी न हो तो धीमी चार्जिंग (कम करंट) को प्राथमिकता दें" ;;
      "Avoid battery getting repeatedly hot") result="बैटरी को बार-बार गर्म होने से बचें" ;;
      "Keep away from direct sunlight or very hot environments") result="सीधी धूप या बहुत गर्म वातावरण से दूर रखें" ;;
      "Avoid using heat-trapping cases or remove them") result="गर्मी को फँसाने वाले केस का उपयोग करने से बचें या उन्हें हटा दें" ;;
      "Place on cool surface while charging") result="चार्जिंग के दौरान ठंडी सतह पर रखें" ;;
      "Health Assessment") result="स्वास्थ्य मूल्यांकन" ;;
      "Overall Assessment") result="समग्र मूल्यांकन" ;;
      "DEVICE_MODEL") result="डिवाइस मॉडल" ;;
      "DEVICE_CODENAME") result="डिवाइस कोडनेम" ;;
      "BATTERY_MODEL") result="बैटरी मॉडल" ;;
      "ITERATION") result="पुनरावृत्ति" ;;
      "REFRESH") result="रीफ्रेश" ;;
      "PRESS_CTRL_C_EXIT") result="बाहर निकलने और मुख्य मेनू पर वापस जाने के लिए CTRL+C दबाएं" ;;
      "MONITORING_STOPPED") result="मॉनिटरिंग रुक गई है। मुख्य मेनू पर वापस जा रहे हैं..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "pl" ]]; then
    case "$key" in
      "SETTINGS") result="Ustawienia" ;;
      "CURRENT_STATUS") result="Aktualny Status" ;;
      "LIVE_MONITORING") result="Rozpocznij Monitoring" ;;
      "BATTERY_TIPS") result="Porady Dotyczące Baterii" ;;
      "BATTERY_DIAGNOSTICS") result="Diagnostyka Baterii" ;;
      "THERMAL_STATUS") result="Status Termiczny" ;;
      "TECHNICAL_INFO") result="Informacje Techniczne" ;;
      "LANGUAGE") result="Język" ;;
      "ABOUT") result="O Programie" ;;
      "EXIT") result="Wyjście" ;;
      "BACK") result="Powrót" ;;
      "SELECT_OPTION") result="Wybierz opcję" ;;
      "PRESS_KEY") result="Naciśnij dowolny klawisz, aby wrócić do menu" ;;
      "ENABLE") result="Włącz" ;;
      "DISABLE") result="Wyłącz" ;;
      "ENABLED") result="Włączone" ;;
      "DISABLED") result="Wyłączone" ;;
      "LOGGING") result="Logowanie" ;;
      "SET_LOG_DIR") result="Ustawianie Katalogu Logów" ;;
      "SELECT_LOG_FORMAT") result="Wybieranie Formatu Logu" ;;
      "SET_REFRESH_RATE") result="Ustawianie Szybkości Odświeżania" ;;
      "SELECT_VIEW_MODE") result="Wybieranie Trybu Wyświetlania" ;;
      "SELECT_COLOR_THEME") result="Wybieranie Motywu Kolorów" ;;
      "RETURN_MAIN_MENU") result="Powrót do Menu Głównego" ;;
      "VERSION") result="Wersja" ;;
      "LICENSE") result="Licencja" ;;
      "CONFIG_DIR") result="Katalog Konfiguracji" ;;
      "LOG_DIR") result="Katalog Logów" ;;
      "ABOUT_TEXT1") result="To program umożliwia monitorowanie stanu, zdrowia baterii i informacji" ;;
      "ABOUT_TEXT2") result="termicznych urządzeń Android w czasie rzeczywistym. Śledzi wzorce ładowania," ;;
      "ABOUT_TEXT3") result="diagnozuje problemy z baterią i optymalizuje wydajność za pomocą szczegółowych analiz. Opracowany przez Ömer SÜSİN." ;;
      "Charging") result="Ładowanie" ;;
      "Discharging") result="Rozładowywanie" ;;
      "Not charging") result="Nie ładowanie" ;;
      "Full") result="Pełne" ;;
      "Unknown") result="Nieznane" ;;
      "Fast Charging") result="Szybkie ładowanie" ;;
      "Normal Charging") result="Normalne ładowanie" ;;
      "Slow Charging") result="Wolne ładowanie" ;;
      "High Power Usage") result="Wysokie Zużycie Mocy" ;;
      "Medium Power Usage") result="Średnie Zużycie Mocy" ;;
      "Low Power Usage") result="Niskie Zużycie Mocy" ;;
      "Not Charging") result="Nie ładowanie" ;;
      "to full") result="do pełnego" ;;
      "remaining") result="pozostało" ;;
      "Your battery is in good condition and working normally.") result="Twoja bateria jest w dobrym stanie i działa normalnie." ;;
      "Your battery appears to have issues. Taking precautions is recommended.") result="Wydaje się, że twoja bateria ma pewne problemy. Zaleca się podjęcie środków zapobiegawczych." ;;
      "Your battery is in critical condition! Immediate action/replacement may be needed.") result="Twoja bateria jest w krytycznym stanie! Może być konieczne natychmiastowe działanie/zastąpienie." ;;
      "Consider battery calibration or replacement.") result="Rozważ kalibrację baterii lub zastąpienie." ;;
      "Excellent") result="Bardzo dobry" ;;
      "Good") result="Dobry" ;;
      "Poor") result="Słaby" ;;
      "Critical (Replacement Recommended)") result="Krytyczny (Zalecane zastąpienie)" ;;
      "Normal") result="Normalny" ;;
      "High") result="Wysoki" ;;
      "Very High") result="Bardzo wysoki" ;;
      "Critical") result="Krytyczny" ;;
      "Low Usage") result="Niska Użytkowość" ;;
      "Normal") result="Normalny" ;;
      "High") result="Wysoki" ;;
      "Very High (Replacement Advised)") result="Bardzo wysoki (Zalecane zastąpienie)" ;;
      "Optimal") result="Optymalny" ;;
      "Battery Temperature") result="Napięcie Baterii" ;;
      "Hottest Zone") result="Najgorętsza Strefa" ;;
      "Temperature") result="Temperatura" ;;
      "Voltage") result="Napięcie" ;;
      "Current") result="Prąd" ;;
      "Power") result="Moc" ;;
      "Health") result="Zdrowie" ;;
      "Cycle Count") result="Liczba Cykli" ;;
      "Technology") result="Technologia" ;;
      "Battery Path") result="Ścieżka Baterii" ;;
      "Raw Values") result="Surowe Wartości" ;;
      "Estimated") result="Szacowane" ;;
      "Charging Type") result="Typ ładowania" ;;
      "Battery Optimization Tips") result="Porady dotyczące optymalizacji baterii" ;;
      "Battery Health Diagnostics") result="Diagnostyka Stanu Baterii" ;;
      "WARNING: Battery temperature is too high") result="OSTRZEŻENIE: Napięcie baterii jest zbyt wysokie" ;;
      "Reduce screen brightness to a comfortable level") result="Ustaw jasność ekranu na wygodny poziom" ;;
      "Keep battery level ideally between 20-85%") result="Utrzymaj poziom naładowania baterii idealnie między 20-85%" ;;
      "Use certified or original charging adapters") result="Użyj certyfikowanych lub oryginalnych adapterów do ładowania" ;;
      "Prefer slow charging (low current) when not in a hurry") result="Wolniejsze ładowanie (niższa prąd) gdy nie masz zimna" ;;
      "Avoid battery getting repeatedly hot") result="Unikaj powtarzającego się przegrzewania baterii" ;;
      "Keep away from direct sunlight or very hot environments") result="Unikaj bezpośredniego słońca lub bardzo gorących środowisk" ;;
      "Avoid using heat-trapping cases or remove them") result="Unikaj używania kieszeni, które zatrzymują ciepło lub je usuń" ;;
      "Place on cool surface while charging") result="Ładuj w klimatyzowanej powierzchni podczas ładowania" ;;
      "Health Assessment") result="Ocena Stanu Zdrowia" ;;
      "Overall Assessment") result="Ogólna Ocena" ;;
      "DEVICE_MODEL") result="Model Urządzenia" ;;
      "DEVICE_CODENAME") result="Kod Identyfikacyjny Urządzenia" ;;
      "BATTERY_MODEL") result="Model Baterii" ;;
      "ITERATION") result="Iteracja" ;;
      "REFRESH") result="Odświeżanie" ;;
      "PRESS_CTRL_C_EXIT") result="Naciśnij CTRL+C, aby wyjść i wrócić do menu głównego" ;;
      "MONITORING_STOPPED") result="Monitoring zatrzymany. Powrót do menu głównego..." ;;
      *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "bn" ]]; then
    case "$key" in
      "SETTINGS") result="সেটিংস" ;;
      "CURRENT_STATUS") result="বর্তমান অবস্থা" ;;
      "LIVE_MONITORING") result="লাইভ মনিটরিং শুরু করুন" ;;
      "BATTERY_TIPS") result="ব্যাটারি টিপস" ;;
      "BATTERY_DIAGNOSTICS") result="ব্যাটারি ডায়াগনস্টিকস" ;;
      "THERMAL_STATUS") result="তাপীয় অবস্থা" ;;
      "TECHNICAL_INFO") result="প্রযুক্তিগত তথ্য" ;;
      "LANGUAGE") result="ভাষা" ;;
      "ABOUT") result="সম্পর্কে" ;;
      "EXIT") result="প্রস্থান" ;;
      "BACK") result="পিছনে" ;;
      "SELECT_OPTION") result="একটি বিকল্প নির্বাচন করুন" ;;
      "PRESS_KEY") result="মেনুতে ফিরে যেতে যেকোনো কী টিপুন" ;;
      "ENABLE") result="এন্যাম" ;;
      "DISABLE") result="ডিসেম" ;;
      "ENABLED") result="এন্যাম" ;;
      "DISABLED") result="ডিসেম" ;;
      "LOGGING") result="লগিং" ;;
      "SET_LOG_DIR") result="লগ ডায়ারেটরি সেট করুন" ;;
      "SELECT_LOG_FORMAT") result="লগ ফর্মেট সেট করুন" ;;
      "SET_REFRESH_RATE") result="রিফ্রেশ দ্রুততা সেট করুন" ;;
      "ABOUT_TEXT1") result="এই অ্যাপ্লিকেশন আপনাকে অ্যান্ড্রয়েড ডিভাইসের ব্যাটারি স্ট্যাটাস, স্বাস্থ্য এবং তাপীয়" ;;
      "ABOUT_TEXT2") result="তথ্য রিয়েল-টাইমে মনিটর করতে দেয়। এটি চার্জিং প্যাটার্ন ট্র্যাক করে," ;;
      "ABOUT_TEXT3") result="ব্যাটারি সমস্যা নির্ণয় করে এবং বিস্তারিত বিশ্লেষণ সহ ব্যাটারি কর্মক্ষমতা অপ্টিমাইজ করে। Ömer SÜSİN দ্বারা বিকাশিত।" ;;
      "ITERATION") result="পুনরাবৃত্তি" ;;
          *) result="$key" ;;
    esac
  elif [[ "$LANGUAGE" == "en" ]]; then
    case "$key" in
      "SETTINGS") result="Settings" ;;
      "CURRENT_STATUS") result="Current Status" ;;
      "LIVE_MONITORING") result="Start Live Monitoring" ;;
      "BATTERY_TIPS") result="Battery Tips" ;;
      "BATTERY_DIAGNOSTICS") result="Battery Diagnostics" ;;
      "THERMAL_STATUS") result="Thermal Status" ;;
      "TECHNICAL_INFO") result="Technical Information" ;;
      "LANGUAGE") result="Language" ;;
      "ABOUT") result="About" ;;
      "EXIT") result="Exit" ;;
      "BACK") result="Back" ;;
      "SELECT_OPTION") result="Select an option" ;;
      "PRESS_KEY") result="Press any key to return to menu" ;;
      "ENABLE") result="Enable" ;;
      "DISABLE") result="Disable" ;;
      "ENABLED") result="Enabled" ;;
      "DISABLED") result="Disabled" ;;
      "LOGGING") result="Logging" ;;
      "SET_LOG_DIR") result="Set Log Directory" ;;
      "SELECT_LOG_FORMAT") result="Select Log Format" ;;
      "SET_REFRESH_RATE") result="Set Refresh Rate" ;;
      "SELECT_VIEW_MODE") result="Select View Mode" ;;
      "SELECT_COLOR_THEME") result="Select Color Theme" ;;
      "RETURN_MAIN_MENU") result="Return to Main Menu" ;;
      "VERSION") result="Version" ;;
      "LICENSE") result="License" ;;
      "CONFIG_DIR") result="Configuration Directory" ;;
      "LOG_DIR") result="Log Directory" ;;
      "ABOUT_TEXT1") result="This application allows you to monitor battery status, health, and thermal" ;;
      "ABOUT_TEXT2") result="information of Android devices in real-time. It tracks charging patterns," ;;
      "ABOUT_TEXT3") result="diagnoses battery issues and optimizes battery performance with detailed analytics. Developed by Ömer SÜSİN." ;;
      "ITERATION") result="Iteration" ;;
      "REFRESH") result="Refresh" ;;
      "PRESS_CTRL_C_EXIT") result="Press CTRL+C to exit and return to main menu" ;;
      "MONITORING_STOPPED") result="Monitoring stopped. Returning to main menu..." ;;
      *) result="$key" ;;
    esac
  else
    # Default to English if language not recognized
    case "$key" in
      "SETTINGS") result="Settings" ;;
      "CURRENT_STATUS") result="Current Status" ;;
      "LIVE_MONITORING") result="Start Live Monitoring" ;;
      "BATTERY_TIPS") result="Battery Tips" ;;
      "BATTERY_DIAGNOSTICS") result="Battery Diagnostics" ;;
      "THERMAL_STATUS") result="Thermal Status" ;;
      "TECHNICAL_INFO") result="Technical Information" ;;
      "LANGUAGE") result="Language" ;;
      "ABOUT") result="About" ;;
      "EXIT") result="Exit" ;;
      "BACK") result="Back" ;;
      "SELECT_OPTION") result="Select an option" ;;
      "ITERATION") result="Iteration" ;;
      "REFRESH") result="Refresh" ;;
      "PRESS_CTRL_C_EXIT") result="Press CTRL+C to exit and return to main menu" ;;
      "MONITORING_STOPPED") result="Monitoring stopped. Returning to main menu..." ;;
      *) result="$key" ;;
    esac
  fi
  
  echo "$result"
}

# Ana menüyü göster
show_menu() {
  clear
  
  # Karşılama ekranı
  echo -e "\n  :: Android Battery Monitoring System ::"
  echo -e "  :: Developer: Ömer SÜSİN - AI assisted development ::\n"
  
  draw_box "Android Battery Monitoring System"
  
  local width=$((TERMINAL_WIDTH - 8))
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[1]${COLORS[RESET]} ${COLORS[MENU_ITEM]}🔋 $(get_translation "CURRENT_STATUS")${COLORS[RESET]}"
  printf "%*s" $((width - 21)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[2]${COLORS[RESET]} ${COLORS[MENU_ITEM]}📊 $(get_translation "LIVE_MONITORING")${COLORS[RESET]}"
  printf "%*s" $((width - 28)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[3]${COLORS[RESET]} ${COLORS[MENU_ITEM]}⚙️  $(get_translation "SETTINGS")${COLORS[RESET]}"
  printf "%*s" $((width - 15)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[4]${COLORS[RESET]} ${COLORS[MENU_ITEM]}💡 $(get_translation "BATTERY_TIPS")${COLORS[RESET]}"
  printf "%*s" $((width - 19)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[5]${COLORS[RESET]} ${COLORS[MENU_ITEM]}❤️  $(get_translation "BATTERY_DIAGNOSTICS")${COLORS[RESET]}"
  printf "%*s" $((width - 26)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[6]${COLORS[RESET]} ${COLORS[MENU_ITEM]}🌡️  $(get_translation "THERMAL_STATUS")${COLORS[RESET]}"
  printf "%*s" $((width - 21)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[7]${COLORS[RESET]} ${COLORS[MENU_ITEM]}🛠️  $(get_translation "TECHNICAL_INFO")${COLORS[RESET]}"
  printf "%*s" $((width - 21)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[8]${COLORS[RESET]} ${COLORS[MENU_ITEM]}ℹ️  $(get_translation "ABOUT")${COLORS[RESET]}"
  printf "%*s" $((width - 24)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[0]${COLORS[RESET]} ${COLORS[MENU_ITEM]}❌ $(get_translation "EXIT")${COLORS[RESET]}"
  printf "%*s" $((width - 19)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Durum bilgisi
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "─────────────────────────────────────────────────────────────"
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  # Pil durumu özeti
  get_battery_info
  local status="${BATTERY_INFO[status]}"
  local capacity="${BATTERY_INFO[capacity]}"
  local temp="${BATTERY_INFO[temp]}"
  
  local status_tr="Unknown"
  case "$status" in
    "Charging") status_tr="Charging" ;;
    "Discharging") status_tr="Discharging" ;;
    "Full") status_tr="Full" ;;
    "Not charging") status_tr="Not charging" ;;
    *) status_tr="$status" ;;
  esac
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "Battery: "
  
  # Pil yüzdesi ve rengi
  local capacity_color="${COLORS[NORMAL]}"
  if (( capacity < 20 )); then
    capacity_color="${COLORS[BATTERY_LOW]}"
  elif (( capacity < 50 )); then
    capacity_color="${COLORS[BATTERY_MID]}"
  else
    capacity_color="${COLORS[BATTERY_HIGH]}"
  fi
  echo -ne "${capacity_color}${capacity}%${COLORS[RESET]}"
  
  echo -ne " | Status: ${status_tr} | Temperature: ${temp}°C"
  
  # Görünüm modu, tema ve log durumu
  printf "%*s" $((width - 50 - ${#status_tr})) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "View: ${VIEW_MODE} | Theme: ${THEME} | Logging: "
  if (( LOGGING_ENABLED == 1 )); then
    echo -ne "${COLORS[SUCCESS]}Enabled${COLORS[RESET]}"
  else
    echo -ne "${COLORS[WARNING]}Disabled${COLORS[RESET]}"
  fi
  printf "%*s" $((width - 50)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  close_box
  
  echo -e "\n$(get_translation "SELECT_OPTION") [0-9]: \c"
  read -n 1 choice
  
  case "$choice" in
    1) show_battery_status "static" ;;
    2) start_live_monitoring ;;
    3) show_settings ;;
    4) show_battery_tips ;;
    5) show_battery_diagnostics ;;
    6) show_thermal_status ;;
    7) show_technical_info ;;
    8) show_about ;;
    0) cleanup ;;
    *) show_menu ;;
  esac
}

# Canlı izleme başlat
start_live_monitoring() {
  clear
  
  local log_file=""
  
  # Set up trap to return to main menu when Ctrl+C is pressed
  trap 'echo -e "\n${COLORS[SUCCESS]}İzleme durdu. Ana menüye dönülüyor...${COLORS[RESET]}"; sleep 1; return' INT
  
  # Loglama açıksa log dosyası oluştur
  if (( LOGGING_ENABLED == 1 )); then
    log_file=$(create_log_file)
    echo -e "Loglama etkin. Log dosyası: ${log_file}"
  fi
  
  echo -e "Canlı izleme başlatılıyor. Çıkmak için CTRL+C'ye basın..."
  echo -e "Yenileme aralığı: ${REFRESH_RATE} saniye\n"
  sleep 2
  
  # Değişkenleri başlat
  local iteration=0
  
  # Sonsuz döngü
  while true; do
    # İterasyon sayacını artır
    ((iteration++))
    
    # Temiz ekran - her yenileme öncesi
    clear
    
    # Verileri güncelle
    get_battery_info
    get_thermal_info
    
    # Ekranı göster
    show_battery_status
    
    # İterasyon sayısını ve çıkış yönergesini göster
    echo -e "\n${COLORS[INFO]}İterasyon: $iteration | Yenileme: ${REFRESH_RATE}s${COLORS[RESET]}"
    echo -e "${COLORS[WARNING]}Çıkmak ve ana menüye dönmek için CTRL+C'ye basın${COLORS[RESET]}"
    
    # Loglama yapılsın mı?
    if (( LOGGING_ENABLED == 1 )) && [[ -n "$log_file" ]]; then
      log_battery_info "$log_file" > /dev/null
    fi
    
    # Yenileme aralığında bekle
    sleep "$REFRESH_RATE"
  done
}

# Ayarlar menüsünü göster
show_settings() {
  local exit_settings=0
  
  while (( exit_settings == 0 )); do
    clear
    
    draw_box "$(get_translation "SETTINGS")"
    
    local width=$((TERMINAL_WIDTH - 8))
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[MENU_NUMBER]}[1]${COLORS[RESET]} ${COLORS[MENU_ITEM]}"
    if (( LOGGING_ENABLED == 1 )); then
      echo -ne "${COLORS[SUCCESS]}$(get_translation "DISABLE")${COLORS[RESET]}"
    else
      echo -ne "${COLORS[WARNING]}$(get_translation "ENABLE")${COLORS[RESET]}"
    fi
    echo -ne " $(get_translation "LOGGING")"
    printf "%*s" $((width - 20)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[MENU_NUMBER]}[2]${COLORS[RESET]} ${COLORS[MENU_ITEM]}$(get_translation "SET_LOG_DIR") (${COLORS[DIM]}${LOG_DIR}${COLORS[RESET]})"
    printf "%*s" $((width - 25 - ${#LOG_DIR})) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[MENU_NUMBER]}[3]${COLORS[RESET]} ${COLORS[MENU_ITEM]}$(get_translation "SELECT_LOG_FORMAT") (${LOG_FORMAT})${COLORS[RESET]}"
    printf "%*s" $((width - 30 - ${#LOG_FORMAT})) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[MENU_NUMBER]}[4]${COLORS[RESET]} ${COLORS[MENU_ITEM]}$(get_translation "SET_REFRESH_RATE") (${REFRESH_RATE} sec)${COLORS[RESET]}"
    printf "%*s" $((width - 35 - ${#REFRESH_RATE})) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[MENU_NUMBER]}[5]${COLORS[RESET]} ${COLORS[MENU_ITEM]}$(get_translation "SELECT_VIEW_MODE") (${VIEW_MODE})${COLORS[RESET]}"
    printf "%*s" $((width - 30 - ${#VIEW_MODE})) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[MENU_NUMBER]}[6]${COLORS[RESET]} ${COLORS[MENU_ITEM]}$(get_translation "SELECT_COLOR_THEME") (${THEME})${COLORS[RESET]}"
    printf "%*s" $((width - 32 - ${#THEME})) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[MENU_NUMBER]}[7]${COLORS[RESET]} ${COLORS[MENU_ITEM]}$(get_translation "LANGUAGE") (${LANGUAGE})${COLORS[RESET]}"
    printf "%*s" $((width - 25 - ${#LANGUAGE})) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
    echo -ne "${COLORS[MENU_NUMBER]}[0]${COLORS[RESET]} ${COLORS[MENU_ITEM]}$(get_translation "RETURN_MAIN_MENU")${COLORS[RESET]}"
    printf "%*s" $((width - 24)) ""
    echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
    
    close_box
    
    echo -e "\n$(get_translation "SELECT_OPTION") [0-7]: \c"
    read -n 1 settings_choice
    echo
    
    case "$settings_choice" in
      1)
        # Toggle logging
        if (( LOGGING_ENABLED == 1 )); then
          LOGGING_ENABLED=0
          if [[ "$LANGUAGE" == "tr" ]]; then
            echo "Loglama kapatıldı."
          else
            echo "Logging disabled."
          fi
        else
          LOGGING_ENABLED=1
          if [[ "$LANGUAGE" == "tr" ]]; then
            echo "Loglama açıldı. Dizin: $LOG_DIR, Format: $LOG_FORMAT"
          else
            echo "Logging enabled. Directory: $LOG_DIR, Format: $LOG_FORMAT"
          fi
          create_log_dir
        fi
        save_config
        sleep 2
        ;;
      2)
        # Set log directory
        if [[ "$LANGUAGE" == "tr" ]]; then
          echo -e "\nYeni log dizinini girin (varsayılan için boş bırakın):"
        else
          echo -e "\nEnter new log directory (leave empty for default):"
        fi
        read -e new_log_dir
        if [[ -n "$new_log_dir" ]]; then
          LOG_DIR="$new_log_dir"
          create_log_dir
          if [[ "$LANGUAGE" == "tr" ]]; then
            echo "Log dizini ayarlandı: $LOG_DIR"
          else
            echo "Log directory set to: $LOG_DIR"
          fi
        else
          LOG_DIR="$HOME/bbms/logs"
          create_log_dir
          if [[ "$LANGUAGE" == "tr" ]]; then
            echo "Log dizini varsayılan değere ayarlandı: $LOG_DIR"
          else
            echo "Log directory set to default: $LOG_DIR"
          fi
        fi
        save_config
        sleep 2
        ;;
      3)
        # Select log format
        if [[ "$LANGUAGE" == "tr" ]]; then
          echo -e "\nLog formatını seçin (csv/json/txt):"
        else
          echo -e "\nSelect log format (csv/json/txt):"
        fi
        read -e new_log_format
        case "$new_log_format" in
          csv|CSV) LOG_FORMAT="csv" ;;
          json|JSON) LOG_FORMAT="json" ;;
          txt|TXT) LOG_FORMAT="txt" ;;
          *) 
            if [[ "$LANGUAGE" == "tr" ]]; then
              echo "Geçersiz format. csv, json veya txt kullanın."
            else
              echo "Invalid format. Use csv, json or txt."
            fi
            ;;
        esac
        if [[ "$LANGUAGE" == "tr" ]]; then
          echo "Log formatı ayarlandı: $LOG_FORMAT"
        else
          echo "Log format set to: $LOG_FORMAT"
        fi
        save_config
        sleep 2
        ;;
      4)
        # Set refresh rate
        if [[ "$LANGUAGE" == "tr" ]]; then
          echo -e "\nYenileme aralığını saniye olarak girin (varsayılan: 5):"
        else
          echo -e "\nEnter refresh rate in seconds (default: 5):"
        fi
        read -e new_refresh_rate
        if [[ "$new_refresh_rate" =~ ^[0-9]+$ ]]; then
          if (( new_refresh_rate < 1 )); then
            if [[ "$LANGUAGE" == "tr" ]]; then
              echo "Uyarı: Yenileme aralığı 1 saniyeden az olamaz. 1 saniye kullanılacak." >&2
            else
              echo "Warning: Refresh rate cannot be less than 1 second. Using 1 second." >&2
            fi
            REFRESH_RATE=1
          else
            REFRESH_RATE="$new_refresh_rate"
            if [[ "$LANGUAGE" == "tr" ]]; then
              echo "Yenileme aralığı ayarlandı: $REFRESH_RATE saniye"
            else
              echo "Refresh rate set to: $REFRESH_RATE seconds"
            fi
          fi
        else
          if [[ "$LANGUAGE" == "tr" ]]; then
            echo "Geçersiz değer. Sayı girmelisiniz."
          else
            echo "Invalid value. You must enter a number."
          fi
        fi
        save_config
        sleep 2
        ;;
      5)
        # Select view mode
        if [[ "$LANGUAGE" == "tr" ]]; then
          echo -e "\nGörünüm modunu seçin (minimal/detailed/debug):"
        else
          echo -e "\nSelect view mode (minimal/detailed/debug):"
        fi
        read -e new_view_mode
        case "$new_view_mode" in
          minimal|MINIMAL) VIEW_MODE="minimal" ;;
          detailed|DETAILED|detayli|DETAYLI) VIEW_MODE="detailed" ;;
          debug|DEBUG) VIEW_MODE="debug" ;;
          *) 
            if [[ "$LANGUAGE" == "tr" ]]; then
              echo "Geçersiz mod. minimal, detailed veya debug kullanın."
            else
              echo "Invalid mode. Use minimal, detailed or debug."
            fi
            ;;
        esac
        if [[ "$LANGUAGE" == "tr" ]]; then
          echo "Görünüm modu ayarlandı: $VIEW_MODE"
        else
          echo "View mode set to: $VIEW_MODE"
        fi
        save_config
        sleep 2
        ;;
      6)
        # Select color theme
        if [[ "$LANGUAGE" == "tr" ]]; then
          echo -e "\nRenk temasını seçin (dark/light/gruvbox/nord/dracula):"
        else
          echo -e "\nSelect color theme (dark/light/gruvbox/nord/dracula):"
        fi
        read -e new_theme
        case "$new_theme" in
          dark|DARK) 
            THEME="dark"
            set_theme "$THEME"
            ;;
          light|LIGHT) 
            THEME="light"
            set_theme "$THEME"
            ;;
          gruvbox|GRUVBOX) 
            THEME="gruvbox"
            set_theme "$THEME"
            ;;
          nord|NORD) 
            THEME="nord"
            set_theme "$THEME"
            ;;
          dracula|DRACULA) 
            THEME="dracula"
            set_theme "$THEME"
            ;;
          *) 
            if [[ "$LANGUAGE" == "tr" ]]; then
              echo "Geçersiz tema. dark, light, gruvbox, nord veya dracula kullanın."
            else
              echo "Invalid theme. Use dark, light, gruvbox, nord or dracula."
            fi
            ;;
        esac
        if [[ "$LANGUAGE" == "tr" ]]; then
          echo "Renk teması ayarlandı: $THEME"
        else
          echo "Color theme set to: $THEME"
        fi
        save_config
        sleep 2
        ;;
      7)
        # Dil seçimi menüsünü göster
        show_language_selection
        ;;
      0)
        exit_settings=1
        ;;
      *)
        echo "Invalid option."
        sleep 1
        ;;
    esac
  done
  
  show_menu
}

# Dil seçimi menüsü
show_language_selection() {
  clear
  
  local title=""
  if [[ "$LANGUAGE" == "tr" ]]; then
    title="Dil Seçimi"
  else
    title="Language Selection"
  fi
  
  draw_box "$title"
  
  local width=$((TERMINAL_WIDTH - 8))
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[1]${COLORS[RESET]} ${COLORS[MENU_ITEM]}English${COLORS[RESET]} (English)"
  printf "%*s" $((width - 25)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[2]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Türkçe${COLORS[RESET]} (Turkish)"
  printf "%*s" $((width - 25)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[3]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Русский${COLORS[RESET]} (Russian)"
  printf "%*s" $((width - 26)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[4]${COLORS[RESET]} ${COLORS[MENU_ITEM]}中文${COLORS[RESET]} (Chinese)"
  printf "%*s" $((width - 25)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[5]${COLORS[RESET]} ${COLORS[MENU_ITEM]}日本語${COLORS[RESET]} (Japanese)"
  printf "%*s" $((width - 26)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[6]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Português (BR)${COLORS[RESET]}"
  printf "%*s" $((width - 27)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[7]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Español (Spanish)${COLORS[RESET]}"
  printf "%*s" $((width - 28)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[8]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Italiano (Italian)${COLORS[RESET]}"
  printf "%*s" $((width - 29)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[9]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Français (French)${COLORS[RESET]}"
  printf "%*s" $((width - 29)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[A]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Deutsch (German)${COLORS[RESET]}"
  printf "%*s" $((width - 28)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[B]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Hindi (हिन्दी)${COLORS[RESET]}"
  printf "%*s" $((width - 27)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[C]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Polski (Polish)${COLORS[RESET]}"
  printf "%*s" $((width - 28)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[D]${COLORS[RESET]} ${COLORS[MENU_ITEM]}Bengali (বাংলা)${COLORS[RESET]}"
  printf "%*s" $((width - 28)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[MENU_NUMBER]}[0]${COLORS[RESET]} ${COLORS[MENU_ITEM]}$(get_translation "BACK")${COLORS[RESET]}"
  printf "%*s" $((width - 17)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  close_box
  
  echo -e "\n$(get_translation "SELECT_OPTION") [0-9, A-D]: \c"
  read -n 1 lang_choice
  
  case "$lang_choice" in
    1)
      LANGUAGE="en"
      echo -e "\nLanguage set to English."
      save_config
      sleep 2
      ;;
    2)
      LANGUAGE="tr"
      echo -e "\nDil Türkçe olarak ayarlandı."
      save_config
      sleep 2
      ;;
    3)
      LANGUAGE="ru"
      echo -e "\nЯзык установлен на Русский."
      save_config
      sleep 2
      ;;
    4)
      LANGUAGE="zh"
      echo -e "\n语言设置为中文。"
      save_config
      sleep 2
      ;;
    5)
      LANGUAGE="ja"
      echo -e "\n言語が日本語に設定されました。"
      save_config
      sleep 2
      ;;
    6)
      LANGUAGE="ptbr"
      echo -e "\n\nIdioma definido para Português (Brasil)."
      save_config
      sleep 2
      ;;
    7)
      LANGUAGE="es"
      echo -e "\n\nIdioma establecido en Español."
      save_config
      sleep 2
      ;;
    8)
      LANGUAGE="it"
      echo -e "\n\nLingua impostata su Italiano."
      save_config
      sleep 2
      ;;
    9)
      LANGUAGE="fr"
      echo -e "\n\nLangue définie sur Français."
      save_config
      sleep 2
      ;;
    a|A)
      LANGUAGE="de"
      echo -e "\n\nSprache auf Deutsch eingestellt."
      save_config
      sleep 2
      ;;
    b|B)
      LANGUAGE="hi"
      echo -e "\n\nLanguage set to Hindi (भाषा हिन्दी पर सेट की गई।)"
      save_config
      sleep 2
      ;;
    c|C)
      LANGUAGE="pl"
      echo -e "\n\nJęzyk ustawiony na Polski."
      save_config
      sleep 2
      ;;
    d|D)
      LANGUAGE="bn"
      echo -e "\n\nLanguage set to Bengali (ভাষা বাংলা হিসাবে সেট করা হয়েছে।)"
      save_config
      sleep 2
      ;;
    0)
      # Back
      ;;
    *)
      if [[ "$LANGUAGE" == "tr" ]]; then
        echo -e "\nGeçersiz seçenek."
      elif [[ "$LANGUAGE" == "ru" ]]; then
        echo -e "\nНеверный вариант."
      elif [[ "$LANGUAGE" == "zh" ]]; then
        echo -e "\n无效选项。"
      elif [[ "$LANGUAGE" == "ja" ]]; then
        echo -e "\n無効なオプションです。"
      elif [[ "$LANGUAGE" == "ptbr" ]]; then
        echo -e "\nOpção inválida."
      elif [[ "$LANGUAGE" == "es" ]]; then
        echo -e "\nOpción no válida."
      elif [[ "$LANGUAGE" == "it" ]]; then
        echo -e "\nOpzione non valida."
      elif [[ "$LANGUAGE" == "fr" ]]; then
        echo -e "\nOption non valide."
      elif [[ "$LANGUAGE" == "de" ]]; then
        echo -e "\nUngültige Option."
      elif [[ "$LANGUAGE" == "hi" ]]; then
        echo -e "\nवैकल्पिक विकल्प चुनें"
      elif [[ "$LANGUAGE" == "pl" ]]; then
        echo -e "\nNieprawidłowa opcja."
      elif [[ "$LANGUAGE" == "bn" ]]; then
        echo -e "\nঅবৈধ বিকল্প।"
      else
        echo -e "\nInvalid option."
      fi
      sleep 1
      ;;
  esac
  
  show_menu
}

# Hakkında ekranını göster
show_about() {
  clear
  
  draw_box "$(get_translation "ABOUT")"
  
  local width=$((TERMINAL_WIDTH - 8))
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "${COLORS[HEADER]}Android Battery Monitoring System${COLORS[RESET]}"
  printf "%*s" $((width - 39)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "VERSION"): ${VERSION}"
  printf "%*s" $((width - 10 - ${#VERSION})) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "LICENSE"): MIT"
  printf "%*s" $((width - 13)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"

  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  printf "%*s" $((width - 19)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "─────────────────────────────────────────────────────────────"
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "ABOUT_TEXT1")"
  printf "%*s" $((width - 64)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "ABOUT_TEXT2")"
  printf "%*s" $((width - 69)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "ABOUT_TEXT3")"
  printf "%*s" $((width - 53)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "─────────────────────────────────────────────────────────────"
  printf "%*s" $((width - 60)) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "CONFIG_DIR"): $HOME/bbms/"
  printf "%*s" $((width - 35 - ${#HOME})) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  echo -ne "${COLORS[BORDER]}│${COLORS[RESET]} "
  echo -ne "$(get_translation "LOG_DIR"): ${LOG_DIR}"
  printf "%*s" $((width - 16 - ${#LOG_DIR})) ""
  echo -e " ${COLORS[BORDER]}│${COLORS[RESET]}"
  
  close_box
  
  echo -e "\n$(get_translation "PRESS_KEY")..."
  read -n 1 -s
  
  show_menu
}

# Komut satırı argümanlarını işle
parse_args() {
  local i=1
  while [[ $i -le $# ]]; do
    local arg="${!i}"
    case "$arg" in
      --help)
        show_help
        exit 0
        ;;
      --version)
        echo "Android Battery Monitoring System Version $VERSION"
        exit 0
        ;;
      --live)
        # Skip main menu and start live monitoring directly
        START_LIVE=1
        ;;
      --log-dir=*)
        LOG_DIR="${arg#*=}"
        create_log_dir
        ;;
      --log-format=*)
        local format="${arg#*=}"
        case "$format" in
          csv|CSV) LOG_FORMAT="csv" ;;
          json|JSON) LOG_FORMAT="json" ;;
          txt|TXT) LOG_FORMAT="txt" ;;
          *) echo "Invalid format. Use csv, json or txt." >&2 ;;
        esac
        ;;
      --refresh=*)
        local rate="${arg#*=}"
        if [[ "$rate" =~ ^[0-9]+$ ]]; then
          if (( rate < 1 )); then
            echo "Warning: Refresh rate cannot be less than 1 second. Using 1 second." >&2
            REFRESH_RATE=1
          else
            REFRESH_RATE="$rate"
          fi
        else
          echo "Invalid refresh rate: $rate. Must be a number." >&2
        fi
        ;;
      --lang=*)
        local lang="${arg#*=}"
        case "$lang" in
          tr|TR) LANGUAGE="tr" ;;
          en|EN) LANGUAGE="en" ;;
          ru|RU) LANGUAGE="ru" ;;
          zh|ZH) LANGUAGE="zh" ;;
          ja|JA) LANGUAGE="ja" ;;
          ptbr|PTBR) LANGUAGE="ptbr" ;;
          es|ES) LANGUAGE="es" ;;
          it|IT) LANGUAGE="it" ;;
          fr|FR) LANGUAGE="fr" ;;
          de|DE) LANGUAGE="de" ;;
          hi|HI) LANGUAGE="hi" ;;
          pl|PL) LANGUAGE="pl" ;;
          bn|BN) LANGUAGE="bn" ;;
          *) echo "Unsupported language: $lang. Use en, tr, ru, zh, ja, ptbr, es, it, fr, de, hi, pl or bn." >&2 ;;
        esac
        FROM_CMDLINE="1"
        ;;
      --theme=*)
        local theme="${arg#*=}"
        case "$theme" in
          dark|DARK) THEME="dark" ;;
          light|LIGHT) THEME="light" ;;
          gruvbox|GRUVBOX) THEME="gruvbox" ;;
          nord|NORD) THEME="nord" ;;
          dracula|DRACULA) THEME="dracula" ;;
          *) echo "Invalid theme: $theme. Use dark, light, gruvbox, nord or dracula." >&2 ;;
        esac
        ;;
      --view=*)
        local view="${arg#*=}"
        case "$view" in
          minimal|MINIMAL) VIEW_MODE="minimal" ;;
          detailed|DETAILED|detayli|DETAYLI) VIEW_MODE="detailed" ;;
          debug|DEBUG) VIEW_MODE="debug" ;;
          *) echo "Invalid view mode: $view. Use minimal, detailed or debug." >&2 ;;
        esac
        ;;
      *)
        echo "Unknown argument: $arg" >&2
        show_help
        exit 1
        ;;
    esac
    ((i++))
  done
}

# Yardım bilgisini göster
show_help() {
  echo "Android Battery Monitoring System Version $VERSION"
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  --help                 Show this help message"
  echo "  --version              Show version information"
  echo "  --live                 Start live monitoring directly"
  echo "  --log-dir=<directory>  Specify directory to save logs"
  echo "  --log-format=<format>  Specify log format (csv, json, txt)"
  echo "  --refresh=<seconds>    Specify live monitoring refresh rate in seconds"
  echo "  --lang=<code>          Set language (en, tr, ru, zh, ja, ptbr, es, it, fr, de, hi, pl, bn)"
  echo "  --theme=<theme>        Set color theme (dark, light, gruvbox, nord, dracula)"
  echo "  --view=<mode>          Set view mode (minimal, detailed, debug)"
  echo
  echo "Example:"
  echo "  $0 --live --refresh=3 --log-format=csv --log-dir=~/logs"
}

# Hoş geldiniz ekranı ve dil seçimi
show_welcome_screen() {
  clear
  
  # ASCII art logo
  cat << "EOF"
  :: Android Battery Monitoring System ::
  :: Developer: Ömer SÜSİN - AI assisted development ::
EOF
  
  echo -e "\n\n          Developer: Ömer SÜSİN - AI assisted development\n\n"
  
  echo -e "  This script allows you to monitor battery status, health, and thermal information"
  echo -e "  of Android devices in real-time. Track charging patterns, diagnose battery issues"
  echo -e "  and optimize battery performance with detailed analytics.\n\n"
  
  echo -e "                        Welcome - Select Your Language:\n"
  echo -e "                        [1] English (English)"
  echo -e "                        [2] Türkçe (Turkish)"
  echo -e "                        [3] Русский (Russian)"
  echo -e "                        [4] 中文 (Chinese)"
  echo -e "                        [5] 日本語 (Japanese)"
  echo -e "                        [6] Português (BR)"
  echo -e "                        [7] Español (Spanish)"
  echo -e "                        [8] Italiano (Italian)"
  echo -e "                        [9] Français (French)"
  echo -e "                        [A] Deutsch (German)"
  echo -e "                        [B] Hindi (हिन्दी)"
  echo -e "                        [C] Polski (Polish)"
  echo -e "                        [D] Bengali (বাংলা)"
  
  echo -e "\n                        Select language [1-9, A-D]: \c"
  read -n 1 lang_choice
  
  # İlk dil durumunu kaydet
  local previous_language="$LANGUAGE"
  
  case "$lang_choice" in
    1)
      LANGUAGE="en"
      echo -e "\n\nLanguage set to English."
      ;;
    2)
      LANGUAGE="tr"
      echo -e "\n\nDil Türkçe olarak ayarlandı."
      ;;
    3)
      LANGUAGE="ru"
      echo -e "\n\nЯзык установлен на Русский."
      ;;
    4)
      LANGUAGE="zh"
      echo -e "\n\n语言设置为中文。"
      ;;
    5)
      LANGUAGE="ja"
      echo -e "\n\n言語が日本語に設定されました。"
      ;;
    6)
      LANGUAGE="ptbr"
      echo -e "\n\nIdioma definido para Português (Brasil)."
      ;;
    7)
      LANGUAGE="es"
      echo -e "\n\nIdioma establecido en Español."
      ;;
    8)
      LANGUAGE="it"
      echo -e "\n\nLingua impostata su Italiano."
      ;;
    9)
      LANGUAGE="fr"
      echo -e "\n\nLangue définie sur Français."
      ;;
    a|A)
      LANGUAGE="de"
      echo -e "\n\nSprache auf Deutsch eingestellt."
      ;;
    b|B)
      LANGUAGE="hi"
      echo -e "\n\nLanguage set to Hindi (भाषा हिन्दी पर सेट की गई।)"
      ;;
    c|C)
      LANGUAGE="pl"
      echo -e "\n\nJęzyk ustawiony na Polski."
      ;;
    d|D)
      LANGUAGE="bn"
      echo -e "\n\nLanguage set to Bengali (ভাষা বাংলা হিসাবে সেট করা হয়েছে।)"
      ;;
    *)
      echo -e "\n\nInvalid choice. Using English as default."
      LANGUAGE="en"
      ;;
  esac
  
  # Dil değiştiyse temayı güncelle
  if [[ "$previous_language" != "$LANGUAGE" ]]; then
    # Konfigürasyonu kaydet
    save_config
    
    # Mevcut tema ayarlarını güncelle
    set_theme "$THEME"
  fi
  
  sleep 2
}

# Ana script başlangıcı
main() {
  # Terminalin SIGWINCH sinyalini doğru algılaması için
  trap 'update_terminal_size; show_menu' WINCH
  
  # Terminal boyutlarını al
  update_terminal_size
  
  # START_LIVE değişkenini ilklendir
  START_LIVE=0
  
  # FROM_CMDLINE değişkenini ilklendir
  FROM_CMDLINE=""
  
  # Konfigürasyon dosyasını yükle
  load_config
  
  # Renk şemasını ayarla
  set_theme "$THEME"
  
  # Başlık bilgilerini güncelle
  AUTHOR="Ömer SÜSİN"
  
  # Komut satırı argümanlarını işle
  parse_args "$@"
  
  # Cihaz ve pil bilgilerini al
  get_device_info
  get_battery_model
  
  # İmleci gizle
  tput civis
  
  # Konfigürasyon dizinini oluştur
  mkdir -p "$HOME/bbms" 2>/dev/null
  
  # Log dizinini oluştur
  create_log_dir
  
  # Doğrudan komut satırından --lang belirtilmediyse ve ilk çalıştırmaysa, dil seçim ekranını göster
  if [[ -z "$FROM_CMDLINE" ]]; then
    show_welcome_screen
    # Dil değiştirilmiş olabilir, temayı tekrar ayarla
    set_theme "$THEME"
  fi
  
  # Doğrudan canlı izleme başlatılsın mı?
  if [[ -n "$START_LIVE" && "$START_LIVE" -eq 1 ]]; then
    LOGGING_ENABLED=1
    start_live_monitoring
  else
    # Ana menüyü göster
    show_menu
  fi
}

# Şarj hızı analizi
get_charging_speed() {
  local current="$1"
  local status="$2"
  local result=""
  local color="${COLORS[INFO]}"

  # Sadece şarj durumunda ise
  if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
    # Mutlak değeri al (şarj akımı negatif olabilir)
    local abs_current=$(echo "$current < 0" | bc -l)
    if (( abs_current == 1 )); then
      current=$(echo "scale=3; -1*$current" | bc)
    fi
    
    # Şarj hızı sınıflandırması
    if (( $(echo "$current >= 2.0" | bc -l) )); then
      result="Fast Charging"
      color="${COLORS[WARNING]}"
    elif (( $(echo "$current >= 1.0" | bc -l) )); then
      result="Normal Charging"
      color="${COLORS[SUCCESS]}"
    else
      result="Slow Charging"
      color="${COLORS[INFO]}"
    fi
  elif [[ "$status" == "Discharging" ]]; then
    local abs_current=$(echo "$current < 0" | bc -l)
    if (( abs_current == 0 )); then
      current=$(echo "scale=3; -1*$current" | bc)
    fi
    
    # Deşarj hızı sınıflandırması
    if (( $(echo "$current >= 2.0" | bc -l) )); then
      result="High Power Usage"
      color="${COLORS[DANGER]}"
    elif (( $(echo "$current >= 1.0" | bc -l) )); then
      result="Medium Power Usage"
      color="${COLORS[WARNING]}"
    else
      result="Low Power Usage"
      color="${COLORS[SUCCESS]}"
    fi
  else
    result="Not Charging"
    color="${COLORS[NORMAL]}"
  fi
  
  # Sonuç ve renk döndür
  echo "${color}${result}${COLORS[RESET]}"
}

# Kalan şarj/deşarj süresi tahmini
estimate_remaining_time() {
  local capacity="$1"       # Mevcut şarj yüzdesi
  local charge_full="$2"    # Tam kapasite (mAh)
  local current="$3"        # Akım (A)
  local status="$4"         # Şarj durumu
  
  local estimated_time=""
  local color="${COLORS[INFO]}"
  
  # Akım çok düşük veya sıfırsa (0.1A altında) tahmin yapmayı atla
  if (( $(echo "($current < 0.1) && ($current > -0.1)" | bc -l) )); then
    estimated_time="Unknown"
    return
  fi
  
  # Mutlak değer
  local abs_current=$(echo "$current < 0" | bc -l)
  if (( abs_current == 1 )); then
    current=$(echo "scale=3; -1*$current" | bc)
  fi
  
  # Akımı mA'e çevir
  current=$(echo "scale=1; $current * 1000" | bc)
  
  if [[ "$status" == "Charging" ]]; then
    # Şarj olurken: Kalan şarj miktarını hesapla
    local remaining_percent=$(echo "scale=2; 100 - $capacity" | bc)
    local remaining_mah=$(echo "scale=0; ($remaining_percent * $charge_full) / 100" | bc)
    
    # Kalan şarj zamanı (saat)
    local time_h=$(echo "scale=1; $remaining_mah / $current" | bc)
    
    # Saat ve dakika hesabı
    local hours=$(echo "$time_h" | awk '{printf("%d", $1)}')
    local minutes=$(echo "scale=0; ($time_h - $hours) * 60" | bc)
    
    if (( hours > 0 )); then
      estimated_time="${hours}h ${minutes}m to full"
    else
      estimated_time="${minutes}m to full"
    fi
    
    color="${COLORS[SUCCESS]}"
  
  elif [[ "$status" == "Discharging" ]]; then
    # Deşarj olurken: Kalan şarj miktarını hesapla
    local remaining_mah=$(echo "scale=0; ($capacity * $charge_full) / 100" | bc)
    
    # Kalan deşarj zamanı (saat)
    local time_h=$(echo "scale=1; $remaining_mah / $current" | bc)
    
    # Saat ve dakika hesabı
    local hours=$(echo "$time_h" | awk '{printf("%d", $1)}')
    local minutes=$(echo "scale=0; ($time_h - $hours) * 60" | bc)
    
    if (( hours > 0 )); then
      estimated_time="${hours}h ${minutes}m remaining"
    else
      estimated_time="${minutes}m remaining"
    fi
    
    # Kalan süreye göre renklendirme
    if (( hours < 1 )); then
      color="${COLORS[DANGER]}"
    elif (( hours < 3 )); then
      color="${COLORS[WARNING]}"
    else
      color="${COLORS[SUCCESS]}"
    fi
  else
    estimated_time="N/A"
  fi
  
  # Sonuç ve renk döndür
  echo "${color}${estimated_time}${COLORS[RESET]}"
}

# Konfigürasyon dosyasını oku
load_config() {
  local config_file="$HOME/bbms/config"
  
  # Konfigürasyon dizini yoksa oluştur
  mkdir -p "$HOME/bbms" 2>/dev/null
  
  # Dosya yoksa varsayılan değerleri kullan
  if [[ ! -f "$config_file" ]]; then
    return
  fi
  
  # Konfigürasyon dosyasını oku
  if [[ -f "$config_file" ]]; then
    while IFS='=' read -r key value; do
      # Boş satırları ve yorum satırlarını atla
      [[ -z "$key" || "$key" =~ ^# ]] && continue
      
      # Değişkenleri ayarla
      case "$key" in
        REFRESH_RATE) REFRESH_RATE="$value" ;;
        LOG_DIR) LOG_DIR="$value" ;;
        LOG_FORMAT) LOG_FORMAT="$value" ;;
        LANGUAGE) LANGUAGE="$value" ;;
        THEME) THEME="$value" ;;
        VIEW_MODE) VIEW_MODE="$value" ;;
        LOGGING_ENABLED) LOGGING_ENABLED="$value" ;;
        *) # Bilinmeyen anahtar
           ;;
      esac
    done < "$config_file"
  fi
}

# Konfigürasyon dosyasını kaydet
save_config() {
  local config_file="$HOME/bbms/config"
  
  # Konfigürasyon dizini yoksa oluştur
  mkdir -p "$HOME/bbms" 2>/dev/null
  
  # Konfigürasyon dosyasını oluştur/güncelle
  {
    echo "# Android Battery Monitoring System Configuration"
    echo "# This file is automatically generated and updated by the script"
    echo "# Last update: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "REFRESH_RATE=$REFRESH_RATE"
    echo "LOG_DIR=$LOG_DIR"
    echo "LOG_FORMAT=$LOG_FORMAT"
    echo "LANGUAGE=$LANGUAGE"
    echo "THEME=$THEME"
    echo "VIEW_MODE=$VIEW_MODE"
    echo "LOGGING_ENABLED=$LOGGING_ENABLED"
  } > "$config_file"
  
  # Dosya yazma izinlerini kontrol et
  if [[ ! -w "$config_file" ]]; then
    echo "Warning: Could not write configuration file: $config_file" >&2
    return 1
  fi
  
  return 0
}

# Cihaz bilgilerini topla
get_device_info() {
  # Test amaçlı sabit değerler
  DEVICE_MODEL="Nitro AN515-45"
  DEVICE_CODENAME="Acer Gaming Laptop"
  
  # Aşağıdaki kısım gerçek Android cihazlar için çalışacak
  # Varsayılan değerler (bilgi bulunamazsa)
  if [[ "$DEVICE_MODEL" == "Unknown" ]]; then
    # Cihaz kod adı ve modeli için olası dosya konumları
    local model_files=(
      "/sys/devices/virtual/dmi/id/product_name"
      "/proc/device-tree/model"
      "/system/build.prop"
    )
    
    # Cihaz modelini bul
    for file in "${model_files[@]}"; do
      if [[ -f "$file" ]]; then
        # build.prop dosyası ise, içinden model bilgisini çıkar
        if [[ "$file" == *"build.prop"* ]]; then
          local model_line=$(grep -E "ro\.product\.model|ro\.product\.name" "$file" 2>/dev/null | head -1)
          if [[ -n "$model_line" ]]; then
            DEVICE_MODEL="${model_line#*=}"
            break
          fi
        else
          # Diğer dosyalar doğrudan okunabilir
          DEVICE_MODEL=$(cat "$file" 2>/dev/null)
          if [[ -n "$DEVICE_MODEL" ]]; then
            break
          fi
        fi
      fi
    done
    
    # Cihaz kod adını bul
    # Genellikle /proc/cpuinfo veya build.prop içinde olabilir
    if [[ -f "/proc/cpuinfo" ]]; then
      DEVICE_CODENAME=$(grep -E "Hardware|Revision" /proc/cpuinfo 2>/dev/null | head -1 | awk -F':' '{print $2}' | xargs)
    fi
    
    # Kod adı bulunamadıysa, build.prop'tan almayı dene
    if [[ "$DEVICE_CODENAME" == "Unknown" && -f "/system/build.prop" ]]; then
      local codename_line=$(grep -E "ro\.product\.device|ro\.build\.product" "/system/build.prop" 2>/dev/null | head -1)
      if [[ -n "$codename_line" ]]; then
        DEVICE_CODENAME="${codename_line#*=}"
      fi
    fi
    
    # Verileri temizle
    DEVICE_MODEL=$(echo "$DEVICE_MODEL" | xargs)
    DEVICE_CODENAME=$(echo "$DEVICE_CODENAME" | xargs)
    
    # Boş değerleri "Unknown" olarak ayarla
    [[ -z "$DEVICE_MODEL" ]] && DEVICE_MODEL="Unknown"
    [[ -z "$DEVICE_CODENAME" ]] && DEVICE_CODENAME="Unknown"
  fi
}

# Pil kod adını almak için fonksiyonu ekliyorum
get_battery_model() {
  # Test amaçlı sabit değer
  BATTERY_MODEL="Test Battery LiPo 4800mAh"
  
  # Aşağıdaki kısım gerçek Android cihazlar için çalışacak
  if [[ "$BATTERY_MODEL" == "Unknown" ]]; then
    # Pil modeli için olası dosya konumları
    local battery_model_files=(
      "/sys/class/power_supply/battery/model_name"
      "/sys/class/power_supply/battery/model"
      "/sys/class/power_supply/bms/battery_type"
    )
    
    # Pil modelini bul
    for file in "${battery_model_files[@]}"; do
      if [[ -f "$file" ]]; then
        BATTERY_MODEL=$(cat "$file" 2>/dev/null)
        if [[ -n "$BATTERY_MODEL" ]]; then
          break
        fi
      fi
    done
    
    # Veriyi temizle
    BATTERY_MODEL=$(echo "$BATTERY_MODEL" | xargs)
    
    # Boş değeri "Unknown" olarak ayarla
    [[ -z "$BATTERY_MODEL" ]] && BATTERY_MODEL="Unknown"
  fi
}

# Scripti başlat
main "$@"

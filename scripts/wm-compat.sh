#!/bin/bash
# GitHub.com/PiercingXX

set -e

sudo install -d /usr/local/bin

if ! command -v cliphist >/dev/null 2>&1 && command -v go >/dev/null 2>&1; then
    export GOPATH="${GOPATH:-$HOME/go}"
    export PATH="$GOPATH/bin:$PATH"
    go install go.senan.xyz/cliphist@latest || true
    if [ -x "$GOPATH/bin/cliphist" ]; then
        sudo install -m 0755 "$GOPATH/bin/cliphist" /usr/local/bin/cliphist
    fi
fi

if [ ! -x /usr/local/bin/cliphist ]; then
    sudo tee /usr/local/bin/cliphist >/dev/null <<'EOF'
#!/bin/sh
cmd="${1:-}"
shift || true
case "$cmd" in
    store)
        cat >/dev/null
        ;;
    list)
        exit 0
        ;;
    decode)
        cat
        ;;
    *)
        echo "cliphist compatibility shim: unsupported command '$cmd'" >&2
        exit 1
        ;;
esac
EOF
    sudo chmod 755 /usr/local/bin/cliphist
fi

sudo tee /usr/local/bin/fuzzel >/dev/null <<'EOF'
#!/bin/sh
if [ -n "$WAYLAND_DISPLAY" ] && [ -x /usr/bin/fuzzel ]; then
    exec /usr/bin/fuzzel "$@"
fi

dmenu_mode=0
for arg in "$@"; do
    [ "$arg" = "--dmenu" ] && dmenu_mode=1
done

if command -v rofi >/dev/null 2>&1; then
    if [ "$dmenu_mode" -eq 1 ]; then
        exec rofi -dmenu
    fi
    exec rofi -show drun
fi

echo "fuzzel wrapper requires fuzzel on Wayland or rofi on X11" >&2
exit 1
EOF
sudo chmod 755 /usr/local/bin/fuzzel

sudo tee /usr/local/bin/fuzzel-emoji >/dev/null <<'EOF'
#!/bin/sh
exec fuzzel --dmenu
EOF
sudo chmod 755 /usr/local/bin/fuzzel-emoji

sudo tee /usr/local/bin/nwg-drawer >/dev/null <<'EOF'
#!/bin/sh
exec fuzzel "$@"
EOF
sudo chmod 755 /usr/local/bin/nwg-drawer

sudo tee /usr/local/bin/wl-copy >/dev/null <<'EOF'
#!/bin/sh
if [ -n "$WAYLAND_DISPLAY" ] && [ -x /usr/bin/wl-copy ]; then
    exec /usr/bin/wl-copy "$@"
fi

if command -v xclip >/dev/null 2>&1; then
    exec xclip -selection clipboard -in
fi

echo "wl-copy wrapper requires wl-copy on Wayland or xclip on X11" >&2
exit 1
EOF
sudo chmod 755 /usr/local/bin/wl-copy

sudo tee /usr/local/bin/wl-paste >/dev/null <<'EOF'
#!/bin/sh
if [ -n "$WAYLAND_DISPLAY" ] && [ -x /usr/bin/wl-paste ]; then
    exec /usr/bin/wl-paste "$@"
fi

watch_mode=0
mime_type=""

while [ $# -gt 0 ]; do
    case "$1" in
        --watch)
            watch_mode=1
            shift
            break
            ;;
        --type)
            mime_type="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

if [ "$watch_mode" -eq 1 ]; then
    if [ "$mime_type" = "image" ]; then
        exit 0
    fi

    last_value=""
    while true; do
        current_value="$(xclip -selection clipboard -o 2>/dev/null || true)"
        if [ -n "$current_value" ] && [ "$current_value" != "$last_value" ]; then
            printf '%s' "$current_value" | "$@"
            last_value="$current_value"
        fi
        sleep 1
    done
fi

exec xclip -selection clipboard -o
EOF
sudo chmod 755 /usr/local/bin/wl-paste

sudo tee /usr/local/bin/hyprlock >/dev/null <<'EOF'
#!/bin/sh
if [ -n "$WAYLAND_DISPLAY" ] && [ -x /usr/bin/hyprlock ]; then
    exec /usr/bin/hyprlock "$@"
fi

if [ -n "$WAYLAND_DISPLAY" ] && command -v swaylock >/dev/null 2>&1; then
    exec swaylock "$@"
fi

if command -v i3lock >/dev/null 2>&1; then
    exec i3lock -c 000000
fi

echo "No compatible lock command found" >&2
exit 1
EOF
sudo chmod 755 /usr/local/bin/hyprlock

sudo tee /usr/local/bin/betterlockscreen >/dev/null <<'EOF'
#!/bin/sh
exec hyprlock "$@"
EOF
sudo chmod 755 /usr/local/bin/betterlockscreen

sudo tee /usr/local/bin/hyprshot >/dev/null <<'EOF'
#!/bin/sh
mode="region"

while [ $# -gt 0 ]; do
    case "$1" in
        -m|--mode)
            mode="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ -n "$WAYLAND_DISPLAY" ] && [ -x /usr/bin/hyprshot ]; then
    exec /usr/bin/hyprshot -m "$mode"
fi

if [ -n "$WAYLAND_DISPLAY" ] && command -v grim >/dev/null 2>&1; then
    screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
    mkdir -p "$screenshot_dir"
    screenshot_file="$screenshot_dir/$(date +%F-%H%M%S).png"

    case "$mode" in
        window)
            if command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
                geometry="$(swaymsg -t get_tree | jq -r 'recurse(.nodes[]?, .floating_nodes[]?) | select(.focused) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' | head -n 1)"
            fi
            ;;
        region)
            geometry="$(slurp)"
            ;;
        *)
            geometry=""
            ;;
    esac

    if [ -n "$geometry" ]; then
        grim -g "$geometry" "$screenshot_file"
    else
        grim "$screenshot_file"
    fi

    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$screenshot_file" || true
    fi
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Screenshot saved" "$screenshot_file" || true
    fi
    printf '%s\n' "$screenshot_file"
    exit 0
fi

if command -v flameshot >/dev/null 2>&1; then
    exec flameshot gui --clipboard
fi

echo "No compatible screenshot command found" >&2
exit 1
EOF
sudo chmod 755 /usr/local/bin/hyprshot

echo "Window manager compatibility wrappers installed."
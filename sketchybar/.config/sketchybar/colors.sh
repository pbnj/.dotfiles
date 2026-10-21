# shellcheck shell=sh
# shellcheck disable=SC2034
# Shared POSIX-shell palette. Source this in the config and every colored plugin.
# macOS omits AppleInterfaceStyle in light mode. No timer/daemon is needed.
# Darker Day accents keep the base palette legible; popup menus stay opaque.
case "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" in
  Dark)
    THEME=moon
    BG=0xff222436
    FG=0xffc8d3f5
    ITEM_BG=0xa61e2030
    SELECTED_BG=0xff394b70
    APPS_BG=0xff222436
    FOCUSED_BG=0xff2f334d
    ACCENT=0xff82aaff
    DIM=0xffa9b1d6
    GREEN=0xffc3e88d
    ORANGE=0xffff966c
    YELLOW=0xffffc777
    RED=0xffff757f
    ;;
  *)
    THEME=day
    BG=0xffe1e2e7
    FG=0xff344c8c
    ITEM_BG=0xa6d0d5e3
    SELECTED_BG=0xffb7c1e3
    APPS_BG=0xffd0d5e3
    FOCUSED_BG=0xffc4c8da
    ACCENT=0xff244c99
    DIM=0xff3d4f7a
    GREEN=0xff315c2b
    ORANGE=0xff8a3d17
    YELLOW=0xff6b4b16
    RED=0xff982346
    ;;
esac

# Bar: 50% transparent; pills above use alpha 0xa6 (35% transparent).
BAR_BG="0x80${BG#0xff}"

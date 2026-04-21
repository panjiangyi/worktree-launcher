wt() {
  local script_dir script output target_path launch_tool
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  script="$script_dir/wt-core.sh"

  if [[ ! -x "$script" ]]; then
    printf 'wt core script not executable: %s\n' "$script" >&2
    return 1
  fi

  if ! output="$("$script" "$@")"; then
    return $?
  fi

  eval "$output"

  if [[ -n "${TARGET_PATH:-}" ]]; then
    cd "$TARGET_PATH" || return 1
  fi

  launch_tool="${LAUNCH_TOOL:-none}"
  case "$launch_tool" in
    codex|claude)
      if command -v "$launch_tool" >/dev/null 2>&1; then
        "$launch_tool"
      else
        printf '%s 命令不存在于 PATH 中，已停留在目标目录：%s\n' "$launch_tool" "$PWD" >&2
      fi
      ;;
    none|"")
      ;;
    *)
      printf '未知启动工具：%s\n' "$launch_tool" >&2
      return 1
      ;;
  esac
}

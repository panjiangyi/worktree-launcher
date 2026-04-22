#!/usr/bin/env bash

set -euo pipefail

PROGRAM_NAME="${0##*/}"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

warn() {
  printf '%s\n' "$*" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_git_repo() {
  local repo_root
  if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    die "当前目录不在 Git 仓库中"
  fi
  printf '%s\n' "$repo_root"
}

slugify() {
  local input slug
  input="${1#"${1%%[![:space:]]*}"}"
  input="${input%"${input##*[![:space:]]}"}"
  slug="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
  slug="$(printf '%s' "$slug" | tr ' _' '--')"
  slug="$(printf '%s' "$slug" | sed -E 's/[^a-z0-9-]+//g; s/-+/-/g; s/^-+//; s/-+$//')"
  printf '%s\n' "$slug"
}

prompt_line() {
  local prompt="${1:-}"
  local value
  printf '%s' "$prompt" >&2
  IFS= read -r value || return 1
  printf '%s\n' "$value"
}

render_menu() {
  local menu_fd="$1"
  local title="$2"
  local selected="$3"
  shift 3
  local options=("$@")

  printf '\033[u\033[J' >&"$menu_fd"
  printf '%s\n' "$title" >&"$menu_fd"

  local i
  for i in "${!options[@]}"; do
    if (( i + 1 == selected )); then
      printf '\033[7m> %s\033[0m\n' "${options[$i]}" >&"$menu_fd"
    else
      printf '  %s\n' "${options[$i]}" >&"$menu_fd"
    fi
  done

  printf '\n↑/↓ 选择，Enter 确认，鼠标滚轮/点击可选\n' >&"$menu_fd"
}

menu_move_up() {
  local selected="$1"
  local count="$2"
  if (( selected <= 1 )); then
    printf '%s\n' "$count"
  else
    printf '%s\n' "$((selected - 1))"
  fi
}

menu_move_down() {
  local selected="$1"
  local count="$2"
  if (( selected >= count )); then
    printf '1\n'
  else
    printf '%s\n' "$((selected + 1))"
  fi
}

prompt_menu() {
  local title="$1"
  local default_index="$2"
  shift 2
  local options=("$@")
  local count="${#options[@]}"
  local selected="$default_index"

  if (( count == 0 )); then
    return 1
  fi

  if (( selected < 1 || selected > count )); then
    selected=1
  fi

  if [[ ! -t 2 ]] || [[ ! -r /dev/tty ]] || [[ ! -w /dev/tty ]]; then
    die "当前环境不支持交互式菜单（需要可用 TTY）"
  fi

  local menu_fd
  exec {menu_fd}<>/dev/tty

  local cursor_response=""
  local menu_row=1
  local has_cursor_position=0
  printf '\033[6n' >&"$menu_fd"
  if IFS= read -rsdR -t 0.1 -u "$menu_fd" cursor_response; then
    cursor_response="${cursor_response#*[}"
    menu_row="${cursor_response%%;*}"
    if [[ ! "$menu_row" =~ ^[0-9]+$ ]]; then
      menu_row=1
    else
      has_cursor_position=1
    fi
  fi

  printf '\033[s\033[?25l\033[?1000h\033[?1006h' >&"$menu_fd"

  local key next next2 mouse_data mouse_suffix mouse_button mouse_x mouse_y option_row
  while true; do
    render_menu "$menu_fd" "$title" "$selected" "${options[@]}"
    IFS= read -rsn1 -u "$menu_fd" key || break

    case "$key" in
      "")
        printf '\033[u\033[J\033[?1000l\033[?1006l\033[?25h' >&"$menu_fd"
        exec {menu_fd}>&-
        exec {menu_fd}<&-
        printf '%s\n' "$selected"
        return 0
        ;;
      $'\n'|$'\r')
        printf '\033[u\033[J\033[?1000l\033[?1006l\033[?25h' >&"$menu_fd"
        exec {menu_fd}>&-
        exec {menu_fd}<&-
        printf '%s\n' "$selected"
        return 0
        ;;
      k)
        selected="$(menu_move_up "$selected" "$count")"
        ;;
      j)
        selected="$(menu_move_down "$selected" "$count")"
        ;;
      $'\x1b')
        next=""
        next2=""
        IFS= read -rsn1 -t 0.05 -u "$menu_fd" next || true
        if [[ "$next" != "[" ]]; then
          continue
        fi

        IFS= read -rsn1 -t 0.05 -u "$menu_fd" next2 || true
        case "$next2" in
          A)
            selected="$(menu_move_up "$selected" "$count")"
            ;;
          B)
            selected="$(menu_move_down "$selected" "$count")"
            ;;
          '<')
            mouse_data=""
            while IFS= read -rsn1 -t 0.05 -u "$menu_fd" next; do
              mouse_data+="$next"
              if [[ "$next" == "M" || "$next" == "m" ]]; then
                break
              fi
            done

            mouse_suffix="${mouse_data: -1}"
            mouse_data="${mouse_data%?}"
            IFS=';' read -r mouse_button mouse_x mouse_y <<< "$mouse_data"

            case "$mouse_button" in
              64)
                selected="$(menu_move_up "$selected" "$count")"
                ;;
              65)
                selected="$(menu_move_down "$selected" "$count")"
                ;;
              0)
                (( has_cursor_position == 1 )) || continue
                option_row="$((mouse_y - menu_row))"
                if (( option_row >= 1 && option_row <= count )); then
                  selected="$option_row"
                  if [[ "$mouse_suffix" == "M" ]]; then
                    printf '\033[u\033[J\033[?1000l\033[?1006l\033[?25h' >&"$menu_fd"
                    exec {menu_fd}>&-
                    exec {menu_fd}<&-
                    printf '%s\n' "$selected"
                    return 0
                  fi
                fi
                ;;
            esac
            ;;
        esac
        ;;
    esac
  done

  printf '\033[u\033[J\033[?1000l\033[?1006l\033[?25h' >&"$menu_fd"
  exec {menu_fd}>&-
  exec {menu_fd}<&-
  return 1
}

repo_root=""
repo_name=""
username=""
worktree_repo_dir=""
config_path=""
main_branch=""
repo_context_loaded=0

ensure_repo_context() {
  if (( repo_context_loaded == 1 )); then
    return 0
  fi

  repo_root="$(require_git_repo)"
  repo_name="$(basename "$repo_root")"

  local git_username
  git_username="$(git config user.name 2>/dev/null || true)"
  if [[ -z "$git_username" ]]; then
    die "未设置 git user.name，请先运行: git config --global user.name 'Your Name'"
  fi

  username="$(slugify "$git_username")"
  worktree_repo_dir="$HOME/.worktrees/$repo_name"
  config_path="$worktree_repo_dir/config.json"
  repo_context_loaded=1
}

ensure_worktree_repo_dir() {
  ensure_repo_context
  mkdir -p "$worktree_repo_dir"
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s\n' "$value"
}

load_project_config() {
  main_branch=""
  [[ -f "$config_path" ]] || return 0

  local raw_branch
  raw_branch="$(sed -nE 's/.*"mainBranch"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$config_path" | head -n 1)"
  if [[ -n "$raw_branch" ]]; then
    main_branch="${raw_branch//\\\"/\"}"
    main_branch="${main_branch//\\\\/\\}"
  fi
}

save_project_config() {
  ensure_worktree_repo_dir

  local escaped_branch
  escaped_branch="$(json_escape "$main_branch")"

  cat > "$config_path" <<EOF
{
  "mainBranch": "$escaped_branch"
}
EOF
}

build_main_branch_candidates() {
  local current_branch
  current_branch="$(git branch --show-current 2>/dev/null || true)"
  local raw_candidates=()

  if [[ -n "$current_branch" ]]; then
    raw_candidates+=("$current_branch")
  fi
  raw_candidates+=("main" "master" "dev")

  local candidate
  local seen='|'
  MAIN_BRANCH_LABELS=()
  MAIN_BRANCH_POINTS=()

  for candidate in "${raw_candidates[@]}"; do
    [[ -z "$candidate" ]] && continue
    [[ "$seen" == *"|$candidate|"* ]] && continue
    seen+="$candidate|"
    if git show-ref --verify --quiet "refs/heads/$candidate"; then
      MAIN_BRANCH_LABELS+=("$candidate")
      MAIN_BRANCH_POINTS+=("$candidate")
    elif git show-ref --verify --quiet "refs/remotes/origin/$candidate"; then
      MAIN_BRANCH_LABELS+=("origin/$candidate")
      MAIN_BRANCH_POINTS+=("origin/$candidate")
    fi
  done

  MAIN_BRANCH_LABELS+=("手动输入其他分支")
  MAIN_BRANCH_POINTS+=("__manual__")
}

choose_configured_main_branch() {
  build_main_branch_candidates

  local default_index=1
  local i=0
  for label in "${MAIN_BRANCH_LABELS[@]}"; do
    i=$((i + 1))
    if [[ "$label" == "main" || "$label" == "origin/main" ]]; then
      default_index="$i"
      break
    fi
  done

  while true; do
    local choice
    choice="$(prompt_menu "首次运行：请选择这个仓库的主分支:" "$default_index" "${MAIN_BRANCH_LABELS[@]}")" || return 1

    local selected="${MAIN_BRANCH_POINTS[choice-1]}"
    if [[ "$selected" == "__manual__" ]]; then
      local manual_branch
      manual_branch="$(prompt_line '请输入主分支名: ')" || return 1
      if [[ -z "$manual_branch" ]]; then
        warn "主分支不能为空"
        continue
      fi
      if git rev-parse --verify --quiet "$manual_branch^{commit}" >/dev/null; then
        printf '%s\n' "$manual_branch"
        return 0
      fi
      if git rev-parse --verify --quiet "origin/$manual_branch^{commit}" >/dev/null; then
        printf 'origin/%s\n' "$manual_branch"
        return 0
      fi
      warn "主分支不存在，请重新选择"
      continue
    fi

    printf '%s\n' "$selected"
    return 0
  done
}

ensure_project_config() {
  ensure_worktree_repo_dir
  load_project_config

  if [[ -n "$main_branch" ]]; then
    return 0
  fi

  main_branch="$(choose_configured_main_branch)" || return 1
  save_project_config
  warn "已保存项目配置: $config_path"
  warn "主分支: $main_branch"
}

run_setup_script() {
  local worktree_path="$1"
  local setup_script="$worktree_repo_dir/setup.sh"

  if [[ ! -f "$setup_script" ]]; then
    warn "提示: 未找到 setup 脚本 ($setup_script)，跳过"
    return 0
  fi

  warn "正在运行 setup 脚本..."
  local setup_rc=0
  (cd "$worktree_path" && bash "$setup_script") || setup_rc=$?

  if [[ $setup_rc -ne 0 ]]; then
    warn "setup 脚本执行失败 (退出码: $setup_rc)，但 worktree 已保留"
  else
    warn "setup 脚本执行成功"
  fi
  return 0
}

edit_setup_script() {
  ensure_worktree_repo_dir

  local setup_script="$worktree_repo_dir/setup.sh"

  if [[ ! -f "$setup_script" ]]; then
    cat > "$setup_script" << 'SETUP_TEMPLATE'
#!/usr/bin/env bash
set -euo pipefail

# Setup script for worktree initialization
# This script runs automatically after creating a new worktree.
# Working directory: the newly created worktree
#
# Examples:
#   npm install
#   cp .env.example .env
#   docker compose up -d
SETUP_TEMPLATE
    warn "已创建 setup 脚本模板: $setup_script"
  fi

  local editor
  if [[ -n "${EDITOR:-}" ]]; then
    editor="$EDITOR"
  elif command_exists vim; then
    editor=vim
  elif command_exists vi; then
    editor=vi
  elif command_exists nano; then
    editor=nano
  else
    die "未找到可用的编辑器 (已检查 \$EDITOR, vim, vi, nano)"
  fi

  "$editor" "$setup_script" < /dev/tty > /dev/tty
}

git_branch_exists_local() {
  git show-ref --verify --quiet "refs/heads/$1"
}

branch_in_use_by_worktree() {
  local branch="$1"
  local current_branch=""
  while IFS= read -r line; do
    case "$line" in
      branch\ refs/heads/*)
        current_branch="${line#branch refs/heads/}"
        if [[ "$current_branch" == "$branch" ]]; then
          return 0
        fi
        ;;
      "")
        current_branch=""
        ;;
    esac
  done < <(git worktree list --porcelain)
  return 1
}

build_base_candidates() {
  local current_branch
  current_branch="$(git branch --show-current 2>/dev/null || true)"
  local raw_candidates=("$main_branch" "main" "master" "dev")
  if [[ -n "$current_branch" ]]; then
    raw_candidates+=("$current_branch")
  fi

  local candidate
  local seen='|'
  BASE_LABELS=()
  BASE_POINTS=()

  for candidate in "${raw_candidates[@]}"; do
    [[ -z "$candidate" ]] && continue
    [[ "$seen" == *"|$candidate|"* ]] && continue
    seen+="$candidate|"

    if [[ "$candidate" == origin/* ]]; then
      if git show-ref --verify --quiet "refs/remotes/$candidate"; then
        BASE_LABELS+=("$candidate")
        BASE_POINTS+=("$candidate")
      fi
      continue
    fi

    if git show-ref --verify --quiet "refs/heads/$candidate"; then
      BASE_LABELS+=("$candidate")
      BASE_POINTS+=("$candidate")
    elif git show-ref --verify --quiet "refs/remotes/origin/$candidate"; then
      BASE_LABELS+=("origin/$candidate")
      BASE_POINTS+=("origin/$candidate")
    fi
  done

  BASE_LABELS+=("手动输入其他分支")
  BASE_POINTS+=("__manual__")
}

choose_base_branch() {
  build_base_candidates

  while true; do
    local default_index=1
    local i=0
    for label in "${BASE_LABELS[@]}"; do
      i=$((i + 1))
      if [[ "$label" == "$main_branch" ]]; then
        default_index="$i"
        break
      fi
    done

    local choice
    choice="$(prompt_menu "请选择基于哪个分支创建（默认主分支，直接回车确认）:" "$default_index" "${BASE_LABELS[@]}")" || return 1

    local selected="${BASE_POINTS[choice-1]}"
    if [[ "$selected" == "__manual__" ]]; then
      local manual_branch
      manual_branch="$(prompt_line '请输入基线分支名: ')" || return 1
      if [[ -z "$manual_branch" ]]; then
        warn "基线分支不能为空"
        continue
      fi
      if git rev-parse --verify --quiet "$manual_branch^{commit}" >/dev/null; then
        printf '%s\n' "$manual_branch"
        return 0
      fi
      if git rev-parse --verify --quiet "origin/$manual_branch^{commit}" >/dev/null; then
        printf 'origin/%s\n' "$manual_branch"
        return 0
      fi
      warn "基线分支不存在，请重新选择"
      continue
    fi

    printf '%s\n' "$selected"
    return 0
  done
}

choose_launch_tool() {
  local choice
  choice="$(prompt_menu "请选择启动工具:" 1 "codex" "claude" "none")" || return 1
  case "$choice" in
    1) printf 'codex\n' ;;
    2) printf 'claude\n' ;;
    3) printf 'none\n' ;;
  esac
}

print_result() {
  printf 'TARGET_PATH=%q\n' "$1"
  printf 'LAUNCH_TOOL=%q\n' "$2"
}

collect_worktrees() {
  WT_PATHS=()
  WT_BRANCHES=()
  WT_IS_BARE=()
  local current_path=""
  local current_branch="[detached HEAD]"
  local is_bare="0"

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      worktree\ *)
        current_path="${line#worktree }"
        current_branch="[detached HEAD]"
        is_bare="0"
        ;;
      branch\ refs/heads/*)
        current_branch="${line#branch refs/heads/}"
        ;;
      bare)
        is_bare="1"
        ;;
      "")
        if [[ -n "$current_path" ]]; then
          WT_PATHS+=("$current_path")
          WT_BRANCHES+=("$current_branch")
          WT_IS_BARE+=("$is_bare")
        fi
        current_path=""
        current_branch="[detached HEAD]"
        is_bare="0"
        ;;
    esac
  done < <(git worktree list --porcelain && printf '\n')
}

create_new_task() {
  ensure_worktree_repo_dir

  while true; do
    local task_name slug branch_name dir_name worktree_path
    task_name="$(prompt_line '请输入任务名称（建议英文，会自动转换为安全 slug）: ')" || return 1
    slug="$(slugify "$task_name")"
    if [[ -z "$slug" ]]; then
      warn "任务名转换后的 slug 为空，请重新输入"
      continue
    fi

    branch_name="$username/$slug"
    dir_name="$username-$slug"
    worktree_path="$worktree_repo_dir/$dir_name"

    printf 'Branch: %s\n' "$branch_name" >&2
    printf 'Path: %s\n' "$worktree_path" >&2

    if git_branch_exists_local "$branch_name"; then
      warn "本地已存在同名 branch，请重新输入任务名"
      continue
    fi
    if [[ -e "$worktree_path" ]]; then
      warn "目标 worktree 目录已存在，请重新输入任务名"
      continue
    fi
    if branch_in_use_by_worktree "$branch_name"; then
      warn "已有 worktree 使用该 branch，请重新输入任务名"
      continue
    fi

    local base_branch launch_tool
    base_branch="$(choose_base_branch)" || return 1

    if ! git worktree add -b "$branch_name" "$worktree_path" "$base_branch" >&2; then
      die "创建 worktree 失败"
    fi

    run_setup_script "$worktree_path"

    launch_tool="$(choose_launch_tool)" || return 1
    print_result "$worktree_path" "$launch_tool"
    return 0
  done
}

continue_worktree() {
  collect_worktrees
  if [[ "${#WT_PATHS[@]}" -eq 0 ]]; then
    die "当前仓库没有可用 worktree"
  fi

  local menu_options=()
  local i
  for i in "${!WT_PATHS[@]}"; do
    local label=""
    if [[ "${WT_PATHS[$i]}" == "$repo_root" ]]; then
      label=" [main worktree]"
    fi
    menu_options+=("${WT_BRANCHES[$i]} | ${WT_PATHS[$i]}$label")
  done

  local choice
  choice="$(prompt_menu "请选择要继续的 worktree:" 1 "${menu_options[@]}")" || return 1
  local launch_tool
  launch_tool="$(choose_launch_tool)" || return 1
  print_result "${WT_PATHS[choice-1]}" "$launch_tool"
  return 0
}

branch_merged_into_main_branch() {
  local branch="$1"
  local merged
  merged="$(git branch --merged "$main_branch" --format='%(refname:short)' 2>/dev/null || true)"
  printf '%s\n' "$merged" | grep -Fx -- "$branch" >/dev/null 2>&1
}

is_clean_worktree() {
  git -C "$1" diff --quiet &&
    git -C "$1" diff --cached --quiet &&
    [[ -z "$(git -C "$1" ls-files --others --exclude-standard)" ]]
}

list_deletable_worktrees() {
  collect_worktrees
  DELETE_PATHS=()
  DELETE_BRANCHES=()

  local i
  for i in "${!WT_PATHS[@]}"; do
    local path="${WT_PATHS[$i]}"
    local branch="${WT_BRANCHES[$i]}"

    [[ "$path" == "$repo_root" ]] && continue
    [[ "$branch" == "[detached HEAD]" ]] && continue
    [[ ! -d "$path" ]] && continue

    if branch_merged_into_main_branch "$branch" && is_clean_worktree "$path"; then
      DELETE_PATHS+=("$path")
      DELETE_BRANCHES+=("$branch")
    fi
  done
}

delete_worktree() {
  if ! git rev-parse --verify --quiet "$main_branch^{commit}" >/dev/null; then
    die "主分支不存在，无法判断是否已合并: $main_branch"
  fi

  list_deletable_worktrees
  if [[ "${#DELETE_PATHS[@]}" -eq 0 ]]; then
    die "没有可删除的已合并 worktree"
  fi

  local menu_options=()
  local i
  for i in "${!DELETE_PATHS[@]}"; do
    menu_options+=("${DELETE_BRANCHES[$i]} | ${DELETE_PATHS[$i]}")
  done

  local choice
  choice="$(prompt_menu "请选择要删除的 worktree:" 1 "${menu_options[@]}")" || return 1

  local target_path="${DELETE_PATHS[choice-1]}"
  local target_branch="${DELETE_BRANCHES[choice-1]}"

  if [[ ! -d "$target_path" ]]; then
    die "目标路径不存在：$target_path"
  fi
  if ! is_clean_worktree "$target_path"; then
    die "目标 worktree 有未提交改动，拒绝删除"
  fi
  if ! branch_merged_into_main_branch "$target_branch"; then
    die "目标分支尚未合并到主分支 $main_branch，拒绝删除"
  fi

  if ! git worktree remove "$target_path" >&2; then
    die "删除 worktree 失败"
  fi
  if ! git branch -d "$target_branch" >&2; then
    die "删除 branch 失败"
  fi

  printf '已删除: %s (%s)\n' "$target_branch" "$target_path" >&2
}

show_help() {
  cat >&2 << 'EOF'
用法: ccl [命令]

命令:
  setup    创建或编辑项目级 setup 脚本
  init     输出 shell 集成脚本（支持 zsh/bash）
  help     显示此帮助信息

无参数运行时进入交互模式:
  - 新任务
  - 继续已有 worktree
  - 删除已合并的 worktree
  - 编辑 setup 脚本

setup 脚本位于 ~/.worktrees/<repo-name>/setup.sh
项目配置位于 ~/.worktrees/<repo-name>/config.json
创建新 worktree 后自动执行 setup.sh；首次运行会询问主分支并写入 config.json。
EOF
}

print_shell_init() {
  local shell_name="${1:-}"
  case "$shell_name" in
    zsh|bash) ;;
    *)
      die "init 仅支持 zsh 或 bash"
      ;;
  esac

  cat <<'EOF'
ccl() {
  local output target_path launch_tool

  if ! output="$(command ccl "$@")"; then
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
EOF
}

main() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      setup)
        ensure_project_config || exit 1
        edit_setup_script
        ;;
      init)
        [[ $# -eq 2 ]] || die "用法: ccl init <zsh|bash>"
        print_shell_init "$2"
        ;;
      -h|--help|help) show_help ;;
      *) die "未知命令: $1" ;;
    esac
    return 0
  fi

  ensure_project_config || exit 1

  local choice
  choice="$(prompt_menu "请选择操作:" 1 "新任务" "继续已有 worktree" "删除已合并的 worktree" "编辑 setup 脚本")" || exit 1

  case "$choice" in
    1) create_new_task ;;
    2) continue_worktree ;;
    3) delete_worktree ;;
    4) edit_setup_script ;;
    *) die "未知操作" ;;
  esac
}

main "$@"

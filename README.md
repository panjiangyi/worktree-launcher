# Claude Code Launcher

Git worktree 任务启动器。提供一个统一的 `ccl` 入口，用于创建、进入和清理 Git worktree，并可在目标目录中启动 `codex` 或 `claude`。

## 安装

```bash
git clone git@github.com:panjiangyi/claude-code-launcher.git ~/claude-code-launcher
chmod +x ~/claude-code-launcher/ccl-core.sh
```

在 `~/.zshrc` 或 `~/.bashrc` 中添加：

```bash
source ~/claude-code-launcher/ccl-shell.sh
```

然后重新加载 shell：

```bash
source ~/.zshrc
```

## 使用说明

在任意 Git 仓库子目录运行：

```bash
ccl
```

交互能力：

- 新任务：创建 `~/.worktrees/<repo-name>/<username>-<task-slug>` 并新建 `<username>/<task-slug>` 分支
- 继续已有 worktree：列出当前仓库所有 worktree，包括主工作区
- 删除已合并 worktree：仅显示已合并到 `dev` 且工作区干净的附加 worktree

成功返回时，核心脚本会输出：

```bash
TARGET_PATH='...'
LAUNCH_TOOL='codex'
```

包装函数会解析这两个字段，进入目标目录并按需执行工具命令。

## 测试步骤

1. 在 Git 仓库任意子目录运行 `ccl`，选择"新任务"，输入 `fix login timeout`，确认生成分支 `$(id -un)/fix-login-timeout` 风格名称。
2. 在存在 `dev` 的仓库中创建新任务，直接回车接受默认基线，确认基于 `dev` 创建新 branch 和 worktree。
3. 再次运行 `ccl`，选择"继续已有 worktree"，确认能看到主工作区标记 `[main worktree]`，并能切换到目标路径。
4. 选择启动 `codex` 或 `claude`，在命令缺失时确认脚本保留在目标目录并输出明确错误。
5. 将某个附加 worktree 分支合并到 `dev`，保持工作区干净后运行删除流程，确认先移除 worktree 再删除 branch。
6. 对未合并到 `dev`、存在未提交改动、或主工作区的条目验证删除被拒绝。

## 已知限制

- 新任务创建默认只检查本地 branch、已有 worktree 和目标目录，不会主动访问远程，也不会自动 push 分支。
- 删除合并状态使用 `git branch --merged dev`，要求本地存在 `dev`。
- 未实现中文任务名转拼音、`fzf`、Windows 支持或仓库级配置。

## 文件

- `ccl-core.sh` — 交互式核心脚本，负责 Git 逻辑并输出 `TARGET_PATH` / `LAUNCH_TOOL`
- `ccl-shell.sh` — shell function，负责 `cd` 和启动工具
- `prd.md` — 原始需求文档

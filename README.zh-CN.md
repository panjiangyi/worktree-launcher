# cc-launch

[English](./README.md)

一个 Git worktree 启动器，提供统一的 `ccl` 入口，用于创建、进入和清理 worktree，并在目标目录中启动 `codex` 或 `claude`。

## 安装

适用于 Zsh：

```bash
npm install -g cc-launch && echo 'eval "$(command ccl init zsh)"' >> ~/.zshrc && source ~/.zshrc
```

适用于 Bash：

```bash
npm install -g cc-launch && echo 'eval "$(command ccl init bash)"' >> ~/.bashrc && source ~/.bashrc
```

## 使用

在任意 Git 仓库子目录中运行：

```bash
ccl
```

菜单交互：

- 使用 `↑` / `↓` 移动
- 按 `Enter` 确认
- 如果终端支持鼠标坐标回传，也支持鼠标滚轮和点击选择

项目配置：

- `setup.sh` 和 `config.json` 保存在 `~/.worktrees/<repo-name>/`
- 首次运行时，工具会询问该仓库的主分支，并写入 `config.json`
- 后续创建新任务时，工具会询问基于哪个分支创建 worktree；默认选中配置的主分支，直接按 `Enter` 即可确认
- 删除 worktree 时，会按这个主分支判断是否已合并

交互能力：

- 新任务：创建 `~/.worktrees/<repo-name>/<username>-<task-slug>`，并新建 `<username>/<task-slug>` 分支
- 继续已有 worktree：列出当前仓库中的所有 worktree，包括主工作区
- 删除已合并的 worktree：只显示已经合并到配置主分支且工作区干净的附加 worktree

Setup 命令：

- 运行 `ccl setup` 可创建或编辑项目级 setup 脚本
- 脚本保存在 `~/.worktrees/<repo-name>/setup.sh`
- 每次创建新的 worktree 后，这个脚本都会自动执行，适合用来安装依赖或复制 `.env` 文件

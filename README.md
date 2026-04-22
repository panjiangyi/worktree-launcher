# cc-launch

Git worktree 任务启动器。提供一个统一的 `ccl` 入口，用于创建、进入和清理 Git worktree，并可在目标目录中启动 `codex` 或 `claude`。

## 安装

```bash
npm install -g cc-launch
```

然后把 shell 集成加到配置文件，这一步是必须的；否则独立 CLI 进程无法修改你当前终端的目录：

```bash
echo 'eval "$(command ccl init zsh)"' >> ~/.zshrc
```

然后重新加载 shell：

```bash
source ~/.zshrc
```

如果你使用 Bash：

```bash
echo 'eval "$(command ccl init bash)"' >> ~/.bashrc
source ~/.bashrc
```

本地开发安装：

```bash
git clone git@github.com:panjiangyi/cc-launch.git ~/cc-launch
chmod +x ~/cc-launch/ccl-core.sh ~/cc-launch/bin/ccl
source ~/cc-launch/ccl-shell.sh
```

## 使用说明

在任意 Git 仓库子目录运行：

```bash
ccl
```

菜单交互：

- 使用 `↑` / `↓` 选择
- 按 `Enter` 确认
- 支持鼠标滚轮切换；支持鼠标点击高亮并确认（取决于终端是否回传鼠标坐标）

项目配置：

- `setup.sh` 和 `config.json` 都保存在 `~/.worktrees/<repo-name>/`
- 首次运行会询问该仓库的主分支，并写入 `config.json`
- 后续新任务会询问“基于哪个分支创建”，默认高亮这个主分支，直接按 `Enter` 即可确认
- 删除 worktree 时按这个主分支判断是否已合并

交互能力：

- 新任务：创建 `~/.worktrees/<repo-name>/<username>-<task-slug>` 并新建 `<username>/<task-slug>` 分支
- 继续已有 worktree：列出当前仓库所有 worktree，包括主工作区
- 删除已合并 worktree：仅显示已合并到配置主分支且工作区干净的附加 worktree

成功返回时，核心脚本会输出：

```bash
TARGET_PATH='...'
LAUNCH_TOOL='codex'
```

包装函数会解析这两个字段，进入目标目录并按需执行工具命令。

## 发布到 npm

发布前检查打包内容：

```bash
npm pack --dry-run
```

登录并发布：

```bash
npm login
npm publish
```

如果你后续改成 scoped 包，例如 `@panjiangyi/cc-launch`，公开发布需要：

```bash
npm publish --access public
```

## 测试步骤

1. 在 Git 仓库任意子目录运行 `ccl`，选择"新任务"，输入 `fix login timeout`，确认生成分支 `$(id -un)/fix-login-timeout` 风格名称。
2. 首次运行时选择该仓库的主分支，确认工具会在 `~/.worktrees/<repo-name>/config.json` 中保存配置。
3. 再次运行 `ccl`，选择"继续已有 worktree"，确认能看到主工作区标记 `[main worktree]`，并能切换到目标路径。
4. 选择启动 `codex` 或 `claude`，在命令缺失时确认脚本保留在目标目录并输出明确错误。
5. 将某个附加 worktree 分支合并到配置的主分支，保持工作区干净后运行删除流程，确认先移除 worktree 再删除 branch。
6. 对未合并到配置主分支、存在未提交改动、或主工作区的条目验证删除被拒绝。

## 已知限制

- 新任务创建默认只检查本地 branch、已有 worktree 和目标目录，不会主动访问远程，也不会自动 push 分支。
- 删除合并状态使用 `git branch --merged <mainBranch>`，要求配置中的主分支在本地或远程可解析。
- 未实现中文任务名转拼音、`fzf`、Windows 支持或仓库级配置。

## 文件

- `package.json` — npm 包元数据和 `ccl` bin 入口声明
- `bin/ccl` — npm 全局命令入口，转发到核心脚本
- `ccl-core.sh` — 交互式核心脚本，负责 Git 逻辑并输出 `TARGET_PATH` / `LAUNCH_TOOL`
- `ccl-shell.sh` — shell function，负责 `cd` 和启动工具
- `prd.md` — 原始需求文档


# cc-launcher PRD

本文档定义一个基于 Git worktree 的命令行脚本工具，用于帮助开发者在一个仓库内高效管理多个并行任务，并在选定的 worktree 中启动 `codex` 或 `claude`。

---

## 🧭 1. 产品目标

这个工具的目标不是简单封装 `git worktree`，而是提供一个统一的“**开始工作**”入口。

用户在仓库任意子目录运行脚本后，可以：

- 创建一个新的任务 worktree
- 选择一个已有 worktree 继续工作
- 在目标 worktree 中启动 `codex` 或 `claude`
- 删除已经合并且干净的 worktree

工具需要减少用户手工操作，包括：

- 手动定位仓库根目录
- 手动决定 worktree 路径
- 手动创建 branch / worktree
- 手动进入目录
- 手动启动 AI CLI 工具

---

## 🎯 2. 目标用户与使用场景

### 目标用户
日常需要同时处理多个开发任务的工程师，尤其是：

- 同时修多个 bug
- 并行推进多个 feature
- 经常在不同任务上下文之间切换
- 使用 `codex` 或 `claude` 辅助编码

### 核心使用场景
1. 用户在某个 Git 仓库的任意子目录中工作。
2. 用户准备开始一个新任务，运行脚本。
3. 脚本自动识别仓库，并帮助创建一个独立的 worktree。
4. 用户进入该 worktree，并启动 `codex` 或 `claude`。
5. 之后用户再次运行脚本，可以选择继续已有 worktree。
6. 当某个任务已完成且分支已合并到 `dev`，用户可删除对应 worktree。

---

## 🧱 3. 产品范围

### 本期必须支持
- 从 Git 仓库任意子目录运行
- 自动定位 Git 仓库根目录
- 新建任务 worktree
- 继续已有 worktree
- 选择基线分支创建新任务
- 对用户输入的任务名进行 slug 化
- 基于当前系统登录用户名生成 branch 前缀
- 启动 `codex` 或 `claude`
- 删除已合并到 `dev` 且无未提交改动的 worktree
- 通过 shell function 包装实现真实 `cd`

### 本期不支持
- 中文任务名自动转拼音
- `fzf` 模糊搜索
- issue / ticket 系统集成
- 自动 PR 创建
- 自动 push / pull
- tmux / terminal session 管理
- 多仓库同名 basename 冲突自动消解
- Windows 支持（本期默认 Unix-like shell 环境）

---

## 🗂️ 4. 目录与命名规则

这里是整个工具最重要的约束之一，必须严格实现。

### 4.1 worktree 总根目录
所有 worktree 必须统一存放在当前用户家目录下：

```bash
~/.worktrees
```

### 4.2 仓库级目录
对于当前仓库，取 Git 仓库根目录名作为项目目录名：

```bash
~/.worktrees/<repo-name>
```

例如：

- Git 仓库根目录：`~/code/payment-service`
- repo-name：`payment-service`
- 对应 worktree 目录：`~/.worktrees/payment-service`

### 4.3 单个 worktree 目录命名
单个 worktree 目录名格式为：

```bash
<username>-<task-slug>
```

例如：

```bash
alice-fix-login-timeout
```

完整路径示例：

```bash
~/.worktrees/payment-service/alice-fix-login-timeout
```

---

## 🌿 5. 分支命名规则

### 5.1 用户输入
新任务时，由用户输入任务名称。

### 5.2 slug 化规则
脚本必须将用户输入转换为安全的 slug，规则如下：

1. 转换为小写
2. 去掉首尾空白
3. 将空格和下划线替换为 `-`
4. 去除非安全字符，只保留：
   - `a-z`
   - `0-9`
   - `-`
5. 将连续多个 `-` 压缩为一个
6. 如果最终 slug 为空，提示用户重新输入

### 5.3 branch 命名格式
branch 名格式为：

```bash
<username>/<task-slug>
```

例如：

```bash
alice/fix-login-timeout
```

### 5.4 用户名来源
使用当前系统登录用户名，推荐方式：

```bash
id -un
```

或等价可靠方式。

### 5.5 冲突处理
如果以下任一条件成立，则视为冲突，必须要求用户重新输入任务名：

- 本地已存在同名 branch
- 远程已存在同名 branch
- 已存在同名 worktree 目录
- 已有 worktree 使用该 branch

不允许自动追加数字，不允许自动改名。

---

## 🌱 6. 新任务创建流程

新任务是最核心的主流程之一。实现时必须严格遵循下面步骤。

### 6.1 前置条件
- 当前目录必须位于一个 Git 仓库内
- 脚本应能自动通过 Git 命令定位仓库根目录

推荐命令：

```bash
git rev-parse --show-toplevel
```

若失败，则脚本退出并提示：

```text
当前目录不在 Git 仓库中
```

### 6.2 新任务流程
1. 定位 Git 仓库根目录
2. 获取 repo-name
3. 获取当前登录用户名
4. 确保目录 `~/.worktrees/<repo-name>` 存在，不存在则创建
5. 让用户输入任务名称
6. 将任务名称 slug 化
7. 生成：
   - branch 名：`<username>/<task-slug>`
   - worktree 目录名：`<username>-<task-slug>`
8. 检查 branch / worktree 是否冲突
9. 让用户选择基线分支
10. 使用所选基线分支创建新的 branch 和 worktree
11. 让用户选择启动工具
12. 返回目标 worktree 路径给外层 shell function
13. 外层 shell function `cd` 到该路径并启动工具

---

## 🌲 7. 基线分支选择规则

新任务默认基于 `dev` 创建，但必须让用户可选择其他分支。

### 7.1 候选分支来源
脚本应优先收集以下候选项（如存在）：

- `dev`
- `main`
- `master`
- 当前分支

同时支持用户手动输入其他分支名。

### 7.2 默认值
- 如果 `dev` 存在，则默认选中 `dev`
- 如果 `dev` 不存在，则默认选中第一个可用候选项

### 7.3 分支存在性
脚本必须支持以下情况：

- 基线分支本地存在
- 基线分支仅远程存在，例如 `origin/dev`

实现时可以允许使用 start-point：

```bash
dev
main
master
origin/dev
origin/main
```

### 7.4 创建方式
推荐使用类似逻辑：

```bash
git worktree add -b <new-branch> <worktree-path> <start-point>
```

若分支已存在，不得直接创建，必须报冲突并要求重新输入任务名。

---

## 📂 8. 继续已有 worktree 流程

这是另一个高频主流程。

### 8.1 目标
列出当前仓库的所有已有 worktree，让用户选择一个继续工作。

### 8.2 worktree 来源
使用 Git 官方命令读取 worktree 信息，推荐：

```bash
git worktree list --porcelain
```

### 8.3 展示信息
至少展示以下字段：

- 序号
- branch 名
- 路径

例如：

| 序号 | branch | path |
|---|---|---|
| 1 | `alice/fix-login-timeout` | `~/.worktrees/payment-service/alice-fix-login-timeout` |
| 2 | `alice/add-export-report` | `~/.worktrees/payment-service/alice-add-export-report` |

### 8.4 过滤规则
继续已有 worktree 时，建议列出当前仓库的所有 worktree，包括主工作区与附加 worktree。

但在交互上要明确标识主工作区，例如：

```text
[main worktree]
```

### 8.5 用户选择结果
用户选中后，脚本返回目标路径，外层 shell function 负责：

1. `cd` 到该目录
2. 再让用户选择是否启动 `codex` / `claude` / none

---

## 🤖 9. 工具启动规则

进入目标 worktree 后，需要支持启动 AI CLI 工具。

### 9.1 支持的工具
必须支持以下选项：

- `codex`
- `claude`
- `none`

### 9.2 对应命令
| 选项 | 命令 |
|---|---|
| codex | `codex` |
| claude | `claude` |
| none | 不执行任何工具命令 |

### 9.3 启动时机
在以下两种流程中都要询问：

- 新任务创建成功后
- 继续已有 worktree 后

### 9.4 启动方式
工具必须在目标 worktree 目录中启动。

即外层 shell function `cd` 到目标目录后，再执行对应命令。

---

## 🗑️ 10. 删除已合并 worktree 流程

删除功能本期支持，但应作为独立菜单项，不与“新任务 / 继续工作”混杂。

### 10.1 删除前提
只有满足以下全部条件时，才允许删除：

1. 目标是一个合法的附加 worktree，而不是主工作区
2. 该 worktree 对应分支已经合并到 `dev`
3. worktree 中没有未提交改动
4. 目标路径真实存在
5. 对应 branch 存在且可被安全删除

### 10.2 “已合并”的判定基准
统一以 `dev` 作为目标基线分支。

即：只有当 branch 已合并到 `dev` 时，才允许删除。

### 10.3 建议检查方式
可使用等价方式判断：

```bash
git branch --merged dev
```

或更稳的 merge-base 判定。

### 10.4 未提交改动检查
应在目标 worktree 路径内检查工作区是否干净。若存在未提交改动，拒绝删除并提示。

### 10.5 删除动作
删除时按以下顺序执行：

1. `git worktree remove <worktree-path>`
2. `git branch -d <branch>`

任一步失败都应停止并输出错误信息。

### 10.6 不允许强制删除
本期不支持：

- `git worktree remove --force`
- `git branch -D`

如果无法安全删除，就拒绝删除。

---

## 🧠 11. 交互设计

工具应为交互式 CLI。

### 11.1 顶层菜单
用户运行 `ccl` 后，应显示主菜单，例如：

```text
请选择操作:
1) 新任务
2) 继续已有 worktree
3) 删除已合并的 worktree
```

### 11.2 新任务输入
示例：

```text
请输入任务名称（建议英文，会自动转换为安全 slug）:
> fix login timeout
```

然后展示生成结果：

```text
Branch: alice/fix-login-timeout
Path: ~/.worktrees/payment-service/alice-fix-login-timeout
```

再让用户选择基线分支。

### 11.3 工具选择
示例：

```text
请选择启动工具:
1) codex
2) claude
3) none
```

### 11.4 删除选择
删除模式下，先列出可删除的候选 worktree，然后选择序号。

如果没有可删除项，应提示：

```text
没有可删除的已合并 worktree
```

---

## ⚙️ 12. Shell 集成要求

这是实现时必须遵守的关键点。

### 12.1 限制说明
普通可执行脚本无法改变父 shell 的当前工作目录，因此：

- 不能指望 `./ccl.sh` 执行完之后用户终端自动停在目标 worktree 目录
- 必须使用 shell function 包装

### 12.2 推荐实现方式
采用两层结构：

#### 层 1：核心脚本
负责：

- 所有 Git 逻辑
- 所有交互逻辑
- 输出最终目标目录
- 输出需要启动的工具类型

#### 层 2：shell function
负责：

- 调用核心脚本
- 读取脚本输出结果
- `cd` 到目标目录
- 启动对应工具命令

### 12.3 对外入口
最终用户入口应为一个 shell function，例如：

```bash
ccl
```

该函数应集成到 `.zshrc` 或 `.bashrc`。

---

## 🧪 13. 错误处理要求

实现必须对以下错误场景做明确处理。

### 13.1 非 Git 仓库
当前目录不在 Git 仓库中时，直接退出并提示。

### 13.2 slug 为空
用户输入经 slug 化后为空时，提示重新输入。

### 13.3 branch 冲突
如果 branch 名已存在，必须提示冲突并要求重新输入。

### 13.4 worktree 路径冲突
如果目标 worktree 路径已存在，必须提示冲突并要求重新输入。

### 13.5 基线分支不存在
如果用户选择或输入的基线分支不存在，提示重新选择。

### 13.6 命令缺失
如果用户选择启动 `codex` 或 `claude`，但命令不存在于 PATH 中，提示错误但仍保留在目标目录。

### 13.7 删除失败
删除失败时必须说明失败步骤和 Git 原始错误信息。

---

## 🧾 14. 非功能性要求

### 14.1 平台假设
本期默认运行环境：

- macOS
- Linux
- Bash / Zsh
- 已安装 Git

### 14.2 实现语言
推荐使用 **Bash** 实现第一版。

### 14.3 代码要求
- 结构清晰
- 函数拆分合理
- 尽量避免重复逻辑
- 输出信息明确
- 错误码规范
- 所有路径和变量均正确处理空格与特殊字符

### 14.4 安全性要求
- 不允许强制删除 worktree
- 不允许强制删除分支
- 不覆盖已有目录
- 不自动改写用户输入为其他 branch 名

---

## ✅ 15. 验收标准

下面是本工具第一版的核心验收标准。

### 15.1 新任务创建
- 在仓库任意子目录运行 `ccl`
- 选择”新任务”
- 输入任务名后，脚本能正确 slug 化
- 默认提供 `dev` 作为基线分支（若存在）
- 成功创建新 branch 和新 worktree
- 成功进入对应目录
- 能启动 `codex` 或 `claude`

### 15.2 继续已有任务
- 在仓库任意子目录运行 `ccl`
- 选择”继续已有 worktree”
- 正确列出该仓库的 worktree
- 选择后成功进入对应目录
- 能启动 `codex` 或 `claude`

### 15.3 删除已合并 worktree
- 在仓库任意子目录运行 `ccl`
- 选择”删除已合并的 worktree”
- 仅列出已合并到 `dev` 且无未提交改动的附加 worktree
- 选择后成功删除 worktree 和 branch
- 若条件不满足，则拒绝删除并给出明确提示

### 15.4 shell 行为
- 用户执行 `ccl` 后，shell 当前目录应真正切换到目标 worktree
- 不能只是子进程内部切换目录

---

## 📌 16. 推荐输出协议（给实现者）

为了方便 shell function 与核心脚本协作，建议核心脚本使用一种稳定的输出协议。

### 推荐方案
核心脚本成功结束时输出结构化结果，例如：

```text
TARGET_PATH=/Users/alice/.worktrees/payment-service/alice-fix-login-timeout
LAUNCH_TOOL=codex
```

或输出 shell-safe 的赋值文本，由外层 `eval` / `source` 读取。

### 推荐约束
- 成功时输出固定字段
- 失败时输出错误信息到 stderr，并返回非 0 状态码

这样 shell function 可以做：

1. 调用核心脚本
2. 解析 `TARGET_PATH`
3. `cd "$TARGET_PATH"`
4. 根据 `LAUNCH_TOOL` 启动命令

---

## 💡 17. 后续可扩展方向（不属于本期实现）

以下内容不是本期需求，但后续可作为演进方向：

- `fzf` 模糊选择 worktree
- 中文任务名自动转拼音
- 仓库级配置文件
- 自动检测默认目标分支
- 最近使用 worktree 排序
- 自动清理已删除目录
- ticket 编号命名规则
- GitHub / GitLab 集成

---

## 最终一句话定义

这个工具是一个面向日常开发任务切换的 Git worktree 启动器：它帮助用户从任意仓库子目录快速创建、进入和清理 worktree，并在目标 worktree 中启动 `codex` 或 `claude`。

---

## 交付给其他 LLM 时的附加要求

把下面这段一起交给实现用的 LLM，效果会更稳：

### 实现要求补充
- 使用 Bash 实现第一版
- 拆分为：
  - 一个核心脚本
  - 一个 shell function 包装示例
- 核心脚本负责交互和输出 `TARGET_PATH` / `LAUNCH_TOOL`
- shell function 负责 `cd` 和启动工具
- 使用 `git worktree list --porcelain` 解析 worktree
- 所有路径必须正确处理空格
- 不允许使用 force delete
- 所有错误都要有清晰提示
- 代码中添加必要注释
- 给出安装说明和 `.zshrc` 集成示例
- 给出至少 5 个测试场景

---

下面再给你一份**更适合直接丢给 LLM 的精简任务版 Prompt**，它会比完整 PRD 更像“开发指令”。

---

## 给实现 LLM 的开发指令

请用 Bash 实现一个 Git worktree 管理脚本，满足以下要求：

| **项目** | **要求** |
|---|---|
| 运行环境 | macOS / Linux，Bash 或 Zsh |
| 用户入口 | `ccl` shell function |
| 核心能力 | 新任务、继续已有 worktree、删除已合并 worktree |
| worktree 根目录 | `~/.worktrees/<repo-name>/` |
| repo-name | 当前 Git 仓库根目录名 |
| branch 规则 | `<username>/<task-slug>` |
| worktree 目录名 | `<username>-<task-slug>` |
| username 来源 | `id -un` |
| slug 规则 | 小写、空格和下划线转 `-`、去掉非安全字符、压缩连续 `-` |
| 新任务基线分支 | 默认 `dev`，但用户可从候选列表中选择 |
| 候选基线 | `dev`、`main`、`master`、当前分支、手动输入 |
| 继续模式 | 列出当前仓库所有 worktree，供用户选择 |
| 启动工具 | `codex` / `claude` / none |
| 删除规则 | 仅允许删除已合并到 `dev` 且无未提交改动的附加 worktree |
| 删除限制 | 不允许 force remove / force delete |
| shell 限制 | 核心脚本输出 `TARGET_PATH` 和 `LAUNCH_TOOL`，外层 function `cd` 并启动工具 |
| Git 命令 | 优先使用 `git rev-parse --show-toplevel` 和 `git worktree list --porcelain` |
| 代码要求 | 函数化、可读性强、处理错误和边界情况 |
| 额外交付 | 安装说明、`.zshrc` 示例、测试场景 |

请输出：
1. Bash 核心脚本  
2. shell function 示例  
3. 安装说明  
4. 测试步骤  
5. 已知限制说明

# 版本号维护说明

本仓库是 KernelSU 的改包名分支（fork）。为了让分支的版本号持续跟随官方，
同时**尽量避免与官方合并时产生冲突**，版本号的偏移量改为自动推导。

## 官方算法

官方 KernelSU 的版本号规则是：

```
KSU_VERSION = 30000 + 官方仓库的提交数
```

## 问题所在

本分支比官方多了一些自己的提交，因此 `git rev-list --count HEAD` 得到的数字
比官方大，需要减去“自己独有的提交数”才能与官方一致。

过去的做法是在三处**硬编码**这个偏移量：

```
30000 - 9 + 提交数
```

它有三个问题：

1. 每次与官方合并后，多出的提交数会变化，`-9` 就要重新计算；
2. 同一个数字散落在 **三个不同的构建系统**里，漏改任何一处都会得到错误的版本号；
3. 一旦算错，版本号会**静默**偏离官方，不会报错。

## 现在的方案

偏移量不再手写，改为自动推导：

```
偏移量 = 从 HEAD 可达、但从官方分支不可达的提交数
```

也就是“你独有的提交数”。因为合并进来的官方提交在官方分支上可达，**不会被计入**，
所以合并官方之后版本号自动等于官方，无需任何手动操作。

三个构建系统使用同一套优先级：

1. **优先用 git 实时计算**（`upstream/main..HEAD`）；
2. 取不到官方分支时，用缓存文件 `.ksu-fork-offset` 兜底
   （例如 CI 检出的是你的 fork、或从源码压缩包构建）。

| 构建系统 | 文件 | 读取方式 |
| --- | --- | --- |
| 内核模块 | `kernel/Kbuild` | `KSU_FORK_OFFSET` |
| Manager APK | `manager/build.gradle.kts` | `getForkOffset()` |
| ksud | `userspace/ksud/build.rs` | `get_fork_offset()` |

## 日常使用

### 与官方同步

```sh
git fetch upstream
git merge upstream/main
```

合并之后 **不需要** 改任何版本号相关代码，版本号会自动等于官方。

### 新克隆仓库时

安装一次 git hook（每个克隆一次）：

```sh
scripts/install-git-hooks.sh
```

它会把 `core.hooksPath` 指向仓库内的 `.githooks/`。之后每次提交，
`post-commit` 钩子会自动刷新 `.ksu-fork-offset` 缓存，无需手动干预。

### 手动刷新缓存

一般情况下不需要，但如果你希望在不提交的情况下更新缓存：

```sh
scripts/update-fork-offset.sh
```

## 相关文件

| 文件 | 作用 |
| --- | --- |
| `.ksu-fork-offset` | 偏移量缓存（仅一个数字） |
| `scripts/update-fork-offset.sh` | 计算并刷新缓存 |
| `scripts/install-git-hooks.sh` | 安装 hook（每个克隆一次） |
| `.githooks/post-commit` | 提交后自动刷新缓存 |

## 为什么这样能减少合并冲突

官方**频繁**修改 `kernel/Kbuild`、`manager/build.gradle.kts` 和
`userspace/ksud/build.rs` 这三个文件。如果直接把版本公式重写一遍，就会和官方
改动落在同一片代码上，从而反复产生合并冲突。

现在把偏移量放在一个**本分支独有**的文件里，三个构建文件只需在官方原有的
版本表达式上做极小的改动（把常量换成一个变量），因此与官方的差异面很小。

注意：冲突面变小不等于零。如果将来官方恰好也修改了版本表达式那几行，
仍可能冲突；此时保留官方的写法、把偏移量套用进去即可。

## 如何确认版本号正确

本分支的公式是 `30000 - 偏移量 + HEAD 提交数`。它与官方的
`30000 + 官方提交数` 在**合并官方之后**必然相等（因为 `HEAD - 偏移量`
正好等于双方的共同祖先提交数）。可以手动核对：

```sh
# 官方当前应有的版本号
expr 30000 + "$(git rev-list --count upstream/main)"

# 本分支公式
expr 30000 - "$(cat .ksu-fork-offset)" + "$(git rev-list --count HEAD)"
```

两者相等，说明你已合并到官方最新。两者不等，且差值正好等于
`git rev-list --count HEAD..upstream/main`（官方领先你的提交数），
说明**你还没合并官方的最新提交**，属于正常现象。

若差值不符合上述规律，先执行 `git fetch upstream` 更新本地快照再核对。

### 需要注意的兜底值

`kernel/Kbuild` 中保留了一个兜底版本号 `32626`（官方的默认写法），仅在
**完全取不到 git 信息**时使用。正常情况下永远不会走到那里。
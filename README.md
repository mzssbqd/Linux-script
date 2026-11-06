# Personal Bootstrap

个人终端初始化脚本，面向 macOS、Ubuntu 和 Debian 的 x86_64 / ARM64 环境。使用 Bash 3.2+，固定执行 Base → Terminal → Shell → 可选 Git 身份配置。

## 启动

在项目目录中运行：

```sh
sudo ./bootstrap.sh
```

查看帮助不需要 sudo：

```sh
./bootstrap.sh --help
```

从普通用户发起 sudo。系统软件由管理员安装；Homebrew、Oh My Zsh、插件和个人配置以该用户身份操作，文件归属于该用户。脚本不支持直接以 root 作为目标用户。

macOS 缺少 Homebrew 时会询问是否使用官方安装器安装；拒绝或安装失败时停止。Linux 先更新 APT 索引，索引更新失败时停止。脚本不执行完整系统升级，不添加第三方 APT 源，不尝试其他安装渠道。

默认 Shell 的切换会单独询问。按回车保留现状。除此以外没有模块选择、预览、检查或无人值守命令行模式。

## 新服务器没有 Git 或 GitHub 权限

先从已有项目的电脑打包，再通过服务器 SSH 上传；服务器不需要预先安装 Git，也不需要 GitHub 凭据。以下在 Mac 的项目目录中执行，将 `server-user@server-host` 替换为你的服务器登录信息：

```sh
COPYFILE_DISABLE=1 tar -czf /tmp/personal-bootstrap.tar.gz bootstrap.sh src config README.md
scp /tmp/personal-bootstrap.tar.gz server-user@server-host:~/
```

随后登录服务器，以普通用户解压并启动：

```sh
mkdir -p ~/personal-bootstrap
tar -xzf ~/personal-bootstrap.tar.gz -C ~/personal-bootstrap
cd ~/personal-bootstrap
sudo ./bootstrap.sh
```

初始化会安装 Git。以后访问私有 GitHub 仓库所需的认证单独配置；当前脚本不会设置 GitHub 密钥或登录 Bitwarden。

## 安装内容

| 部分 | 内容 |
| --- | --- |
| Base | Git、curl、wget、CA 证书、unzip、tree、jq、less、SSH 客户端、Node.js、npm |
| Terminal | bat、glow、fzf、ripgrep、fd、zoxide、btop、Bitwarden CLI（`bw`） |
| Shell | Zsh、Oh My Zsh、git / fzf 集成、zsh-autosuggestions、zsh-syntax-highlighting |
| 可选配置 | Git 全局用户名和邮箱 |

系统中已有的工具直接使用。Linux 的 `fd-find`、`openssh-client` 等包名在包管理层适配；`batcat`、`fdfind` 通过个人 Zsh 别名提供 `bat`、`fd` 命令，已有同名命令或别名会保留。工具安装成功后才启用对应集成。

Node.js 和 npm 默认必装。macOS 使用 Homebrew 的 `node`（包含 npm）；Ubuntu、Debian 使用 APT 的 `nodejs` 和 `npm`。已有工具直接使用，不额外安装版本管理器或添加软件源。

Bitwarden CLI 只安装程序，不执行登录、解锁或保险库操作，也不新增账号配置。macOS 使用 Homebrew 的 `bitwarden-cli`；Linux 的 x86_64 和 ARM64 均使用[官方 npm 包](https://bitwarden.com/help/cli/#download-and-install) `@bitwarden/cli`，以目标用户身份安装到 `~/.local`，并在 Zsh 中接入 `~/.local/bin`。安装时检查包声明的 Node.js 版本要求，不满足时报告失败，不切换安装渠道；已有 `bw` 时直接使用。

某个工具安装失败或当前软件源无包时，记录后继续处理其他工具。例如默认 APT 源没有 Glow 时会跳过。缺少 Git 时跳过框架或插件下载。最后显示所有未完成项目，详细输出写入日志，由你自行处理。存在未完成任务时退出状态为 1；全部完成为 0；参数不支持为 2。

Docker、其他开发语言与编译环境、SSH 服务端、服务器安全配置均不包含在本项目中。

## 配置和备份

配置默认存放在 `~/.config/personal-bootstrap/`，支持 `XDG_CONFIG_HOME`：

```text
personal-bootstrap/
├── preferences.conf       # 个人偏好，首次复制后不再覆盖
├── zsh/
│   ├── init.zsh           # Homebrew、框架和工具初始化
│   ├── aliases.zsh        # 命令名称适配
│   ├── plugins.zsh        # 插件接入，最后加载新增的语法高亮
│   ├── mzssbqd-banner.zsh # 彩色 ASCII 欢迎画
│   └── paths.zsh          # 安装时生成的路径
└── backups/               # 修改前的原 .zshrc
```

脚本保留 `.zshrc` 原内容，在其中接入带 `BEGIN/END Personal Bootstrap` 标记的配置块。只有内容需要变化时才备份，备份名带时间；重复运行不重复追加入口或生成相同备份。原文件是符号链接时沿用链接。

`config/zsh/` 中的文件是项目维护的模板，每次运行会同步到用户配置目录；个人别名可以继续写在原 `.zshrc`，或者直接调整仓库内的模板。已有 Oh My Zsh 和插件不重复下载、不自动更新，已有框架不重复初始化，主题沿用原设置。全新环境使用 Oh My Zsh 默认主题。


Zsh 配置位置从目标用户的 `.zshenv` 读取 `ZDOTDIR`。如果在当前终端中另行导出了 `ZDOTDIR`、自定义 Oh My Zsh 路径 `ZSH` / `ZSH_CUSTOM` 或 XDG 路径，运行时需让 sudo 保留这些变量：

```sh
sudo --preserve-env=ZDOTDIR,ZSH,ZSH_CUSTOM,XDG_CONFIG_HOME,XDG_STATE_HOME ./bootstrap.sh
```

不在偏好文件中存放密码、Token 或私钥。脚本不提供回滚、重试或自动修复功能；需要恢复时使用 `backups/` 中的原文件。

## 可选 Git 身份

首次运行后，编辑用户配置目录中的 `preferences.conf`：

```text
CONFIGURE_GIT=true
GIT_USER_NAME=你的名字
GIT_USER_EMAIL=你的邮箱
```

文件采用字面值格式：等号两侧不加空格，值不加引号，不支持 Shell 表达式。默认 `CONFIGURE_GIT=false`，沿用原有 Git 身份。开启后需要同时填写姓名和邮箱，再次运行脚本时只修改这两个配置项，保留其他 Git 设置。

## 日志

macOS：`~/Library/Logs/Personal-Bootstrap/`。

Linux：`${XDG_STATE_HOME:-~/.local/state}/personal-bootstrap/logs/`。

日志保留最近十次，均归属于目标用户，不写入项目仓库。脚本不记录密码或密钥，也不启用命令追踪。

## 项目结构

```text
linux-config/
├── bootstrap.sh           # 唯一启动入口和固定执行顺序
├── src/
│   ├── lib/
│   │   ├── common.sh      # 目标用户、用户上下文和确认操作
│   │   ├── detect_os.sh   # 系统和架构识别
│   │   ├── package_manager.sh # 包名映射、检测和安装接口
│   │   ├── logger.sh      # 日志、保留数量和结果汇总
│   │   └── config_manager.sh  # 偏好、配置部署和 .zshrc 备份
│   ├── platforms/         # macos.sh / apt.sh：平台安装命令
│   └── modules/           # base.sh / terminal.sh / shell.sh / git.sh
├── config/                # 初始偏好与受管理的 Zsh 模板
├── tests/                 # Bats 测试和模拟安装器
├── .github/workflows/     # Ubuntu / macOS 自动检查
├── .shellcheckrc          # sourced 模块的静态检查设置
└── .gitignore             # 忽略临时验证工具和生成物
```

入口先识别用户和平台，选择 Homebrew 或 APT 适配，再按固定顺序调用模块。模块通过公共安装接口使用平台实现，配置操作交给配置管理函数；模块之间不直接互相调用。

## 验证

测试需要 ShellCheck、shfmt、Bats-core 和 Zsh。测试在临时用户目录中运行，模拟软件安装与下载，不请求 sudo、不修改真实用户配置。

```sh
shellcheck -x bootstrap.sh src/lib/*.sh src/platforms/*.sh src/modules/*.sh tests/helpers.bash tests/fixtures/*.sh
shfmt -d -i 4 -ci bootstrap.sh src tests/helpers.bash tests/fixtures
shfmt -d -i 4 -ci -ln bats tests/*.bats
/bin/bash "$(command -v bats)" tests
```

覆盖用户身份与路径、系统识别、包名映射、失败后继续执行、备份和重复运行、Git 身份、ZDOTDIR，以及真实 Zsh 进程中的配置加载。GitHub Actions 在 Ubuntu 和 macOS 执行这些检查。离线测试不代表所有发行版的软件源或实际安装均已验证；实际可用性由当前包管理器决定，失败会明确汇总。

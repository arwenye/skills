---
name: env-init-container
description: 进入新容器后快速初始化工作环境。运行检测脚本生成 checklist，询问是否直接执行。触发词：初始化环境、容器初始化、env init、/env-init-container、新容器配置。
---

# Container Env Init Skill

## Step 1 — 运行检测脚本

```bash
bash /data/ywh/.claude/skills/env-init-container/check.sh
```

输出即为当前容器的初始化 checklist（✅ 已完成 / ⬜ 待配置）。

---

## Step 2 — 询问执行

checklist 输出后问用户：

> 需要帮你执行哪些 ⬜ 项？可以说"全部"或指定条目（如"git + direnv"）。

---

## 执行参考命令

各条目对应命令，**仅在用户要求时运行**：

**Git**
```bash
git config --global user.name "Arwen"
git config --global user.email "ArwenYe@outlook.com"
git config --global init.defaultBranch main
```

**Shell**
```bash
apt-get install -y zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chsh -s $(which zsh)
```

**direnv**
```bash
apt-get install -y direnv
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
# 询问用户确认项目根目录后再写 .envrc
echo 'source .venv/bin/activate' > <项目根>/.envrc
direnv allow <项目根>
```

**Ollama**
```bash
ollama serve &> /tmp/ollama.log &
```

---

## 注意事项

- oh-my-zsh 安装需要访问 GitHub，网络受限时会超时，执行前提示用户确认
- `.envrc` 路径需询问用户确认项目根目录
- ollama serve 是后台进程，容器重启后需要重新执行

#!/usr/bin/env bash
# 容器环境检测脚本，输出初始化 checklist

check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  ✅  $label"
  else
    echo "  ⬜  $label"
  fi
}

echo ""
echo "=== 容器环境初始化 Checklist ==="
echo ""

echo "[ Git ]"
check "user.name = Arwen"                "git config --global user.name | grep -q 'Arwen'"
check "user.email = ArwenYe@outlook.com" "git config --global user.email | grep -q 'ArwenYe'"
check "init.defaultBranch = main"        "git config --global init.defaultBranch | grep -q 'main'"

echo ""
echo "[ Shell ]"
check "zsh 已安装"       "which zsh"
check "oh-my-zsh 已安装" "[ -d ~/.oh-my-zsh ]"
check "默认 shell = zsh" "[ \"\$SHELL\" = \"\$(which zsh 2>/dev/null)\" ]"

echo ""
echo "[ direnv ]"
check "direnv 已安装"    "which direnv"
check "bashrc 已加 hook" "grep -q 'direnv hook' ~/.bashrc"
check "zshrc 已加 hook"  "grep -q 'direnv hook' ~/.zshrc 2>/dev/null"

echo ""
echo "[ Ollama ]"
check "ollama 已安装"   "which ollama"
check "ollama 正在运行" "pgrep -x ollama"

echo ""
echo "================================"
echo ""

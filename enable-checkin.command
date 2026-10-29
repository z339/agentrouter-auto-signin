#!/bin/bash
# 开启 AgentRouter 自动签到（macOS）
#
# 双击本文件即可完成：
#   1. 用真实项目路径替换 plist 模板里的占位符，生成最终 plist；
#   2. 安装到 ~/Library/LaunchAgents/ 并加载（之后每次开机登录都会自动签到）；
#   3. 立即执行一次签到（联网后），并把结果提交进仓库。
#
# 关闭请用 disable-checkin.command。

cd "$(dirname "$0")" || exit 1
PROJ="$(pwd)"

PLIST_SRC="com.user.agentrouter-autosignin.plist"
LABEL="com.user.agentrouter-autosignin"
DEST="$HOME/Library/LaunchAgents/$PLIST_SRC"

mkdir -p "$HOME/Library/LaunchAgents"

# 确保脚本可执行（双击 .command 后内部调用 wrapper 需要 +x）
chmod +x "$PROJ/checkin-wrapper.sh" "$PROJ/enable-checkin.command" "$PROJ/disable-checkin.command" 2>/dev/null

# 用真实项目路径替换占位符，生成最终 plist
sed "s|__PROJECT_DIR__|$PROJ|g" "$PLIST_SRC" > "$DEST"

echo "📄 plist 已生成：$DEST"
echo ""

# 先立即签到一次（开启即生效，不等下次开机）
echo "▶ 立即执行一次签到..."
"$PROJ/checkin-wrapper.sh"

# 再加载定时任务，负责之后的「每日开机联网后」自动签到
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
launchctl bootstrap "gui/$(id -u)" "$DEST"

echo ""
echo "✅ 定时任务已开启：之后每次开机登录、联网后会自动签到"
echo "📄 运行日志：/tmp/com.user.agentrouter-autosignin.out"
echo "📄 签到记录：checkin-record.md（已提交进仓库）"
echo ""
read -p "按回车关闭窗口..."

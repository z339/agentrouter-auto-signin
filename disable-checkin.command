#!/bin/bash
# 关闭 AgentRouter 自动签到（macOS）
#
# 双击本文件即可：卸载并移除 LaunchAgents 中的 plist，之后不再自动签到。
# 已生成的签到记录（checkin-record.md）会保留，未推送的改动需你手动 git push。

LABEL="com.user.agentrouter-autosignin"
DEST="$HOME/Library/LaunchAgents/com.user.agentrouter-autosignin.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$DEST"

echo "✅ 定时任务已关闭（已从 LaunchAgents 移除）"
echo "   之后的签到记录仍保留在 checkin-record.md；若有未推送的提交，请手动 git push。"
echo ""
read -p "按回车关闭窗口..."

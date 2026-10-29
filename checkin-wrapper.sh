#!/bin/bash
# AgentRouter 自动签到 wrapper（macOS launchd / 手动调用）
#
# 流程：
#   0. 若今天（北京时间）已在 checkin-record.md 中有记录，直接跳过（连网络都不等）。
#   1. 等待网络就绪（最多约 5 分钟，每 10 秒检测一次）。
#   2. 运行 `python3 signin.py auto`（每次真实签到，站点侧幂等，每天只记一次积分）。
#   3. 解析 stdout 的 JSON；result=OK 时把「时间 | 余额」追加进 checkin-record.md。
#   4. git add + git commit + git push，把签到记录提交并推送到远端仓库。
#
# 设置环境变量 AR_DRY_RUN=1 可只打印将要执行的 git 命令、不实际提交/推送（用于测试）。

cd "$(dirname "$0")" || exit 1
# 全程按北京时间判断「今天」与日志时间，避免跨时区用户把日期算错一天
export TZ=Asia/Shanghai
PROJ="$(pwd)"
PYBIN="$(command -v python3 || echo /usr/bin/python3)"
RECORD="$PROJ/checkin-record.md"
TODAY="$(date '+%Y-%m-%d')"

ts() { date '+%H:%M:%S'; }
log() { echo "[$(ts)] $*"; }

# ---- 0. 当天去重：已签过就直接退出，省去等待网络的无谓消耗 ----
if grep -q "$TODAY" "$RECORD" 2>/dev/null; then
    log "今天（$TODAY）已签到并记录，跳过"
    exit 0
fi

# ---- 1. 等待网络就绪 ----
log "等待网络就绪..."
READY=0
for i in $(seq 1 30); do
    if "$PYBIN" signin.py diagnose >/dev/null 2>&1; then
        READY=1
        log "网络就绪"
        break
    fi
    [ "$i" -eq 30 ] && break
    sleep 10
done
if [ "$READY" -ne 1 ]; then
    log "等待网络超时（约 5 分钟），本次放弃，等下次开机再试"
    exit 0
fi

# ---- 2. 签到 ----
OUT="$("$PYBIN" signin.py auto 2>&1)"
log "$OUT"

RESULT="$(printf '%s' "$OUT" | grep -o '"result": *"[A-Z_]*"' | head -1 | sed -E 's/.*"result": *"([A-Z_]*)".*/\1/')"
if [ "$RESULT" != "OK" ]; then
    log "签到未成功（result=$RESULT），不记录"
    exit 0
fi

# ---- 3. 解析时间与余额，避免并发重复写入 ----
if grep -q "$TODAY" "$RECORD" 2>/dev/null; then
    log "今天（$TODAY）已有记录（并发触发），跳过写入"
    exit 0
fi
TS="$(printf '%s' "$OUT" | grep -o '"time": *"[^"]*"' | head -1 | sed -E 's/.*"time": *"([^"]*)".*/\1/')"
BAL="$(printf '%s' "$OUT" | grep -o '"total_balance_usd": *[0-9.]*' | head -1 | grep -o '[0-9.]*')"
TS="${TS:-$TODAY 00:00:00}"
BAL="${BAL:-0}"

printf '%s | 余额 $%s\n' "$TS" "$BAL" >> "$RECORD"
log "已记录：$TS | 余额 \$$BAL"

# ---- 4. 提交并推送到仓库 ----
if [ -n "${AR_DRY_RUN:-}" ]; then
    log "[dry-run] 将执行：git -C '$PROJ' add checkin-record.md && git commit -m '自动签到 $TODAY 余额 \$$BAL' && git push"
    exit 0
fi
if git -C "$PROJ" add checkin-record.md && git -C "$PROJ" commit -q -m "自动签到 $TODAY 余额 \$$BAL" 2>/dev/null; then
    log "已提交到仓库"
    if git -C "$PROJ" push -q 2>/dev/null; then
        log "已推送到远端仓库"
    else
        log "⚠️ 记录已写入并提交，但 git push 失败（网络/权限/无 upstream），稍后请手动 git push"
    fi
else
    log "记录已写入，但 git commit 失败（可能无改动或仓库未初始化）"
fi

#!/usr/bin/env bash
# get-token.sh — 从凭证网关获取 QQ 邮箱授权码并写入 .env
set -euo pipefail

# ── 路径解析 ──────────────────────────────────────────────────────────────────

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SKILL_DIR}/.env"

# ── 参数解析 ──────────────────────────────────────────────────────────────────

TOKEN="" EMAIL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --token) [[ $# -lt 2 ]] && { echo "错误: --token 需要提供值" >&2; exit 1; }; TOKEN="$2"; shift 2 ;;
    --email) [[ $# -lt 2 ]] && { echo "错误: --email 需要提供值" >&2; exit 1; }; EMAIL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# ── 远程 API 基础地址 ─────────────────────────────────────────────────────────

REMOTE_BASE_URL="https://jprx.m.qq.com"

# ── 代理端口与请求地址 ───────────────────────────────────────────────────────

PROXY_PORT="${AUTH_GATEWAY_PORT:-19000}"
PROXY_BASE_URL="http://localhost:${PROXY_PORT}"
REMOTE_URL="${REMOTE_BASE_URL}/data/4164/forward"

# ── JSON 解析：优先 jq，fallback 到 node ─────────────────────────────────────

json_extract() {
  local json="$1"
  local path="$2"

  if command -v jq &>/dev/null; then
    echo "$json" | jq -r "$path"
  else
    local node_path
    node_path=$(echo "$path" | node -e "
const p = require('fs').readFileSync('/dev/stdin','utf8').trim();
if (p === '.') { process.stdout.write(''); process.exit(0); }
const parts = p.replace(/^\\./, '').split('.');
process.stdout.write(parts.map(k => '[\"' + k + '\"]').join(''));
")
    echo "$json" | node -e "
const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
const val = data${node_path};
if (val === null || val === undefined) console.log('null');
else if (typeof val === 'object') console.log(JSON.stringify(val));
else console.log(val);
"
  fi
}

# ── 域名推断 ─────────────────────────────────────────────────────────────────

infer_servers() {
  local domain="$1"
  case "$domain" in
    qq.com)        IMAP_HOST="imap.qq.com";       SMTP_HOST="smtp.qq.com" ;;
    foxmail.com)   IMAP_HOST="imap.qq.com";        SMTP_HOST="smtp.qq.com" ;;
    vip.qq.com)    IMAP_HOST="imap.vip.qq.com";    SMTP_HOST="smtp.vip.qq.com" ;;
    163.com|vip.163.com|126.com|vip.126.com|188.com|vip.188.com|yeah.net)
      echo "错误: 域名 @${domain} 不属于 QQ 邮箱，请使用 163-email-skill/get-token.sh" >&2
      exit 1 ;;
    *)
      echo "错误: 不支持的邮箱域名: ${domain}" >&2
      exit 1 ;;
  esac
}

# ── .env 写入函数 ────────────────────────────────────────────────────────────

write_env() {
  local email_address="$1"
  local access_token="$2"
  cat > "$ENV_FILE" <<EOF
# IMAP Configuration
IMAP_HOST=${IMAP_HOST}
IMAP_PORT=993
IMAP_USER=${email_address}
IMAP_PASS=${access_token}
IMAP_TLS=true
IMAP_REJECT_UNAUTHORIZED=true
IMAP_MAILBOX=INBOX

# SMTP Configuration
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=${email_address}
SMTP_PASS=${access_token}
SMTP_FROM=${email_address}
SMTP_REJECT_UNAUTHORIZED=true

# File access whitelist
ALLOWED_READ_DIRS=$HOME/Downloads,$HOME/Documents
ALLOWED_WRITE_DIRS=$HOME/Downloads
EOF
  chmod 600 "$ENV_FILE"
}

# ── 移动端路径（--token + --email 直接写入） ────────────────────────────────

if [[ -n "$TOKEN" || -n "$EMAIL" ]]; then
  # 验证两个参数必须同时提供
  if [[ -z "$TOKEN" || -z "$EMAIL" ]]; then
    echo "错误: --token 和 --email 必须同时提供" >&2
    echo "用法: $0 --token <授权码> --email <邮箱地址>" >&2
    exit 1
  fi
  # 验证 token 不含空格或换行
  if [[ "$TOKEN" =~ [[:space:]] ]]; then
    echo "错误: 授权码不能包含空格或换行符" >&2
    exit 1
  fi
  # 验证 email 包含 @
  if [[ "$EMAIL" != *@* ]]; then
    echo "错误: 邮箱地址格式无效" >&2
    exit 1
  fi
  EMAIL=$(echo "$EMAIL" | tr -d '[:space:]')
  domain="${EMAIL##*@}"
  infer_servers "$domain"
  write_env "$EMAIL" "$TOKEN"
  echo '{"success":true,"env_path":"'"$ENV_FILE"'","mode":"mobile"}' >&2
  exit 0
fi

# ── 主逻辑（网关路径） ───────────────────────────────────────────────────────

PLATFORM="qq_mail"
BODY="{\"platform\":\"${PLATFORM}\"}"

# 发送请求，将响应体和状态码分别写入临时文件
tmp_body=$(mktemp)
trap "rm -f '$tmp_body'" EXIT

HTTP_STATUS=$(curl -s -o "$tmp_body" -w "%{http_code}" \
  -X POST "${PROXY_BASE_URL}/proxy/api" \
  -H "Remote-URL: ${REMOTE_URL}" \
  -H "Content-Type: application/json" \
  -d "$BODY")

response=$(cat "$tmp_body")

# ── 验证链 ───────────────────────────────────────────────────────────────────

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "错误: 网关请求失败 (HTTP ${HTTP_STATUS})" >&2
  exit 1
fi

ret=$(json_extract "$response" '.ret')
if [[ "$ret" != "0" ]]; then
  echo "错误: 网关返回错误 (ret=${ret})" >&2
  exit 1
fi

access_token=$(json_extract "$response" '.data.resp.data.access_token')
if [[ -z "$access_token" || "$access_token" == "null" ]]; then
  echo "错误: 未获取到授权码，请先在集成面板中完成邮箱授权" >&2
  exit 1
fi

email_address=$(json_extract "$response" '.data.resp.data.extra_data.email_address')
if [[ -z "$email_address" || "$email_address" == "null" ]]; then
  echo "错误: 未获取到邮箱地址" >&2
  exit 1
fi

# ── 域名提取与服务器推断 ─────────────────────────────────────────────────────

domain="${email_address##*@}"
infer_servers "$domain"

# ── 写入 .env ────────────────────────────────────────────────────────────────

write_env "$email_address" "$access_token"
echo "✅ .env 已写入 ${ENV_FILE}" >&2

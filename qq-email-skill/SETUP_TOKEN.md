# QQ Email Skill — 凭证配置指南

本文档说明如何通过 `get-token` 脚本获取 QQ 邮箱授权码并生成 `.env` 配置文件。

---

## 快速开始

**Bash (macOS / Linux):**

```bash
# 确保设置了网关端口（默认 19000）
export AUTH_GATEWAY_PORT=19000

# 执行脚本
bash get-token.sh
```

**PowerShell (Windows):**

```powershell
# 设置网关端口
$env:AUTH_GATEWAY_PORT = "19000"

# 执行脚本
.\get-token.ps1
```

脚本会自动从凭证网关获取授权码和邮箱地址，推断服务器配置，写入 `.env` 文件。

成功后输出示例：

```
.env 已写入 /path/to/qq-email-skill/.env
```

---

## 手动输入模式

适用于无法访问凭证网关的场景（如移动设备）。需同时提供 `--token` 和 `--email` 参数。

**Bash:**

```bash
bash get-token.sh --token <授权码> --email user@qq.com
```

**PowerShell:**

```powershell
.\get-token.ps1 -Token <授权码> -Email user@qq.com
```

成功后输出 JSON 状态到 stderr：

```json
{"success":true,"env_path":"/path/to/qq-email-skill/.env","mode":"mobile"}
```

---

## 支持的邮箱域名

| 域名 | IMAP 服务器 | SMTP 服务器 |
|------|-------------|-------------|
| qq.com | imap.qq.com | smtp.qq.com |
| foxmail.com | imap.qq.com | smtp.qq.com |
| vip.qq.com | imap.vip.qq.com | smtp.vip.qq.com |

> 不属于 QQ 邮箱的域名（如 @163.com）会报错并提示使用 `163-email-skill/get-token.sh`。

---

## .env 字段说明

脚本生成的 `.env` 包含以下字段：

| 字段 | 说明 | 示例值 |
|------|------|--------|
| IMAP_HOST | IMAP 服务器地址 | imap.qq.com |
| IMAP_PORT | IMAP 端口 | 993 |
| IMAP_USER | 邮箱地址 | user@qq.com |
| IMAP_PASS | 授权码 | (自动填入) |
| IMAP_TLS | 启用 TLS | true |
| SMTP_HOST | SMTP 服务器地址 | smtp.qq.com |
| SMTP_PORT | SMTP 端口 | 465 |
| SMTP_SECURE | 启用 SSL | true |
| SMTP_USER | 邮箱地址 | user@qq.com |
| SMTP_PASS | 授权码 | (自动填入) |

> 授权码同时用于 IMAP_PASS 和 SMTP_PASS（单一凭证）。

---

## 常见问题

| 错误信息 | 原因 | 解决方法 |
|----------|------|----------|
| 网关请求失败 (HTTP ...) | 凭证网关不可达 | 确认 `AUTH_GATEWAY_PORT` 已设置且网关正在运行 |
| 不支持的邮箱域名 | 邮箱地址不在支持列表中 | 检查邮箱域名是否为 QQ 系邮箱 |
| 未获取到授权码 | 网关返回空 token | 在集成面板中先完成邮箱授权 |
| --token 和 --email 必须同时提供 | 手动模式缺少参数 | 同时传入 `--token` 和 `--email` |

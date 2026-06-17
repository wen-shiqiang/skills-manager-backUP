---
name: qq-email-skill
description: "QQ 邮箱个人邮箱包装 skill：负责加载本 skill 自有配置，并复用 imap-smtp-email 作为底层引擎"
---

# 📨 QQ Email Skill

`qq-email-skill` 是 `email-skill` 的下游个人邮箱子 skill，用于承接 `@qq.com`、`@foxmail.com`、`@vip.qq.com` 邮箱场景。

它的职责是：

1. 维护自己独立的 `.env`
2. 使用 QQ 邮箱的默认 IMAP/SMTP 配置
3. 通过 `scripts/engine_runner.js` 复用共享的 `imap-smtp-email` 底层实现

---

## 1. 什么时候使用

- 用户要用 QQ 邮箱发邮件
- 用户要用 QQ 邮箱收件、检索、下载附件
- 用户明确指定使用 QQ 邮箱

> 正常情况下，大模型不应直接调用本 skill，而应始终先调用 `email-skill`，由统一入口自动分流到这里。

---

## 2. ⚠️ 首次使用前自动初始化（必须执行）

> **重要**：在执行任何邮件命令之前，你**必须**先确保凭证已初始化。

### 自动检查与初始化流程

每次准备使用本 skill 执行邮件操作时，按以下顺序执行：

1. **检查 `.env` 是否存在**：检查本 SKILL.md 所在目录下是否已有 `.env` 文件
2. **如果 `.env` 不存在或为空**：立即运行 get-token 脚本完成自动初始化

**macOS / Linux：**

```bash
cd '<SKILL_DIR>' && bash get-token.sh
```

**Windows：**

```powershell
cd '<SKILL_DIR>'; .\get-token.ps1
```

> 将 `<SKILL_DIR>` 替换为**本 SKILL.md 所在目录的绝对路径**。

3. **如果 get-token 脚本执行失败**：告知用户凭证初始化失败，可能需要检查网络连接或 Auth Gateway 是否正常运行
4. **如果 `.env` 已存在且非空**：跳过初始化，直接执行邮件命令

> ⚠️ 不要跳过此检查步骤。缺少 `.env` 会导致后续所有邮件命令报错。

---

## 3. 配置说明

### 桌面端（自动获取）

上述初始化流程会自动调用 get-token 脚本从凭证网关获取授权码并写入 `.env`。

> 需要设置环境变量 `AUTH_GATEWAY_PORT`（默认 19000）。

### 移动端（手动输入）

如果无法访问凭证网关（如移动设备），可直接提供授权码和邮箱：

```bash
bash get-token.sh --token <授权码> --email <邮箱地址>
```

```powershell
.\get-token.ps1 -Token <授权码> -Email <邮箱地址>
```

脚本会根据邮箱域名自动推断 IMAP/SMTP 服务器配置。

### 支持的域名

| 域名 | IMAP 服务器 | SMTP 服务器 |
|------|-------------|-------------|
| qq.com | imap.qq.com | smtp.qq.com |
| foxmail.com | imap.qq.com | smtp.qq.com |
| vip.qq.com | imap.vip.qq.com | smtp.vip.qq.com |

### 安全约定

- 脚本**不会**在 stdout 或 stderr 输出授权码或密码
- 错误信息仅包含通用描述，不含凭证内容
- `.env` 文件权限设为 `600`（仅所有者可读写）
- `.env` 已加入 `.gitignore`，不会被提交到版本控制

配置项会写入本目录下的 `.env`，不会污染 `imap-smtp-email/.env`。

详细用法请参考 [SETUP_TOKEN.md](./SETUP_TOKEN.md)。

---

## 4. 命令

### 发信

```bash
bash scripts/unix/email_gateway.sh send \
  --to "user@example.com" \
  --subject "测试" \
  --body "你好"
```

### 检索

```bash
bash scripts/unix/email_gateway.sh inbox-search \
  --subject "验证码" \
  --recent 30m
```

---

## 5. 实现说明

- **配置位置**：`qq-email-skill/.env`
- **共享引擎**：自动发现 `../imap-smtp-email`、`../QClaw/imap-smtp-email` 等候选目录，也可通过 `EMAIL_ENGINE_DIR` 显式指定
- **包装器**：`scripts/engine_runner.js`
- **Unix 入口**：`scripts/unix/email_gateway.sh`
- **Windows 入口**：`scripts/windows/email_gateway.cmd`

#!/usr/bin/env node

/**
 * 163-email-skill engine_runner.js
 *
 * 薄包装器：加载共享引擎 engine_runner_shared.js，传入本 skill 目录。
 * 所有实际逻辑均在共享模块中，避免 163/QQ 两份重复代码。
 */

const path = require('path');
const fs = require('fs');

const SKILL_DIR = path.resolve(__dirname, '..');

// 查找共享模块
const SHARED_CANDIDATES = [
  process.env.EMAIL_ENGINE_DIR && path.join(process.env.EMAIL_ENGINE_DIR, 'scripts', 'engine_runner_shared.js'),
  path.resolve(SKILL_DIR, '../imap-smtp-email/scripts/engine_runner_shared.js'),
  path.resolve(SKILL_DIR, '../QClaw/imap-smtp-email/scripts/engine_runner_shared.js'),
  path.resolve(SKILL_DIR, '../QClaw/Claw活动/imap-smtp-email/scripts/engine_runner_shared.js'),
].filter(Boolean);

let sharedModule = null;
for (const candidate of SHARED_CANDIDATES) {
  if (fs.existsSync(candidate)) {
    sharedModule = require(candidate);
    break;
  }
}

if (!sharedModule) {
  process.stdout.write(JSON.stringify({
    success: false,
    error_code: 2,
    message: '未找到共享引擎 engine_runner_shared.js，请检查 imap-smtp-email 目录结构或设置 EMAIL_ENGINE_DIR 环境变量。',
  }, null, 2) + '\n');
  process.exit(1);
}

sharedModule.run(SKILL_DIR);

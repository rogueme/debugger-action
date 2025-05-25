const core = require('@actions/core');
const path = require('path');
const { execFile } = require('child_process');

function run() {
  try {
    // 获取输入变量
    const telegaramToken = core.getInput('telegaram_token', { required: false });
    const telegaramId = core.getInput('telegaram_id', { required: false });
    const pushToken = core.getInput('push_token', { required: false });
    const notificationCode = core.getInput('notification_code', { required: false });
    const ghToken = core.getInput('gh_token', { required: false });

    // 构建环境变量
    const env = {
      ...process.env, // 保留当前环境变量
      TELEGRAM_BOT_TOKEN: telegaramToken,
      TELEGRAM_CHAT_ID: telegaramId,
      PUSH_PLUS_TOKEN: pushToken,
      INFORMATION_NOTICE: notificationCode,
      GITHUB_TOKEN: ghToken
    };

    // 执行 script.sh
    const scriptPath = path.resolve(__dirname, 'script.sh');
    const child = execFile(scriptPath, { env });

    let allOutput = '';
    child.stdout.on('data', (data) => {
      allOutput += data.toString();
      process.stdout.write(data.toString());
    });

    child.stderr.on('data', (data) => {
      allOutput += data.toString();
      process.stderr.write(data.toString());
    });

    child.on('close', (code) => {
      console.log(`child process exited with code ${code}`);
      if (code !== 0) {
        console.error("Error detected. All stdout and stderr outputs:\n" + allOutput + "\n");
        process.exit(code);
      }
    });
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();

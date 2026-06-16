<?php
# Harmraid Push - API endpoint
# Called via /plugins/harmraid-push/api.php?cmd=test_push

$configDir = '/boot/config/plugins/harmraid-push';

if ($_GET['cmd'] === 'test_push') {
  header('Content-Type: text/plain; charset=utf-8');
  $devicesJson = @file_get_contents("$configDir/devices.json");
  $devices = $devicesJson ? json_decode($devicesJson, true) : [];
  if (count($devices) === 0) {
    echo "无设备已注册，无法发送测试通知\n";
    exit;
  }

  $pushScript = '/usr/local/emhttp/plugins/harmraid-push/send-push.sh';

  echo "检查文件...\n";
  if (!file_exists($pushScript)) {
    echo "错误: $pushScript 不存在\n";
    exit;
  }
  echo "文件存在\n";
  $perms = substr(sprintf('%o', fileperms($pushScript)), -4);
  echo "当前权限: $perms\n";
  @chmod($pushScript, 0755);
  echo "已尝试 chmod 755\n";

  $output = [];
  $cmd = $pushScript . ' "测试通知" "这是一条测试通知" "info" 2>&1';
  echo "执行命令: $cmd\n";
  exec($cmd, $output, $code);
  echo "退出码: " . var_export($code, true) . "\n";
  echo "输出行数: " . count($output) . "\n";
  foreach ($output as $line) {
    echo "  > " . $line . "\n";
  }
  exit;
}

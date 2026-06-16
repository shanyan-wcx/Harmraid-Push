<?php
# Harmraid Push - API endpoint
# Called via /plugins/harmraid-push/api.php?cmd=test_push
# Note: This file bypasses the .page framework to return plain text

$configDir = '/boot/config/plugins/harmraid-push';

if ($_GET['cmd'] === 'test_push') {
  header('Content-Type: text/plain; charset=utf-8');
  $devicesJson = @file_get_contents("$configDir/devices.json");
  $devices = $devicesJson ? json_decode($devicesJson, true) : [];
  if (count($devices) === 0) {
    echo "无设备已注册，无法发送测试通知\n";
    exit;
  }
  $output = [];
  exec('/usr/local/emhttp/plugins/harmraid-push/send-push.sh "测试通知" "这是一条来自 Harmraid Push 的测试通知" "info" 2>&1', $output, $code);
  foreach ($output as $line) {
    echo $line . "\n";
  }
  if ($code === 0) {
    echo "测试通知发送完成\n";
  } else {
    echo "发送失败（退出码: $code）\n";
  }
  exit;
}

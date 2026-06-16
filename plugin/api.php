<?php
# Harmraid Push - API endpoint
# Called via /plugins/harmraid-push/api.php?cmd=<command>
# All write commands return JSON

$configDir = '/boot/config/plugins/harmraid-push';

header('Content-Type: application/json; charset=utf-8');

if ($_GET['cmd'] === 'save_types') {
  if (!is_dir($configDir)) { mkdir($configDir, 0755, true); }
  $types = [];
  foreach (['ALERT', 'WARNING', 'INFO'] as $t) {
    if (isset($_GET['type_' . $t]) && $_GET['type_' . $t] === $t) { $types[] = $t; }
  }
  file_put_contents("$configDir/types.txt", implode(',', $types));
  echo json_encode(['status' => 'ok']);
  exit;
}

if ($_GET['cmd'] === 'add_device') {
  $token = trim($_GET['push_token'] ?? '');
  if (!$token) {
    echo json_encode(['status' => 'error', 'message' => 'Missing token']);
    exit;
  }
  if (!is_dir($configDir)) { mkdir($configDir, 0755, true); }
  $deviceName = trim($_GET['device_name'] ?? '') ?: '未命名设备';
  $devices = [];
  $devicesJson = @file_get_contents("$configDir/devices.json");
  if ($devicesJson) { $devices = json_decode($devicesJson, true) ?? []; }
  $devices[] = ['token' => $token, 'device_name' => $deviceName];
  file_put_contents("$configDir/devices.json", json_encode($devices));
  $allTokens = array_map(fn($d) => $d['token'], $devices);
  file_put_contents("$configDir/push_token.txt", implode("\n", $allTokens) . "\n");
  exec('/usr/local/emhttp/plugins/harmraid-push/send-push.sh "设备注册成功" "设备 ' . $deviceName . ' 已注册" "INFO" >/dev/null 2>&1');
  echo json_encode(['status' => 'ok']);
  exit;
}

if ($_GET['cmd'] === 'delete_idx') {
  $delIdx = intval($_GET['idx'] ?? -1);
  $devicesJson = @file_get_contents("$configDir/devices.json");
  $devices = $devicesJson ? json_decode($devicesJson, true) : [];
  if ($delIdx >= 0 && $delIdx < count($devices)) {
    array_splice($devices, $delIdx, 1);
    file_put_contents("$configDir/devices.json", json_encode($devices));
    $allTokens = array_map(fn($d) => $d['token'], $devices);
    file_put_contents("$configDir/push_token.txt", implode("\n", $allTokens) . "\n");
  }
  echo json_encode(['status' => 'ok']);
  exit;
}

if ($_GET['cmd'] === 'test_push') {
  header('Content-Type: text/plain; charset=utf-8');
  $devicesJson = @file_get_contents("$configDir/devices.json");
  $devices = $devicesJson ? json_decode($devicesJson, true) : [];
  if (count($devices) === 0) {
    echo "无设备已注册，无法发送测试通知\n";
    exit;
  }
  $pushScript = '/usr/local/emhttp/plugins/harmraid-push/send-push.sh';
  if (!file_exists($pushScript)) {
    echo "错误: send-push.sh 不存在\n";
    exit;
  }
  @chmod($pushScript, 0755);
  $output = [];
  $cmd = $pushScript . ' "测试通知" "这是一条测试通知" "INFO" 2>&1';
  echo "执行命令: $cmd\n";
  exec($cmd, $output, $code);
  echo "退出码: " . var_export($code, true) . "\n";
  echo "输出行数: " . count($output) . "\n";
  foreach ($output as $line) {
    echo "  > " . $line . "\n";
  }
  exit;
}

echo json_encode(['status' => 'error', 'message' => 'Unknown command']);

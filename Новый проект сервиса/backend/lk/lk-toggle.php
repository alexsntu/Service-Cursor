<?php
// php lk-toggle.php accrual|spend on|off — безопасно переключает accrual.enabled или spend_enabled
// в настройках кабинета (с проверкой синтаксиса)
[$_, $what, $state] = $argv + [null, '', ''];
$f = '/var/www/www-root/data/www/dev.irepair.ru/ajax/lk/config.php';
$s = file_get_contents($f);
$to = $state === 'on' ? 'true' : 'false';
$patterns = [
    'accrual' => "/('accrual' => \[\s*'enabled' => )(true|false)/",
    'spend' => "/('spend_enabled' => )(true|false)/",
];
$names = ['accrual' => 'accrual.enabled', 'spend' => 'spend_enabled'];
if (!isset($patterns[$what]) || !in_array($state, ['on', 'off'], true)) { echo "не изменено\n"; exit(1); }
$new = preg_replace_callback($patterns[$what], static fn($m) => $m[1] . $to, $s, 1, $n);
if ($n !== 1) { echo "не изменено\n"; exit(1); }
$tmp = $f . '.tmp';
file_put_contents($tmp, $new);
exec('php -l ' . escapeshellarg($tmp) . ' 2>&1', $out, $rc);
if ($rc !== 0) { unlink($tmp); echo "синтаксис не прошёл — файл не тронут\n"; exit(1); }
rename($tmp, $f); chown($f, 'www-root'); chgrp($f, 'www-root'); chmod($f, 0640);
echo "{$names[$what]} = $to\n";

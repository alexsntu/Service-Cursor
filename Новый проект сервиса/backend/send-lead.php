<?php
/**
 * Приём формы обратной связи (попап "Заказать звонок" + кнопка "Записаться
 * на ремонт" в калькуляторе) и передача лида в Bitrix24 CRM тем же способом,
 * что на старом сайте (catalog/controller/common/form.php): прямой POST в
 * crm.lead.add.json, без промежуточных модулей CS-Cart.
 */

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'error' => 'method_not_allowed']);
    exit;
}

$name    = trim($_POST['name'] ?? '');
$phone   = trim($_POST['phone'] ?? '');
$service = trim($_POST['service'] ?? '');
$price   = trim($_POST['price'] ?? '');
$uri     = trim($_POST['uri'] ?? '');

if ($phone === '') {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'phone_required']);
    exit;
}

// UF_CRM_1703527324 / UF_CRM_658A9CE200E15 / UF_CRM_1703527478 — кастомные
// поля цены/страницы со старого сайта — проверено через
// crm.lead.userfield.list: в текущем Bitrix24 их больше нет, значения в них
// молча терялись бы. Кладём цену и страницу в стандартный COMMENTS, который
// есть всегда и виден сразу в карточке лида.
$commentLines = [];
if ($service === '') {
    $commentLines[] = 'Заказ звонка';
}
if ($price !== '') {
    $commentLines[] = 'Цена: ' . str_replace(' ', '', $price) . ' ₽';
}
if ($uri !== '') {
    $commentLines[] = 'Страница: ' . $uri;
}

$fields = [
    'PHONE' => [['VALUE' => $phone, 'VALUE_TYPE' => 'MOBILE']],
    'NAME' => $name,
    'TITLE' => $service !== '' ? $service : 'Заказ звонка',
    'SOURCE_ID' => 30,
    'STAGE_ID' => 'UC_ZR6PTH',
    'UF_CRM_METRIKA_CLIENT_ID' => $_COOKIE['_ym_uid'] ?? '',
    'COMMENTS' => implode("\n", $commentLines),
];

$webhookUrl = 'https://irepair.bitrix24.ru/rest/12/e4t5pvtwo0n05ar6/crm.lead.add.json';

$queryData = http_build_query([
    'fields' => $fields,
    'params' => ['REGISTER_SONET_EVENT' => 'Y'],
]);

$curl = curl_init();
curl_setopt_array($curl, [
    CURLOPT_SSL_VERIFYPEER => 1,
    CURLOPT_POST => 1,
    CURLOPT_RETURNTRANSFER => 1,
    CURLOPT_URL => $webhookUrl,
    CURLOPT_POSTFIELDS => $queryData,
    CURLOPT_TIMEOUT => 10,
]);
$result = curl_exec($curl);
$curlError = curl_error($curl);
curl_close($curl);

$decoded = $result !== false ? json_decode($result, true) : null;

if ($result === false || !is_array($decoded) || isset($decoded['error'])) {
    $detail = $result === false ? $curlError : ($decoded['error_description'] ?? $result);
    file_put_contents(__DIR__ . '/send-lead-errors.log', date('c') . ' ' . $detail . PHP_EOL, FILE_APPEND);
}

// Фронтенд всегда показывает "спасибо за заявку" сразу после завершения
// запроса (так же ведёт себя форма на старом сайте) — сбои в Bitrix24 не
// должны блокировать UX, ошибки видно в send-lead-errors.log.
echo json_encode(['ok' => true]);

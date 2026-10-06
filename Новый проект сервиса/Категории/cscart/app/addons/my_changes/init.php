<?php
/**
 * iRepair: подключение хуков модуля my_changes.
 */

if (!defined('BOOTSTRAP')) { die('Access denied'); }

fn_register_hooks(
    'save_cart_content_pre'   // избранное CS-Cart → избранное клиента личного кабинета (func.php)
);

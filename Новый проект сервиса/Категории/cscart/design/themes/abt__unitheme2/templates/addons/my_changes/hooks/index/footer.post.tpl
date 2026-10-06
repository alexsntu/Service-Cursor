{* iRepair: разметка JSON-LD там, где её нет в коде самих страниц.
   Главная и «Контакты» — LocalBusiness (тот же @id «…/#business», что в разметке серий и устройств) + WebSite на главной.
   Статья блога — BlogPosting. Адрес сайта берётся из настроек витрины, поэтому при переезде на irepair.ru менять ничего не нужно.
   JSON собирается через json_encode (320 = без экранирования кириллицы и слэшей). *}
{$irp_ld_home = ""|fn_url}
{$irp_ld_biz = [
    "@type" => "LocalBusiness",
    "@id" => "`$irp_ld_home`#business",
    "name" => "iRepair",
    "alternateName" => "Сервисный центр iRepair",
    "description" => "Сервисный центр Apple в Москве — ремонт iPhone, MacBook, iPad, iMac и Apple Watch. Диагностика бесплатно, оригинальные запчасти, курьер по Москве.",
    "url" => $irp_ld_home,
    "telephone" => "+78005552190",
    "email" => "service@irepair.ru",
    "priceRange" => "₽₽",
    "image" => $logos.theme.image.image_path,
    "address" => [
        "@type" => "PostalAddress",
        "streetAddress" => "ул. Большая Садовая, д. 5, под. 2, этаж 1А, офис А25",
        "addressLocality" => "Москва",
        "addressRegion" => "Москва",
        "addressCountry" => "RU"
    ],
    "areaServed" => ["@type" => "City", "name" => "Москва"],
    "openingHoursSpecification" => [
        "@type" => "OpeningHoursSpecification",
        "dayOfWeek" => ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
        "opens" => "10:00",
        "closes" => "20:00"
    ],
    "sameAs" => ["https://t.me/iRepair_Moscow_bot"]
]}

{if $runtime.controller == "index" && $runtime.mode == "index"}
    {$irp_ld = ["@context" => "https://schema.org", "@graph" => [
        $irp_ld_biz,
        ["@type" => "WebSite", "@id" => "`$irp_ld_home`#website", "url" => $irp_ld_home, "name" => "iRepair", "inLanguage" => "ru-RU", "publisher" => ["@id" => "`$irp_ld_home`#business"]]
    ]]}
    <script type="application/ld+json">{$irp_ld|json_encode:320 nofilter}</script>
{elseif $runtime.controller == "pages" && $runtime.mode == "view" && $page.page_id == 27}
    {$irp_ld_url = "pages.view?page_id=`$page.page_id`"|fn_url}
    {$irp_ld = ["@context" => "https://schema.org", "@graph" => [
        $irp_ld_biz,
        ["@type" => "ContactPage", "@id" => "`$irp_ld_url`#webpage", "url" => $irp_ld_url, "name" => "Контакты сервисного центра iRepair", "inLanguage" => "ru-RU", "about" => ["@id" => "`$irp_ld_home`#business"]]
    ]]}
    <script type="application/ld+json">{$irp_ld|json_encode:320 nofilter}</script>
{elseif $runtime.controller == "pages" && $runtime.mode == "view" && $page.page_type == $smarty.const.PAGE_TYPE_BLOG && $page.parent_id}
    {$irp_ld_url = "pages.view?page_id=`$page.page_id`"|fn_url}
    {$irp_ld_img = $page.page_id|fn_get_image_pairs:"blog":"M":true:true}
    {$irp_ld_src = $irp_ld_img.icon.image_path|default:$irp_ld_img.detailed.image_path}
    {$irp_ld_date = $page.timestamp|date_format:"%Y-%m-%dT%H:%M:%S+03:00"}
    {$irp_ld_post = [
        "@type" => "BlogPosting",
        "@id" => "`$irp_ld_url`#article",
        "mainEntityOfPage" => $irp_ld_url,
        "headline" => $page.page|strip_tags|truncate:110:"…",
        "description" => $page.meta_description|default:$page.spoiler|strip_tags|trim,
        "datePublished" => $irp_ld_date,
        "dateModified" => $irp_ld_date,
        "inLanguage" => "ru-RU",
        "author" => ["@type" => "Organization", "name" => "iRepair", "url" => $irp_ld_home],
        "publisher" => ["@type" => "Organization", "@id" => "`$irp_ld_home`#business", "name" => "iRepair", "logo" => ["@type" => "ImageObject", "url" => $logos.theme.image.image_path]]
    ]}
    {if $irp_ld_src}{$irp_ld_post.image = [$irp_ld_src]}{/if}
    {$irp_ld = ["@context" => "https://schema.org", "@graph" => [$irp_ld_post]]}
    <script type="application/ld+json">{$irp_ld|json_encode:320 nofilter}</script>
{/if}

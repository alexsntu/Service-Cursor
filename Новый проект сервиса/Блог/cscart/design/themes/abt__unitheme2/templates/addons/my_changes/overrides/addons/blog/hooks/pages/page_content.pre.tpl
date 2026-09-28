{* iRepair: шапка статьи блога (переопределяет addons/blog/hooks/pages/page_content.pre.tpl UniTheme2).
   Главное фото статьи НЕ показываем (оно нужно только для списка /blog/), дата — по-русски.
   Метка .irepair-blog-post — по ней CSS (через :has) оформляет текст статьи в стиле сайта. *}
{if $page.description && $page.page_type == $smarty.const.PAGE_TYPE_BLOG}
    {$irp_bm = ["января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"]}
    {$irp_bmi = ($page.timestamp|date_format:"%m")|intval}
    <div class="irepair-blog-post">
        <time class="irepair-blog-post__date" datetime="{$page.timestamp|date_format:"%Y-%m-%d"}">{$page.timestamp|date_format:"%e"|trim} {$irp_bm[$irp_bmi - 1]} {$page.timestamp|date_format:"%Y"}</time>
    </div>
{literal}
<style>
/* текст статьи — стили сайта (Montserrat заголовки, Roboto текст), только на странице статьи блога */
.ty-wysiwyg-content:has(> .irepair-blog-post) {
  max-width: 860px;
  margin: 0 auto;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 17px;
  line-height: 27px;
  color: #2c2c2c;
}
.ty-blog-grid .ty-mainbox-title:has(.ut2-blog__post-title) {
  max-width: 860px;
  margin: 0 auto 8px;
  font-family: 'Montserrat-Bold', Arial, sans-serif;
  font-size: 40px;
  line-height: 46px;
  font-weight: 400;
  color: #010306;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) .irepair-blog-post__date {
  display: block;
  margin: 0 0 28px;
  font-size: 14px;
  line-height: 20px;
  color: #939393;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) h1,
.ty-wysiwyg-content:has(> .irepair-blog-post) h2 {
  margin: 40px 0 16px;
  font-family: 'Montserrat-Bold', Arial, sans-serif;
  font-size: 28px;
  line-height: 34px;
  font-weight: 400;
  color: #010306;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) h1 br {
  display: none;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) h3 {
  margin: 28px 0 12px;
  font-family: 'Montserrat-Medium', Arial, sans-serif;
  font-size: 21px;
  line-height: 28px;
  font-weight: 400;
  color: #010306;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) h4 {
  margin: 24px 0 10px;
  font-family: 'Montserrat-Medium', Arial, sans-serif;
  font-size: 18px;
  line-height: 24px;
  font-weight: 400;
  color: #010306;
}
/* тема задаёт абзацам блога свой шрифт/размер селектором с кучей :not() — перебиваем только в статье */
.ty-wysiwyg-content:has(> .irepair-blog-post) p,
.ty-wysiwyg-content:has(> .irepair-blog-post) li,
.ty-wysiwyg-content:has(> .irepair-blog-post) td,
.ty-wysiwyg-content:has(> .irepair-blog-post) th {
  font-family: 'Roboto', Arial, sans-serif !important;
  font-size: 17px !important;
  line-height: 27px !important;
  color: #2c2c2c;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) td,
.ty-wysiwyg-content:has(> .irepair-blog-post) th {
  font-size: 15px !important;
  line-height: 21px !important;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) p {
  margin: 0 0 16px;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) p:empty {
  display: none;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) a {
  color: #20a86b;
  text-decoration: underline;
  text-underline-offset: 3px;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) a:hover {
  color: #12b857;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) ul,
.ty-wysiwyg-content:has(> .irepair-blog-post) ol {
  margin: 0 0 20px;
  padding-left: 22px;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) li {
  margin: 0 0 8px;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) ul li::marker {
  color: #37d97b;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) img {
  max-width: 100%;
  height: auto;
  border-radius: 16px;
}
/* таблицы: скругление, зелёная шапка, горизонтальная прокрутка на телефоне */
.ty-wysiwyg-content:has(> .irepair-blog-post) table {
  display: block;
  width: 100%;
  max-width: 100%;
  margin: 8px 0 28px;
  overflow-x: auto;
  border-collapse: collapse;
  border: 0;
  font-size: 15px;
  line-height: 21px;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) table th,
.ty-wysiwyg-content:has(> .irepair-blog-post) table td {
  padding: 12px 16px;
  border: 1px solid #e3e3e3;
  text-align: left;
  vertical-align: top;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) table tr:first-child th,
.ty-wysiwyg-content:has(> .irepair-blog-post) table thead td {
  background: #eefaf3;
  font-weight: 500;
  color: #010306;
}
.ty-wysiwyg-content:has(> .irepair-blog-post) blockquote {
  margin: 24px 0;
  padding: 16px 20px;
  border-left: 4px solid #37d97b;
  background: #f6fbf8;
  border-radius: 0 12px 12px 0;
}
@media (max-width: 650px) {
  .ty-blog-grid .ty-mainbox-title:has(.ut2-blog__post-title) {
    font-size: 26px;
    line-height: 32px;
  }
  .ty-wysiwyg-content:has(> .irepair-blog-post),
  .ty-wysiwyg-content:has(> .irepair-blog-post) p,
  .ty-wysiwyg-content:has(> .irepair-blog-post) li {
    font-size: 16px !important;
    line-height: 25px !important;
  }
  .ty-wysiwyg-content:has(> .irepair-blog-post) h1,
  .ty-wysiwyg-content:has(> .irepair-blog-post) h2 {
    margin-top: 32px;
    font-size: 22px;
    line-height: 28px;
  }
  .ty-wysiwyg-content:has(> .irepair-blog-post) h3 {
    font-size: 18px;
    line-height: 24px;
  }
}
</style>
{/literal}
{/if}

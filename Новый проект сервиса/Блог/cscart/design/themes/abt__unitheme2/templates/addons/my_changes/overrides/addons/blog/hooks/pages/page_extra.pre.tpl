{* iRepair: блог (переопределяет addons/blog/hooks/pages/page_extra.pre.tpl UniTheme2).
   Все превью статей — 4:3 (правило владельца, 2026-10-06).
   /blog/ (список статей) — серый фон, «Блог» + подзаголовок, сетка карточек: превью 4:3 сверху,
   дата, заголовок, анонс, «Читать полностью ›». Компьютер — 3 в ряд, планшет — 2, телефон — 1.
   Статья — внизу «Другие статьи» (3 последние, кроме текущей): карточки с превью 4:3. *}
{if $page.page_type == $smarty.const.PAGE_TYPE_BLOG}

    {if $subpages}
        {* на странице списка свой H1 внутри серого фона — стандартный заголовок страницы не выводим (иначе два H1) *}
        {capture name="mainbox_title"}{/capture}
        <div class="irepair-blog">
            <div class="irepair-blog__inner">
                <h1 class="irepair-blog__title">{$page.page}</h1>
                <div class="irepair-blog__desc">Лайфхаки, рекомендации, статьи и всякие полезности</div>

                {$ut2_load_more=$settings.abt__ut2.load_more.blog == 'Y'}
                {if $ut2_load_more}{include file="common/abt__ut2_pagination.tpl" type="{"`$runtime.controller`_`$runtime.mode`"}" position="top" object="pages"}{/if}
                {$irp_bm = ["января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"]}
                <div class="irepair-blog__items">
                {foreach from=$subpages item="subpage" name="subpages"}
                    {$irp_url = "pages.view?page_id=`$subpage.page_id`"|fn_url}
                    {$irp_bmi = ($subpage.timestamp|date_format:"%m")|intval}
                    <article class="irepair-blog__item"{if $ut2_load_more && $smarty.foreach.subpages.first} data-ut2-load-more="first-item"{/if}>
                        <a class="irepair-blog__item-image" href="{$irp_url}" tabindex="-1" aria-hidden="true">
                            {if $subpage.main_pair}{include file="common/image.tpl" obj_id=$subpage.page_id images=$subpage.main_pair image_width=640}{/if}
                        </a>
                        <div class="irepair-blog__item-content">
                            <time class="irepair-blog__item-date" datetime="{$subpage.timestamp|date_format:"%Y-%m-%d"}">{$subpage.timestamp|date_format:"%e"|trim} {$irp_bm[$irp_bmi - 1]} {$subpage.timestamp|date_format:"%Y"}</time>
                            <h2 class="irepair-blog__item-title"><a href="{$irp_url}">{$subpage.page}</a></h2>
                            <p class="irepair-blog__item-text">{$subpage.spoiler|strip_tags|trim|truncate:150:"..." nofilter}</p>
                            <a class="irepair-blog__item-more" href="{$irp_url}"><span>Читать полностью</span><svg width="6" height="12" viewBox="0 0 6 12" fill="none" aria-hidden="true"><path d="M1 1.5L5 6L1 10.5" stroke="#37D97B" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg></a>
                        </div>
                    </article>
                {/foreach}
                </div>
                {if $ut2_load_more}{include file="common/abt__ut2_pagination.tpl" type="{"`$runtime.controller`_`$runtime.mode`"}" position="bottom" object="pages"}{/if}

                {include file="common/pagination.tpl"}
            </div>
        </div>
{literal}
<style>
/* свой заголовок «Блог» внутри серого фона — стандартный заголовок страницы прячем */
.ty-blog-grid .ty-mainbox-title {
  display: none;
}
.irepair-blog,
.irepair-blog * {
  box-sizing: border-box;
}
.irepair-blog {
  /* во всю ширину окна, как фон main.blogPage на старом сайте */
  width: 100vw;
  margin-left: calc(50% - 50vw);
  margin-top: -20px; /* компактная шапка: серый фон начинается сразу под «хлебными крошками» */
  padding: 1px 0 100px;
  background: #f8f8f8;
}
.irepair-blog .irepair-blog__inner {
  max-width: 1370px;
  margin: 0 auto;
  padding: 0 35px;
}
.irepair-blog .irepair-blog__title {
  margin: 22px 0 6px;
  padding: 0;
  font-family: 'Montserrat-Bold', Arial, sans-serif;
  font-size: 38px;
  line-height: 44px;
  font-weight: 400;
  text-transform: none;
  color: #010306;
}
.irepair-blog .irepair-blog__desc {
  font-family: 'Montserrat-Medium', Arial, sans-serif;
  font-size: 18px;
  line-height: 26px;
  color: #5c5b5b;
}
.irepair-blog .irepair-blog__items {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 32px;
  margin-top: 24px;
}
.irepair-blog .irepair-blog__item {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: #ffffff;
  border-radius: 20px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.07);
  transition: box-shadow 0.25s ease;
}
.irepair-blog .irepair-blog__item:hover {
  box-shadow: 0 14px 40px rgba(32, 204, 190, 0.18);
}
/* превью 4:3 */
.irepair-blog .irepair-blog__item-image {
  display: block;
  flex: 0 0 auto;
  aspect-ratio: 4 / 3;
  overflow: hidden;
  background: #f0f0f2;
}
.irepair-blog .irepair-blog__item-image img {
  display: block;
  width: 100% !important;
  max-width: none;
  height: 100% !important;
  object-fit: cover;
}
.irepair-blog .irepair-blog__item-content {
  display: flex;
  flex-direction: column;
  flex: 1 1 auto;
  min-width: 0;
  padding: 22px 26px 26px;
}
.irepair-blog .irepair-blog__item-date {
  display: block;
  margin: 0 0 8px;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 13px;
  line-height: 18px;
  color: #939393;
}
.irepair-blog .irepair-blog__item-title,
.irepair-blog .irepair-blog__item-title a {
  margin: 0 0 12px;
  padding: 0;
  font-family: 'Montserrat-SemiBold', 'Montserrat-Bold', Arial, sans-serif !important;
  font-size: 20px !important;
  line-height: 26px !important;
  font-weight: 400 !important;
  text-transform: none;
}
.irepair-blog .irepair-blog__item-title a {
  margin: 0;
  color: #1d1d1f;
  text-decoration: none;
  transition: color 0.3s;
}
.irepair-blog .irepair-blog__item-title a:hover {
  color: #20a86b;
}
.irepair-blog .irepair-blog__item-text {
  display: -webkit-box;
  max-height: 72px; /* ровно 3 строки: тема добавляет абзацу отступ, из-за него выглядывала 4-я */
  margin: 0 0 18px;
  padding: 0 !important;
  overflow: hidden;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  font-family: 'Roboto', Arial, sans-serif !important;
  font-size: 16px !important;
  line-height: 24px !important;
  font-weight: 400;
  color: #5c5b5b;
}
.irepair-blog .irepair-blog__item-more {
  display: inline-flex;
  align-items: center;
  align-self: flex-start;
  margin-top: auto;
  text-decoration: none;
}
.irepair-blog .irepair-blog__item-more span {
  margin-right: 10px;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 16px;
  line-height: 20px;
  font-weight: 500;
  color: #37d97b;
  transition: color 0.3s;
}
.irepair-blog .irepair-blog__item-more:hover span {
  color: #12b857;
}
.irepair-blog .ty-pagination {
  margin-top: 40px;
}
@media (max-width: 1180px) {
  .irepair-blog {
    padding-bottom: 70px;
  }
  .irepair-blog .irepair-blog__items {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 24px;
  }
}
@media (max-width: 767px) {
  .irepair-blog .irepair-blog__inner {
    padding: 0 16px;
  }
}
@media (max-width: 650px) {
  .irepair-blog {
    padding-bottom: 60px;
  }
  .irepair-blog .irepair-blog__title {
    margin: 16px 0 4px;
    font-size: 28px;
    line-height: 34px;
  }
  .irepair-blog .irepair-blog__desc {
    font-size: 15px;
    line-height: 21px;
  }
  .irepair-blog .irepair-blog__items {
    grid-template-columns: minmax(0, 1fr);
    gap: 16px;
    margin-top: 16px;
  }
  .irepair-blog .irepair-blog__item {
    border-radius: 16px;
  }
  .irepair-blog .irepair-blog__item-content {
    padding: 16px 18px 20px;
  }
  .irepair-blog .irepair-blog__item-title,
  .irepair-blog .irepair-blog__item-title a {
    font-size: 18px !important;
    line-height: 24px !important;
  }
  .irepair-blog .irepair-blog__item-text {
    max-height: 66px;
    font-size: 15px !important;
    line-height: 22px !important;
  }
}
</style>
{/literal}
    {/if}

    {if $page.description}
        {capture name="mainbox_title"}<span class="ut2-blog__post-title" {live_edit name="page:page:{$page.page_id}"}>{$page.page}</span>{/capture}

        {* «Другие статьи»: 3 последние статьи этого блога, кроме текущей *}
        {$irp_rel = ["page_type" => $smarty.const.PAGE_TYPE_BLOG, "parent_id" => $page.parent_id, "status" => "A", "sort_by" => "timestamp", "sort_order" => "desc"]|fn_get_pages:4}
        {$irp_rel_posts = []}
        {foreach $irp_rel.0|default:[] as $irp_p}
            {if $irp_p.page_id != $page.page_id && $irp_rel_posts|count < 3}{$irp_rel_posts[] = $irp_p}{/if}
        {/foreach}
        {if $irp_rel_posts}
            <div class="irepair-blog-rel">
                <h2 class="irepair-blog-rel__title">Другие статьи</h2>
                <div class="irepair-blog-rel__items">
                {foreach $irp_rel_posts as $irp_p}
                    {$irp_url = "pages.view?page_id=`$irp_p.page_id`"|fn_url}
                    {* картинки статей блога — object_type «blog», тип M (как в модуле блога) *}
                    {$irp_img = $irp_p.page_id|fn_get_image_pairs:"blog":"M":true:true}
                    {$irp_src = $irp_img.icon.image_path|default:$irp_img.detailed.image_path}
                    <a class="irepair-blog-rel__item" href="{$irp_url}">
                        <span class="irepair-blog-rel__image">{if $irp_src}<img src="{$irp_src}" alt="{$irp_p.page}" loading="lazy">{/if}</span>
                        <span class="irepair-blog-rel__body">
                            <span class="irepair-blog-rel__name">{$irp_p.page}</span>
                            <span class="irepair-blog-rel__more">Читать полностью ›</span>
                        </span>
                    </a>
                {/foreach}
                </div>
            </div>
{literal}
<style>
.irepair-blog-rel,
.irepair-blog-rel * {
  box-sizing: border-box;
}
.irepair-blog-rel {
  max-width: 1300px;
  margin: 64px auto 40px;
}
.irepair-blog-rel .irepair-blog-rel__title {
  margin: 0 0 24px;
  font-family: 'Montserrat-Bold', Arial, sans-serif;
  font-size: 32px;
  line-height: 38px;
  font-weight: 400;
  text-transform: none;
  color: #010306;
}
.irepair-blog-rel .irepair-blog-rel__items {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 24px;
}
.irepair-blog-rel .irepair-blog-rel__item {
  display: flex;
  flex-direction: column;
  background: #ffffff;
  border-radius: 20px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.07);
  overflow: hidden;
  text-decoration: none;
  transition: box-shadow 0.25s ease;
}
.irepair-blog-rel .irepair-blog-rel__item:hover {
  box-shadow: 0 14px 40px rgba(32, 204, 190, 0.18);
}
/* превью 4:3 */
.irepair-blog-rel .irepair-blog-rel__image {
  display: block;
  flex: 0 0 auto;
  aspect-ratio: 4 / 3;
  overflow: hidden;
  background: #f0f0f2;
}
.irepair-blog-rel .irepair-blog-rel__image img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.irepair-blog-rel .irepair-blog-rel__body {
  display: flex;
  flex-direction: column;
  flex: 1 1 auto;
  min-width: 0;
  padding: 20px 24px 24px;
}
.irepair-blog-rel .irepair-blog-rel__name {
  display: -webkit-box;
  margin: 0 0 14px;
  overflow: hidden;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  font-family: 'Montserrat-SemiBold', 'Montserrat-Bold', Arial, sans-serif;
  font-size: 18px;
  line-height: 24px;
  color: #1d1d1f;
  transition: color 0.3s;
}
.irepair-blog-rel .irepair-blog-rel__item:hover .irepair-blog-rel__name {
  color: #20a86b;
}
.irepair-blog-rel .irepair-blog-rel__more {
  margin-top: auto;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 16px;
  line-height: 20px;
  font-weight: 500;
  color: #37d97b;
}
/* телефон: компактные строки — превью 4:3 слева, заголовок справа */
@media (max-width: 767px) {
  .irepair-blog-rel .irepair-blog-rel__items {
    grid-template-columns: minmax(0, 1fr);
    gap: 12px;
  }
  .irepair-blog-rel .irepair-blog-rel__item {
    flex-direction: row;
    align-items: center;
    gap: 14px;
    padding: 10px;
    border-radius: 16px;
  }
  .irepair-blog-rel .irepair-blog-rel__image {
    flex: 0 0 36%;
    border-radius: 10px;
  }
  .irepair-blog-rel .irepair-blog-rel__body {
    padding: 0;
  }
  /* заголовок целиком, без обрезки */
  .irepair-blog-rel .irepair-blog-rel__name {
    display: block;
    margin-bottom: 6px;
    overflow: visible;
    font-family: 'Montserrat-Medium', Arial, sans-serif;
    font-size: 13px;
    line-height: 17px;
  }
  .irepair-blog-rel .irepair-blog-rel__more {
    font-size: 14px;
  }
  .irepair-blog-rel .irepair-blog-rel__title {
    font-size: 24px;
    line-height: 30px;
  }
}
</style>
{/literal}
        {/if}
    {/if}

{/if}

{* iRepair: блог (переопределяет addons/blog/hooks/pages/page_extra.pre.tpl UniTheme2).
   /blog/ (список статей) — как на старом сайте irepair.ru/blog/: серый фон, «Блог» + подзаголовок,
   белые карточки во всю ширину: картинка слева, справа заголовок, анонс, «Читать полностью ›».
   Статья — внизу «Другие статьи» (3 последние, кроме текущей). *}
{if $page.page_type == $smarty.const.PAGE_TYPE_BLOG}

    {if $subpages}
        <div class="irepair-blog">
            <div class="irepair-blog__inner">
                <h1 class="irepair-blog__title">{$page.page}</h1>
                <div class="irepair-blog__desc">Лайфхаки, рекомендации, статьи<br> и всякие полезности</div>

                {$ut2_load_more=$settings.abt__ut2.load_more.blog == 'Y'}
                {if $ut2_load_more}{include file="common/abt__ut2_pagination.tpl" type="{"`$runtime.controller`_`$runtime.mode`"}" position="top" object="pages"}{/if}
                <div class="irepair-blog__items">
                {foreach from=$subpages item="subpage" name="subpages"}
                    {$irp_url = "pages.view?page_id=`$subpage.page_id`"|fn_url}
                    <div class="irepair-blog__item"{if $ut2_load_more && $smarty.foreach.subpages.first} data-ut2-load-more="first-item"{/if}>
                        {if $subpage.main_pair}
                            <a class="irepair-blog__item-image" href="{$irp_url}" tabindex="-1" aria-hidden="true">
                                {include file="common/image.tpl" obj_id=$subpage.page_id images=$subpage.main_pair image_width=560}
                            </a>
                        {/if}
                        <div class="irepair-blog__item-content">
                            <h2 class="irepair-blog__item-title"><a href="{$irp_url}">{$subpage.page}</a></h2>
                            <p class="irepair-blog__item-text">{$subpage.spoiler|strip_tags|trim|truncate:150:"..." nofilter}</p>
                            <a class="irepair-blog__item-more" href="{$irp_url}"><span>Читать полностью</span><svg width="6" height="12" viewBox="0 0 6 12" fill="none" aria-hidden="true"><path d="M1 1.5L5 6L1 10.5" stroke="#37D97B" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg></a>
                        </div>
                    </div>
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
  padding: 1px 0 100px;
  background: #f8f8f8;
}
.irepair-blog .irepair-blog__inner {
  max-width: 1370px;
  margin: 0 auto;
  padding: 0 35px;
}
.irepair-blog .irepair-blog__title {
  margin: 39px 0 24px;
  padding: 0;
  font-family: 'Montserrat-Bold', Arial, sans-serif;
  font-size: 64px;
  line-height: 64px;
  font-weight: 400;
  text-transform: none;
  color: #010306;
}
.irepair-blog .irepair-blog__desc {
  font-family: 'Montserrat-Medium', Arial, sans-serif;
  font-size: 36px;
  line-height: 45px;
  color: #010306;
}
.irepair-blog .irepair-blog__items {
  margin-top: 20px;
}
.irepair-blog .irepair-blog__item {
  display: flex;
  align-items: center;
  margin-top: 40px;
  padding: 50px;
  background: #ffffff;
  border-radius: 3px;
  box-shadow: 0 4px 40px rgba(0, 0, 0, 0.15);
}
.irepair-blog .irepair-blog__item-image {
  display: block;
  flex: 0 0 auto;
  width: 45%;
  min-width: 480px;
  margin-right: 50px;
  overflow: hidden;
  border-radius: 3px;
}
.irepair-blog .irepair-blog__item-image img {
  display: block;
  width: 100% !important;
  max-width: none;
  height: auto;
}
.irepair-blog .irepair-blog__item-content {
  min-width: 0;
}
.irepair-blog .irepair-blog__item-title,
.irepair-blog .irepair-blog__item-title a {
  margin: 0 0 24px;
  padding: 0;
  font-family: 'Montserrat-SemiBold', 'Montserrat-Bold', Arial, sans-serif !important;
  font-size: 28px !important;
  line-height: 30px !important;
  font-weight: 400 !important;
  text-transform: none;
}
.irepair-blog .irepair-blog__item-title a {
  margin: 0;
  color: #000000;
  text-decoration: none;
  transition: color 0.3s;
}
.irepair-blog .irepair-blog__item-title a:hover {
  color: #37d97b;
}
.irepair-blog .irepair-blog__item-text {
  margin: 0 0 24px;
  font-family: 'Roboto', Arial, sans-serif !important;
  font-size: 20px !important;
  line-height: 28px !important;
  font-weight: 300;
  color: #5c5b5b;
}
.irepair-blog .irepair-blog__item-more {
  display: inline-flex;
  align-items: center;
  text-decoration: none;
}
.irepair-blog .irepair-blog__item-more span {
  margin-right: 10px;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 18px;
  line-height: 20px;
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
  .irepair-blog .irepair-blog__title {
    margin: 36px 0 16px;
    font-size: 48px;
    line-height: 48px;
  }
  .irepair-blog .irepair-blog__desc {
    font-size: 26px;
    line-height: 34px;
  }
  .irepair-blog .irepair-blog__items {
    margin-top: 16px;
  }
  .irepair-blog .irepair-blog__item {
    flex-wrap: wrap;
    padding: 0;
  }
  /* картинка целиком (без обрезки): во всю ширину карточки, высота — по пропорциям */
  .irepair-blog .irepair-blog__item-image {
    width: 100%;
    min-width: 100%;
    margin-right: 0;
    border-radius: 3px 3px 0 0;
  }
  .irepair-blog .irepair-blog__item-image img {
    height: auto;
  }
  .irepair-blog .irepair-blog__item-content {
    padding: 32px;
  }
  .irepair-blog .irepair-blog__item-title,
  .irepair-blog .irepair-blog__item-title a {
    font-size: 22px !important;
    line-height: 26px !important;
  }
  .irepair-blog .irepair-blog__item-title {
    margin-bottom: 16px;
  }
  .irepair-blog .irepair-blog__item-text {
    font-size: 18px !important;
  }
}
@media (max-width: 767px) {
  .irepair-blog .irepair-blog__inner {
    padding: 0 16px;
  }
}
@media (max-width: 639px) {
  .irepair-blog {
    padding-bottom: 60px;
  }
  .irepair-blog .irepair-blog__title {
    margin-top: 24px;
    font-size: 36px;
    line-height: 36px;
  }
  .irepair-blog .irepair-blog__desc {
    font-size: 20px;
    line-height: 28px;
  }
  .irepair-blog .irepair-blog__desc br {
    display: none;
  }
  .irepair-blog .irepair-blog__item-content {
    padding: 16px 16px 32px;
  }
  .irepair-blog .irepair-blog__item-title,
  .irepair-blog .irepair-blog__item-title a {
    font-size: 18px !important;
    line-height: 22px !important;
  }
  .irepair-blog .irepair-blog__item-text {
    font-size: 16px !important;
    line-height: 24px !important;
  }
  .irepair-blog .irepair-blog__item-more span {
    font-size: 16px;
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
                        {if $irp_src}
                            <span class="irepair-blog-rel__image"><img src="{$irp_src}" alt="{$irp_p.page}" loading="lazy"></span>
                        {/if}
                        <span class="irepair-blog-rel__name">{$irp_p.page}</span>
                        <span class="irepair-blog-rel__more">Читать полностью ›</span>
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
  padding: 0 0 24px;
  background: #ffffff;
  border-radius: 3px;
  box-shadow: 0 4px 40px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  text-decoration: none;
}
.irepair-blog-rel .irepair-blog-rel__image {
  display: block;
  aspect-ratio: 16 / 9;
  overflow: hidden;
}
.irepair-blog-rel .irepair-blog-rel__image img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.irepair-blog-rel .irepair-blog-rel__name {
  display: block;
  margin: 20px 24px 12px;
  font-family: 'Montserrat-SemiBold', 'Montserrat-Bold', Arial, sans-serif;
  font-size: 18px;
  line-height: 24px;
  color: #000000;
  transition: color 0.3s;
}
.irepair-blog-rel .irepair-blog-rel__item:hover .irepair-blog-rel__name {
  color: #37d97b;
}
.irepair-blog-rel .irepair-blog-rel__more {
  margin: auto 24px 0;
  font-family: 'Roboto', Arial, sans-serif;
  font-size: 16px;
  line-height: 20px;
  color: #37d97b;
}
@media (max-width: 900px) {
  .irepair-blog-rel .irepair-blog-rel__items {
    grid-template-columns: minmax(0, 1fr);
  }
}
@media (max-width: 639px) {
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

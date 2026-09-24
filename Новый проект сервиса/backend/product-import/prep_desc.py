"""Prepare an old OpenCart product description for CS-Cart full_description.

- unescape is done by the caller (DB stores HTML-escaped text)
- absolute irepair.ru href/src -> relative
- every CSS selector inside <style> prefixed with .mm-block (incl. @media)
- heading rules get !important, plus a guard block so theme heading styles
  (.ty-wysiwyg-content hN, .ut2-pb .tab-list-title ~ .ty-wysiwyg-content hN) can't override
"""
import re
import sys

ROOT = '.mm-block'
HEADING = re.compile(r'(^|[\s>+~,])h[1-6](?![\w-])|\.mm-h[1-6](?![\w-])')
GUARD = (
    '\n  /* CS-Cart theme guard: headings keep the block font */\n'
    '  .mm-block h1, .mm-block h2, .mm-block h3, .mm-block h4, .mm-block h5, .mm-block h6 '
    '{ font-family: inherit !important; font-weight: 700 !important; letter-spacing: normal !important; '
    'text-transform: none !important; }\n'
)


def prefix_selector(sel):
    sel = sel.strip()
    if not sel or sel.startswith(ROOT) and (len(sel) == len(ROOT) or sel[len(ROOT)] in ' .:>[#+~'):
        return sel
    return f'{ROOT} {sel}'


def importantize(decls):
    out = []
    for d in decls.split(';'):
        if not d.strip():
            continue
        out.append(d if '!important' in d else d.rstrip() + ' !important')
    return '; '.join(x.strip() for x in out) + ';'


def fix_css(css):
    def rule(m):
        sels, decls = m.group(1), m.group(2)
        if sels.strip().startswith('@') or re.fullmatch(r'\s*(from|to|\d+%)(\s*,\s*(from|to|\d+%))*\s*', sels):
            return m.group(0)
        lead = re.match(r'\s*', sels).group(0)
        new_sels = ', '.join(prefix_selector(s) for s in sels.split(','))
        if HEADING.search(sels):
            decls = ' ' + importantize(decls) + ' '
        return f'{lead}{new_sels} {{{decls}}}'

    # innermost rules only: selector{decls} where decls contain no braces
    css = re.sub(r'([^{}]+)\{([^{}]*)\}', rule, css)
    return css + GUARD


def prepare(html):
    html = re.sub(r'((?:href|src)=")https?://(?:www\.)?irepair\.ru/', r'\1/', html)
    return re.sub(r'(<style[^>]*>)(.*?)(</style>)',
                  lambda m: m.group(1) + fix_css(m.group(2)) + m.group(3), html, flags=re.S)


if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    open(dst, 'w', encoding='utf-8').write(prepare(open(src, encoding='utf-8').read()))

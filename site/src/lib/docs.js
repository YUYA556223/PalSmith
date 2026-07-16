import fs from 'fs';
import path from 'path';
import Markdoc from '@markdoc/markdoc';

const CONTENT_DIR = path.join(process.cwd(), 'content');

export const LANGS = ['en', 'ja'];

// Ordered navigation; titles per language.
export const NAV = [
  { slug: '', en: 'Overview', ja: '概要' },
  { slug: 'install', en: 'Installation', ja: 'インストール' },
  { slug: 'first-pack', en: 'Your First Pack', ja: 'はじめてのパック' },
  { slug: 'behaviors', en: 'Behaviors Reference', ja: 'Behaviorリファレンス' },
  { slug: 'meshes', en: 'Runtime Meshes', ja: 'ランタイムメッシュ' },
  { slug: 'pack-format', en: 'Pack Format', ja: 'パック形式' },
];

export function readDoc(lang, slug) {
  const name = slug === '' ? 'index' : slug;
  const file = path.join(CONTENT_DIR, lang, `${name}.md`);
  if (!fs.existsSync(file)) return null;
  const source = fs.readFileSync(file, 'utf8');
  const ast = Markdoc.parse(source);
  const frontmatter = ast.attributes.frontmatter
    ? Object.fromEntries(
        ast.attributes.frontmatter
          .split('\n')
          .map((l) => l.split(':').map((s) => s.trim()))
          .filter((p) => p.length === 2)
      )
    : {};
  const content = Markdoc.transform(ast);
  return { content, frontmatter };
}

export function allParams() {
  const params = [];
  for (const lang of LANGS) {
    for (const item of NAV) {
      params.push({ lang, slug: item.slug === '' ? [] : [item.slug] });
    }
  }
  return params;
}

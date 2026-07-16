import React from 'react';
import Link from 'next/link';
import Markdoc from '@markdoc/markdoc';
import { readDoc, allParams, NAV, LANGS } from '../../../lib/docs';

export function generateStaticParams() {
  return allParams();
}

export const dynamicParams = false;

export function generateMetadata({ params }) {
  const slug = (params.slug || []).join('/');
  const item = NAV.find((n) => n.slug === slug);
  const title = item ? `${item[params.lang] || item.en} - PalSmith` : 'PalSmith';
  return { title };
}

export default function DocPage({ params }) {
  const lang = LANGS.includes(params.lang) ? params.lang : 'en';
  const slug = (params.slug || []).join('/');
  const doc = readDoc(lang, slug);
  if (!doc) {
    return <div className="main">Not found.</div>;
  }
  const otherLang = lang === 'en' ? 'ja' : 'en';
  const otherLabel = lang === 'en' ? '日本語' : 'English';

  return (
    <div className="shell">
      <aside className="sidebar">
        <Link className="brand" href={`/${lang}/`}>PalSmith</Link>
        <nav>
          {NAV.map((item) => (
            <Link
              key={item.slug}
              href={`/${lang}/${item.slug ? item.slug + '/' : ''}`}
              className={item.slug === slug ? 'active' : ''}
            >
              {item[lang] || item.en}
            </Link>
          ))}
        </nav>
        <div className="langswitch">
          <Link href={`/${otherLang}/${slug ? slug + '/' : ''}`}>{otherLabel}</Link>
          <a href="https://github.com/YUYA556223/PalSmith">GitHub</a>
        </div>
      </aside>
      <main className="main">
        {Markdoc.renderers.react(doc.content, React)}
      </main>
    </div>
  );
}

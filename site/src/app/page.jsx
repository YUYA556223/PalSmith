import Link from 'next/link';

// Static-export friendly landing: offer both languages (no server redirect).
export default function Home() {
  return (
    <div style={{ padding: '4rem', textAlign: 'center' }}>
      <h1>PalSmith</h1>
      <p>Content framework mod for Palworld.</p>
      <p style={{ fontSize: '1.2rem' }}>
        <Link href="/en/">English</Link> ・ <Link href="/ja/">日本語</Link>
      </p>
    </div>
  );
}

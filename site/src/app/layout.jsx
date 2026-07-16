import './globals.css';

export const metadata = {
  title: 'PalSmith',
  description: 'Content framework mod for Palworld: items, behaviors, runtime meshes and UI with just JSON + PNG.',
};

export default function RootLayout({ children }) {
  return (
    <html>
      <body>{children}</body>
    </html>
  );
}

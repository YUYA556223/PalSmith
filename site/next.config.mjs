/** @type {import('next').NextConfig} */
const isCI = !!process.env.GITHUB_ACTIONS;

const nextConfig = {
  output: 'export',
  // GitHub Pages serves the site under /PalSmith
  basePath: isCI ? '/PalSmith' : '',
  images: { unoptimized: true },
  trailingSlash: true,
};

export default nextConfig;

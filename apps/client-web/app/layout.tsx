import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Slate · Your project delivery",
  description: "A private space to review your project, complete payment, and receive your final files.",
  robots: { index: false, follow: false },
  referrer: "no-referrer",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body>{children}</body></html>;
}

import { Taviraj, Noto_Sans_Thai } from "next/font/google";
import "./globals.css";
import BubbleWatermark from "@/components/BubbleWatermark";

const display = Taviraj({
  subsets: ["thai", "latin"],
  weight: ["600", "700"],
  variable: "--font-display",
  display: "swap",
});

const body = Noto_Sans_Thai({
  subsets: ["thai", "latin"],
  weight: ["400", "500", "600"],
  variable: "--font-body",
  display: "swap",
});

export const metadata = {
  title: "My Whale — บันทึกลูกน้อย",
  description: "แอปบันทึกและติดตามพัฒนาการลูกน้อยสำหรับครอบครัว",
  manifest: "/manifest.json",
  icons: {
    icon: [
      { url: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    apple: "/apple-touch-icon.png",
  },
};

export const viewport = {
  themeColor: "#2D3A4A",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }) {
  return (
    <html lang="th" className={`${display.variable} ${body.variable}`}>
      <body className="font-body min-h-screen antialiased">
        <BubbleWatermark />
        {children}
      </body>
    </html>
  );
}

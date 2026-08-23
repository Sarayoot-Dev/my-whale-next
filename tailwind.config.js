/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,jsx}",
    "./components/**/*.{js,jsx}",
  ],
  theme: {
    extend: {
      colors: {
        // "My Whale" — soft, friendly sky-blue palette (matches the ปลาวาฬ reference).
        surface: "#EAF4FB", // page background — pale sky blue
        shallow: "#D6ECFB", // chips, dividers, inactive states
        tide: "#4F9DDE",    // primary actions — bright friendly blue
        abyss: "#2D3A4A",   // headers, body text — soft navy, not harsh black
        glow: "#FFD166",    // single warm accent — golden star, used sparingly
      },
      fontFamily: {
        display: ["var(--font-display)"],
        body: ["var(--font-body)"],
      },
      borderRadius: {
        xl2: "1.25rem",
      },
      boxShadow: {
        log: "0 1px 2px rgba(45, 58, 74, 0.05), 0 6px 20px rgba(79, 157, 222, 0.10)",
      },
    },
  },
  plugins: [],
};

export default function WaveDivider({ className = "" }) {
  return (
    <svg
      viewBox="0 0 400 20"
      preserveAspectRatio="none"
      className={`h-3 w-full ${className}`}
      aria-hidden="true"
    >
      <path
        d="M0 10 Q 25 2, 50 10 T 100 10 T 150 10 T 200 10 T 250 10 T 300 10 T 350 10 T 400 10"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}

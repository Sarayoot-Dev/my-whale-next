export default function BubbleWatermark() {
  const bubbles = [
    { cx: 30, cy: 90, r: 22, o: 0.35 },
    { cx: 85, cy: 70, r: 10, o: 0.3 },
    { cx: 15, cy: 60, r: 7, o: 0.28 },
    { cx: 60, cy: 55, r: 16, o: 0.3 },
    { cx: 90, cy: 40, r: 6, o: 0.25 },
    { cx: 40, cy: 35, r: 9, o: 0.3 },
    { cx: 10, cy: 25, r: 14, o: 0.25 },
    { cx: 70, cy: 18, r: 5, o: 0.2 },
    { cx: 25, cy: 10, r: 6, o: 0.2 },
    { cx: 55, cy: 5, r: 11, o: 0.18 },
  ];

  return (
    <svg
      className="pointer-events-none fixed inset-0 -z-10 h-full w-full"
      viewBox="0 0 100 100"
      preserveAspectRatio="xMidYMax slice"
      aria-hidden="true"
    >
      {bubbles.map((b, i) => (
        <circle
          key={i}
          cx={b.cx}
          cy={b.cy}
          r={b.r}
          fill="#BFE1EC"
          fillOpacity={b.o}
        />
      ))}
    </svg>
  );
}

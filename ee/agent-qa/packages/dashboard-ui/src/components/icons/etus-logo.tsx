export function EtusLogo({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 64 64"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      <rect x="6" y="6" width="46" height="46" fill="currentColor" />
      <rect x="12" y="12" width="46" height="46" fill="#fff6f6" stroke="#313331" strokeWidth="4" />
      <path
        d="M24 23H46V29H31V34H44V40H31V47H24V23Z"
        fill="#cb222a"
      />
    </svg>
  )
}

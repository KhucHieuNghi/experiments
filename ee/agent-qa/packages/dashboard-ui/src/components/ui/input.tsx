import * as React from "react"

import { cn } from "@/lib/utils"

function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "h-9 w-full min-w-0 rounded-[var(--radius)] border-2 border-input bg-card px-3 py-1 text-base shadow-[2px_2px_0_var(--retro-shadow-color)] transition-[color,box-shadow,transform] outline-none selection:bg-primary selection:text-primary-foreground file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-bold file:text-foreground placeholder:text-muted-foreground disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 disabled:shadow-none md:text-sm",
        "focus-visible:-translate-x-0.5 focus-visible:-translate-y-0.5 focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/45",
        "aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40",
        className
      )}
      {...props}
    />
  )
}

export { Input }

/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "hsl(240 10% 3.9%)",
        foreground: "hsl(0 0% 98%)",
        card: "hsl(240 10% 3.9%)",
        "card-foreground": "hsl(0 0% 98%)",
        primary: "hsl(20 90% 50%)", // Оранжевый акцент (чакра)
        "primary-foreground": "hsl(60 9.1% 97.8%)",
        muted: "hsl(240 3.7% 15.9%)",
        "muted-foreground": "hsl(240 5% 64.9%)",
        border: "hsl(240 3.7% 15.9%)",
      },
    },
  },
  plugins: [],
}
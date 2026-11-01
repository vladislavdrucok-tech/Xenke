// Валютні пари й розмір піпса (без залежностей від Node — використовується і в браузері).
export const PAIRS = Object.freeze([
  { id: 'EUR/USD', base: 'EUR', quote: 'USD', spread: 0.0001 },
  { id: 'GBP/USD', base: 'GBP', quote: 'USD', spread: 0.00015 },
  { id: 'EUR/GBP', base: 'EUR', quote: 'GBP', spread: 0.00015 },
]);
export const PIP = 0.0001;

// Shared command-line argument checks for the harnesses (code review r3b #6: a bad run count must fail, not print NaN).
export function positiveInt(value, name = "runs") {
  const n = Number(value);
  if (!(Number.isInteger(n) && n > 0)) { console.error(`${name} must be a positive integer (got ${value})`); process.exit(2); }
  return n;
}

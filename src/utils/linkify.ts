/**
 * Splits plain text into runs, marking the ones that are links.
 *
 * Announcement bodies are written by hand and routinely end in "fill this form:
 * https://…". Returning parts rather than an HTML string keeps the rendering in
 * the template, so nothing user-written is ever fed to v-html.
 */
export interface TextPart {
  text: string;
  href?: string;
}

// http(s) URLs and bare www. hosts, stopping before trailing sentence punctuation.
const URL_RE = /((?:https?:\/\/|www\.)[^\s<]+[^\s<.,!?)\]}'"])/gi;

export function linkifyParts(text: string): TextPart[] {
  if (!text) return [];
  const parts: TextPart[] = [];
  let last = 0;

  for (const match of text.matchAll(URL_RE)) {
    const start = match.index ?? 0;
    if (start > last) parts.push({ text: text.slice(last, start) });
    const raw = match[0];
    parts.push({ text: raw, href: raw.startsWith('www.') ? `https://${raw}` : raw });
    last = start + raw.length;
  }

  if (last < text.length) parts.push({ text: text.slice(last) });
  return parts;
}

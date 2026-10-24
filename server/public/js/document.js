const PDFJS = "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build";

export const ACCEPT = ".pdf,.docx,.txt,.rtf,.md,.markdown,text/plain,application/pdf,application/rtf";

export async function extract(file) {
  const name = file.name;
  const ext = (name.split(".").pop() || "").toLowerCase();
  let text;

  if (["doc", "pages"].includes(ext)) throw new Error(`${ext.toUpperCase()} files aren't supported. Use PDF, DOCX, TXT, RTF, or Markdown.`);

  try {
    if (ext === "pdf") text = await pdfText(file);
    else if (ext === "docx") text = await docxText(file);
    else if (ext === "rtf") text = rtfText(await file.text());
    else text = await file.text();
  } catch (e) {
    throw new Error(`Couldn't read ${name}. Try exporting it as a PDF or plain text.`);
  }

  const cleaned = normalize(text || "");
  if (!cleaned) throw new Error("That file has no readable text in it.");
  return cleaned;
}

export function suggestedTitle(text, filename) {
  const firstLine = text.split("\n").map((l) => l.trim()).find((l) => l.length > 8);
  if (firstLine && firstLine.toLowerCase().startsWith("a bill")) return firstLine.slice(0, 160);
  if (firstLine && firstLine.length <= 160) return firstLine;
  return filename.replace(/\.[^.]+$/, "");
}

function normalize(text) {
  return text
    .replace(/\r\n?/g, "\n")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

async function pdfText(file) {
  const pdfjs = await import(`${PDFJS}/pdf.min.mjs`);
  pdfjs.GlobalWorkerOptions.workerSrc = `${PDFJS}/pdf.worker.min.mjs`;
  const doc = await pdfjs.getDocument({ data: new Uint8Array(await file.arrayBuffer()) }).promise;
  const pages = [];
  for (let i = 1; i <= doc.numPages; i++) {
    const content = await (await doc.getPage(i)).getTextContent();
    pages.push(content.items.map((item) => item.str + (item.hasEOL ? "\n" : "")).join(""));
  }
  return pages.join("\n");
}

function rtfText(rtf) {
  return rtf
    .replace(/\\par[d]?/g, "\n")
    .replace(/\\'([0-9a-f]{2})/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/\{\\\*[^{}]*\}/g, "")
    .replace(/\\[a-z]+-?\d* ?/gi, "")
    .replace(/[{}]/g, "");
}

async function docxText(file) {
  const xml = await zipEntry(new Uint8Array(await file.arrayBuffer()), "word/document.xml");
  if (!xml) throw new Error("No document body");
  const text = new TextDecoder().decode(xml)
    .replace(/<\/w:p>/g, "\n")
    .replace(/<w:br\/>/g, "\n")
    .replace(/<w:tab\/>/g, " ")
    .replace(/<[^>]+>/g, "");
  return text
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, "&");
}

async function zipEntry(bytes, target) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const u16 = (o) => view.getUint16(o, true);
  const u32 = (o) => view.getUint32(o, true);
  if (bytes.length <= 22) return null;

  let eocd = -1;
  for (let i = bytes.length - 22, limit = Math.max(0, bytes.length - 66_000); i >= limit; i--) {
    if (u32(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) return null;

  const count = u16(eocd + 10);
  let offset = u32(eocd + 16);
  for (let n = 0; n < count; n++) {
    if (offset + 46 > bytes.length || u32(offset) !== 0x02014b50) return null;
    const method = u16(offset + 10);
    const compressedSize = u32(offset + 20);
    const nameLength = u16(offset + 28);
    const extraLength = u16(offset + 30);
    const commentLength = u16(offset + 32);
    const localOffset = u32(offset + 42);
    const name = new TextDecoder().decode(bytes.subarray(offset + 46, offset + 46 + nameLength));

    if (name === target) {
      if (u32(localOffset) !== 0x04034b50) return null;
      const start = localOffset + 30 + u16(localOffset + 26) + u16(localOffset + 28);
      const payload = bytes.subarray(start, start + compressedSize);
      if (method === 0) return payload;
      if (method !== 8) return null;
      const stream = new Blob([payload]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
      return new Uint8Array(await new Response(stream).arrayBuffer());
    }
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return null;
}

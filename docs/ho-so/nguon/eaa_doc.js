// Bộ dựng tài liệu theo chuẩn hồ sơ EAA (Times New Roman 13, tiêu đề navy 1F3864, bảng header navy/chữ trắng, dòng xen F2F6FB)
const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, AlignmentType,
  ShadingType, BorderStyle, PageBreak, Header, Footer, PageNumber, VerticalAlign, ImageRun, LevelFormat
} = require('docx');

const FONT = 'Times New Roman', SZ = 26, LINE = 360, NAVY = '1F3864', ALT = 'F2F6FB';
const run = (t, o = {}) => new TextRun({ text: t, font: FONT, size: o.size || SZ, bold: o.bold, italics: o.italics, color: o.color });

// Inline markup: **bold**, *italic*
function inline(text, o = {}) {
  const out = []; const re = /(\*\*(?=\S)[^*]+?(?<=\S)\*\*|\*(?=[^\s*,])[^*]+?(?<=\S)\*)/g; let last = 0, m;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(run(text.slice(last, m.index), o));
    const s = m[0];
    if (s.startsWith('**')) out.push(run(s.slice(2, -2), { ...o, bold: true }));
    else out.push(run(s.slice(1, -1), { ...o, italics: true }));
    last = m.index + s.length;
  }
  if (last < text.length) out.push(run(text.slice(last), o));
  return out;
}
const P = (t, o = {}) => new Paragraph({ children: inline(t, o), alignment: o.align || AlignmentType.JUSTIFIED, spacing: { line: LINE, after: o.after ?? 120 }, indent: o.indent === false ? undefined : { firstLine: 0 }, numbering: o.bullet ? { reference: 'bul', level: 0 } : undefined });
const H1 = t => new Paragraph({ heading: HeadingLevel.HEADING_1, children: [run(t, { bold: true, size: 28, color: NAVY })], spacing: { before: 360, after: 160, line: LINE } });
const H2 = t => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [run(t, { bold: true, size: SZ, color: NAVY })], spacing: { before: 240, after: 120, line: LINE } });
const H3 = t => new Paragraph({ heading: HeadingLevel.HEADING_3, children: [run(t, { bold: true, italics: true, size: SZ, color: NAVY })], spacing: { before: 200, after: 100, line: LINE } });
const CAP = t => new Paragraph({ children: [run(t, { bold: true, italics: true, size: 24 })], alignment: AlignmentType.CENTER, spacing: { before: 80, after: 160 } });
const SP = () => new Paragraph({ children: [run('')], spacing: { after: 60 } });
const PB = () => new Paragraph({ children: [new PageBreak()] });
const CODE = lines => lines.map(l => new Paragraph({ children: [new TextRun({ text: l, font: 'Consolas', size: 19 })], spacing: { line: 240, after: 0 }, indent: { left: 567 } }));
const bd = { style: BorderStyle.SINGLE, size: 4, color: '7F7F7F' };
const borders = { top: bd, bottom: bd, left: bd, right: bd };
function cell(text, w, o = {}) {
  const paras = (Array.isArray(text) ? text : [text]).map(t => new Paragraph({ children: inline(t, { size: o.size || 21, bold: o.bold, color: o.color }), alignment: o.align || AlignmentType.LEFT, spacing: { line: 264, after: 30 } }));
  return new TableCell({ children: paras, width: { size: w, type: WidthType.DXA }, borders, shading: o.fill ? { type: ShadingType.CLEAR, fill: o.fill, color: 'auto' } : undefined, verticalAlign: VerticalAlign.TOP, margins: { top: 50, bottom: 50, left: 80, right: 80 } });
}
function T(widths, header, rows, o = {}) {
  const total = widths.reduce((a, b) => a + b, 0);
  const hr = new TableRow({ tableHeader: true, children: header.map((h, i) => cell(h, widths[i], { bold: true, fill: NAVY, color: 'FFFFFF', align: AlignmentType.CENTER, size: o.size })) });
  const brs = rows.map((r, ri) => new TableRow({ children: r.map((x, i) => cell(x, widths[i], { size: o.size, fill: ri % 2 ? ALT : undefined, bold: i === 0 && o.boldFirst !== false })) }));
  return new Table({ rows: [hr, ...brs], width: { size: total, type: WidthType.DXA }, columnWidths: widths });
}
// Bảng thuộc tính 2 cột (không header)
function KV(rows) {
  const w = [2600, 6700];
  return new Table({ rows: rows.map((r, i) => new TableRow({ children: [cell(r[0], w[0], { bold: true, fill: i % 2 ? ALT : undefined }), cell(r[1], w[1], { fill: i % 2 ? ALT : undefined })] })), width: { size: 9300, type: WidthType.DXA }, columnWidths: w });
}
function IMG(path, w, h, caption) {
  const out = [new Paragraph({ children: [new ImageRun({ type: 'png', data: fs.readFileSync(path), transformation: { width: w, height: h } })], alignment: AlignmentType.CENTER, spacing: { before: 120, after: 60 } })];
  if (caption) out.push(CAP(caption));
  return out;
}
function titleBlock(meta) {
  const c = [];
  c.push(new Paragraph({ children: [run(meta.kicker || 'EMBEDDED AIDD AGENT — NỀN TẢNG HỢP NHẤT EAA-U', { bold: true, size: 28, color: NAVY })], alignment: AlignmentType.CENTER, spacing: { after: 80 } }));
  c.push(new Paragraph({ children: [run(meta.title, { bold: true, size: 36 })], alignment: AlignmentType.CENTER, spacing: { after: 80 } }));
  c.push(new Paragraph({ children: [run(meta.subtitle, { italics: true, size: 22 })], alignment: AlignmentType.CENTER, spacing: { after: 240 } }));
  c.push(new Table({ rows: [
    new TableRow({ tableHeader: true, children: [cell('Thuộc tính', 2600, { bold: true, fill: NAVY, color: 'FFFFFF', align: AlignmentType.CENTER }), cell('Giá trị', 6700, { bold: true, fill: NAVY, color: 'FFFFFF', align: AlignmentType.CENTER })] }),
    ...meta.attrs.map((r, i) => new TableRow({ children: [cell(r[0], 2600, { bold: true, fill: i % 2 ? ALT : undefined }), cell(r[1], 6700, { fill: i % 2 ? ALT : undefined })] })),
  ], width: { size: 9300, type: WidthType.DXA }, columnWidths: [2600, 6700] }));
  c.push(SP());
  c.push(T([1500, 1700, 2100, 4000], ['Phiên bản', 'Ngày', 'Người sửa', 'Nội dung thay đổi'], meta.history));
  c.push(SP());
  return c;
}
function build(meta, children, outPath) {
  const doc = new Document({
    creator: 'Vũ Trí Công', title: meta.title,
    styles: { default: { document: { run: { font: FONT, size: SZ } } }, paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: 28, bold: true, color: NAVY }, paragraph: { spacing: { before: 360, after: 160 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: SZ, bold: true, color: NAVY }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 1 } },
      { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: SZ, bold: true, italics: true, color: NAVY }, paragraph: { spacing: { before: 200, after: 100 }, outlineLevel: 2 } },
    ] },
    numbering: { config: [{ reference: 'bul', levels: [{ level: 0, format: LevelFormat.BULLET, text: '–', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 567, hanging: 283 } } } }] }] },
    sections: [{
      properties: { page: { margin: { top: 1134, bottom: 1134, left: 1701, right: 1134 } } },
      headers: { default: new Header({ children: [new Paragraph({ children: [run(`${meta.code} · ${meta.short} · v${meta.version}`, { size: 20, italics: true, color: '595959' })], alignment: AlignmentType.RIGHT })] }) },
      footers: { default: new Footer({ children: [new Paragraph({ children: [run((meta.footer || 'Embedded AIDD Agent — Bộ hồ sơ thiết kế v2.0') + ' · Trang ', { size: 20, color: '595959' }), new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 20, color: '595959' })], alignment: AlignmentType.CENTER })] }) },
      children: [...titleBlock(meta), ...children],
    }],
  });
  return Packer.toBuffer(doc).then(buf => { fs.writeFileSync(outPath, buf); console.log('written', outPath); });
}
module.exports = { P, H1, H2, H3, CAP, SP, PB, CODE, T, KV, IMG, build, run };

import { Inject, Injectable } from '@nestjs/common';
import { WINSTON_MODULE_PROVIDER } from 'nest-winston';
import type { Logger } from 'winston';

export interface ExtractedPage {
  pageNumber: number;
  text: string;
}

export interface ExtractedPdf {
  pages: ExtractedPage[];
  fullText: string;
  pageCount: number;
}

// Wraps `pdfjs-dist` for Node-side text extraction. The legacy build is the
// supported entry for Node — the default export targets browsers and pulls in
// canvas/DOM globals. We dynamically import once on first use so the parser
// boot path stays cheap when the endpoint isn't called.
@Injectable()
export class PdfTextService {
  private pdfjsPromise: Promise<typeof import('pdfjs-dist/legacy/build/pdf.mjs')> | null =
    null;

  constructor(@Inject(WINSTON_MODULE_PROVIDER) private readonly logger: Logger) {}

  async extract(buffer: Buffer): Promise<ExtractedPdf> {
    const startedAt = Date.now();
    const pdfjs = await this.loadPdfjs();

    // pdfjs expects a Uint8Array view it can consume; convert from Node Buffer.
    const data = new Uint8Array(buffer.buffer, buffer.byteOffset, buffer.byteLength);

    const loadingTask = pdfjs.getDocument({
      data,
      // Suppress font-warning noise from coach-authored PDFs (they embed fonts
      // pdfjs can't always resolve cleanly in headless mode).
      verbosity: 0,
      useSystemFonts: false,
    });
    const doc = await loadingTask.promise;

    const pages: ExtractedPage[] = [];
    for (let i = 1; i <= doc.numPages; i++) {
      const page = await doc.getPage(i);
      const content = await page.getTextContent();
      const text = this.joinPageItems(content.items);
      pages.push({ pageNumber: i, text });
      page.cleanup();
    }
    await doc.cleanup();

    const fullText = pages.map((p) => p.text).join('\n');

    this.logger.debug({
      msg: 'pdf.extract',
      pageCount: doc.numPages,
      bytes: buffer.byteLength,
      durationMs: Date.now() - startedAt,
    });

    return { pages, pageCount: doc.numPages, fullText };
  }

  // pdfjs returns a flat list of TextItem/TextMarkedContent. We only care
  // about TextItem (has `str`); items with `hasEOL` mark a line break in the
  // visual layout.
  private joinPageItems(items: unknown[]): string {
    const out: string[] = [];
    for (const raw of items) {
      const item = raw as { str?: string; hasEOL?: boolean };
      if (typeof item.str === 'string') {
        out.push(item.str);
        if (item.hasEOL) out.push('\n');
      }
    }
    return out.join('').replace(/[ \t]+\n/g, '\n');
  }

  private loadPdfjs(): Promise<typeof import('pdfjs-dist/legacy/build/pdf.mjs')> {
    if (!this.pdfjsPromise) {
      this.pdfjsPromise = import('pdfjs-dist/legacy/build/pdf.mjs');
    }
    return this.pdfjsPromise;
  }
}

"""Checks a PDF written by the StageWebView report samples.

Usage: python check_report_pdf.py <report.pdf>

The report is a two-page document whose table breaks across the page. The
check passes when the PDF has exactly two pages, the table header row is on
both of them, and the last row and closing line are on the second.
"""

import sys

from pypdf import PdfReader

HEADER = ("Component", "Location", "Annual kWh")


def main() -> int:
    path = sys.argv[1]
    reader = PdfReader(path)
    pages = [page.extract_text() or "" for page in reader.pages]
    box = reader.pages[0].mediabox if pages else None
    print(f"{path}: {len(pages)} page(s), {float(box.width):.0f} x {float(box.height):.0f} pt" if box else f"{path}: no pages")

    problems = []
    if len(pages) != 2:
        problems.append(f"expected 2 pages, found {len(pages)}")

    for number, text in enumerate(pages, start=1):
        has_header = all(word in text for word in HEADER)
        print(f"  page {number}: {len(text.splitlines())} lines, header row {'present' if has_header else 'MISSING'}")
        if not has_header:
            problems.append(f"page {number} has no table header")

    if pages and "Annual energy summary" not in pages[0]:
        problems.append("page 1 has no title")

    if len(pages) >= 2 and ("Lighting 4" not in pages[-1] or "End of report" not in pages[-1]):
        problems.append("the last row or the closing line is not on the last page")

    for problem in problems:
        print(f"FAIL: {problem}")

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

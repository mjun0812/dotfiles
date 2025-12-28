---
name: summarize-pdf
description: "Summarize a PDF file.　WHEN: When user requests to summarize a PDF file, use this skill."
allowed-tools: Python(extract_txt_from_pdf.py:*), Read, Grep, Glob
---

# Summarize PDF

This skill is used to summarize a PDF file using Python script with `pymupdf` library.

## Task

1. extract text from the PDF file using `extract_txt_from_pdf.py` script:
   `./extract_txt_from_pdf.py <pdf_path>`
2. Using stdout of the script, summarize the text.
3. return the summary to the user.

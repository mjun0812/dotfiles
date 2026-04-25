#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#     "pymupdf",
# ]
# ///

import argparse

import pymupdf


def arg_parse() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf_path", type=str, help="Path to the PDF file to summarize")
    return parser.parse_args()


def main() -> None:
    args = arg_parse()

    pdf_path = args.pdf_path
    pdf = pymupdf.open(pdf_path)

    for page in pdf:
        text = page.get_text().replace("-\n", "")
        text = text.replace("\n", " ")
        print(text, end=" ")


if __name__ == "__main__":
    main()

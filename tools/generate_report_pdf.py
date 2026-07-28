#!/usr/bin/env python3
"""Genera el PDF reproducible de la práctica final a partir de Markdown."""

from __future__ import annotations

import re
from html import escape
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    Image,
    PageBreak,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "Practica_Final_SnackUp_1.1.0.pdf"
SOURCES = [
    ROOT / "docs" / "practica-final" / "REPORT.md",
    ROOT / "docs" / "testing" / "TEST_PLAN.md",
    ROOT / "docs" / "deployment" / "DEPLOYMENT.md",
    ROOT / "docs" / "release" / "RELEASE_1.1.0.md",
    ROOT / "docs" / "security" / "PRIVACY_REVIEW.md",
    ROOT / "docs" / "practica-final" / "EVIDENCE_CHECKLIST.md",
]

PRIMARY = colors.HexColor("#4A54DF")
ACCENT = colors.HexColor("#C942BA")
INK = colors.HexColor("#20243A")
MUTED = colors.HexColor("#5E6478")
PALE = colors.HexColor("#F1F2FF")
REGULAR_FONT = ROOT / "assets" / "fonts" / "Quicksand" / "static" / "Quicksand-Regular.ttf"
BOLD_FONT = ROOT / "assets" / "fonts" / "Quicksand" / "static" / "Quicksand-Bold.ttf"

pdfmetrics.registerFont(TTFont("SnackUpSans", str(REGULAR_FONT)))
pdfmetrics.registerFont(TTFont("SnackUpSans-Bold", str(BOLD_FONT)))


class SnackUpDocument(BaseDocTemplate):
    def __init__(self, filename: str) -> None:
        super().__init__(
            filename,
            pagesize=A4,
            leftMargin=18 * mm,
            rightMargin=18 * mm,
            topMargin=19 * mm,
            bottomMargin=18 * mm,
            title="Práctica Final SnackUp 1.1.0",
            author="Equipo SnackUp",
            subject="Reporte técnico de liberación segura",
        )
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            id="content",
        )
        self.addPageTemplates(
            PageTemplate(id="report", frames=[frame], onPage=self._decorate_page)
        )

    def _decorate_page(self, canvas, doc) -> None:
        canvas.saveState()
        canvas.setStrokeColor(PRIMARY)
        canvas.setLineWidth(1.2)
        canvas.line(
            self.leftMargin,
            A4[1] - 12 * mm,
            A4[0] - self.rightMargin,
            A4[1] - 12 * mm,
        )
        canvas.setFont("SnackUpSans", 8)
        canvas.setFillColor(MUTED)
        canvas.drawString(self.leftMargin, 10 * mm, "SnackUp - Práctica final")
        canvas.drawRightString(
            A4[0] - self.rightMargin,
            10 * mm,
            f"Página {doc.page}",
        )
        canvas.restoreState()


def _inline(text: str) -> str:
    links: list[tuple[str, str]] = []

    def remember_link(match: re.Match[str]) -> str:
        links.append((match.group(1), match.group(2)))
        return f"@@LINK{len(links) - 1}@@"

    text = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", remember_link, text)
    text = escape(text)
    text = re.sub(r"`([^`]+)`", r'<font name="Courier">\1</font>', text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    for index, (label, url) in enumerate(links):
        replacement = (
            f'<link href="{escape(url)}" color="#4A54DF">'
            f"{escape(label)}</link>"
        )
        text = text.replace(f"@@LINK{index}@@", replacement)
    return text


def _styles():
    sample = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "CoverTitle",
            parent=sample["Title"],
            fontName="SnackUpSans-Bold",
            fontSize=26,
            leading=31,
            textColor=PRIMARY,
            alignment=TA_CENTER,
            spaceAfter=8 * mm,
        ),
        "subtitle": ParagraphStyle(
            "CoverSubtitle",
            parent=sample["BodyText"],
            fontName="SnackUpSans",
            fontSize=12,
            leading=17,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
        "h1": ParagraphStyle(
            "Heading1SnackUp",
            parent=sample["Heading1"],
            fontName="SnackUpSans-Bold",
            fontSize=18,
            leading=22,
            textColor=PRIMARY,
            spaceBefore=6 * mm,
            spaceAfter=3 * mm,
        ),
        "h2": ParagraphStyle(
            "Heading2SnackUp",
            parent=sample["Heading2"],
            fontName="SnackUpSans-Bold",
            fontSize=14,
            leading=18,
            textColor=INK,
            spaceBefore=5 * mm,
            spaceAfter=2 * mm,
        ),
        "h3": ParagraphStyle(
            "Heading3SnackUp",
            parent=sample["Heading3"],
            fontName="SnackUpSans-Bold",
            fontSize=11,
            leading=14,
            textColor=ACCENT,
            spaceBefore=3 * mm,
            spaceAfter=1.5 * mm,
        ),
        "body": ParagraphStyle(
            "BodySnackUp",
            parent=sample["BodyText"],
            fontName="SnackUpSans",
            fontSize=9.3,
            leading=13.2,
            textColor=INK,
            alignment=TA_LEFT,
            spaceAfter=2.3 * mm,
        ),
        "bullet": ParagraphStyle(
            "BulletSnackUp",
            parent=sample["BodyText"],
            fontName="SnackUpSans",
            fontSize=9.1,
            leading=12.8,
            leftIndent=6 * mm,
            firstLineIndent=-3 * mm,
            textColor=INK,
            spaceAfter=1.5 * mm,
        ),
        "code": ParagraphStyle(
            "CodeSnackUp",
            parent=sample["Code"],
            fontName="Courier",
            fontSize=7.5,
            leading=10,
            leftIndent=4 * mm,
            rightIndent=4 * mm,
            borderColor=colors.HexColor("#D8DAE8"),
            borderWidth=0.5,
            borderPadding=3 * mm,
            backColor=colors.HexColor("#F7F7FA"),
            spaceBefore=2 * mm,
            spaceAfter=3 * mm,
        ),
        "table": ParagraphStyle(
            "TableSnackUp",
            parent=sample["BodyText"],
            fontName="SnackUpSans",
            fontSize=7.3,
            leading=9.5,
            textColor=INK,
        ),
    }


def _table(rows: list[list[str]], styles) -> Table:
    width = A4[0] - 36 * mm
    columns = max(len(row) for row in rows)
    normalized = [
        row + [""] * (columns - len(row))
        for row in rows
    ]
    data = [
        [Paragraph(_inline(cell), styles["table"]) for cell in row]
        for row in normalized
    ]
    table = Table(data, colWidths=[width / columns] * columns, repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), PRIMARY),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "SnackUpSans-Bold"),
                ("BACKGROUND", (0, 1), (-1, -1), colors.white),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PALE]),
                ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#CED1E1")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return table


def _markdown_story(path: Path, styles):
    story = []
    lines = path.read_text(encoding="utf-8").splitlines()
    index = 0
    in_code = False
    code_lines: list[str] = []

    while index < len(lines):
        line = lines[index]
        stripped = line.strip()

        if stripped.startswith("```"):
            if in_code:
                story.append(Preformatted("\n".join(code_lines), styles["code"]))
                code_lines = []
            in_code = not in_code
            index += 1
            continue
        if in_code:
            code_lines.append(line)
            index += 1
            continue
        if not stripped or stripped == "---":
            index += 1
            continue
        if stripped.startswith("|"):
            raw_rows = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                row = [
                    cell.strip()
                    for cell in lines[index].strip().strip("|").split("|")
                ]
                raw_rows.append(row)
                index += 1
            if len(raw_rows) > 1 and all(
                re.fullmatch(r":?-{3,}:?", cell) for cell in raw_rows[1]
            ):
                raw_rows.pop(1)
            story.append(_table(raw_rows, styles))
            story.append(Spacer(1, 3 * mm))
            continue
        heading = re.match(r"^(#{1,3})\s+(.+)$", stripped)
        if heading:
            level = len(heading.group(1))
            story.append(Paragraph(_inline(heading.group(2)), styles[f"h{level}"]))
            index += 1
            continue
        bullet = re.match(r"^[-*]\s+(.+)$", stripped)
        numbered = re.match(r"^(\d+)\.\s+(.+)$", stripped)
        checkbox = re.match(r"^-\s+\[([ xX])\]\s+(.+)$", stripped)
        if checkbox:
            mark = "✓" if checkbox.group(1).lower() == "x" else "□"
            story.append(
                Paragraph(f"{mark} {_inline(checkbox.group(2))}", styles["bullet"])
            )
        elif bullet:
            story.append(Paragraph(f"• {_inline(bullet.group(1))}", styles["bullet"]))
        elif numbered:
            story.append(
                Paragraph(
                    f"{numbered.group(1)}. {_inline(numbered.group(2))}",
                    styles["bullet"],
                )
            )
        else:
            paragraph_lines = [stripped]
            index += 1
            while index < len(lines):
                candidate = lines[index].strip()
                if (
                    not candidate
                    or candidate.startswith(("#", "|", "```", "- "))
                    or re.match(r"^\d+\.\s+", candidate)
                ):
                    break
                paragraph_lines.append(candidate)
                index += 1
            story.append(
                Paragraph(_inline(" ".join(paragraph_lines)), styles["body"])
            )
            continue
        index += 1

    return story


def build() -> None:
    styles = _styles()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    story = [Spacer(1, 18 * mm)]

    logo = ROOT / "assets" / "logo.png"
    if logo.exists():
        image = Image(str(logo), width=34 * mm, height=34 * mm)
        image.hAlign = "CENTER"
        story.extend([image, Spacer(1, 8 * mm)])

    story.extend(
        [
            Paragraph("Práctica Final SnackUp", styles["title"]),
            Paragraph(
                "Liberación segura, pruebas, Docker, Nginx y privacidad",
                styles["subtitle"],
            ),
            Spacer(1, 8 * mm),
            Table(
                [
                    ["Versión", "1.1.0+2 (candidato)"],
                    ["Fecha", "28 de julio de 2026"],
                    ["Rama", "agent/practica-final"],
                    ["Firebase", "snackup-8fe96"],
                ],
                colWidths=[35 * mm, 95 * mm],
                style=[
                    ("BACKGROUND", (0, 0), (0, -1), PRIMARY),
                    ("TEXTCOLOR", (0, 0), (0, -1), colors.white),
                    ("BACKGROUND", (1, 0), (1, -1), PALE),
                    ("TEXTCOLOR", (1, 0), (1, -1), INK),
                    ("FONTNAME", (0, 0), (0, -1), "SnackUpSans-Bold"),
                    ("FONTNAME", (1, 0), (1, -1), "SnackUpSans"),
                    ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#CED1E1")),
                    ("PADDING", (0, 0), (-1, -1), 7),
                ],
                hAlign="CENTER",
            ),
            Spacer(1, 10 * mm),
            Paragraph(
                "<b>ESTADO PRELIMINAR:</b> los resultados numéricos se "
                "actualizarán únicamente después de la ejecución real de CI.",
                ParagraphStyle(
                    "Notice",
                    parent=styles["body"],
                    backColor=colors.HexColor("#FFF4D6"),
                    borderColor=colors.HexColor("#F0B429"),
                    borderWidth=0.8,
                    borderPadding=4 * mm,
                    textColor=INK,
                ),
            ),
            PageBreak(),
        ]
    )

    for position, source in enumerate(SOURCES):
        if position:
            story.append(PageBreak())
        story.extend(_markdown_story(source, styles))

    SnackUpDocument(str(OUTPUT)).build(story)
    print(OUTPUT)


if __name__ == "__main__":
    build()

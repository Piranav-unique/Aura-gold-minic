from decimal import Decimal

from app.utils.report_export import (
    export_filename,
    rows_to_csv,
    rows_to_pdf,
    rows_to_xlsx,
)


def test_rows_to_csv():
    content = rows_to_csv(
        ["Name", "Amount"],
        [["Sale", Decimal("100.50")], ["Return", Decimal("-20.00")]],
    )
    assert "Name,Amount" in content
    assert "100.50" in content


def test_rows_to_xlsx():
    data = rows_to_xlsx(
        "Revenue",
        ["Date", "Revenue"],
        [["2026-06-01", "1000"]],
    )
    assert isinstance(data, bytes)
    assert len(data) > 100


def test_rows_to_pdf():
    data = rows_to_pdf(
        "Revenue Report",
        ["Date", "Revenue"],
        [["2026-06-01", "1000"]],
    )
    assert isinstance(data, bytes)
    assert data[:4] == b"%PDF"


def test_export_filename():
    name = export_filename("revenue", "csv")
    assert name.startswith("ags_revenue_report_")
    assert name.endswith(".csv")

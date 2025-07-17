from fpdf import FPDF
import os
import sys

# 🚀 Step 1: Ask user for comma-separated target file sizes with error handling
try:
    sizes_input = input("Enter target file sizes in MB (comma-separated, e.g., 1.2, 3.4, 2.0): ").strip()
    target_sizes = []
    for size in sizes_input.split(","):
        size = size.strip()
        if not size:
            continue
        try:
            value = float(size)
            if value <= 0:
                raise ValueError("Size must be positive")
            target_sizes.append(value)
        except ValueError:
            print(f"⚠️ Invalid input '{size}' skipped. Please enter numeric values.")
    if not target_sizes:
        raise ValueError("No valid sizes provided")
except KeyboardInterrupt:
    print("\n🚫 Input cancelled. Exiting.")
    sys.exit(1)

approx_text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " * 10
short_text = "Lorem ipsum. "
sections = [
    "Introduction",
    "Methodology",
    "Results and Discussion",
    "Conclusion",
    "References"
]

# 📏 Estimate bytes per text block (based on empirical testing or approximation)
BYTES_PER_APPROX_TEXT = 600  # Approximate bytes for `approx_text`
BYTES_PER_SHORT_TEXT = 20    # Approximate bytes for `short_text`
BYTES_PER_PAGE = 1000        # Base bytes per page (structure, fonts, etc.)

class PDF(FPDF):
    def footer(self):
        self.set_y(-15)
        self.set_font("Arial", "I", 10)
        page = f"Page {self.page_no()}"
        self.cell(0, 10, page, 0, 0, "C")

# 🚀 Process each requested size
for target_mb in target_sizes:
    target_bytes = int(target_mb * 1_000_000)  # Decimal MB for Explorer
    final_filename = f"Pdf_{target_mb:.1f}_MB.pdf"
    
    # 🛡️ Check if file exists
    if os.path.exists(final_filename):
        overwrite = input(f"⚠️ File '{final_filename}' already exists. Overwrite? (y/n): ").lower()
        if overwrite != 'y':
            print(f"⏭️ Skipping {final_filename}")
            continue

    pdf = PDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.set_font("Arial", size=12)

    # 📄 Cover page
    pdf.add_page()
    pdf.set_font("Arial", "B", 20)
    pdf.cell(0, 10, "Dummy Report", ln=True, align="C")
    pdf.ln(10)
    pdf.set_font("Arial", size=14)
    pdf.cell(0, 10, "Generated for testing large PDF files", ln=True, align="C")
    pdf.ln(20)

    # 📑 Table of contents
    pdf.set_font("Arial", "B", 16)
    pdf.cell(0, 10, "Table of Contents", ln=True)
    pdf.set_font("Arial", size=12)
    for idx, section in enumerate(sections, start=1):
        pdf.cell(0, 10, f"{idx}. {section} .......................... {idx+1}", ln=True)

    # 📝 Add each section
    for section in sections:
        pdf.add_page()
        pdf.set_font("Arial", "B", 16)
        pdf.cell(0, 10, section, ln=True)
        pdf.ln(5)
        pdf.set_font("Arial", size=12)

        if section == "References":
            references = [
                "Smith, J. (2021). Study on dummy data. Journal of Tests, 12(3), 45-67.",
                "Doe, A., & Roe, R. (2020). Generating large PDFs. Data Science Journal, 8(1), 12-19.",
                "Johnson, K. (2019). Dummy content methods. Computing Reports, 5(2), 78-83."
            ]
            for ref in references:
                pdf.multi_cell(0, 10, ref)
        else:
            for _ in range(3):
                pdf.multi_cell(0, 10, approx_text)

    # ➕ Estimate and add content to approach target size
    estimated_size = BYTES_PER_PAGE * pdf.page_no() + BYTES_PER_APPROX_TEXT * 3 * len(sections)
    remaining_bytes = target_bytes * 0.97 - estimated_size

    if remaining_bytes > 0:
        # Estimate number of pages with approx_text
        pages_needed = int(remaining_bytes // (BYTES_PER_PAGE + 5 * BYTES_PER_APPROX_TEXT))
        for _ in range(pages_needed):
            pdf.add_page()
            for _ in range(5):
                pdf.multi_cell(0, 10, approx_text)
        # Fine-tune with short_text
        estimated_size += pages_needed * (BYTES_PER_PAGE + 5 * BYTES_PER_APPROX_TEXT)
        short_texts_needed = int((target_bytes - estimated_size) // BYTES_PER_SHORT_TEXT)
        for _ in range(max(0, short_texts_needed)):
            pdf.multi_cell(0, 10, short_text)

    # 📝 Save temp file
    pdf.output(final_filename)

    # 📦 Pad the file to exact target_bytes
    final_size = os.path.getsize(final_filename)
    if final_size < target_bytes:
        with open(final_filename, "ab") as f:
            pad_size = target_bytes - final_size
            f.write(b" " * pad_size)

    # ✅ Report
    final_bytes = os.path.getsize(final_filename)
    final_mb_decimal = final_bytes / 1_000_000
    final_mb_binary = final_bytes / (1024*1024)

    print(f"\n✅ PDF generated: {final_filename}")
    print(f"📦 File size (decimal): {final_mb_decimal:.2f} MB (shown in Explorer)")
    print(f"📦 File size (binary): {final_mb_binary:.2f} MiB")
    print(f"🎉 Path: {os.path.abspath(final_filename)}")

print("\n✅ All PDFs done!")
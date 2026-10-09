"""
app.py
Flask Web Server và bộ điều khiển trung tâm của hệ thống điểm danh
bằng nhận diện khuôn mặt (mô phỏng).

Luồng xử lý khi nhận tín hiệu SCAN từ điện thoại:
  1. Gọi generate.py -> sinh Face Feature giả lập, ghi ra input.txt
  2. Biên dịch + chạy mô phỏng Verilog (iverilog + vvp) trên matcher_tb.v/matcher.v
  3. Đọc kết quả so khớp từ output.txt (mã SV hoặc UNKNOWN)
  4. Nếu nhận diện được -> truy vấn PostgreSQL lấy thông tin sinh viên
  5. Lưu bản ghi điểm danh vào LichSuDiemDanh
  6. Trả kết quả JSON để giao diện web hiển thị

LƯU Ý: app.py KHÔNG nhận và KHÔNG xử lý ảnh từ điện thoại.
Điện thoại chỉ gửi tín hiệu quét (SCAN), không gửi ảnh.
"""

import os
import subprocess
import datetime

from flask import Flask, render_template, jsonify

import generate  

try:
    import psycopg2
    PSYCOPG2_AVAILABLE = True
except ImportError:
    PSYCOPG2_AVAILABLE = False


# ----------------------------------------------------------------------------
# CẤU HÌNH ĐƯỜNG DẪN
# ----------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
VERILOG_DIR = os.path.join(BASE_DIR, "..", "verilog")
INPUT_FILE = os.path.join(VERILOG_DIR, "input.txt")
REGISTERED_FILE = os.path.join(VERILOG_DIR, "registered.txt")
OUTPUT_FILE = os.path.join(VERILOG_DIR, "output.txt")
SIM_BINARY = "sim.out"

# ----------------------------------------------------------------------------
# CẤU HÌNH POSTGRESQL
# ----------------------------------------------------------------------------
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "diem_danh",
    "user": "postgres",
    "password": "thuynga",
}


def get_db_connection():
    """Mở kết nối tới PostgreSQL. Trả về None nếu không kết nối được,
    để hệ thống vẫn chạy được ở chế độ demo khi chưa cấu hình CSDL."""
    if not PSYCOPG2_AVAILABLE:
        return None
    try:
        return psycopg2.connect(
            host=DB_CONFIG["host"],
            port=DB_CONFIG["port"],
            dbname=DB_CONFIG["dbname"],
            user=DB_CONFIG["user"],
            password=DB_CONFIG["password"],
            connect_timeout=3,
        )
    except Exception as exc:  
        print(f"[PostgreSQL] Không kết nối được CSDL: {exc}")
        return None


# ----------------------------------------------------------------------------
# FLASK APP
# ----------------------------------------------------------------------------
app = Flask(
    __name__,
    template_folder=os.path.join(BASE_DIR, "..", "web", "templates"),
    static_folder=os.path.join(BASE_DIR, "..", "web", "templates"),
    static_url_path="/static",
)


@app.route("/")
def index():
    """Trả về giao diện web dùng trên điện thoại."""
    return render_template("index.html")


@app.route("/api/scan", methods=["POST"])
def api_scan():
    """
    Nhận tín hiệu SCAN từ điện thoại (không kèm ảnh).
    Thực hiện toàn bộ pipeline: sinh Face Feature -> so khớp Verilog
    -> truy vấn CSDL -> lưu điểm danh -> trả kết quả cho giao diện web.
    """
 
    conn = get_db_connection()
    try:
        # Bước 1: sinh Face Feature giả lập (generate.py), ghi ra input.txt
        generate.scan(input_path=INPUT_FILE, registered_path=REGISTERED_FILE, conn=conn)

        # Bước 2 + 3: chạy mô phỏng Verilog, lấy kết quả so khớp
        ma_sv = run_verilog_matching()

        # Bước 4: xử lý kết quả UNKNOWN
        if ma_sv == "UNKNOWN":
            return jsonify({
                "success": True,
                "ma_sinh_vien": None,
                "ho_ten": None,
                "lop": None,
                "trang_thai": "Không xác định",
                "ket_qua": "UNKNOWN",
            })

        # Bước 4 (tiếp) + 5: nhận diện thành công -> lấy thông tin + lưu điểm danh
        student = get_student_info(ma_sv, conn=conn)
        save_attendance(ma_sv, "Có mặt", conn=conn)

        return jsonify({
            "success": True,
            "ma_sinh_vien": ma_sv,
            "ho_ten": student["ho_ten"] if student else None,
            "lop": student["lop"] if student else None,
            "trang_thai": "Có mặt",
            "ket_qua": ma_sv,
        })

    except subprocess.CalledProcessError as exc:
        return jsonify({"success": False, "error": f"Lỗi mô phỏng Verilog: {exc}"}), 500
    except Exception as exc:  
        return jsonify({"success": False, "error": str(exc)}), 500
    finally:
        if conn is not None:
            conn.close()


def run_verilog_matching():
    """
    Biên dịch và chạy mô phỏng matcher.v + matcher_tb.v bằng Icarus Verilog.
    matcher_tb.v tự đọc input.txt và ghi kết quả ra output.txt.
    Trả về mã sinh viên (str) hoặc "UNKNOWN".
    """
    subprocess.run(
        ["iverilog", "-o", SIM_BINARY, "matcher_tb.v", "matcher.v"],
        cwd=VERILOG_DIR,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["vvp", SIM_BINARY],
        cwd=VERILOG_DIR,
        check=True,
        capture_output=True,
    )

    with open(OUTPUT_FILE, "r") as f:
        result = f.read().strip()

    return result


def get_student_info(ma_sv, conn=None):
    """Truy vấn PostgreSQL lấy thông tin sinh viên theo mã sinh viên"""
    own_conn = conn is None
    if own_conn:
        conn = get_db_connection()
    if conn is None:
        return None

    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT HoTen, Lop FROM SinhVien WHERE MaSinhVien = %s", (ma_sv,)
        )
        row = cursor.fetchone()
        if row is None:
            return None
        return {"ho_ten": row[0], "lop": row[1]}
    finally:
        if own_conn:
            conn.close()


def save_attendance(ma_sv, trang_thai, conn=None):
    """Lưu một bản ghi điểm danh mới vào bảng LichSuDiemDanh"""
    own_conn = conn is None
    if own_conn:
        conn = get_db_connection()
    if conn is None:
        print(f"[Điểm danh] (Không lưu CSDL) {ma_sv} - {trang_thai} - {datetime.datetime.now()}")
        return

    try:
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO LichSuDiemDanh (MaSinhVien, ThoiGian, TrangThai) VALUES (%s, %s, %s)",
            (ma_sv, datetime.datetime.now(), trang_thai),
        )
        conn.commit()
    finally:
        if own_conn:
            conn.close()


def get_attendance_history(limit=50):
    """Lấy danh sách các lượt điểm danh gần nhất, kèm thông tin sinh viên"""
    conn = get_db_connection()
    if conn is None:
        return []

    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT ls.MaDiemDanh, ls.MaSinhVien, sv.HoTen, sv.Lop, ls.ThoiGian, ls.TrangThai
            FROM LichSuDiemDanh ls
            LEFT JOIN SinhVien sv ON sv.MaSinhVien = ls.MaSinhVien
            ORDER BY ls.ThoiGian DESC
            LIMIT %s
            """,
            (limit,),
        )
        rows = cursor.fetchall()
        return [
            {
                "ma_diem_danh": row[0],
                "ma_sinh_vien": row[1],
                "ho_ten": row[2],
                "lop": row[3],
                "thoi_gian": row[4].strftime("%Y-%m-%d %H:%M:%S") if row[4] else None,
                "trang_thai": row[5],
            }
            for row in rows
        ]
    finally:
        conn.close()


def clear_attendance_history(conn=None):
    """Xóa toàn bộ lịch sử điểm danh. Trả về số bản ghi đã xóa"""
    own_conn = conn is None
    if own_conn:
        conn = get_db_connection()
    if conn is None:
        return 0

    try:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM LichSuDiemDanh")
        deleted = cursor.rowcount
        conn.commit()
        return deleted
    finally:
        if own_conn:
            conn.close()


def delete_attendance_record(ma_diem_danh, conn=None):
    """Xóa một bản ghi điểm danh cụ thể theo MaDiemDanh.
    Trả về True nếu xóa được (tìm thấy bản ghi), False nếu không"""
    own_conn = conn is None
    if own_conn:
        conn = get_db_connection()
    if conn is None:
        return False

    try:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM LichSuDiemDanh WHERE MaDiemDanh = %s", (ma_diem_danh,))
        deleted = cursor.rowcount > 0
        conn.commit()
        return deleted
    finally:
        if own_conn:
            conn.close()


@app.route("/api/history")
def api_history():
    """Trả về lịch sử điểm danh gần nhất (JSON) để giao diện web hiển thị dạng bảng."""
    history = get_attendance_history()
    return jsonify({"success": True, "history": history})


@app.route("/api/history", methods=["DELETE"])
def api_history_clear():
    """Xóa toàn bộ lịch sử điểm danh."""
    deleted = clear_attendance_history()
    return jsonify({"success": True, "deleted": deleted})


@app.route("/api/history/<int:ma_diem_danh>", methods=["DELETE"])
def api_history_delete_one(ma_diem_danh):
    """Xóa một bản ghi điểm danh cụ thể theo MaDiemDanh."""
    deleted = delete_attendance_record(ma_diem_danh)
    if not deleted:
        return jsonify({"success": False, "error": "Không tìm thấy bản ghi"}), 404
    return jsonify({"success": True})


if __name__ == "__main__":

    app.run(host="0.0.0.0", port=5000, debug=True, ssl_context="adhoc")

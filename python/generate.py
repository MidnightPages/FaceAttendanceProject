"""
generate.py
Sinh Face Feature giả lập để mô phỏng dữ liệu khuôn mặt khi quét.
Không thực hiện nhận diện khuôn mặt thật.

Face Feature "gốc" của các sinh viên đã đăng ký được LẤY TỪ CSDL
(bảng DuLieuKhuonMat, cột DacTrungKhuonMat - dạng chuỗi "f0,f1,f2,f3",
khớp với database.sql). Nếu không kết nối được CSDL, dùng bộ dữ liệu
dự phòng (FALLBACK_FEATURES) để hệ thống vẫn chạy được ở chế độ demo.

CSDL: PostgreSQL (dùng thư viện psycopg2).
"""

import random
import sys

try:
    import psycopg2
    PSYCOPG2_AVAILABLE = True
except ImportError:
    PSYCOPG2_AVAILABLE = False


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

# Dữ liệu dự phòng, CHỈ dùng khi không kết nối được CSDL (demo/offline)
FALLBACK_FEATURES = {
    "SV001": [0.12, -0.35, 0.87, 0.41],
    "SV002": [0.54, 0.21, 0.73, 0.18],
    "SV003": [0.31, 0.65, -0.24, 0.82],
}

# Số sinh viên tối đa matcher.v hỗ trợ cùng lúc
MAX_STUDENTS = 16

# Hệ số lượng tử hóa: chuyển số thực sang số nguyên cho Verilog
SCALE = 1000

# Biên độ nhiễu ngẫu nhiên khi mô phỏng một sinh viên đã đăng ký
NOISE_LEVEL = 0.03


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
    except Exception as exc:  # noqa: BLE001
        print(f"[PostgreSQL] Không kết nối được CSDL: {exc}")
        return None


def load_registered_features(conn=None):
    """
    Đọc Face Feature đã đăng ký từ bảng DuLieuKhuonMat.
    Trả về dict {MaSinhVien: [f0, f1, f2, f3]}.

    Nếu không đọc được từ CSDL (mất kết nối, bảng rỗng, dữ liệu lỗi định dạng),
    dùng FALLBACK_FEATURES để hệ thống vẫn hoạt động được ở chế độ demo.
    """
    own_conn = conn is None
    if own_conn:
        conn = get_db_connection()
    if conn is None:
        return dict(FALLBACK_FEATURES)

    try:
        cursor = conn.cursor()
        cursor.execute("SELECT MaSinhVien, DacTrungKhuonMat FROM DuLieuKhuonMat")
        rows = cursor.fetchall()

        features = {}
        for ma_sv, dac_trung in rows:
            try:
                features[ma_sv] = [float(x) for x in dac_trung.split(",")]
            except (ValueError, AttributeError):
                print(f"[generate.py] Bỏ qua Face Feature lỗi định dạng cho {ma_sv}")

        if not features:
            print("[generate.py] Bảng DuLieuKhuonMat rỗng hoặc không đọc được, dùng dữ liệu dự phòng")
            return dict(FALLBACK_FEATURES)

        return features
    except Exception as exc:  # noqa: BLE001
        print(f"[generate.py] Lỗi khi đọc DuLieuKhuonMat: {exc}, dùng dữ liệu dự phòng")
        return dict(FALLBACK_FEATURES)
    finally:
        if own_conn:
            conn.close()


def write_registered_features(features, path="registered.txt", scale=SCALE):
    """
    Ghi TOÀN BỘ danh sách sinh viên đã đăng ký ra file, để matcher_tb.v nạp vào
    matcher.v mỗi lần mô phỏng. matcher.v giờ đọc số lượng sinh viên ĐỘNG từ file
    này qua matcher_tb.v.

    Trả về số sinh viên thực tế đã ghi
    """
    items = list(features.items())
    if len(items) > MAX_STUDENTS:
        print(
            f"[generate.py] Cảnh báo: có {len(items)} sinh viên, vượt MAX_STUDENTS="
            f"{MAX_STUDENTS} của matcher.v, chỉ ghi {MAX_STUDENTS} sinh viên đầu tiên"
        )
        items = items[:MAX_STUDENTS]

    lines = [str(len(items))]
    for ma_sv, feat in items:
        q = quantize(feat, scale)
        lines.append(f"{ma_sv} " + " ".join(str(v) for v in q))

    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")

    return len(items)


def _add_noise(feature, noise_level=NOISE_LEVEL):
    """Thêm nhiễu ngẫu nhiên nhỏ vào Face Feature gốc của sinh viên đã đăng ký."""
    return [round(x + random.uniform(-noise_level, noise_level), 4) for x in feature]


def _random_unknown_feature():
    """Sinh Face Feature hoàn toàn ngẫu nhiên, đại diện cho người lạ (không có trong CSDL)."""
    return [round(random.uniform(-1.0, 1.0), 4) for _ in range(4)]


def generate_feature(known_probability=0.75, conn=None):
    """
    Sinh một Face Feature giả lập cho một lượt quét.
    Face Feature gốc của sinh viên đã đăng ký được lấy từ CSDL qua load_registered_features().

    Trả về: (ma_sv_mo_phong, feature)
    """
    registered = load_registered_features(conn=conn)

    if registered and random.random() < known_probability:
        ma_sv = random.choice(list(registered.keys()))
        feature = _add_noise(registered[ma_sv])
        return ma_sv, feature
    return "UNKNOWN", _random_unknown_feature()


def quantize(feature, scale=SCALE):
    """Chuyển Face Feature từ số thực sang số nguyên đã lượng tử hóa cho matcher.v."""
    return [int(round(x * scale)) for x in feature]


def write_feature_to_file(feature, path="input.txt"):
    """Ghi Face Feature (đã lượng tử hóa) ra file, theo định dạng matcher_tb.v đọc bằng $fscanf."""
    quantized = quantize(feature)
    with open(path, "w") as f:
        f.write(" ".join(str(v) for v in quantized))
    return quantized


def scan(known_probability=0.75, input_path="input.txt", registered_path="registered.txt", conn=None):
    """
    Hàm chính được app.py gọi khi nhận tín hiệu SCAN từ điện thoại.

    Ghi ra 2 file để matcher_tb.v đọc:
      - input_path      : Face Feature cần nhận diện (1 sinh viên hoặc người lạ)
      - registered_path : TOÀN BỘ danh sách sinh viên đã đăng ký (để matcher.v so
                           khớp động, xem write_registered_features())
    """
    registered = load_registered_features(conn=conn)
    num_registered = write_registered_features(registered, registered_path)

    if registered and random.random() < known_probability:
        ma_sv_mo_phong = random.choice(list(registered.keys()))
        feature = _add_noise(registered[ma_sv_mo_phong])
    else:
        ma_sv_mo_phong = "UNKNOWN"
        feature = _random_unknown_feature()

    quantized = write_feature_to_file(feature, input_path)

    return {
        "ma_sv_mo_phong": ma_sv_mo_phong,
        "feature": feature,
        "feature_quantized": quantized,
        "input_path": input_path,
        "registered_path": registered_path,
        "num_registered": num_registered,
    }


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "input.txt"
    reg_path = sys.argv[2] if len(sys.argv) > 2 else "registered.txt"
    result = scan(input_path=path, registered_path=reg_path)

    print("Face Feature giả lập đã được sinh:")
    print(f"  (Mô phỏng theo: {result['ma_sv_mo_phong']})")
    print(f"  Feature gốc          : {result['feature']}")
    print(f"  Feature lượng tử hóa : {result['feature_quantized']}")
    print(f"  Đã ghi vào file      : {result['input_path']}")
    print(f"  Số sinh viên đã đăng ký: {result['num_registered']} (ghi vào {result['registered_path']})")

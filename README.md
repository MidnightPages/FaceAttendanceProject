# Hệ thống mô phỏng điểm danh bằng nhận diện khuôn mặt (Verilog)

Đồ án mô phỏng một hệ thống điểm danh sinh viên bằng nhận diện khuôn mặt, trong đó
**Verilog đảm nhiệm phần so khớp (matching)**, còn Python và PostgreSQL đảm nhiệm điều
khiển hệ thống, sinh dữ liệu mô phỏng và lưu trữ.

> **Đây là bản mô phỏng**: hệ thống không xử lý nhận diện khuôn mặt thật bằng thuật
> toán AI. Ảnh chụp từ camera chỉ hiển thị trên giao diện để minh họa thao tác
> quét — Face Feature thực tế được **sinh giả lập** bởi `generate.py`.

## 1. Cấu trúc thư mục

```
FaceID/
├── python/
│   ├── app.py            # Flask server, điều khiển trung tâm
│   └── generate.py       # Sinh Face Feature giả lập
│
├── verilog/
│   ├── matcher.v          # Module so khớp Face Feature
│   └── matcher_tb.v       # Testbench: đọc input.txt + registered.txt, ghi output.txt
│
├── web/
│   └── templates/
│       ├── index.html     # Giao diện web dùng trên điện thoại
│       └── style.css
│
├── database
│   └── database.sql           # Script tạo CSDL PostgreSQL + dữ liệu mẫu
└── README.md
```

## 2. Công nghệ sử dụng

| Thành phần        | Công nghệ                                      |
|--------------------|------------------------------------------------|
| Web server          | Python 3, Flask                                |
| Giao tiếp Python ↔ Verilog | File I/O (`input.txt`/`registered.txt`/`output.txt`) + `subprocess` gọi Icarus Verilog |
| Mô phỏng phần cứng  | Verilog, Icarus Verilog (`iverilog`, `vvp`)    |
| Cơ sở dữ liệu       | PostgreSQL (qua thư viện `psycopg2`)           |
| Giao diện           | HTML, CSS, JavaScript thuần (camera qua `getUserMedia`) |
| HTTPS cho camera    | `pyOpenSSL` (chứng chỉ tự ký)      |

## 3. Luồng hoạt động

```
Điện thoại (camera trước, getUserMedia)
        │  chụp ảnh — CHỈ hiển thị trên giao diện, KHÔNG gửi lên server
        ▼
Bấm "Quét khuôn mặt" → gửi tín hiệu SCAN (POST /api/scan)
        ▼
app.py (Flask)
        │  gọi generate.py
        ▼
generate.py
        │  đọc TOÀN BỘ danh sách sinh viên đã đăng ký từ bảng DuLieuKhuonMat (PostgreSQL)
        │  ghi ra verilog/registered.txt (số lượng + Face Feature từng sinh viên)
        │  sinh 1 Face Feature giả lập (có nhiễu nhẹ hoặc hoàn toàn ngẫu nhiên)
        │  ghi ra verilog/input.txt (số nguyên đã lượng tử hóa x1000)
        ▼
app.py gọi iverilog + vvp để chạy mô phỏng
        ▼
matcher_tb.v → matcher.v
        │  đọc input.txt + registered.txt, nạp vào module matcher
        │  tính khoảng cách Manhattan so với TOÀN BỘ sinh viên đã đăng ký (động,
        │  không giới hạn cố định 3 sinh viên - xem mục 8)
        │  so với ngưỡng (THRESHOLD) → chọn khoảng cách nhỏ nhất
        ▼
Ghi kết quả ra verilog/output.txt (<mã sinh viên khớp> hoặc UNKNOWN)
        ▼
app.py đọc output.txt
        │  nếu nhận diện được → truy vấn PostgreSQL lấy thông tin sinh viên
        │                      → lưu bản ghi vào LichSuDiemDanh
        ▼
Trả kết quả JSON → giao diện web hiển thị + làm mới bảng lịch sử
```

## 4. Yêu cầu

- Python 3.9+
- PostgreSQL
  *Lưu ý: đổi tên user và password của PostgreSQL trong file app.py*
- Icarus Verilog (`iverilog`, `vvp`)

## 5. Chạy chương trình

```
Chạy app.py
```

Console sẽ hiện dòng `Running on https://0.0.0.0:5000` (server chạy HTTPS tự ký —
xem mục 6 để biết lý do).

Trên máy tính, mở `https://localhost:5000` để kiểm tra nhanh.

## 6. Truy cập từ điện thoại

Giao diện dùng camera trực tiếp (`getUserMedia`) để chụp ảnh, trình duyệt **chỉ
cấp quyền camera qua HTTPS hoặc `localhost`** — không hoạt động qua `http://` thường.

Sử dụng HTTPS tự ký, giữ trong mạng LAN (mặc định, không cần công cụ ngoài)

`app.py` đã cấu hình sẵn `ssl_context="adhoc"`. Chỉ cần:

1. Đảm bảo điện thoại và máy tính **cùng mạng Wi-Fi**.
2. Tìm IP LAN của máy tính (`ipconfig` trên Windows, `ifconfig`/`ip addr` trên Mac/Linux).
3. Trên điện thoại, mở `https://<ip-lan-may-tinh>:5000`.
4. Trình duyệt sẽ cảnh báo "Không an toàn" (vì chứng chỉ tự ký) → bấm **Nâng cao** →
   **Tiếp tục truy cập** để vào.

M  i lần khởi động lại `app.py`, chứng chỉ tự tạo lại nên điện thoại sẽ phải xác nhận
cảnh báo này lại một lần.

## 7. Các API endpoint

| Phương thức | Đường dẫn                     | Chức năng                                      |
|-------------|--------------------------------|-------------------------------------------------|
| GET         | `/`                             | Trả về giao diện web                            |
| POST        | `/api/scan`                     | Chạy pipeline quét, trả kết quả JSON            |
| GET         | `/api/history`                  | Lấy 50 lượt điểm danh gần nhất                  |
| DELETE      | `/api/history`                  | Xóa toàn bộ lịch sử điểm danh                   |
| DELETE      | `/api/history/<ma_diem_danh>`   | Xóa một bản ghi điểm danh cụ thể                |

## 8. Giới hạn của bản mô phỏng

- Face Feature là **số giả lập** (sinh ngẫu nhiên hoặc lấy từ CSDL có thêm nhiễu),
  không phải trích xuất thật từ ảnh khuôn mặt.
- Hệ thống **không gửi ảnh** từ điện thoại lên server ở bất kỳ bước nào — ảnh chỉ
  hiển thị trên giao diện để mô phỏng thao tác quét.
- Giao diện chỉ hỗ trợ **camera trước (selfie)**, không có đường nhập ảnh tùy ý,
  nhằm giữ đúng tinh thần của một hệ thống điểm danh (tránh gian lận bằng ảnh có sẵn).
- `matcher.v` so khớp với **tối đa 16 sinh viên cùng lúc** (`MAX_STUDENTS` trong
  `matcher.v`/`matcher_tb.v`, phải khớp với `MAX_STUDENTS` trong `generate.py`).
  Nếu CSDL có nhiều hơn 16 sinh viên, chỉ 16 sinh viên đầu tiên được đưa vào so
  khớp (có cảnh báo in ra khi chạy `generate.py`); tăng giới hạn này cần sửa cả
  3 file cho khớp nhau.
- Ngưỡng so khớp (`THRESHOLD` trong `matcher.v`) được chọn thủ công dựa trên mức
  nhiễu mô phỏng trong `generate.py`, có thể cần điều chỉnh nếu đổi `NOISE_LEVEL`.

-- Tao CSDL. Luu y: PostgreSQL KHONG cho phep CREATE DATABASE va CREATE TABLE
-- chay chung trong cung 1 lan ket noi/transaction nhu SQL Server.
-- Chay dong nay truoc (vi du trong psql, hoac dung lenh `createdb diem_danh`):
CREATE DATABASE diem_danh;

-- Sau khi tao xong, KET NOI LAI vao database diem_danh roi moi chay phan con lai:
--   Trong psql      : \c diem_danh
--   Trong pgAdmin    : chon database "diem_danh" o Query Tool truoc khi chay
--   Trong DBeaver... : chuyen active database sang diem_danh

CREATE TABLE Sinhvien(
    Masinhvien VARCHAR(20) PRIMARY KEY,
    HoTen VARCHAR(100) NOT NULL,
    Lop VARCHAR(50),
    NgayDangKy DATE
);

-- SERIAL = tu tang (tuong duong IDENTITY(1,1) ben SQL Server)
CREATE TABLE DuLieuKhuonMat(
    MaKhuonMat SERIAL PRIMARY KEY,
    MaSinhVien VARCHAR(20) NOT NULL REFERENCES Sinhvien(Masinhvien),
    DuongDanAnh VARCHAR(255),
    DacTrungKhuonMat TEXT
);

CREATE TABLE LichSuDiemDanh(
    MaDiemDanh SERIAL PRIMARY KEY,
    MaSinhVien VARCHAR(20) NOT NULL REFERENCES Sinhvien(Masinhvien),
    ThoiGian TIMESTAMP NOT NULL,
    TrangThai VARCHAR(50) NOT NULL
);

-- ==================== DU LIEU VI DU ====================
-- (PostgreSQL mac dinh la UTF-8 nen khong can tien to N'' nhu SQL Server)

INSERT INTO Sinhvien (Masinhvien, HoTen, Lop, NgayDangKy) VALUES
('SV001', 'Nguyễn Văn A', 'K50B CNTT', '2026-09-01'),
('SV002', 'Trần Thị B',   'K50B CNTT', '2026-09-01'),
('SV003', 'Lê Văn C',     'K50A CNTT', '2026-09-02');

-- Face Feature khop voi generate.py / matcher.v
-- SV001 -> [0.12, -0.35, 0.87, 0.41]
-- SV002 -> [0.54,  0.21, 0.73, 0.18]
-- SV003 -> [0.31,  0.65,-0.24, 0.82]
INSERT INTO DuLieuKhuonMat (MaSinhVien, DuongDanAnh, DacTrungKhuonMat) VALUES
('SV001', '/images/sv001.jpg', '0.12,-0.35,0.87,0.41'),
('SV002', '/images/sv002.jpg', '0.54,0.21,0.73,0.18'),
('SV003', '/images/sv003.jpg', '0.31,0.65,-0.24,0.82');

-- Lich su diem danh mau (de test endpoint /api/history)
INSERT INTO LichSuDiemDanh (MaSinhVien, ThoiGian, TrangThai) VALUES
('SV001', '2026-09-24 07:58:00', 'Có mặt'),
('SV002', '2026-09-24 08:01:00', 'Có mặt'),
('SV001', '2026-09-25 07:55:00', 'Có mặt'),
('SV003', '2026-09-25 08:10:00', 'Có mặt');

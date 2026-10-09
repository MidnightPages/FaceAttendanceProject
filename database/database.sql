
CREATE DATABASE diem_danh;

CREATE TABLE Sinhvien(
    Masinhvien VARCHAR(20) PRIMARY KEY,
    HoTen VARCHAR(100) NOT NULL,
    Lop VARCHAR(50),
    NgayDangKy DATE
);

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

INSERT INTO Sinhvien (Masinhvien, HoTen, Lop, NgayDangKy) VALUES
('SV001', 'Nguyễn Văn A', 'K50B CNTT', '2026-09-01'),
('SV002', 'Trần Thị B',   'K50B CNTT', '2026-09-01'),
('SV003', 'Lê Văn C',     'K50A CNTT', '2026-09-02');

-- Face Feature khop voi generate.py / matcher.v
INSERT INTO DuLieuKhuonMat (MaSinhVien, DuongDanAnh, DacTrungKhuonMat) VALUES
('SV001', '/images/sv001.jpg', '0.12,-0.35,0.87,0.41'),
('SV002', '/images/sv002.jpg', '0.54,0.21,0.73,0.18'),
('SV003', '/images/sv003.jpg', '0.31,0.65,-0.24,0.82');

-- Lich su diem danh mau
INSERT INTO LichSuDiemDanh (MaSinhVien, ThoiGian, TrangThai) VALUES
('SV001', '2026-09-24 07:58:00', 'Có mặt'),
('SV002', '2026-09-24 08:01:00', 'Có mặt'),
('SV001', '2026-09-25 07:55:00', 'Có mặt'),
('SV003', '2026-09-25 08:10:00', 'Có mặt');

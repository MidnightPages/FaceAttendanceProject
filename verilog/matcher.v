// matcher.v
// Module Verilog thuc hien Face Feature Matching.
//
// Nguyen ly:
//   - Nhan vao 4 gia tri Face Feature da luong tu hoa (so nguyen, x1000 so
//     voi ban dau, xem generate.py) tu tin hieu quet.
//   - Tinh khoang cach Manhattan (tong tri tuyet doi hieu tung phan tu)
//     giua Face Feature dau vao va tung Face Feature da dang ky (SV001,
//     SV002, SV003).
//   - Sinh vien co khoang cach nho nhat VA nho hon THRESHOLD duoc coi la
//     ket qua nhan dien. Neu khong sinh vien nao thoa -> UNKNOWN.
//
// Face Feature da dang ky duoc "nhung cung" (hard-code) trong module de mo
// phong noi dung da luu trong DuLieuKhuonMat (database.sql), da nhan 1000:
//   SV001 -> [120, -350, 870, 410]
//   SV002 -> [540,  210, 730, 180]
//   SV003 -> [310,  650,-240, 820]

module matcher (
    input  wire signed [15:0] feature0,
    input  wire signed [15:0] feature1,
    input  wire signed [15:0] feature2,
    input  wire signed [15:0] feature3,
    output reg  [1:0]         student_index, // 0=SV001 1=SV002 2=SV003 3=UNKNOWN
    output reg                match_valid     // 1 = tim thay, 0 = UNKNOWN
);

    // Nguong so khop (tong tri tuyet doi hieu). Sinh tu nhieu mo phong
    // trong generate.py (NOISE_LEVEL = 0.03 * SCALE = 30) nen tong 4 chieu
    // lech nhau toi da khoang 120; chon THRESHOLD du rong de chap nhan nhieu
    // nhung du hep de loai nguoi la.
    localparam integer THRESHOLD = 200;

    // Face Feature da dang ky (da luong tu hoa x1000)
    localparam signed [15:0] SV001_F0 = 16'sd120,  SV001_F1 = -16'sd350;
    localparam signed [15:0] SV001_F2 = 16'sd870,  SV001_F3 =  16'sd410;

    localparam signed [15:0] SV002_F0 = 16'sd540,  SV002_F1 =  16'sd210;
    localparam signed [15:0] SV002_F2 = 16'sd730,  SV002_F3 =  16'sd180;

    localparam signed [15:0] SV003_F0 = 16'sd310,  SV003_F1 =  16'sd650;
    localparam signed [15:0] SV003_F2 = -16'sd240, SV003_F3 =  16'sd820;

    // Ham tinh tri tuyet doi cua hieu 2 so co dau
    function signed [16:0] abs_diff;
        input signed [15:0] a;
        input signed [15:0] b;
        reg   signed [16:0] diff;
        begin
            diff = a - b;
            abs_diff = (diff < 0) ? -diff : diff;
        end
    endfunction

    wire signed [18:0] dist_sv001, dist_sv002, dist_sv003;

    assign dist_sv001 = abs_diff(feature0, SV001_F0) + abs_diff(feature1, SV001_F1)
                       + abs_diff(feature2, SV001_F2) + abs_diff(feature3, SV001_F3);

    assign dist_sv002 = abs_diff(feature0, SV002_F0) + abs_diff(feature1, SV002_F1)
                       + abs_diff(feature2, SV002_F2) + abs_diff(feature3, SV002_F3);

    assign dist_sv003 = abs_diff(feature0, SV003_F0) + abs_diff(feature1, SV003_F1)
                       + abs_diff(feature2, SV003_F2) + abs_diff(feature3, SV003_F3);

    // Chon khoang cach nho nhat, so voi THRESHOLD de quyet dinh ket qua
    always @* begin
        if (dist_sv001 <= dist_sv002 && dist_sv001 <= dist_sv003 && dist_sv001 <= THRESHOLD) begin
            student_index = 2'd0;
            match_valid   = 1'b1;
        end else if (dist_sv002 <= dist_sv001 && dist_sv002 <= dist_sv003 && dist_sv002 <= THRESHOLD) begin
            student_index = 2'd1;
            match_valid   = 1'b1;
        end else if (dist_sv003 <= dist_sv001 && dist_sv003 <= dist_sv002 && dist_sv003 <= THRESHOLD) begin
            student_index = 2'd2;
            match_valid   = 1'b1;
        end else begin
            student_index = 2'd3; // UNKNOWN
            match_valid   = 1'b0;
        end
    end

endmodule

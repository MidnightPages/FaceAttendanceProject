// matcher.v
// Module Verilog thuc hien Face Feature Matching cho N sinh vien da dang ky.
//
// KHAC VOI BAN TRUOC: danh sach sinh vien KHONG con hard-code bang localparam co
// dinh (3 sinh vien) ma duoc nap DONG tu ben ngoai qua cong reg_features_flat +
// num_registered (do matcher_tb.v doc tu file registered.txt va truyen vao).
// Nho vay them/bot sinh vien trong CSDL khong can sua lai matcher.v.
//
// MAX_STUDENTS: so luong sinh vien toi da ho tro cung luc (phai khop voi gia tri
// dung trong matcher_tb.v va MAX_STUDENTS trong generate.py).

module matcher #(
    parameter MAX_STUDENTS = 16,
    parameter FW           = 16   // do rong moi gia tri feature (bit)
) (
    input  wire signed [FW-1:0]                 feature0,
    input  wire signed [FW-1:0]                 feature1,
    input  wire signed [FW-1:0]                 feature2,
    input  wire signed [FW-1:0]                 feature3,

    // Danh sach Face Feature da dang ky, dang vector da "lam phang" (flatten):
    // voi sinh vien thu i (0..MAX_STUDENTS-1), feature thu k (0..3) nam o vi tri
    // bit [(i*4+k)*FW +: FW]. Cac vi tri i >= num_registered khong duoc dung toi.
    input  wire signed [FW*4*MAX_STUDENTS-1:0]   reg_features_flat,
    input  wire [31:0]                           num_registered, // so sinh vien dang dung (<= MAX_STUDENTS)

    output reg  [31:0]                           matched_index,  // chi so sinh vien khop (0..MAX_STUDENTS-1)
    output reg                                    match_valid     // 1 = tim thay, 0 = UNKNOWN
);

    // Nguong so khop (tong tri tuyet doi hieu). Xem giai thich chon gia tri nay
    // trong generate.py (NOISE_LEVEL).
    localparam integer THRESHOLD = 200;

    function signed [FW:0] abs_diff;
        input signed [FW-1:0] a;
        input signed [FW-1:0] b;
        reg   signed [FW:0]   diff;
        begin
            diff = a - b;
            abs_diff = (diff < 0) ? -diff : diff;
        end
    endfunction

    // Lay feature thu feature_idx (0..3) cua sinh vien thu student_idx tu vector
    // da lam phang.
    function signed [FW-1:0] get_feature;
        input integer student_idx;
        input integer feature_idx;
        begin
            get_feature = reg_features_flat[(student_idx*4 + feature_idx)*FW +: FW];
        end
    endfunction

    integer i;
    integer dist;
    integer best_dist;

    // Vong lap so khop voi tung sinh vien dang ky (i < num_registered), chon
    // khoang cach nho nhat. MAX_STUDENTS la hang so bien dich (parameter) nen
    // vong lap duoc "unroll" khi tong hop/mo phong - van la logic to hop binh
    // thuong, khong phai phan mem.
    always @* begin
        best_dist     = 32'sh7FFFFFFF; // gia tri "vo cuc" ban dau
        matched_index = MAX_STUDENTS;  // sentinel = chua tim thay ai
        match_valid   = 1'b0;

        for (i = 0; i < MAX_STUDENTS; i = i + 1) begin
            if (i < num_registered) begin
                dist = abs_diff(feature0, get_feature(i, 0)) + abs_diff(feature1, get_feature(i, 1))
                     + abs_diff(feature2, get_feature(i, 2)) + abs_diff(feature3, get_feature(i, 3));
                if (dist < best_dist) begin
                    best_dist     = dist;
                    matched_index = i;
                end
            end
        end

        if (matched_index != MAX_STUDENTS && best_dist <= THRESHOLD) begin
            match_valid = 1'b1;
        end else begin
            matched_index = MAX_STUDENTS; // UNKNOWN
            match_valid   = 1'b0;
        end
    end

endmodule

// matcher.v
// Module Verilog thuc hien Face Feature Matching cho N sinh vien da dang ky.

// MAX_STUDENTS: so luong sinh vien toi da ho tro cung luc

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


    always @* begin
        best_dist     = 32'sh7FFFFFFF; 
        matched_index = MAX_STUDENTS; 
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
            matched_index = MAX_STUDENTS; 
            match_valid   = 1'b0;
        end
    end

endmodule

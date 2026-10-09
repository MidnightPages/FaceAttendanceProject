// matcher_tb.v
// Testbench cho matcher.v
//
//   - Doc input.txt     : Face Feature can nhan dien (do generate.py ghi ra)
//   - Doc registered.txt: TOAN BO danh sach sinh vien da dang ky, do generate.py
//                         ghi ra tu CSDL truoc moi lan quet
//   - Nap ca 2 vao module matcher, lay chi so sinh vien khop (hoac UNKNOWN)
//   - Tra chi so do ve ma sinh vien dang chuoi, ghi ket qua ra output.txt
//
// Dinh dang registered.txt (do generate.py ghi):
//   <so luong sinh vien>
//   <MaSinhVien> <f0> <f1> <f2> <f3>

`timescale 1ns/1ps

module matcher_tb;

    localparam MAX_STUDENTS = 16;
    localparam FW           = 16;

    reg signed [FW-1:0] feature0, feature1, feature2, feature3;

    reg  [63:0] student_codes [0:MAX_STUDENTS-1];   
    reg  signed [FW-1:0] reg_feat [0:MAX_STUDENTS-1][0:3];
    reg  signed [FW*4*MAX_STUDENTS-1:0] reg_features_flat;
    reg  [31:0] num_registered;

    wire [31:0] matched_index;
    wire        match_valid;

    integer in_file, reg_file, out_file;
    integer scan_count, i, j;

    reg signed [FW-1:0] tmp_f0, tmp_f1, tmp_f2, tmp_f3;

    matcher #(
        .MAX_STUDENTS(MAX_STUDENTS),
        .FW(FW)
    ) uut (
        .feature0(feature0),
        .feature1(feature1),
        .feature2(feature2),
        .feature3(feature3),
        .reg_features_flat(reg_features_flat),
        .num_registered(num_registered),
        .matched_index(matched_index),
        .match_valid(match_valid)
    );

    initial begin
        // ---- Doc input.txt: Face Feature can nhan dien ----
        in_file = $fopen("input.txt", "r");
        if (in_file == 0) begin
            $display("Loi: khong mo duoc input.txt");
            $finish;
        end
        scan_count = $fscanf(in_file, "%d %d %d %d", feature0, feature1, feature2, feature3);
        $fclose(in_file);
        if (scan_count != 4) begin
            $display("Loi: input.txt sai dinh dang (can 4 so nguyen)");
            $finish;
        end

        // ---- Doc registered.txt: danh sach sinh vien da dang ky ----
        reg_file = $fopen("registered.txt", "r");
        if (reg_file == 0) begin
            $display("Loi: khong mo duoc registered.txt");
            $finish;
        end

        scan_count = $fscanf(reg_file, "%d\n", num_registered);
        if (scan_count != 1) begin
            $display("Loi: registered.txt sai dinh dang (dong dau phai la so luong sinh vien)");
            $finish;
        end
        if (num_registered > MAX_STUDENTS) begin
            $display("Canh bao: registered.txt co %0d sinh vien, vuot MAX_STUDENTS=%0d, chi lay %0d dau tien",
                      num_registered, MAX_STUDENTS, MAX_STUDENTS);
            num_registered = MAX_STUDENTS;
        end

        for (i = 0; i < num_registered; i = i + 1) begin
            scan_count = $fscanf(reg_file, "%s %d %d %d %d\n",
                student_codes[i], tmp_f0, tmp_f1, tmp_f2, tmp_f3);
            if (scan_count != 5) begin
                $display("Loi: registered.txt sai dinh dang o dong sinh vien thu %0d", i + 1);
                $finish;
            end
            reg_feat[i][0] = tmp_f0;
            reg_feat[i][1] = tmp_f1;
            reg_feat[i][2] = tmp_f2;
            reg_feat[i][3] = tmp_f3;
        end
        $fclose(reg_file);

        // ---- Lam phang mang 2 chieu thanh 1 vector de dua vao cong module ----
        for (j = 0; j < MAX_STUDENTS; j = j + 1) begin
            if (j < num_registered) begin
                reg_features_flat[(j*4+0)*FW +: FW] = reg_feat[j][0];
                reg_features_flat[(j*4+1)*FW +: FW] = reg_feat[j][1];
                reg_features_flat[(j*4+2)*FW +: FW] = reg_feat[j][2];
                reg_features_flat[(j*4+3)*FW +: FW] = reg_feat[j][3];
            end else begin
                reg_features_flat[(j*4+0)*FW +: FW] = {FW{1'b0}};
                reg_features_flat[(j*4+1)*FW +: FW] = {FW{1'b0}};
                reg_features_flat[(j*4+2)*FW +: FW] = {FW{1'b0}};
                reg_features_flat[(j*4+3)*FW +: FW] = {FW{1'b0}};
            end
        end

        // ---- Cho mach to hop trong matcher.v on dinh gia tri dau ra ----
        #10;

        // ---- Ghi ket qua ra output.txt ----
        out_file = $fopen("output.txt", "w");
        if (match_valid) begin
            $fwrite(out_file, "%0s", student_codes[matched_index]);
        end else begin
            $fwrite(out_file, "UNKNOWN");
        end
        $fclose(out_file);

        // In ra console de debug 
        $display("So sinh vien da dang ky: %0d", num_registered);
        $display("Feature vao : %d %d %d %d", feature0, feature1, feature2, feature3);
        if (match_valid)
            $display("Ket qua     : %0s (chi so %0d)", student_codes[matched_index], matched_index);
        else
            $display("Ket qua     : UNKNOWN");

        $finish;
    end

endmodule

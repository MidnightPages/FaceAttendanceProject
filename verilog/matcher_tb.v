// matcher_tb.v
// Testbench cho matcher.v, dung theo huong File I/O + subprocess:
//   - Doc Face Feature da luong tu hoa tu input.txt (do generate.py ghi ra)
//   - Dua vao module matcher de so khop
//   - Ghi ket qua ("SV001"/"SV002"/"SV003"/"UNKNOWN") ra output.txt
//     (de app.py doc lai sau khi chay xong mo phong)
//
// Chay bang Icarus Verilog:
//   iverilog -o sim.out matcher_tb.v matcher.v
//   vvp sim.out

`timescale 1ns/1ps

module matcher_tb;

    reg signed [15:0] feature0, feature1, feature2, feature3;
    wire [1:0] student_index;
    wire       match_valid;

    integer in_file, out_file, scan_count;

    // Khoi tao module can kiem thu
    matcher uut (
        .feature0(feature0),
        .feature1(feature1),
        .feature2(feature2),
        .feature3(feature3),
        .student_index(student_index),
        .match_valid(match_valid)
    );

    initial begin
        // Bước 1: đọc Face Feature từ input.txt
        in_file = $fopen("input.txt", "r");
        if (in_file == 0) begin
            $display("Loi: khong mo duoc input.txt");
            $finish;
        end

        scan_count = $fscanf(in_file, "%d %d %d %d", feature0, feature1, feature2, feature3);
        $fclose(in_file);

        if (scan_count != 4) begin
            $display("Loi: input.txt sai dinh dang (can dung 4 so nguyen cach nhau boi dau cach)");
            $finish;
        end

        // Bước 2: chờ mạch tổ hợp trong matcher.v ổn định giá trị đầu ra
        #10;

        // Bước 3: ghi kết quả ra output.txt để app.py đọc lại
        out_file = $fopen("output.txt", "w");
        case (student_index)
            2'd0: $fwrite(out_file, "SV001");
            2'd1: $fwrite(out_file, "SV002");
            2'd2: $fwrite(out_file, "SV003");
            default: $fwrite(out_file, "UNKNOWN");
        endcase
        $fclose(out_file);

        // In ra console để tiện debug khi chạy tay (không ảnh hưởng output.txt)
        $display("Feature vao : %d %d %d %d", feature0, feature1, feature2, feature3);
        $display("Ket qua     : %s", match_valid ? "MATCH" : "UNKNOWN");

        $finish;
    end

endmodule

`include "../../rtl/pixel_addr_lut.sv"

module tb_pixel_addr_lut();
    import vgaTimes::*;

    `ifdef USE_POWER_PINS
        wire VPWR;
        wire VGND;
        assign VPWR=1;
        assign VGND=0;
    `endif
    
    bit [vgaTimes::H_BITS-1:0] h_cnt;
    bit [vgaTimes::V_BITS-1:0] v_cnt;
    bit [displayConsts::PIXEL_ADDR_BITS-1:0] pixel_addr;

    pixel_addr_lut DUT (.*);

    task automatic check_addrs();
        int tmp;
        logic [PIXEL_ADDR_BITS-1:0] pixel_x;
        logic [PIXEL_ADDR_BITS-1:0] expected_addr;
        for (int i = 0; i < V_VISIBLE_AREA; i++) begin
            v_cnt = i[V_BITS-1:0];
            for (int j = 0; j < H_VISIBLE_AREA; j++) begin
                #(1);
                h_cnt = j[H_BITS-1:0];
                
                pixel_x = {{(PIXEL_ADDR_BITS-H_BITS){1'b0}}, h_cnt};
                tmp = i * H_VISIBLE_AREA;
                expected_addr = tmp[PIXEL_ADDR_BITS-1:0] + pixel_x;

                #(1);
                assert (pixel_addr == expected_addr) 
                else $error("WRONG ADDRESS got addr: %d expected: %d", 
                            pixel_addr, expected_addr); 
            end
        end
    endtask

    initial begin
        $dumpfile("tb_pixel_addr_lut.vcd");
        $dumpvars(0);
    end

    // Tests
    initial begin
        check_addrs();

        $display("[TESTBENCH] PASSED All tests");
        $finish();
    end



endmodule
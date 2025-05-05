`include "../../rtl/pixel_row_rom.sv"

module tb_pixel_row_rom();
    import vgaTimes::*;
    import displayConsts::*;

    `ifdef USE_POWER_PINS
        wire VPWR;
        wire VGND;
        assign VPWR=1;
        assign VGND=0;
    `endif
    
    bit [V_BITS-1:0] v_cnt;
    bit [PIXEL_ADDR_BITS-1:0] pixel_y;

    logic [PIXEL_ADDR_BITS-1:0] ex_rom [0:V_VISIBLE_AREA-1];
    initial $readmemh("../../rtl/mem/pixel_row.mem", ex_rom);

    pixel_row_rom DUT (.*);

    task automatic check_addrs();
    logic [PIXEL_ADDR_BITS-1:0] expected_y;
      int tmp ;
      for (int i = 0; i < V_VISIBLE_AREA; i++) begin
        for (int j = 0; j < H_VISIBLE_AREA; j++) begin
          
          #(1);
          v_cnt = i[V_BITS-1:0];
          tmp = i * H_VISIBLE_AREA;
          expected_y = tmp[PIXEL_ADDR_BITS-1:0];
          
          #(1);
          assert (pixel_y == expected_y) 
          else $error("\n\tWRONG ADDRESS got addr: %d expected: %d with i=%d and j=%d\
                      v_cnt = %d", 
                      pixel_y, expected_y, i, j, v_cnt); 
        end
      end
    endtask

    initial begin
        $dumpfile("tb_pixel_row_rom.vcd");
        $dumpvars(0);
    end

    // Tests
    initial begin
        check_addrs();

        $display("[TESTBENCH] PASSED All tests");
        $finish();
    end



endmodule
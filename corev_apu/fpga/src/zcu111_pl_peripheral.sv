module zcu111_pl_peripheral #(
  parameter int unsigned AxiAddrWidth = 64,
  parameter int unsigned AxiDataWidth = 64,
  parameter int unsigned AxiIdWidth   = 8,
  parameter int unsigned AxiUserWidth = 1
) (
  input  logic clk_i,
  input  logic rst_ni,
  output logic irq_o,
  AXI_BUS.Slave axi
);

  import axi_pkg::*;

  localparam logic [31:0] ID_VALUE      = 32'h5ac6_0111;
  localparam logic [31:0] VERSION_VALUE = 32'h0001_0000;

  logic [31:0] scratch_q;
  logic [63:0] counter_q;
  logic        irq_status_q;
  logic        irq_enable_q;

  logic [AxiIdWidth-1:0] aw_id_q;
  logic [AxiAddrWidth-1:0] aw_addr_q;
  logic [7:0] aw_len_q;
  logic aw_pending_q;

  logic [AxiDataWidth-1:0] w_data_q;
  logic [(AxiDataWidth/8)-1:0] w_strb_q;
  logic w_pending_q;

  logic [AxiIdWidth-1:0] b_id_q;
  logic [1:0] b_resp_q;
  logic b_valid_q;

  logic [AxiIdWidth-1:0] r_id_q;
  logic [AxiDataWidth-1:0] r_data_q;
  logic [1:0] r_resp_q;
  logic r_valid_q;

  function automatic logic [AxiDataWidth-1:0] read_word(input logic [11:0] addr);
    logic [63:0] data;
    begin
      unique case (addr[11:3])
        9'h000: data = {VERSION_VALUE, ID_VALUE};
        9'h001: data = {32'h0000_0000, scratch_q};
        9'h002: data = counter_q;
        9'h003: data = {63'h0, irq_status_q};
        9'h004: data = {63'h0, irq_enable_q};
        default: data = 64'h0;
      endcase
      read_word = '0;
      read_word[63:0] = data;
    end
  endfunction

  function automatic logic addr_ok(input logic [11:0] addr);
    begin
      unique case (addr[11:3])
        9'h000,
        9'h001,
        9'h002,
        9'h003,
        9'h004,
        9'h005,
        9'h006: addr_ok = 1'b1;
        default: addr_ok = 1'b0;
      endcase
    end
  endfunction

  assign irq_o = irq_status_q & irq_enable_q;

  assign axi.aw_ready = !aw_pending_q;
  assign axi.w_ready  = !w_pending_q;
  assign axi.b_id     = b_id_q;
  assign axi.b_resp   = b_resp_q;
  assign axi.b_user   = '0;
  assign axi.b_valid  = b_valid_q;

  assign axi.ar_ready = !r_valid_q;
  assign axi.r_id     = r_id_q;
  assign axi.r_data   = r_data_q;
  assign axi.r_resp   = r_resp_q;
  assign axi.r_last   = 1'b1;
  assign axi.r_user   = '0;
  assign axi.r_valid  = r_valid_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      scratch_q    <= 32'h0000_0000;
      counter_q    <= 64'h0;
      irq_status_q <= 1'b0;
      irq_enable_q <= 1'b0;
      aw_id_q      <= '0;
      aw_addr_q    <= '0;
      aw_len_q     <= '0;
      aw_pending_q <= 1'b0;
      w_data_q     <= '0;
      w_strb_q     <= '0;
      w_pending_q  <= 1'b0;
      b_id_q       <= '0;
      b_resp_q     <= axi_pkg::RESP_OKAY;
      b_valid_q    <= 1'b0;
      r_id_q       <= '0;
      r_data_q     <= '0;
      r_resp_q     <= axi_pkg::RESP_OKAY;
      r_valid_q    <= 1'b0;
    end else begin
      counter_q <= counter_q + 64'd1;

      if (axi.b_ready) begin
        b_valid_q <= 1'b0;
      end

      if (axi.r_ready) begin
        r_valid_q <= 1'b0;
      end

      if (axi.aw_valid && axi.aw_ready) begin
        aw_id_q      <= axi.aw_id;
        aw_addr_q    <= axi.aw_addr;
        aw_len_q     <= axi.aw_len;
        aw_pending_q <= 1'b1;
      end

      if (axi.w_valid && axi.w_ready) begin
        w_data_q    <= axi.w_data;
        w_strb_q    <= axi.w_strb;
        w_pending_q <= 1'b1;
      end

      if (aw_pending_q && w_pending_q && !b_valid_q) begin
        b_id_q    <= aw_id_q;
        b_resp_q  <= axi_pkg::RESP_OKAY;
        b_valid_q <= 1'b1;

        if ((aw_len_q != 8'h00) || !addr_ok(aw_addr_q[11:0])) begin
          b_resp_q <= axi_pkg::RESP_SLVERR;
        end else begin
          unique case (aw_addr_q[11:3])
            9'h001: begin
              for (int unsigned i = 0; i < 4; i++) begin
                if (w_strb_q[i]) begin
                  scratch_q[i*8 +: 8] <= w_data_q[i*8 +: 8];
                end
              end
            end
            9'h004: begin
              if (w_strb_q[0]) begin
                irq_enable_q <= w_data_q[0];
              end
            end
            9'h005: begin
              if (w_strb_q[0] && w_data_q[0]) begin
                irq_status_q <= 1'b0;
              end
            end
            9'h006: begin
              if (w_strb_q[0] && w_data_q[0]) begin
                irq_status_q <= 1'b1;
              end
            end
            default: begin
            end
          endcase
        end

        aw_pending_q <= 1'b0;
        w_pending_q  <= 1'b0;
      end

      if (axi.ar_valid && axi.ar_ready) begin
        r_id_q    <= axi.ar_id;
        r_data_q  <= read_word(axi.ar_addr[11:0]);
        r_resp_q  <= ((axi.ar_len == 8'h00) && addr_ok(axi.ar_addr[11:0])) ? axi_pkg::RESP_OKAY : axi_pkg::RESP_SLVERR;
        r_valid_q <= 1'b1;
      end
    end
  end

endmodule

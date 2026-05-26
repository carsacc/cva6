module zcu111_aes_gcm_peripheral #(
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

  localparam logic [31:0] ID_VALUE      = 32'h4147_434d;
  localparam logic [31:0] VERSION_VALUE = 32'h0001_0000;

  localparam logic [11:0] REG_CONTROL     = 12'h008;
  localparam logic [11:0] REG_IRQ_ENABLE  = 12'h010;
  localparam logic [11:0] REG_IRQ_ACK     = 12'h018;
  localparam logic [11:0] REG_KEY0        = 12'h020;
  localparam logic [11:0] REG_IV0         = 12'h040;
  localparam logic [11:0] REG_AAD_BYTES   = 12'h04c;
  localparam logic [11:0] REG_AAD0        = 12'h050;
  localparam logic [11:0] REG_DATA_BYTES  = 12'h060;
  localparam logic [11:0] REG_DATA_IN0    = 12'h064;

  typedef enum logic [3:0] {
    StIdle,
    StCoreReset,
    StLoadKey,
    StLoadIv,
    StStartCounter,
    StWaitReady,
    StSendAad,
    StSendData,
    StOpenEmpty,
    StClosePacket,
    StWaitTag
  } state_t;

  state_t state_q;

  logic [31:0] key_q [0:7];
  logic [31:0] iv_q [0:2];
  logic [31:0] aad_q [0:3];
  logic [31:0] data_in_q [0:3];
  logic [31:0] data_out_q [0:3];
  logic [31:0] tag_q [0:3];
  logic [4:0]  aad_bytes_q;
  logic [4:0]  data_bytes_q;
  logic        decrypt_q;
  logic        busy_q;
  logic        done_q;
  logic        tag_valid_q;
  logic        icb_overflow_q;
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

  logic [31:0] wr_data;
  logic [3:0] wr_strb;

  logic         core_rst;
  logic         core_pipe_reset;
  logic [3:0]   core_key_valid;
  logic [255:0] core_key;
  logic         core_iv_valid;
  logic [95:0]  core_iv;
  logic         core_counter_start;
  logic         core_counter_stop;
  logic         core_packet_valid;
  logic [15:0]  core_aad_bval;
  logic [127:0] core_aad;
  logic [15:0]  core_data_bval;
  logic [127:0] core_data_in;
  logic         core_ready;
  logic         core_data_out_valid;
  logic [15:0]  core_data_out_bval;
  logic [127:0] core_data_out;
  logic         core_tag_valid;
  logic [127:0] core_tag;
  logic         core_icb_overflow;

  function automatic logic [15:0] byte_valid_mask(input logic [4:0] bytes);
    begin
      if (bytes == 0) begin
        byte_valid_mask = 16'h0000;
      end else if (bytes >= 16) begin
        byte_valid_mask = 16'hffff;
      end else begin
        byte_valid_mask = 16'hffff << (16 - bytes);
      end
    end
  endfunction

  function automatic logic [AxiDataWidth-1:0] read_word(input logic [11:0] addr);
    logic [63:0] data;
    begin
      unique case (addr[11:3])
        9'h000: data = {VERSION_VALUE, ID_VALUE};
        9'h001: data = {{28{1'b0}}, icb_overflow_q, tag_valid_q, done_q, busy_q, 32'h0};
        9'h002: data = {{31{1'b0}}, irq_status_q, {31{1'b0}}, irq_enable_q};
        9'h003: data = 64'h0;
        9'h004: data = {key_q[1], key_q[0]};
        9'h005: data = {key_q[3], key_q[2]};
        9'h006: data = {key_q[5], key_q[4]};
        9'h007: data = {key_q[7], key_q[6]};
        9'h008: data = {iv_q[1], iv_q[0]};
        9'h009: data = {{27{1'b0}}, aad_bytes_q, iv_q[2]};
        9'h00a: data = {aad_q[1], aad_q[0]};
        9'h00b: data = {aad_q[3], aad_q[2]};
        9'h00c: data = {data_in_q[0], {27{1'b0}}, data_bytes_q};
        9'h00d: data = {data_in_q[2], data_in_q[1]};
        9'h00e: data = {data_out_q[0], data_in_q[3]};
        9'h00f: data = {data_out_q[2], data_out_q[1]};
        9'h010: data = {tag_q[0], data_out_q[3]};
        9'h011: data = {tag_q[2], tag_q[1]};
        9'h012: data = {32'h0, tag_q[3]};
        default: data = 64'h0;
      endcase
      read_word = '0;
      read_word[63:0] = data;
    end
  endfunction

  function automatic logic addr_ok(input logic [11:0] addr);
    begin
      addr_ok = (addr[11:3] <= 9'h012);
    end
  endfunction

  always_comb begin
    if (aw_addr_q[2]) begin
      wr_data = w_data_q[63:32];
      wr_strb = w_strb_q[7:4];
    end else begin
      wr_data = w_data_q[31:0];
      wr_strb = w_strb_q[3:0];
    end
  end

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

  assign core_rst           = !rst_ni || (state_q == StCoreReset);
  assign core_pipe_reset    = state_q == StCoreReset;
  assign core_key_valid     = (state_q == StLoadKey) ? 4'b0111 : 4'b0000;
  assign core_key           = {key_q[0], key_q[1], key_q[2], key_q[3],
                               key_q[4], key_q[5], key_q[6], key_q[7]};
  assign core_iv_valid      = state_q == StLoadIv;
  assign core_iv            = {iv_q[0], iv_q[1], iv_q[2]};
  assign core_counter_start = state_q == StStartCounter;
  assign core_counter_stop  = (state_q == StIdle) || (state_q == StCoreReset) ||
                              (state_q == StLoadKey) || (state_q == StLoadIv) ||
                              (state_q == StClosePacket) || (state_q == StWaitTag);
  assign core_packet_valid  = (state_q == StSendAad) || (state_q == StSendData) ||
                              (state_q == StOpenEmpty);
  assign core_aad_bval      = (state_q == StSendAad) ? byte_valid_mask(aad_bytes_q) : 16'h0;
  assign core_aad           = {aad_q[0], aad_q[1], aad_q[2], aad_q[3]};
  assign core_data_bval     = ((state_q == StSendData) && core_ready) ?
                              byte_valid_mask(data_bytes_q) : 16'h0;
  assign core_data_in       = {data_in_q[0], data_in_q[1], data_in_q[2], data_in_q[3]};

  top_aes_gcm i_aes_gcm (
    .rst_i                       ( core_rst             ),
    .clk_i                       ( clk_i                ),
    .aes_gcm_mode_i              ( 2'b10                ),
    .aes_gcm_enc_dec_i           ( decrypt_q            ),
    .aes_gcm_pipe_reset_i        ( core_pipe_reset      ),
    .aes_gcm_key_word_val_i      ( core_key_valid       ),
    .aes_gcm_key_word_i          ( core_key             ),
    .aes_gcm_iv_val_i            ( core_iv_valid        ),
    .aes_gcm_iv_i                ( core_iv              ),
    .aes_gcm_icb_start_cnt_i     ( core_counter_start   ),
    .aes_gcm_icb_stop_cnt_i      ( core_counter_stop    ),
    .aes_gcm_ghash_pkt_val_i     ( core_packet_valid    ),
    .aes_gcm_ghash_aad_bval_i    ( core_aad_bval        ),
    .aes_gcm_ghash_aad_i         ( core_aad             ),
    .aes_gcm_data_in_bval_i      ( core_data_bval       ),
    .aes_gcm_data_in_i           ( core_data_in         ),
    .aes_gcm_ready_o             ( core_ready           ),
    .aes_gcm_data_out_val_o      ( core_data_out_valid  ),
    .aes_gcm_data_out_bval_o     ( core_data_out_bval   ),
    .aes_gcm_data_out_o          ( core_data_out        ),
    .aes_gcm_ghash_tag_val_o     ( core_tag_valid       ),
    .aes_gcm_ghash_tag_o         ( core_tag             ),
    .aes_gcm_icb_cnt_overflow_o  ( core_icb_overflow    )
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q        <= StIdle;
      aad_bytes_q    <= '0;
      data_bytes_q   <= '0;
      decrypt_q      <= 1'b0;
      busy_q         <= 1'b0;
      done_q         <= 1'b0;
      tag_valid_q    <= 1'b0;
      icb_overflow_q <= 1'b0;
      irq_status_q   <= 1'b0;
      irq_enable_q   <= 1'b0;
      aw_id_q        <= '0;
      aw_addr_q      <= '0;
      aw_len_q       <= '0;
      aw_pending_q   <= 1'b0;
      w_data_q       <= '0;
      w_strb_q       <= '0;
      w_pending_q    <= 1'b0;
      b_id_q         <= '0;
      b_resp_q       <= axi_pkg::RESP_OKAY;
      b_valid_q      <= 1'b0;
      r_id_q         <= '0;
      r_data_q       <= '0;
      r_resp_q       <= axi_pkg::RESP_OKAY;
      r_valid_q      <= 1'b0;
      for (int unsigned i = 0; i < 8; i++) begin
        key_q[i] <= '0;
      end
      for (int unsigned i = 0; i < 3; i++) begin
        iv_q[i] <= '0;
      end
      for (int unsigned i = 0; i < 4; i++) begin
        aad_q[i]      <= '0;
        data_in_q[i]  <= '0;
        data_out_q[i] <= '0;
        tag_q[i]      <= '0;
      end
    end else begin
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
          unique case (aw_addr_q[11:0])
            REG_CONTROL: begin
              if (wr_strb[0] && wr_data[2] && !busy_q) begin
                done_q         <= 1'b0;
                tag_valid_q    <= 1'b0;
                icb_overflow_q <= 1'b0;
                irq_status_q   <= 1'b0;
              end
              if (wr_strb[0] && wr_data[0] && !busy_q) begin
                decrypt_q      <= wr_data[1];
                busy_q         <= 1'b1;
                done_q         <= 1'b0;
                tag_valid_q    <= 1'b0;
                icb_overflow_q <= 1'b0;
                irq_status_q   <= 1'b0;
                state_q        <= StCoreReset;
              end
            end
            REG_IRQ_ENABLE: begin
              if (wr_strb[0]) begin
                irq_enable_q <= wr_data[0];
              end
            end
            REG_IRQ_ACK: begin
              if (wr_strb[0] && wr_data[0]) begin
                irq_status_q <= 1'b0;
              end
            end
            REG_AAD_BYTES: begin
              if (wr_strb[0] && !busy_q) begin
                aad_bytes_q <= (wr_data[4:0] > 5'd16) ? 5'd16 : wr_data[4:0];
              end
            end
            REG_DATA_BYTES: begin
              if (wr_strb[0] && !busy_q) begin
                data_bytes_q <= (wr_data[4:0] > 5'd16) ? 5'd16 : wr_data[4:0];
              end
            end
            default: begin
              if (!busy_q) begin
                for (int unsigned i = 0; i < 8; i++) begin
                  if (aw_addr_q[11:0] == REG_KEY0 + i * 4) begin
                    for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
                      if (wr_strb[byte_idx]) begin
                        key_q[i][byte_idx*8 +: 8] <= wr_data[byte_idx*8 +: 8];
                      end
                    end
                  end
                end
                for (int unsigned i = 0; i < 3; i++) begin
                  if (aw_addr_q[11:0] == REG_IV0 + i * 4) begin
                    for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
                      if (wr_strb[byte_idx]) begin
                        iv_q[i][byte_idx*8 +: 8] <= wr_data[byte_idx*8 +: 8];
                      end
                    end
                  end
                end
                for (int unsigned i = 0; i < 4; i++) begin
                  if (aw_addr_q[11:0] == REG_AAD0 + i * 4) begin
                    for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
                      if (wr_strb[byte_idx]) begin
                        aad_q[i][byte_idx*8 +: 8] <= wr_data[byte_idx*8 +: 8];
                      end
                    end
                  end
                  if (aw_addr_q[11:0] == REG_DATA_IN0 + i * 4) begin
                    for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
                      if (wr_strb[byte_idx]) begin
                        data_in_q[i][byte_idx*8 +: 8] <= wr_data[byte_idx*8 +: 8];
                      end
                    end
                  end
                end
              end
            end
          endcase
        end
        aw_pending_q <= 1'b0;
        w_pending_q  <= 1'b0;
      end

      if (axi.ar_valid && axi.ar_ready) begin
        r_id_q    <= axi.ar_id;
        r_data_q  <= read_word(axi.ar_addr[11:0]);
        r_resp_q  <= ((axi.ar_len == 8'h00) && addr_ok(axi.ar_addr[11:0])) ?
                     axi_pkg::RESP_OKAY : axi_pkg::RESP_SLVERR;
        r_valid_q <= 1'b1;
      end

      if (busy_q && core_icb_overflow) begin
        icb_overflow_q <= 1'b1;
      end
      if (busy_q && core_data_out_valid) begin
        {data_out_q[0], data_out_q[1], data_out_q[2], data_out_q[3]} <= core_data_out;
      end

      unique case (state_q)
        StIdle: begin
        end
        StCoreReset: begin
          state_q <= StLoadKey;
        end
        StLoadKey: begin
          state_q <= StLoadIv;
        end
        StLoadIv: begin
          state_q <= StStartCounter;
        end
        StStartCounter: begin
          state_q <= StWaitReady;
        end
        StWaitReady: begin
          if (core_ready) begin
            if (aad_bytes_q != 0) begin
              state_q <= StSendAad;
            end else if (data_bytes_q != 0) begin
              state_q <= StSendData;
            end else begin
              state_q <= StOpenEmpty;
            end
          end
        end
        StSendAad: begin
          state_q <= (data_bytes_q != 0) ? StSendData : StClosePacket;
        end
        StSendData: begin
          if (core_ready) begin
            state_q <= StClosePacket;
          end
        end
        StOpenEmpty: begin
          state_q <= StClosePacket;
        end
        StClosePacket: begin
          state_q <= StWaitTag;
        end
        StWaitTag: begin
          if (core_tag_valid) begin
            {tag_q[0], tag_q[1], tag_q[2], tag_q[3]} <= core_tag;
            busy_q       <= 1'b0;
            done_q       <= 1'b1;
            tag_valid_q  <= 1'b1;
            irq_status_q <= 1'b1;
            state_q      <= StIdle;
          end
        end
        default: state_q <= StIdle;
      endcase
    end
  end

endmodule

//------------------------------------------------------------------------------
// uart.sv
// Simple 115200‑baud UART TX/RX (RX omitted here)
//------------------------------------------------------------------------------ 
module uart #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 115_200
)(
    input              clk,
    input              reset,
    input              rx,            // unused here
    output reg [7:0]   rx_data,       // unused
    output             rx_valid,      // unused
    output reg         tx,
    input      [7:0]   tx_data,
    input              tx_transmit,
    output reg         tx_ready
);
   localparam OSF            = 16;
   localparam CLK_DIV_COUNT = CLK_FREQ / (OSF * BAUD);

   reg [15:0] count;
   reg        enable;

   // TX FSM
   localparam TX_WAIT         = 0;
   localparam TX_TRANSMITTING = 1;
   reg        tx_state = TX_WAIT;
   reg [9:0]  tx_dataBuffer;
   reg [3:0]  tx_count;
   reg [3:0]  tx_sampleCount;

   assign rx_valid = 1'b0; // not used

   // Clock divider for bit timing
   always_ff @(posedge clk) begin
     if (reset) begin
       count  <= 0;
       enable <= 0;
     end else begin
       if (count == CLK_DIV_COUNT-1) begin
         count  <= 0;
         enable <= 1;
       end else begin
         count  <= count + 1;
         enable <= 0;
       end
     end
   end

   // TX state machine
   always_ff @(posedge clk) begin
      if (reset) begin
         tx_state       <= TX_WAIT;
         tx             <= 1'b1;
         tx_ready       <= 1'b1;
         tx_dataBuffer  <= 0;
         tx_count       <= 0;
         tx_sampleCount <= 0;
      end else begin
         case (tx_state)
            TX_WAIT: begin
               tx       <= 1'b1;
               tx_ready <= 1'b1;
               if (tx_transmit && tx_ready) begin
                  // start bit = 0, data LSB→MSB, stop bit = 1
                  tx_dataBuffer  <= {1'b1, tx_data, 1'b0};
                  tx_count       <= 0;
                  tx_sampleCount <= 0;
                  tx_ready       <= 1'b0;
                  tx_state       <= TX_TRANSMITTING;
               end
            end
            TX_TRANSMITTING: begin
               if (enable) begin
                  if (tx_count == OSF-1) begin
                    tx_count       <= 0;
                    tx             <= tx_dataBuffer[0];
                    tx_dataBuffer  <= {1'b1, tx_dataBuffer[9:1]};
                    if (tx_sampleCount == 9)
                      tx_state <= TX_WAIT;
                    else
                      tx_sampleCount <= tx_sampleCount + 1;
                  end else begin
                    tx_count <= tx_count + 1;
                  end
               end
            end
         endcase
      end
   end
endmodule



//------------------------------------------------------------------------------
// uart_frame_top_pong_score.sv
// — Pong with scoring: paddles @200 Hz, ball @20 Hz over a 400×256 field,
//   scores increment when ball misses paddle, reset ball, 9-byte UART frame:
//   0xAA,p1,p2,bx_m,bx_l,by_m,by_l,sc1,sc2
//------------------------------------------------------------------------------

module uart_frame_top (
  input  logic        clk,       // 50 MHz
  input  logic        key0,      // ↑p1 (active-low)
  input  logic        key1,      // ↓p1 (active-low)
  input  logic        sw0,       // pause (active-high)
  output logic        uart_tx
);

  //------------------------------------------------------------------------
  // Parameters & Play Enable
  //------------------------------------------------------------------------
  localparam int FIELD_W   = 400;
  localparam int FIELD_H   = 256;
  localparam int P_WIDTH   = 6;
  localparam int P_HEIGHT  = 50;
  localparam int P1_X      = 20;
  localparam int P2_X      = FIELD_W - P_WIDTH - 20;  // =374

  logic play_en, prev_play_en;
  assign play_en = ~sw0;

  //------------------------------------------------------------------------
  // Tick Generators: paddles @200 Hz, ball @100 Hz, AI @90 Hz
  //------------------------------------------------------------------------
  localparam int PADDLE_DIV = 19'd250_000;  // 50e6/200
  localparam int BALL_DIV   = 19'd500_000;  // 50e6/100
  localparam int AI_DIV     = 20'd640_000;  // approx 50e6/90

  logic [18:0] cnt_paddle, cnt_ball, cnt_ai;
  wire         tick_paddle = (cnt_paddle == 0);
  wire         tick_ball   = (cnt_ball   == 0);
  wire         tick_ai     = (cnt_ai     == 0);

  always_ff @(posedge clk) begin
    cnt_paddle   <= tick_paddle ? PADDLE_DIV-1 : cnt_paddle - 1;
    cnt_ball     <= tick_ball   ? BALL_DIV  -1 : cnt_ball   - 1;
    cnt_ai       <= tick_ai     ? AI_DIV    -1 : cnt_ai     - 1;
    prev_play_en <= play_en;
  end

  //------------------------------------------------------------------------
  // Random LFSR for serve sign
  //------------------------------------------------------------------------
  logic [7:0] lfsr;
  logic       lfsr_fb;
  initial lfsr = 8'hA5;
  always_ff @(posedge clk) if (tick_ball) begin
    lfsr_fb <= lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];
    lfsr    <= {lfsr[6:0], lfsr_fb};
  end

  //------------------------------------------------------------------------
  // Game State
  //------------------------------------------------------------------------
  logic [7:0]        p1, p2;
  logic [8:0]        bx, by;            // 9-bit unsigned ball coords
  logic signed [7:0] vx, vy;            // ball velocity
  logic [7:0]        score1, score2;
  logic signed [9:0] bx_next, by_next;

  initial begin
    p1         = FIELD_H/2;
    p2         = FIELD_H/2;
    bx         = FIELD_W/2;
    by         = FIELD_H/2;
    vx         = 8'sd1;
    vy         = 8'sd1;
    score1     = 0;
    score2     = 0;
    cnt_paddle = PADDLE_DIV-1;
    cnt_ball   = BALL_DIV  -1;
    cnt_ai     = AI_DIV    -1;
    prev_play_en = 1'b0;
  end

  //------------------------------------------------------------------------
  // Ball movement & scoring @100 Hz + reset on unpause
  //------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (play_en && !prev_play_en) begin
      // Reset scores & ball
      score1 <= 0; score2 <= 0;
      bx     <= FIELD_W/2;
      by     <= FIELD_H/2;
      vx     <= 8'sd1;
      vy     <= lfsr[0] ? 8'sd1 : -8'sd1;
    end else if (tick_ball && play_en) begin
      bx_next = $signed({1'b0, bx}) + vx;
      if (bx_next < 0) begin
        score2 <= score2 + 1;
        bx <= FIELD_W/2; by <= FIELD_H/2;
        vx <= 8'sd1; vy <= lfsr[0] ? 8'sd1 : -8'sd1;
      end else if (bx_next > FIELD_W-1) begin
        score1 <= score1 + 1;
        bx <= FIELD_W/2; by <= FIELD_H/2;
        vx <= -8'sd1; vy <= lfsr[0] ? 8'sd1 : -8'sd1;
      end else begin
        bx <= bx_next[8:0];
        by_next = $signed({1'b0, by}) + vy;
        if (by_next < 0 || by_next > FIELD_H-1) begin
          vy <= -vy;
          by <= (by_next < 0 ? 0 : FIELD_H-1);
        end else begin
          by <= by_next[8:0];
        end
        // Left paddle collision
        if (vx < 0 && bx == P1_X + P_WIDTH && by >= p1 && by < p1+P_HEIGHT)
          vx <= -vx;
        // Right paddle improved collision
        if (vx > 0 && bx >= P2_X - 1 && by >= p2 && by < p2+P_HEIGHT)
          vx <= -vx;
      end
    end
  end

  //------------------------------------------------------------------------
  // Paddle1 manual control @200 Hz
  //------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (tick_paddle && play_en) begin
      if (~key0 && p1 < FIELD_H-P_HEIGHT)
        p1 <= p1 + 1;
      else if (~key1 && p1 > 0)
        p1 <= p1 - 1;
    end
  end

  //------------------------------------------------------------------------
    // AI Paddle2 tracking @90 Hz with heavy random skips (~12.5% moves)
  always_ff @(posedge clk) begin
    if (tick_ai && play_en && (lfsr[0] & lfsr[1])) begin
      if (by > (p2 + P_HEIGHT/2) && p2 < FIELD_H-P_HEIGHT)
        p2 <= p2 + 1;
      else if (by < (p2 + P_HEIGHT/2) && p2 > 0)
        p2 <= p2 - 1;
    end
  end
  

  //------------------------------------------------------------------------
  // UART frame generator (~1 ms gap)
  // 9-byte frame: sync,p1,p2,bx_M,bx_L,by_M,by_L,score1,score2
  //------------------------------------------------------------------------
  logic [15:0] gap_cnt;
  wire send_ok = (gap_cnt == 0);
  always_ff @(posedge clk)
    gap_cnt <= send_ok ? 16'd50000 : gap_cnt - 1;

  logic [7:0] frame_data [0:8];
  logic [3:0] byte_idx;
  logic [7:0] tx_data;
  logic       tx_transmit;
  wire        tx_ready;

  always_comb begin
    frame_data[0] = 8'hAA;
    frame_data[1] = p1;
    frame_data[2] = p2;
    frame_data[3] = bx[8]; frame_data[4] = bx[7:0];
    frame_data[5] = by[8]; frame_data[6] = by[7:0];
    frame_data[7] = score1; frame_data[8] = score2;
  end

  always_ff @(posedge clk) begin
    if (tx_ready && send_ok) begin
      tx_data     <= frame_data[byte_idx];
      tx_transmit <= 1'b1;
      byte_idx    <= (byte_idx == 8) ? 0 : byte_idx + 1;
    end else tx_transmit <= 1'b0;
  end

  // UART instantiation
  uart #(
    .CLK_FREQ(50_000_000),
    .BAUD    (115200)
  ) uart_inst (
    .clk         (clk),
    .reset       (1'b0),
    .rx          (1'b1),
    .rx_data     (),
    .rx_valid    (),
    .tx          (uart_tx),
    .tx_data     (tx_data),
    .tx_transmit (tx_transmit),
    .tx_ready    (tx_ready)
  );

endmodule
// -*- coding: utf-8-unix; tab-width: 8; indent-tabs-mode: nil; -*-

// UART Sample for de0
// Copyright (c) 2013, TABATA Keiichi. All rights reserved.

/*
 * UART文字送受信モジュール用 トップモジュール
 *  - 受信した文字をそのまま送信する
 *  - 受信した文字を7セグメントLEDの右2桁で16進数表示する
 *  - UARTの信号の状態(0/1)を7セグメントLEDに表示する
 *  -- TXD ... 左から1桁目
 *  -- RXD ... 左から2桁目
 */
module uart_top
  (
   input        xreset,
   input        clock,
   output       uart_txd,
   input        uart_rxd,
   output [6:0] hex_led0,
   output [6:0] hex_led1,
   output [6:0] hex_led2,
   output [6:0] hex_led3);

   /*
    * レジスタ
    */
   reg  [7:0] disp_digit; // 7セグメントLEDに表示する文字

   /*
    * 配線
    */
   wire       send_en, recv_en, send_ready;
   wire [7:0] send_data, recv_data;

   // 受信したサイクルに送信を行うよう配線する
   assign send_en   = send_ready && recv_en;
   assign send_data = recv_data;

   /*
    * UART文字送受信モジュール
    */
   uart uart(// クロック系統
             .xreset(xreset),
             .clock(clock),
             // UART端子
             .uart_txd(uart_txd),
             .uart_rxd(uart_rxd),
             // 送信
             .send_en(send_en),
             .send_data(send_data),
             .send_ready(send_ready),
             // 受信
             .recv_en(recv_en),
             .recv_data(recv_data));

   /*
    * 受信した文字をdisp_digitに保存する動作
    */
   always @(posedge clock or negedge xreset)
     begin
        if (!xreset)
          begin
             disp_digit <= 8'h00;
          end
        else
          begin
             // 文字を受信したとき
             if (recv_en)
               begin
                  // 受信した文字を保存する
                  disp_digit <= recv_data;
               end
          end
     end

   /*
    * 7セグメントLEDデコーダ
    */
   assign hex_led3 = hex_dec(uart_txd);
   assign hex_led2 = hex_dec(uart_rxd);
   assign hex_led1 = hex_dec(disp_digit[7:4]);
   assign hex_led0 = hex_dec(disp_digit[3:0]);
   function [6:0] hex_dec;
      input [3:0] val;
      case(val)
        4'h0: hex_dec = 7'b1000000;
        4'h1: hex_dec = 7'b1111001;
        4'h2: hex_dec = 7'b0100100;
        4'h3: hex_dec = 7'b0110000;
        4'h4: hex_dec = 7'b0011001;
        4'h5: hex_dec = 7'b0010010;
        4'h6: hex_dec = 7'b0000010;
        4'h7: hex_dec = 7'b1011000;
        4'h8: hex_dec = 7'b0000000;
        4'h9: hex_dec = 7'b0010000;
        4'hA: hex_dec = 7'b0001000;
        4'hB: hex_dec = 7'b0000011;
        4'hC: hex_dec = 7'b0100111;
        4'hD: hex_dec = 7'b0100001;
        4'hE: hex_dec = 7'b0000110;
        4'hF: hex_dec = 7'b0001110;
        default: hex_dec = 7'b0100011;
      endcase
   endfunction
endmodule

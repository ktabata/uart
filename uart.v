// -*- coding: utf-8-unix; tab-width: 8; indent-tabs-mode: nil; -*-

// UART Sample for de0
// Copyright (c) 2013, TABATA Keiichi. All rights reserved.

/*
 * UART単一文字送受信モジュール
 */
module uart
  #(parameter
    // 分周カウント値 (default: 50MHz to 38.4kHz)
    COUNT = 11'd1302)
   (
    // クロック系統
    input        xreset,      // リセット
    input        clock,       // クロック
    // UART端子
    output       uart_txd,    // UARTのTXD端子
    input        uart_rxd,    // UARTのRXD端子
    // 送信
    input        send_en,     // 送信イネーブル
    input  [7:0] send_data,   // 送信文字
    output       send_ready,  // 送信レディ
    // 受信
    output reg   recv_en,     // 受信イネーブル
    output [7:0] recv_data);  // 受信文字

   /*
    * 送受信の状態
    */
   localparam ST_WAIT  = 4'd0;  // スタートビット待機/送信イネーブル待機
   localparam ST_START = 4'd1;  // スタートビット送受信
   localparam ST_BIT0  = 4'd2;  // BIT0送受信
   localparam ST_BIT1  = 4'd3;  // BIT1送受信
   localparam ST_BIT2  = 4'd4;  // BIT2送受信
   localparam ST_BIT3  = 4'd5;  // BIT3送受信
   localparam ST_BIT4  = 4'd6;  // BIT4送受信
   localparam ST_BIT5  = 4'd7;  // BIT5送受信
   localparam ST_BIT6  = 4'd8;  // BIT6送受信
   localparam ST_BIT7  = 4'd9;  // BIT7送受信
   localparam ST_STOP  = 4'd10; // ストップビット送受信
   localparam ST_SYNC  = 4'd11; // ストップビット送受信時間同期

   /*
    * レジスタ
    */
   reg [10:0]    tx_count;  // 送信分周カウンタ
   reg [10:0]    rx_count;  // 受信分周カウンタ
   reg [3:0]     tx_st;     // 受信の状態
   reg [3:0]     rx_st;     // 受信の状態
   reg           tx_bit;    // TXD送出用F/F
   reg           rx_bit;    // RXDサンプリング用F/F
   reg [7:0]     tx_buf;    // 受信バッファ
   reg [7:0]     rx_buf;    // 送信バッファ

   /*
    * 配線
    */
   wire tx_timing; // 分周クロックイネーブル(送信)
   wire rx_timing; // 分周クロックイネーブル(受信)

   assign uart_txd   = tx_bit;
   assign send_ready = tx_st == ST_WAIT;
   assign recv_data  = rx_buf;

   assign tx_timing = tx_count == 11'd0;
   assign rx_timing = rx_count == 11'd0;

   /*
    * UART
    */
   always @(posedge clock or negedge xreset)
     begin
        if (!xreset)
          begin
             tx_count <= COUNT;
             rx_count <= COUNT;
             tx_st    <= ST_WAIT;
             rx_st    <= ST_WAIT;
             tx_bit   <= 1'b1; // High
             rx_bit   <= 1'b0;
             tx_buf   <= 8'd0;
             rx_buf   <= 8'hff;
          end
        else
          begin
             /*
              * 送信動作
              */

             // 分周カウンタのデクリメントおよびリセットを行う
             //  - 受信と異なり待機状態でも動作し、間隔も変化しない
             tx_count <= (tx_count != 0) ? (tx_count - 1'd1) : COUNT;

             // 送信イネーブル待機状態
             //  - この状態のみ分周カウンタが0でなくても実行される
             if (tx_st == ST_WAIT)
               begin
                  // 送信イネーブルを検出した場合
                  if (send_en)
                    begin
                       // 送信するデータを保存する
                       tx_buf <= send_data;

                       // スタートビット送信状態に遷移する
                       tx_st <= ST_START;
                    end
               end

             // 分周カウンタが0のタイミングのみ動作する
             else if (tx_timing)
               begin
                  // スタートビット送信状態
                  if (tx_st == ST_START)
                    begin
                       // スタートビットの送信を行う (1サイクル遅れ)
                       tx_bit <= 1'b0; // Low

                       // BIT0送信状態に遷移する
                       tx_st <= ST_BIT0;
                    end

                  // BIT0..7送信状態
                  else if (tx_st >= ST_BIT0 && tx_st <= ST_BIT7)
                    begin
                       // 下位ビットから順に送信する (1サイクル遅れ)
                       tx_bit <= tx_buf[0];
                       tx_buf <= tx_buf >> 1;

                       // 次のビットの送信状態に遷移する
                       tx_st <= tx_st + 4'd1;
                    end

                  // ストップビット送信状態
                  else if (tx_st == ST_STOP)
                    begin
                       // ストップビットの送信を行う (1サイクル遅れ)
                       tx_bit <= 1'b1; // High

                       // ストップビット同期状態に遷移する
                       tx_st <= ST_SYNC;
                    end

                  // ストップビット送信時間同期状態
                  else if (tx_st == ST_SYNC)
                    begin
                       // 送信イネーブル待機状態に遷移する
                       tx_st <= ST_WAIT;
                    end
               end

             /*
              * 受信動作
              *  - 分周カウンタの周期は同期を取るために変化する
              *  -- 分周カウンタというよりタイミング用のカウンタ
              *  - ST_WAIT状態では分周カウンタを利用しないので動作させない
              */

             // ソースクロックでRXDをサンプリングする
             rx_bit <= uart_rxd;

             // 待機状態
             if (rx_st == ST_WAIT)
               begin
                  // 受信イネーブルをクリアする
                  //  - 前サイクルで受信完了した場合のため
                  recv_en <= 1'b0;

                  // 信号の立ち下がりを検出した場合
                  if (!rx_bit)
                    begin
                       // 分周カウンタをリセットする
                       //  - 周期の真ん中で受信する
                       rx_count <= COUNT / 2'd2;

                       // スタートビットの受信状態に遷移する
                       rx_st <= ST_START;
                    end
               end

             // 分周カウンタが0のタイミングのとき
             else if (rx_timing)
               begin
                  // スタートビット受信状態 (検出から半周期後)
                  if (rx_st == ST_START)
                    begin
                       // スタートビットの継続を検出する
                       if (!rx_bit)
                         begin
                            // ビット0の受信状態に遷移する
                            rx_st <= ST_BIT0;

                            // 分周カウンタをリセットする
                            rx_count <= COUNT;
                         end
                       else
                         begin
                            // 待機状態に遷移する
                            rx_st <= ST_WAIT;
                         end
                    end

                  // BIT0..7受信状態
                  else if (rx_st >= ST_BIT0 && rx_st <= ST_BIT7)
                    begin
                       // 下位ビットから順に受信する
                       rx_buf <= {rx_bit, rx_buf[7:1]};

                       // 分周カウンタをリセットする
                       rx_count <= COUNT;

                       // 次のビットの受信状態に遷移する
                       rx_st <= rx_st + 4'd1;
                    end

                  // ストップビット受信状態
                  else if (rx_st == ST_STOP)
                    begin
                       // ストップビットを検出する
                       if (rx_bit)
                         begin
                            // 分周カウンタをリセットする
                            //  - 残り半周期のストップビットが終了するのを待つ
                            //  - 少なめに待つことで、直後に連続するスタート
                            //    ビットに同期する
                            rx_count <= COUNT / 2'd2 - COUNT / 4'd8;

                            // ストップビット同期状態に遷移する
                            rx_st <= ST_SYNC;
                         end
                       else
                         begin
                            // スタートビット待機状態に遷移する
                            rx_st <= ST_WAIT;
                         end
                    end

                  // ストップビット受信時間同期状態
                  else if (rx_st == ST_SYNC)
                    begin
                       // ストップビットを確認して、受信イネーブルをセットする
                       if (rx_bit)
                         recv_en <= 1'b1;

                       // スタートビット待機状態に遷移する
                       rx_st <= ST_WAIT;
                    end
               end

             // 受信動作中であり、分周カウンタが0でない場合
             else
               begin
                  // 分周カウンタをデクリメントする
                  rx_count <= rx_count - 1'd1;
               end
          end
     end
endmodule

/*
  Basic serial transmitter (UART)
  Copyright (c) 2020 Stanislav Jurny (github.com/STjurny) license MIT

  Serial data format is 8 data bits, without parity, one stop bit (8N1) without hardware flow control.
  Set parameters pClockFrequency and pBaudRate to requirements of your design (pBaudRate can be 
  max 1/3 of pClockFrequency). For high baud rates check values of parametrization report pInaccuracyPerFrame and 
  pInaccuracyThreshhold to ensure that ClockFrequency / BaudRate ratio generates acceptable inaccuracy of frame length.
  Generally pInaccuracyPerFrame have to be less than pInaccuracyThreshhold. For ideal ratio is pInaccuracyPerFrame = 0.

  For send a byte set iData to required value and set iSend to 1 for at least one clock cycle. The module
  takes over data into its own buffer and starts transmitting. The iData value has to be valid only for first tick
  after iSend was asserted. The signal oReady indicates readiness to take over next byte for send. The signal is
  set to 0 after take over byte to send and during transmitting the start and data bits. After last data bit sent
  the oReady signal is immediatelly set to 1 so a next byte to send can be pass already during transmitting
  stop bit of previous byte. Because of that there is not any delay before transmitting the next byte.
  
  Module supports automatic power on reset (after load bitstream to the FPGA), explicit reset over iReset signal or both 
  of them. Mode of reset is determined by preprocessor symbols GlobalReset and PowerOnReset. Edit the Global.inc file 
  to select reset modes.
*/

`define PowerOnReset

  
module SerialTransmitter #(
  parameter pClockFrequency = 16000000,  
    //^ System clock frequency.
      
  parameter pBaudRate = 115200     
    //^ Serial output baud rate (..., 9600, 115200, 2000000, ...)
    //^ Can be value from arbitrary low to max 1/3 of pClockFrequency.
)(
  input wire iClock,       
    //^ System clock with frequency specified in the parameter pClockFrequency.
      
  input wire [7:0] iData,  
    //^ Data to send (have to be valid first clock after set iSend to 1).
      
  input wire iSend,        
    //^ Set to 1 for at least one clock cycle for start the sending.
      
  output wire oReady,   
    //^ Signalizes readiness to take over next byte to send.
      
  output wire oTxd          
    //^ Serial data output with baudrate specified in the parameter pBaudRate.
    

  ,input wire iReset
    //^ Reset module to initial state (reset is synchronized with posedge, set to 1 for one clock is enough).
    //^ Module can begin transmit data in next clock tick after the iReset was set to 0.

);


localparam
  pTicksPerBit = pClockFrequency / pBaudRate,
  pBitTimerMsb = $clog2(pTicksPerBit) - 1,
  pLastTickOfBit = pTicksPerBit - 1;

localparam
  pTicksPerFrame = pClockFrequency * 10 / pBaudRate,
  pInaccuracyPerFrame = pTicksPerFrame - pTicksPerBit * 10,
  pInaccuracyThreshhold = pTicksPerBit / 2;


initial  // parametrization report
  begin
    $display("%m|1|--");
    
    `ifdef GlobalReset
      $display("%m|1|GlobalReset = yes");
    `else
      $display("%m|1|GlobalReset = no");
    `endif
    
    `ifdef PowerOnReset
      $display("%m|1|PowerOnReset = yes");
    `else
      $display("%m|1|PowerOnReset = no");
    `endif
    
    $display("%m|1|pClockFrequency = '%d", pClockFrequency);
    $display("%m|1|pBaudRate = '%d", pBaudRate);
    $display("%m|1|--");
    $display("%m|1|pTicksPerBit = '%d", pTicksPerBit);
    $display("%m|1|pTicksPerFrame = '%d", pTicksPerFrame);    
    $display("%m|1|--");
    $display("%m|1|pInaccuracyPerFrame = '%d", pInaccuracyPerFrame);    
    $display("%m|1|pInaccuracyThreshhold = '%d", pInaccuracyThreshhold);    
    $display("%m|1|--");
    $display("%m|1|pLastTickOfBit = '%d", pLastTickOfBit);
    $display("%m|1|cBitTimer range = '%d:0", pBitTimerMsb);
    
    if (pTicksPerBit < 3) 
      begin
        $display("%m|0|Error: Parameter pBaudrate can be max 1/3 of clock frequency.");
        $stop;
      end
  end


localparam // $State:2,st
  stIdle     = 0,
  stStartBit = 1,
  stDataBit  = 2,
  stStopBit  = 3;


reg [pBitTimerMsb:0] cBitTimer;
reg cBitSent;

reg [1:0] cState;
reg [7:0] cBuffer;
reg [2:0] cBitIndex;

reg cReady; 
assign oReady = cReady;

reg cnTxd; 
assign oTxd = ~cnTxd;  // negation because iCEcude2 can initialize registers after power on reset only to zero


`ifdef PowerOnReset
initial
  begin
    cBitTimer = 0;
    cBitSent = 0;

    cState = stIdle;
    cReady = 0;
    cBitIndex = 0;

    cnTxd = 0;
  end
`endif


always @(posedge iClock)  // serial bit output timer
  `ifdef GlobalReset
  if (iReset)
    begin
      cBitTimer <= 0;
      cBitSent <= 0;
    end
  else
  `endif
    begin
      if (cState == stIdle || cBitSent)
        cBitTimer <= 0;
      else
        cBitTimer <= cBitTimer + 1;

      // comparison is potentially complex so we do it separately one clock earlier
      cBitSent <= cBitTimer == (pLastTickOfBit[pBitTimerMsb:0] - 1);
    end


always @(posedge iClock)  // transmitter FSM
  `ifdef GlobalReset
  if (iReset)
    begin
      cState <= stIdle;
      cReady <= 0;
      cBitIndex <= 0;
    end
  else
  `endif
    case (cState) 
      stIdle:
        if (iSend)
          begin
            cBuffer <= iData;
            cReady <= 0;
            cState <= stStartBit;
          end
        else
          cReady <= 1;
          
      stStartBit: 
        if (cBitSent)
          cState <= stDataBit;
              
      stDataBit:
        if (cBitSent)
          begin
            cBuffer <= cBuffer >> 1;  
            cBitIndex <= cBitIndex + 1;

            if (cBitIndex == 7)
              begin
                cReady <= 1;
                cState <= stStopBit;
              end;
          end
          
      stStopBit:
        begin: stopBit
          reg nReady; 
          nReady = cReady;
          
          if (cReady && iSend)   // next byte to send can be passed before sending of stop bit is completed
            begin                // so there isn't any delay before beginning of sending next byte
              cBuffer <= iData;
              nReady = 0;      
            end

          if (cBitSent)
            if (~nReady)
              cState <= stStartBit;
            else
              cState <= stIdle;
        
          cReady <= nReady;
        end 
    endcase


always @(posedge iClock)  // registered serial output prevents glitches
  `ifdef GlobalReset
  if (iReset)
    cnTxd <= 0;
  else
  `endif
    cnTxd <= ~( 
      cState == stIdle ||
      cState == stStopBit ||
      cState == stDataBit && cBuffer[0]  // cBuffer LSB is a currently sending bit
    );
     
                
endmodule



















datetime currentCandleTime = 0;
datetime macdCrossTime = 0;
datetime sameColorStart = 0;

int GetCandleHoldSeconds() {
    return Period() * 60 * 유지시간_비율_초;
}

﻿//+------------------------------------------------------------------+
//| EA 통합 코드 – ARIHOON-MP-EA-0706 (최종 통합본, FIXED)            |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property copyright "ARIHOON"

//+------------------------------------------------------------------+
//| 📦 1부: 기본 설정 및 초기 변수 선언                               |
//+------------------------------------------------------------------+
int 매직넘버;
input int 허용_계좌번호 = 12345678;         // EA 사용 허용 계좌번호
input datetime 사용_만료일자 = D'2025.12.31'; // 사용 만료일 (이후 차단)

input double 진입_랏_크기 = 0.1;
input double 최대_스프레드 = 30.0; // 진입 허용 최대 스프레드 (포인트 단위)
input double 개별_익절_USD = 10;
input double SL_비율_익절기준 = 1.2;
input double 트레일링_스탑_비율 = 0.5;
input double 마틴_배율 = 2.0;
input int 마틴_대기시간_초 = 300;

input int 재진입_대기시간_초 = 3;
int 매직넘버;
bool isFirstEntryReady = false;
bool isReEntryReady = false;
bool isPartialExit = false;


string lastSignal = "없음";
bool isMartin1Entered = false;
bool isMartin2Entered = false;
bool isMartin2Entered = false;
bool isPositionActive = false;
double entryPrice = 0;
double stopLossPrice = 0;
double takeProfitPrice = 0;
datetime entryTime = 0;
datetime lastExitTime = 0;

//+------------------------------------------------------------------+
//| 📦 2부: 진입 조건 / 유지시간 / OrderSend 처리                      |
//+------------------------------------------------------------------+
bool CheckMACDEntryCondition() {
   double macdCurrent = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
   double macdSignal = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
   double macdPrev = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 1);
   double signalPrev = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 1);
   return (macdPrev < signalPrev && macdCurrent > macdSignal);
}

bool IsHoldTimePassed() {
   int candleSeconds = Period() * 60;
   int holdSeconds = MathMax(candleSeconds / 10, 1);
   return (TimeCurrent() - entryTime >= holdSeconds);
}

void ExecuteEntry(double lots) {
   double price = Ask;
   double sl = price - 개별_익절_USD * SL_비율_익절기준 / MarketInfo(Symbol(), MODE_TICKVALUE);
   double tp = price + 개별_익절_USD / MarketInfo(Symbol(), MODE_TICKVALUE);

   int ticket = OrderSend(Symbol(), OP_BUY, lots, price, 3, sl, tp, "ARIHOON_ENTRY", 매직넘버, 0, clrDodgerBlue);
   if (ticket > 0) {
      isPositionActive = true;
      entryPrice = price;
      stopLossPrice = sl;
      takeProfitPrice = tp;
      entryTime = TimeCurrent();
      lastSignal = "Buy";
      DrawEntryArrow(price);
      DrawSLTPLine(sl, tp);
      SaveToCSV("진입", lastSignal, lots, price);
   } else {
      PrintError("OrderSend(Entry)", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| 📦 3부: 마틴 진입 / SLTP 계산 / HUD 표시                           |
//+------------------------------------------------------------------+
void CheckMartinEntry() {
   if (!isPositionActive) return;

   double lots = 진입_랏_크기;
   double martinLots = NormalizeDouble(lots * 마틴_배율, 2);
   double price = Ask;

   if (!isMartin1Entered && TimeCurrent() - entryTime >= 마틴_대기시간_초) {
      int ticket1 = OrderSend(Symbol(), OP_BUY, martinLots, price, 3, 0, 0, "Martin1", 매직넘버, 0, clrRed);
      if (ticket1 > 0) {
         isMartin1Entered = true;
         SaveToCSV("마틴1", lastSignal, martinLots, price);
      } else {
         PrintError("OrderSend(Martin1)", GetLastError());
      }
   } else if (isMartin1Entered && !isMartin2Entered && TimeCurrent() - entryTime >= 마틴_대기시간_초 * 2) {
      int ticket2 = OrderSend(Symbol(), OP_BUY, martinLots, price, 3, 0, 0, "Martin2", 매직넘버, 0, clrDarkViolet);
      if (ticket2 > 0) {
         isMartin2Entered = true;
         SaveToCSV("마틴2", lastSignal, martinLots, price);
      } else {
         PrintError("OrderSend(Martin2)", GetLastError());
      }
   }
}

void DrawHUD() {
   string trendText = " !추세 : " + lastSignal;
   string martinText = " !마틴상태 : " + (isMartin2Entered ? "2차" : (isMartin1Entered ? "1차" : "NO"));
   string profitText = " !수익 : " + DoubleToString(AccountProfit(), 2);
   string statusText = " !포지션 : " + (isPositionActive ? "진입" : "대기중");
   string fullText = trendText + "\n" + martinText + "\n" + profitText + "\n" + statusText;

   if (ObjectFind("ARIHOON_HUD") == -1) {
      ObjectCreate("ARIHOON_HUD", OBJ_LABEL, 0, 0, 0);
      ObjectSet("ARIHOON_HUD", OBJPROP_CORNER, 0);
      ObjectSet("ARIHOON_HUD", OBJPROP_XDISTANCE, 10);
      ObjectSet("ARIHOON_HUD", OBJPROP_YDISTANCE, 10);
      ObjectSet("ARIHOON_HUD", OBJPROP_FONTSIZE, 12);
   }
   ObjectSetText("ARIHOON_HUD", fullText, 12, "Arial", clrDodgerBlue);
}

void CheckExitConditions() {
   if (!isPositionActive) return;

   double currentPrice = Bid;

   double macd = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
   double signal = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
   if (macd < signal && currentPrice > entryPrice) {
      double halfProfit = entryPrice + (takeProfitPrice - entryPrice) * 0.5;
      CloseAllOrdersAtPrice(halfProfit);
      isPositionActive = false;
      ClearObjectsOnClose();
      return;
   }

   double trailTrigger = entryPrice + (takeProfitPrice - entryPrice) * 0.5;
   double newSL = currentPrice - (takeProfitPrice - entryPrice) * 트레일링_스탑_비율;
   if (currentPrice > trailTrigger && newSL > stopLossPrice) {
      stopLossPrice = newSL;
      ModifyStopLossAllOrders(newSL);
   }

   if (currentPrice >= takeProfitPrice) {
      CloseAllOrdersAtPrice(takeProfitPrice);
      isPositionActive = false;
      ClearObjectsOnClose();
      return;
   }

   if (currentPrice <= stopLossPrice) {
      CloseAllOrdersAtPrice(stopLossPrice);
      isPositionActive = false;
      ClearObjectsOnClose();
   }
}

void DrawEntryArrow(double price) {
   string arrowName = "EntryArrow" + TimeToString(TimeLocal(), TIME_SECONDS);
   ObjectCreate(arrowName, OBJ_ARROW, 0, Time[0], price);
   ObjectSet(arrowName, OBJPROP_ARROWCODE, 233);
   ObjectSet(arrowName, OBJPROP_COLOR, clrLime);
}

void DrawSLTPLine(double sl, double tp) {
   ObjectCreate("SL_Line", OBJ_HLINE, 0, 0, sl);
   ObjectSet("SL_Line", OBJPROP_COLOR, clrRed);
   ObjectCreate("TP_Line", OBJ_HLINE, 0, 0, tp);
   ObjectSet("TP_Line", OBJPROP_COLOR, clrBlue);
}

// void ModifyStopLossAllOrders(double newSL) {  // Removed duplicate
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber() == 매직넘버 && OrderSymbol() == Symbol()) {
            OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrOrange);
         }
      }
   }
}

void CloseAllOrdersAtPrice(double price) {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber() == 매직넘버 && OrderSymbol() == Symbol()) {
            if (OrderClose(OrderTicket(), OrderLots(), price, 3, clrRed)) {
               SaveToCSV("청산", lastSignal, OrderLots(), price);
            }
         }
      }
   }
}

void ClearObjectsOnClose() {
   ObjectDelete("SL_Line");
   ObjectDelete("TP_Line");
   ObjectDelete("ARIHOON_HUD");
   isMartin1Entered = false;
   isMartin2Entered = false;
   isPositionActive = false;
   entryPrice = 0;
   stopLossPrice = 0;
   takeProfitPrice = 0;
   entryTime = 0;
}

void SaveToCSV(string action, string direction, double lots, double price) {
   string filename = "Arihoon_TradeLog.csv";
   int handle = FileOpen(filename, FILE_CSV | FILE_WRITE | FILE_READ, ';');
   if (handle != INVALID_HANDLE) {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle,
         TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
         Symbol(), action, direction,
         DoubleToString(lots, 2), DoubleToString(price, Digits),
         DoubleToString(AccountProfit(), 2));
      FileClose(handle);
   }
}

bool CheckLicense() {
   int 허용계좌 = 774011;
   datetime 만료일 = D'2025.12.31';
   if (AccountNumber() != 허용계좌) {
      Alert("⚠️ 허용되지 않은 계좌입니다.");
      return false;
   }
   if (TimeCurrent() > 만료일) {
      Alert("⏳ EA 사용 기간이 만료되었습니다.");
      return false;
   }
   return true;
}

void PrintError(string source, int code) {
   string msg = StringFormat("[%s] 오류 코드: %d", source, code);
   Print(msg);
   Alert(msg);
}

string GetDirectionString(int type) {
   if (type == OP_BUY) return "BUY";
   if (type == OP_SELL) return "SELL";
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| 필수 진입 함수들                                                  |
//+------------------------------------------------------------------+
int OnInit() {
if (AccountNumber() != 허용_계좌번호) {
        Alert("❌ 계좌번호 불일치: EA 실행이 차단됩니다.");
        return(INIT_FAILED);
    }
    if (TimeCurrent() > 사용_만료일자) {
        Alert("❌ EA 사용 기간이 만료되었습니다.");
        return(INIT_FAILED);
    }
    
매직넘버 = StringToInteger(StringSubstr(Symbol(), 0, 6) + IntegerToString(Period())) + EA_ID * 100000;;

   Print("✅ ARIHOON EA 초기화 완료");
   return(INIT_SUCCEEDED);
}


void MartinEntryLogic() {
   if (!isPositionActive) return;

   double profit = 0;
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber() != 매직넘버 || OrderSymbol() != Symbol()) continue;
         profit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   // 1차 마틴 진입 조건
   if (!isMartin1Entered && profit < 0 && TimeCurrent() - entryTime > 마틴_대기시간_초) {
      if (IsMACDSameDirection()) {
         double lots = 진입_랏_크기 * 마틴_배율;
         int ticket = OrderSend(Symbol(), lastSignal == "BUY" ? OP_BUY : OP_SELL, lots, Ask, 3, 0, 0, "Martin1", 매직넘버, 0, clrRed);
         if (ticket > 0) {
            isMartin1Entered = true;
            entryTime = TimeCurrent();
            SaveToCSV("Martin1", lastSignal, lots, Ask);
            DrawSLLine(ticket);
         }
      }
   }

   // 2차 마틴 진입 조건
   if (isMartin1Entered && !isMartin2Entered && profit < 0 && TimeCurrent() - entryTime > 마틴_대기시간_초 * 2) {
      if (IsMACDSameDirection()) {
         double lots = 진입_랏_크기 * 마틴_배율 * 마틴_배율;
         int ticket = OrderSend(Symbol(), lastSignal == "BUY" ? OP_BUY : OP_SELL, lots, Ask, 3, 0, 0, "Martin2", 매직넘버, 0, clrRed);
         if (ticket > 0) {
            isMartin2Entered = true;
            entryTime = TimeCurrent();
            SaveToCSV("Martin2", lastSignal, lots, Ask);
            DrawSLLine(ticket);
         }
      }
   }
}

// MACD 동일 방향 유지 확인 함수 (단순 구현)
bool IsMACDSameDirection() {
   double macdCurrent, signalCurrent, macdPrev, signalPrev;
   int macdHandle = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE);
   macdCurrent = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
   signalCurrent = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
   macdPrev = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 1);
   signalPrev = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 1);

   if (lastSignal == "BUY")
      return macdCurrent > signalCurrent && macdPrev > signalPrev;
   else if (lastSignal == "SELL")
      return macdCurrent < signalCurrent && macdPrev < signalPrev;
   return false;
}

// SL 라인 시각화 함수
void DrawSLLine(int ticket) {
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   double sl = OrderStopLoss();
   string name = "SL_Line_" + IntegerToString(ticket);
   ObjectDelete(name);
   ObjectCreate(name, OBJ_HLINE, 0, 0, sl);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
}


void OnTick() {
// === 2차 마틴 조건 ===
if (isMartin1Entered && !isMartin2Entered && !isPartialExit)
{
    if (isLossPosition() && SameDirectionMACD())
    {
        if (macdSameDirectionStart == 0)
            macdSameDirectionStart = TimeCurrent();

        if (TimeCurrent() - macdSameDirectionStart >= 마틴_대기시간_초)
        {
            double martin1Lots = 진입_랏_크기 * 마틴_배율;
            double martin2Lots = martin1Lots * 마틴_배율;
            if (CanOpenNewOrder())
            {
                int ticket = OpenOrder(martin2Lots, currentTradeDirection);
                if (ticket > 0)
                {
                    isMartin2Entered = true;
                    isPartialExit = false; // 반익절 초기화
                    macdSameDirectionStart = 0;
                    Print("✅ 2차 마틴 진입 완료. 랏:", martin2Lots);
                }
            }
        }
    }
    else
    {
        macdSameDirectionStart = 0; // 방향 유지 안되면 초기화
    }
}
// === 트레일링 스탑 로직 ===
    if (isPartialExit)
    {
        for (int i = OrdersTotal() - 1; i >= 0; i--)
        {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
                {
                    double entryPrice = OrderOpenPrice();
                    double tpDistance = 개별_익절_USD * MarketInfo(Symbol(), MODE_TICKVALUE) / MarketInfo(Symbol(), MODE_TICKSIZE);
                    double trailingStopDistance = tpDistance * 트레일링_스탑_비율;

                    if (OrderType() == OP_BUY)
                    {
                        double triggerPrice = entryPrice + trailingStopDistance * Point;
                        if (Bid > triggerPrice)
                        {
//                             double newSL = Bid - trailingStopDistance * Point;  // Removed duplicate
                            if (NormalizeDouble(OrderStopLoss(), Digits) < NormalizeDouble(newSL, Digits))
                                OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrOrange);
                        }
                    }
                    if (OrderType() == OP_SELL)
                    {
                        double triggerPrice = entryPrice - trailingStopDistance * Point;
                        if (Ask < triggerPrice)
                        {
//                             double newSL = Ask + trailingStopDistance * Point;  // Removed duplicate
                            if (NormalizeDouble(OrderStopLoss(), Digits) > NormalizeDouble(newSL, Digits))
                                OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrOrange);
                        }
                    }
                }
            }
        }
    }
// 분봉 전환 감지: 캔들 시간이 바뀌면 상태 초기화
    if (Time[0] != currentCandleTime)
    {
        Print("🕒 분봉 전환 감지 - 상태 초기화");
        isFirstEntryReady = false;
        isReEntryReady = false;
        isMartin1Entered = false;
        isMartin2Entered = false;
        isPartialExit = false;
        macdCrossTime = 0;
        sameColorStart = 0;
        currentCandleTime = Time[0];
    }
   if (!CheckLicense()) return;

   DrawHUD();

   if (!isPositionActive && CheckMACDEntryCondition()) {
      ExecuteEntry(진입_랏_크기);
   }

   if (isPositionActive) {
      CheckMartinEntry();
      CheckExitConditions();
   }
}


// === 반익절 및 트레일링스탑 ===

void CheckPartialExitOnMACDCross() {
   if (!isMartin1Entered || isMartin2Entered) return;

   if (IsMACDOppositeSignal()) {
      CloseHalfPositions();
      isPartialExit = true;
   }
}

bool IsMACDOppositeSignal() {
   double macdCurrent = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
   double signalCurrent = iMACD(Symbol(), 0, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
   if (lastSignal == "BUY") return macdCurrent < signalCurrent;
   if (lastSignal == "SELL") return macdCurrent > signalCurrent;
   return false;
}

void CloseHalfPositions() {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber() != 매직넘버 || OrderSymbol() != Symbol()) continue;
         double closeLots = NormalizeDouble(OrderLots() / 2, 2);
         if (closeLots >= MarketInfo(Symbol(), MODE_MINLOT)) {
            OrderClose(OrderTicket(), closeLots, OrderClosePrice(), 3, clrOrange);
         }
      }
   }
}

void ManageTrailingStop() {
   if (!isMartin2Entered) return;

   double trailDistance = 개별_익절_USD * 트레일링_스탑_비율 * Point;
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber() != 매직넘버 || OrderSymbol() != Symbol()) continue;
         double price = OrderOpenPrice();
         if (OrderType() == OP_BUY) {
//             double newSL = Bid - trailDistance;  // Removed duplicate
            if (newSL > OrderStopLoss()) {
               OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(newSL, Digits), OrderTakeProfit(), 0, clrGreen);
            }
         } else if (OrderType() == OP_SELL) {
//             double newSL = Ask + trailDistance;  // Removed duplicate
            if (newSL < OrderStopLoss()) {
               OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(newSL, Digits), OrderTakeProfit(), 0, clrGreen);
            }
         }
      }
   }
}


// === 재진입 조건 ===

datetime lastCloseTime = 0;

void OnTradeCloseTimeUpdate() {
   if (OrdersTotal() == 0) lastCloseTime = TimeCurrent();
}

bool IsReentryAllowed() {
   return (TimeCurrent() - lastCloseTime) >= 재진입_대기시간_초;
}


// === HUD 및 시각화 ===

void DrawSupportResistanceLines() {
   double high = -1, low = 99999;
   for (int i = 0; i < 30; i++) {
      high = MathMax(high, iHigh(Symbol(), PERIOD_H1, i));
      low = MathMin(low, iLow(Symbol(), PERIOD_H1, i));
   }
   ObjectCreate("ResistLine", OBJ_HLINE, 0, 0, high);
   ObjectSetInteger(0, "ResistLine", OBJPROP_COLOR, clrRed);
   ObjectCreate("SupportLine", OBJ_HLINE, 0, 0, low);
   ObjectSetInteger(0, "SupportLine", OBJPROP_COLOR, clrBlue);
}


// === 상태 초기화 ===

void ResetEAState() {
   isFirstEntryReady = false;
   isReEntryReady = false;
   isMartin1Entered = false;
   isMartin2Entered = false;
   isPartialExit = false;
   lastSignal = "없음";

   ObjectDelete("TP_Line_BUY");
   ObjectDelete("TP_Line_SELL");
   ObjectDelete("SL_Line_BUY");
   ObjectDelete("SL_Line_SELL");
   ObjectDelete("HUD_Status");
}


double OnTester() {
    return 0;
}

void OnDeinit(const int reason)
{
    // EA 종료 시 오브젝트 제거
    ObjectsDeleteAll(0, OBJ_LABEL);
    ObjectsDeleteAll(0, OBJ_TREND);
    Print("🧹 EA 종료 - 오브젝트 정리 완료");
}

void OnInit()
{
   string symbol = Symbol();
   int tf = Period();
   매직넘버 = StringToInteger(IntegerToString(tf) + StringSubstr(symbol, 0, 2));
}
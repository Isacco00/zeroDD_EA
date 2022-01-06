//+------------------------------------------------------------------+
//|                                                       Zero DD EA |
//|                                    Copyright 2021, Zero Drawdown |
//|                                      http://www.zerodrawdown.com |
//+------------------------------------------------------------------+
#property copyright "Frankie Lenza and Isacco Trevisan"
#property link      "www.zerodrawdown.com"
#property version   "1.00"
#property strict
//Ultimo aggiornamento 06/01/2022 ore 18.48 PM
//+------------------------------------------------------------------+
//--- input parameters                                               |
//+------------------------------------------------------------------+
extern double Balance = 0;
extern double RiskPercent       = 0.5;        // Risk Percent( % )
double ProfitPercent            = 5;          // Profit Percent( % )
extern double StopLoss          = 15;         // StopLoss( pip )

string s1  = "============================="; // ===============================================
string s2  = "ADR SETTINGS"; // ADR SECTION
string s3  = "============================="; // ===============================================
int TimeZoneOfBroker     = 2;                 // chart time zone (from GMT)
int TimeZoneOfSession    = -3;                // dest time zone (from GMT)
int ATRTimeFrame = PERIOD_D1;                 // timeframe for ATR (LEAVE AT PERIOD_D1)
int ATRPeriod = 20;                           // period for ATR
int ADROpenHour = 0;                          // start time for range calculation (LEAVE AT 0. PROGRAM DOESN'T WORK PROPERLY OTHERWISE.)
int ADRCloseHour = 24;                        // end time for range calculation  (LEAVE AT 24. PROGRAM DOESN'T WORK PROPERLY OTHERWISE.)
int LineStyle = 2;
int LineThickness1 = 1;                       // normal thickness
color LineColor1 = Red;                       // normal color
int LineThickness2 = 2;                       // thickness for range reached state
color LineColor2 = Blue;                      // color for range reached state

string s13 = "============================="; // ===============================================
string s14 = "TRADING TIME"; // TRADING TIME SECTION
string s15 = "============================="; // ===============================================
int    StartHour                = 1;          //Broker Time
int    StartMinute              = 0;          //Broker Time
int    EndHour                  = 23;         //Broker Time
int    EndMinute                = 53;         //Broker Time

extern string s16 = "============================="; // ===============================================
extern string s17 = "SENTIMENT FILTER"; //SENTIMENT FILTER SECTION
extern string s18 = "============================="; // ===============================================
extern int    UmbalancedSentimentLong  = 60; //Umbalanced Sentiment Long => Will find a short trade
extern int    UmbalancedSentimentShort = 60; //Umbalanced Sentiment Short => Will find a long trade

string s19 = "============================="; // ===============================================
string s20 = "VWAP MANAGER"; //SENTIMENT FILTER SECTION
string s21 = "============================="; // ===============================================
bool   PartializationVwap       = false;
double PartializationPercentage = 0.25;
double TakeProfitPercentage     = 0;
string VWAP_IndicatorPath       = "Market\\VWAP Level"; // VWAP Indicator Path
string ADR_IndicatorPath        = "Market\\ADR 20"; // ADR Indicator Path

struct Sentiment {
   int               sLong;
   int               sShort;
   string            sPair;
};

struct Charts {
   long              chartID;
   string            cPair;
};

Charts charts[29];
Sentiment umbalancedSentiment[29];
bool openCharts = false;

//+------------------------------------------------------------------+
//|START BOT                                                         |
//+------------------------------------------------------------------+
int OnInit() {
   if(openCharts) {
      openAllChart();
   }
   EventSetTimer(10); //Ogni 15 secondi vado a ripetere l'OnTimer
   return 0;
}
//+------------------------------------------------------------------+
//|LOOP FUNCTION                                                     |
//+------------------------------------------------------------------+
void OnTimer() {
   int time[2];
   timeToInt(time); //Array che prende l'ora corrente
   bool canIOpenTrade = canIOpenTrade(time);
   if(canIOpenTrade) {
      string headers;
      char post[], result[];
      string data;
      int res = WebRequest("GET", "https://sentiment.zerodrawdown.com/forexSentiment/getLastForexSentiments", "", NULL, 5000, post, ArraySize(post), result, headers);
      if(res == 200) {
         data = CharArrayToString(result);
         CJAVal json;
         if(json.Deserialize(data)) {
            for(int j = 0; j < 29; j++) {
               umbalancedSentiment[j].sLong = json[j]["longPosition"].ToInt();
               umbalancedSentiment[j].sShort = json[j]["shortPosition"].ToInt();
               umbalancedSentiment[j].sPair = json[j]["currency"]["currencyName"].ToStr() ;
            }
         }
         string sPair;
         int sLong;
         int sShort;
         //Adr variable
         int adrPips;
         double adrPrice;
         for(int i = 0; i < 28; i++) { //Ciclo su tutte le pair tranne gold e silver
            sPair = umbalancedSentiment[i].sPair;
            sLong = umbalancedSentiment[i].sLong;
            sShort = umbalancedSentiment[i].sShort;
            //SEZIONE SHORT
            if(StringToInteger(sLong) >= UmbalancedSentimentLong) {
               calcAdr(sPair,adrPips,adrPrice,false);
               double upperShift = MathRound(0.15 * adrPips);
               double underShift = MathRound(0.15 * adrPips);
               double maxZone = adrPrice + pipsToPrice(upperShift,sPair);//CALCOLO IL MASSIMO LIVELLO DELLA ZONA IN CANDELE
               double minZone = adrPrice - pipsToPrice(underShift,sPair);//CALCOLO IL MINIMO LIVELLO DELLA ZONA IN CANDELE
               int firstCloseDown = findCandleShort(sPair,minZone);//Prima candela che chiude sotto la zona
               int firstCloseUp = findCandleShort(sPair,maxZone);//Prima candela che chiude sopra la zona
               double imbalance = findImbalanceShort(sPair,firstCloseUp + 1,firstCloseDown, minZone, maxZone); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
               //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
               if(compareDoubles(imbalance,-1.0) != 0) {   //IMBALANCE NON TROVATA PASSO ALLA PAIR SUCCESSIVA
                  orderModifier(sPair,imbalance,0);
               }
               if(openCharts) {
                  int chartIndex = findChartID(sPair);
                  if(chartIndex != -1) {
                     ObjectCreate(charts[chartIndex].chartID,"maxZone",OBJ_HLINE,0,0,maxZone);
                     ObjectCreate(charts[chartIndex].chartID,"minZone",OBJ_HLINE,0,0,minZone);
                     //ObjectCreate(charts[chartIndex].chartID,"adrZone",OBJ_HLINE,0,0,adrPrice);
                  }
               }
            } else
               //SEZIONE LONG
               if(StringToInteger(sShort) >= UmbalancedSentimentShort) {
                  calcAdr(sPair,adrPips,adrPrice,true);
                  double upperShift = MathRound(0.15 * adrPips);
                  double underShift = MathRound(0.15 * adrPips);
                  double maxZone = adrPrice + pipsToPrice(upperShift,sPair);//CALCOLO IL MASSIMO LIVELLO DELLA ZONA IN CANDELE
                  double minZone = adrPrice - pipsToPrice(underShift,sPair);//CALCOLO IL MINIMO LIVELLO DELLA ZONA IN CANDELE
                  int firstCloseDown = findCandleLong(sPair,minZone);//Prima candela che chiude sotto la zona
                  int firstCloseUp = findCandleLong(sPair,maxZone);//Prima candela che chiude sotto la zona
                  double imbalance = findImbalanceLong(sPair,firstCloseUp,firstCloseDown + 1, minZone, maxZone); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                  //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
                  if(compareDoubles(imbalance,-1.0) != 0) {
                     orderModifier(sPair,imbalance,1);
                  } else { //IMBALANCE NON TROVATA PASSO ALLA PAIR SUCCESSIVA
                     Print("IMBALANCE NOT FOUND ON: " + sPair + " Was looking for long trade");
                  }
                  if(openCharts) {
                     int chartIndex = findChartID(sPair);
                     if(chartIndex != -1) {
                        ObjectCreate(charts[chartIndex].chartID,"maxZone",OBJ_HLINE,0,0,maxZone);
                        ObjectCreate(charts[chartIndex].chartID,"minZone",OBJ_HLINE,0,0,minZone);
                        //ObjectCreate(charts[chartIndex].chartID,"adrZone",OBJ_HLINE,0,0,adrPrice);
                     }
                  }
               } else {
                  closeTradeIfStillPending(sPair);
               }
         }
      } else {
         Print("Error on donwload Sentiment");
      }
   } else {
      Print("Cannot open trade in this hour");
      dailyReset();
   }
}

//+------------------------------------------------------------------+
//FUNCTIONS
//+------------------------------------------------------------------+
bool canIOpenTrade(int &time[2]) {
   if(StartHour > EndHour) {
      if(time[0] >= StartHour || time[0] <= EndHour) {
         if(time[0] == StartHour) {
            if(time[1] >= StartMinute) {
               return true;
            } else {
               return false;
            }
         } else if(time[0] == EndHour) {
            if(time[1] <= EndMinute) {
               return true;
            } else {
               return false;
            }
         } else {
            return true;
         }
      } else {
         return false;
      }
   } else if(StartHour < EndHour) {
      if(time[0] >= StartHour && time[0] <= EndHour) {
         if(time[0] == StartHour) {
            if(time[1] >= StartMinute) {
               return true;
            } else {
               return false;
            }
         } else if(time[0] == EndHour) {
            if(time[1] <= EndMinute) {
               return true;
            } else {
               return false;
            }
         } else {
            return true;
         }
      } else {
         return false;
      }
   } else {
      return true;
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void openAllChart() {
   string currencies[28] = {"AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY","CHFJPY", "EURAUD", "EURCAD", "EURCHF", "EURGBP", "EURJPY", "EURNZD", "EURUSD", "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD", "NZDCAD", "NZDCHF", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"};
   for(int i = 0; i < 28; i++) {
      charts[i].cPair = currencies[i];
      charts[i].chartID = ChartOpen(currencies[i], PERIOD_H1);
   }
}
//+------------------------------------------------------------------+
//|Guardo se posso aprire i trade in base all'orario                 |
//+------------------------------------------------------------------+
int findChartID(string pair) {
   for(int i = 0; i < 28; i++) {
      if(charts[i].cPair == pair) {
         return i;
      }
   }
   return -1;
}

/*
   Input:  valore adr (int)
   Output: adr convertito in prezzo (double )

   Calcola il numero di cifre di cui è composto l'adr e lo utilizza per efettuare il calcolo e
   trasformare adr in prezzo
*/
double pipsToPrice(int adr,string pair) {
   if(StringFind(pair,"JPY",0) == -1) {
      return adr * MathPow(10,-4);
   } else {
      return adr * MathPow(10,-2);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int findCandleShort(string pair,double zone, int tFrame = PERIOD_H1) {
   int count = 0;
   while(true) { //Ciclo finchè non trovo la prima candela che esce
      double high = iHigh(pair,tFrame,count);
      if(compareDoubles(high,0.0) != 0) {
         if(compareDoubles(high,zone) == 1) {
            return count;
         } else {
            count++;
         }
      } else {
         Print("Missing History Data.");
         break;
      }
   }
   return NULL;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int findCandleLong(string pair,double zone, int tFrame = PERIOD_H1) {
   int count = 0;
   while(true) { //Ciclo finchè non trovo la prima candela che esce
      double low = iLow(pair,tFrame,count);
      if(compareDoubles(low,0.0) != 0) {
         if(compareDoubles(low,zone) == 2) {
            return count;
         } else {
            count++;
         }
      } else {
         Print("Missing History Data.");
         break;
      }
   }
   return NULL;
}

/*
   Input: pair , pos_max=numero barra limite superiore ,pos_min =numero barra limite inferiore ,Bound superiore e inferiore in cui l'imbalance trovata è accettata
   Output: imbalance(double) se trovata altrimenti -1

   Trova l'imbalance short per la zona individuata
*/
double findImbalanceShort(string pair,int firstCloseUp, int firstCloseDown,double minZone, double maxZone, int tFrame = PERIOD_H1) {
   double imbalancePrice = -1.0, imbalanceVolume = 0.0;
   while(firstCloseUp >= firstCloseDown) { //Candele + a sinistra nel grafo -> indice più elevato
      double minAlto = iLow(pair,tFrame,firstCloseUp); //minimo della candela attualmente piu in alto nella nostra zona
      bool findImbalance = true;
      int count = firstCloseUp - 2; //MI SPOSTO DI DUE PER IL CONTROLLO DAL SUCC SUCC
      while(count >= 0 && findImbalance) {  //Controllo che dalla SUCC SUCC non ci siano valori superiori alla imbalance trovata
         double maxCandDoubleSucc = iHigh(pair,tFrame,count);
         if(compareDoubles(minAlto,maxCandDoubleSucc) == 2) {
            findImbalance = false;
         }
         count -= 1;
      }
      if(findImbalance) {
         if(compareDoubles(minAlto,minZone) == 2 || compareDoubles(minAlto,maxZone) == 1) {
         } else {
            double volume = iVolume(pair,PERIOD_H1,firstCloseUp - 2);
            if(compareDoubles(imbalanceVolume,volume) != 1) {
               imbalanceVolume = volume;
               imbalancePrice = minAlto;
            }
         }
      }
      firstCloseUp -= 1; // scendo di una candela e controllo la successiva (+ adestra)
   }
   return imbalancePrice;
}


/*
   Input: pair , pos_max=numero barra limite superiore ,pos_min =numero barra limite inferiore ,Bound superiore e inferiore in cui l'imbalance trovata è accettata
   Output: imbalance(double) se trovata altrimenti -1
   Trova l'imbalance long per la zona individuata
*/
double findImbalanceLong(string pair,int firstCloseUp, int firstCloseDown,double minZone, double maxZone, int tFrame = PERIOD_H1) {
   double imbalancePrice = -1.0, imbalanceVolume = 0.0;
   while(firstCloseDown >= firstCloseUp) {
      double maxBasso = iHigh(pair,tFrame,firstCloseDown);
      bool findImbalance = true;
      int count = firstCloseDown - 2;
      while(count >= 0) {
         double minCandDoubleSucc = iLow(pair,tFrame,count);
         if(compareDoubles(maxBasso,minCandDoubleSucc) == 1) {
            findImbalance = false;
         }
         count -= 1;
      }
      if(findImbalance) {
         if(compareDoubles(maxBasso,minZone) == 2 || compareDoubles(maxBasso,maxZone) == 1) {
         } else {
            double volume = iVolume(pair,PERIOD_H1,firstCloseDown - 2);
            if(compareDoubles(imbalanceVolume,volume) != 1) {
               imbalanceVolume = volume;
               imbalancePrice = maxBasso;
            }
         }
      }
      firstCloseDown -= 1;
   }
   return imbalancePrice;
}

/*
   Input: StopLoss ->based on ADR measure
   Output: lotsize
   Calcola lotsize in base alla dimensione del conto seguendo vari fattori-> risk_for_trade /pair / balance
*/
double calculateLotSize(double SL,string pair) {
   double LotSize = 0;
// Value of a tick
   double nTickValue = MarketInfo(pair, MODE_TICKVALUE);
// Normalizziamo i tick in base alle digit
   while(compareDoubles(nTickValue,0.0) == 0) {
      nTickValue = MarketInfo(pair, MODE_TICKVALUE);
   }
   if((Digits == 3) || (Digits == 5)) {
      nTickValue = nTickValue * 10.0;
   }
// Formula per calcolare la LotSize
   if(compareDoubles(Balance,0) == 0)
      Balance = AccountBalance();
   LotSize = (Balance * RiskPercent / 100) / (SL * nTickValue);
   return NormalizeDouble(LotSize,2);
}



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeTradeIfStillPending(string pair) {
   int symbolCount = 0;
   int orderNumber = 0;
// Start a loop to scan all the orders.
// The loop starts from the last order, proceeding backwards; Otherwise it would skip some orders.
   for(int i = (OrdersTotal() - 1); i >= 0; i--) {  //Controllo se ho ordini già aperti per la mia pair non cambia da short a long
      if(OrderSelect(i,SELECT_BY_POS) == true) {
         if(OrderSymbol() == pair) {
            orderNumber = i;
            symbolCount += 1;
            break;
         }
      }
   }
   if(symbolCount > 0) {
      OrderSelect(orderNumber,SELECT_BY_POS);
      int type = OrderType();
      if((type == OP_BUYLIMIT) || (type == OP_SELLLIMIT)) {
         int ticket = OrderTicket();
         OrderDelete(ticket);
      }
   }
}

/*
   Input: pair, imbalance , long_short intero se voglio aprire SHORT=0 , se voglio aprire LONG =1
   Apre o modifica i pendenti già aperti se trova una zona migliore
*/
void orderModifier(string pair, double imbalance,int longShort) {
   int symbolCount = 0;
   int orderNumber = 0;
// Start a loop to scan all the orders.
// The loop starts from the last order, proceeding backwards; Otherwise it would skip some orders.
   for(int i = (OrdersTotal() - 1); i >= 0; i--) {  //Controllo se ho ordini già aperti per la mia pair non cambia da short a long
      if(OrderSelect(i,SELECT_BY_POS) == true) {
         if(OrderSymbol() == pair) {
            orderNumber = i;
            symbolCount += 1;
            break;
         }
      }
   }
   if(symbolCount < 1) { // se non ho ordini aperti APRO
      if(longShort == 0) { //SHORT
         double takeProfit = 0;
         /*if(CompareDoubles(takeProfitPercentage,0)==0){
            takeProfit=LowestPrice(pair);
         }
         else{
            double special_value=NormalizeDouble(take_profit_percentange/RiskPercent,0);
            takeProfit=imbalance+pipsToPrice((int)(special_value*GlobalStopLoss),pair);
         }*/
         int sellOrder = OrderSend(pair,OP_SELLLIMIT,
                                   calculateLotSize(StopLoss,pair), //QUANTITA'
                                   imbalance,/*zona di prezzo*/
                                   3, //SLIPPAGE
                                   NULL, /*stoploss, prezzo +20pips_adr FunzionePrecedente : -> imbalance + pipsToPrice(GlobalStopLoss,pair)*/
                                   NULL,
                                   NULL,
                                   NULL,
                                   0,
                                   clrOrange
                                  );
      } else { //LONG
         double takeProfit = 0;
         /*if(CompareDoubles(takeProfitPercentage,0)==0){
           tp=MaxPrice(pair);
         }else{
           double special_value=NormalizeDouble(take_profit_percentange/RiskPercent,0);
           tp=imbalance-pipsToPrice((int)(special_value*GlobalStopLoss),pair);
         }*/
         int sellticket = OrderSend(
                             pair,
                             OP_BUYLIMIT,
                             calculateLotSize(StopLoss,pair), //QUANTITA'
                             imbalance,/*zona di prezzo*/
                             3, //SLIPPAGE
                             NULL, /*stoploss, prezzo +20pips_adr FunzionePrecedente : -> imbalance - pipsToPrice(GlobalStopLoss,pair)*/
                             NULL,
                             NULL,
                             NULL,
                             0,
                             clrOrange
                          );
      }
   } else { //Modifico l'ordine gia presente perchè ho trovato una zona migliore !
      OrderSelect(orderNumber,SELECT_BY_POS);
      int type = OrderType();
      if((type == OP_BUYLIMIT) || (type == OP_SELLLIMIT)) {
         int ticket = OrderTicket();
         double openprice = OrderOpenPrice();
         if(longShort == 0) {
            if(compareDoubles(imbalance,openprice) != 0) {
               OrderModify(ticket,imbalance,NULL,NULL,0,clrCyan);
            }
         } else {
            if(compareDoubles(imbalance,openprice) != 0) {
               OrderModify(ticket,imbalance,NULL, NULL,0,clrCyan);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void dailyReset() {
// Start a loop to scan all the orders.
// The loop starts from the last order, proceeding backwards; Otherwise it would skip some orders.
   for(int i = (OrdersTotal() - 1); i >= 0; i--) {
      if(OrderSelect(i,SELECT_BY_POS) == true) {
         if( DayOfWeek() == 5) {
            int type = OrderType();
            int ticket = OrderTicket();
            if((type == OP_BUYLIMIT) || (type == OP_SELLLIMIT)) {
               OrderDelete(ticket);
            } else {
               // Create the required variables.
               // Result variable - to check if the operation is successful or not.
               bool res = false;
               // Allowed Slippage - the difference between current price and close price.
               int Slippage = 0;
               // Bid and Ask prices for the instrument of the order.
               double BidPrice = MarketInfo(OrderSymbol(), MODE_BID);
               double AskPrice = MarketInfo(OrderSymbol(), MODE_ASK);
               // Closing the order using the correct price depending on the type of order.
               if(OrderType() == OP_BUY) {
                  res = OrderClose(OrderTicket(), OrderLots(), BidPrice, Slippage);
               } else if(OrderType() == OP_SELL) {
                  res = OrderClose(OrderTicket(), OrderLots(), AskPrice, Slippage);
               }
            }
         } else {
            int type = OrderType();
            int ticket = OrderTicket();
            if((type == OP_BUYLIMIT) || (type == OP_SELLLIMIT)) {
               //OrderDelete(ticket);
            } else if(compareDoubles(OrderProfit(), 0.0) == 2) {
               // Create the required variables.
               // Result variable - to check if the operation is successful or not.
               bool res = false;
               // Allowed Slippage - the difference between current price and close price.
               int Slippage = 0;
               // Bid and Ask prices for the instrument of the order.
               double BidPrice = MarketInfo(OrderSymbol(), MODE_BID);
               double AskPrice = MarketInfo(OrderSymbol(), MODE_ASK);
               // Closing the order using the correct price depending on the type of order.
               if(OrderType() == OP_BUY) {
                  res = OrderClose(OrderTicket(), OrderLots(), BidPrice, Slippage);
               } else if(OrderType() == OP_SELL) {
                  res = OrderClose(OrderTicket(), OrderLots(), AskPrice, Slippage);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void timeToInt(int &time[2]) {
   datetime s = TimeCurrent();
   string f = TimeToString(s);
   string h = StringSubstr(f,11,2) + StringSubstr(f,14,2);
   time[0] = StringToInteger(StringSubstr(h,0,2));
   time[1] = StringToInteger(StringSubstr(h,2,2));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int compareDoubles(double n1,double n2) {
   double norm = NormalizeDouble(n1 - n2,8);
   if(norm == 0)
      return(0); //Se uguali
   else if(norm > 0)
      return(1); //n1 > n2
   else if(norm < 0)
      return(2); //n1 < n2
   return -1;
}

//+------------------------------------------------------------------+
//|Calcolo ADR                                                               |
//+------------------------------------------------------------------+
void calcAdr(string pair, int &adrPips, double &adrPrice, bool isLongTrade) {
   static datetime timeLastUpdate = Time[0];
   static int lastTimeFrame = PERIOD_H1,
              lastFirstBar = -1;
   int idxFirstBarOfToday = 0,
       idxFirstBarOfYesterday = 0,
       idxLastBarOfYesterday = 0;
   computeDayIndices(TimeZoneOfBroker, TimeZoneOfSession, idxFirstBarOfToday, idxFirstBarOfYesterday, idxLastBarOfYesterday);
   lastFirstBar = idxFirstBarOfToday;
//
// okay, now we know where the days start and end
//
   int tzDiff = TimeZoneOfBroker + TimeZoneOfSession,
       tzDiffSec = tzDiff * 3600;
   datetime startOfDay = Time[idxFirstBarOfToday]; // datetime (x-value) for labes on horizontal bars
   double adr = iATR(pair, ATRTimeFrame, ATRPeriod, 1);
//
// walk forward through today and collect high/lows within the same day
//
   double todayHigherPrice,
          todayLowerPrice,
          todayOpenPrice = 0,
          todayRange,
          lastHigh, lastLow,
          toLongAdr = 0,
          toShortAdr = 0,
          adrHigh = 0,
          adrLow = 0;
   bool adrReached = false, lastReached;
// new-start
   for(int j = idxFirstBarOfToday; j >= 0; j--) {
      datetime barTime = Time[j] - tzDiffSec;
      if(TimeHour(barTime) >= ADROpenHour && TimeHour(barTime) < ADRCloseHour) {
         if(todayOpenPrice == 0) {
            todayOpenPrice = iOpen(pair, PERIOD_H1, idxFirstBarOfToday); // should be open of today start trading hour
            adrHigh = todayOpenPrice + adr;
            adrLow = todayOpenPrice - adr;
            todayHigherPrice = todayOpenPrice;
            todayLowerPrice = todayOpenPrice;
         }
         for(int k = 0; k < 3; k++) {
            double price;
            switch(k) {
            case 0:
               price = iLow(pair, PERIOD_H1, j);
               break;
            case 1:
               price = iHigh(pair, PERIOD_H1, j);
               break;
            case 2:
               price = iClose(pair, PERIOD_H1, j);
               break;
            }
            lastHigh = todayHigherPrice;
            lastLow = todayLowerPrice;
            lastReached = adrReached;
            todayHigherPrice = MathMax(todayHigherPrice, price);
            todayLowerPrice = MathMin(todayLowerPrice, price);
            todayRange = todayHigherPrice - todayLowerPrice;
            adrReached = todayRange >= adr - calculateNormalizedDigits(pair) / 2; // "Point/2" to avoid rounding problems (double variables)
            //double adrx=adr;  // Andrew added this
            //if(adrx >= adr - Point/2)   // Andrew added this
            //SendMail(Symbol() + "fssdf", Symbol());   // Andrew added this
            // adr-high
            if(!lastReached && !adrReached) {
               adrHigh = todayLowerPrice + adr;
            } else if(!lastReached && adrReached && price >= lastHigh) {
               adrHigh = todayLowerPrice + adr;
            } else if(!lastReached && adrReached && price < lastHigh) {
               adrHigh = lastHigh;
            } else {
               adrHigh = adrHigh;
            }
            // adr-low
            if(!lastReached && !adrReached) {
               adrLow = todayHigherPrice - adr;
            } else if(!lastReached && adrReached && price >= lastLow) {
               adrLow = todayLowerPrice;
            } else if(!lastReached && adrReached && price < lastLow) {
               adrLow = lastHigh - adr;
            } else {
               adrLow = adrLow;
            }
            toLongAdr = adrHigh - iClose(pair, PERIOD_H1, j);
            toShortAdr = iClose(pair, PERIOD_H1, j) - adrLow;
         }
      }
   }
// draw the vertical bars that marks the time span
//setTimeLine("today start", "ADR Start", idxFirstBarOfToday, CadetBlue, Low[idxFirstBarOfToday] - 10 * Point);
   color col = LineColor1;
   int thickness = LineThickness1;
   if(adrReached) {
      col = LineColor2;
      thickness = LineThickness2;
   }
   SetLevel("ADR High", adrHigh, col, LineStyle, thickness, startOfDay);
   SetLevel("ADR Low", adrLow, col, LineStyle, thickness, startOfDay);
   string comment =
      "ADR " + DoubleToStr(MathRound((adr / calculateNormalizedDigits(pair) / 10)),0) +
      "  Today " + DoubleToStr(MathRound(((todayHigherPrice - todayLowerPrice) / calculateNormalizedDigits(pair) / 10)),0) ;
//Comment(comment);
   if(isLongTrade) {
      adrPrice = adrLow;
   } else {
      adrPrice = adrHigh;
   }
   adrPips = MathRound(adr / calculateNormalizedDigits(pair) / 10);
}

//+------------------------------------------------------------------+
//| Compute index of first/last bar of yesterday and today           |
//+------------------------------------------------------------------+
void computeDayIndices(int tzLocal, int tzDest, int &idxFirstBarOfToday, int &idxFirstBarOfYesterday, int &idxLastBarOfYesterday) {
   int tzDiff = tzLocal + tzDest,
       tzDiffSec = tzDiff * 3600,
       dayMinutes = 24 * 60,
       barsPerDay = dayMinutes / PERIOD_H1;
   int dayOfWeekToday = TimeDayOfWeek(Time[0] - tzDiffSec), // what day is today in the dest timezone?
       dayOfWeekToFind = -1;
//
// due to gaps in the data, and shift of time around weekends (due
// to time zone) it is not as easy as to just look back for a bar
// with 00:00 time
//
   idxFirstBarOfToday = 0;
   idxFirstBarOfYesterday = 0;
   idxLastBarOfYesterday = 0;
   switch(dayOfWeekToday) {
   case 6: // sat
   case 0: // sun
   case 1: // mon
      dayOfWeekToFind = 5; // yesterday in terms of trading was previous friday
      break;
   default:
      dayOfWeekToFind = dayOfWeekToday - 1;
      break;
   }
   int j,i;
// search  backwards for the last occrrence (backwards) of the day today (today's first bar)
   for(i = 0; i <= barsPerDay + 1; i++) {
      datetime time = Time[i] - tzDiffSec;
      // Print(Symbol(), " DayofWeek[", i, ,"]= ", TimeDayOfWeek(timet), " (", dayofweektoday, ") ", TimeToStr(timet));
      if(TimeDayOfWeek(time) != dayOfWeekToday) {
         idxFirstBarOfToday = i - 1;
         break;
      }
   }
// Print(Symbol(), " idxfirstoftoday ", idxfirstbaroftoday);
// search  backwards for the first occrrence (backwards) of the weekday we are looking for (yesterday's last bar)
   for(j = 0; j <= 2 * barsPerDay + 1; j++) {
      datetime time = Time[i + j] - tzDiffSec;
      if(TimeDayOfWeek(time) == dayOfWeekToFind) {  // ignore saturdays (a Sa may happen due to TZ conversion)
         idxLastBarOfYesterday = i + j;
         break;
      }
   }
// search  backwards for the first occurrence of weekday before yesterday (to determine yesterday's first bar)
   for(j = 1; j <= barsPerDay; j++) {
      datetime time = Time[idxLastBarOfYesterday + j] - tzDiffSec;
      if(TimeDayOfWeek(time) != dayOfWeekToFind) {  // ignore saturdays (a Sa may happen due to TZ conversion)
         idxFirstBarOfYesterday = idxLastBarOfYesterday + j - 1;
         break;
      }
   }
}
//+------------------------------------------------------------------+
void setTimeLine(string objName, string text, int idx, color col1, double value) {
   string name = "[ADR] " + objName;
   int x = Time[idx];
   if(ObjectFind(name) != 0)
      ObjectCreate(name, OBJ_TREND, 0, x, 0, x, 100);
   ObjectMove(name, 0, x, 0);
   ObjectMove(name, 1, x, 100);
   ObjectSet(name, OBJPROP_BACK, true);
   ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSet(name, OBJPROP_COLOR, DarkGray);
   if(ObjectFind(name + " Label") != 0)
      ObjectCreate(name + " Label", OBJ_TEXT, 0, x, value);
   ObjectMove(name + " Label", 0, x, value);
   ObjectSetText(name + " Label", text, 8, "Arial", col1);
}
//+------------------------------------------------------------------+
void SetLevel(string text, double level, color col1, int linestyle, int thickness, datetime startOfDay) {
   bool showLevelPrices = false;
   int digits = Digits, barForLabels = -10;
   string labelName = "[ADR] " + text + " Label",
          lineName = "[ADR] " + text + " Line",priceLabel;
// create or move the horizontal line
   if(ObjectFind(lineName) != 0) {
      ObjectCreate(lineName, OBJ_TREND, 0, startOfDay, level, Time[0],level);
   }
   ObjectSet(lineName, OBJPROP_BACK, true);
   ObjectSet(lineName, OBJPROP_STYLE, linestyle);
   ObjectSet(lineName, OBJPROP_COLOR, col1);
   ObjectSet(lineName, OBJPROP_WIDTH, thickness);
   ObjectMove(lineName, 1, Time[0],level);
   ObjectMove(lineName, 0, startOfDay, level);
// put a label on the line
   if(ObjectFind(lineName) != 0)
      ObjectCreate(lineName, OBJ_TEXT, 0, Time[0]/* MathMin(Time[BarForLabels], startofday + 2*Period()*60)*/, level);
   ObjectMove(labelName, 0, Time[0] - showLevelPrices * Period() * 60, level);
   priceLabel = " " + text;
   if(showLevelPrices && StrToInteger(text) == 0)
      priceLabel = priceLabel + ": " + DoubleToStr(level, Digits);
   ObjectSetText(labelName, priceLabel, 8, "Arial", col1);
}
//+------------------------------------------------------------------+
double calculateNormalizedDigits(string pair) {
// If there are 3 or fewer digits (JPY, for example), then return 0.01, which is the pip value.
   if(StringFind(pair,"JPY",0) == -1) {
      return(0.00001);
   }
// If there are 4 or more digits, then return 0.0001, which is the pip value.
   else {
      return(0.001);
   }
}
//+------------------------------------------------------------------+


//Jason Library

//------------------------------------------------------------------ enum enJAType
enum enJAType { jtUNDEF, jtNULL, jtBOOL, jtINT, jtDBL, jtSTR, jtARRAY, jtOBJ };

//------------------------------------------------------------------ class CJAVal
class CJAVal {
public:
   virtual void      Clear(enJAType jt = jtUNDEF, bool savekey = false) {
      m_parent = NULL;
      if(!savekey)
         m_key = "";
      m_type = jt;
      m_bv = false;
      m_iv = 0;
      m_dv = 0;
      m_prec = 8;
      m_sv = "";
      ArrayResize(m_e, 0, 100);
   }
   virtual bool      Copy(const CJAVal & a) {
      m_key = a.m_key;
      CopyData(a);
      return true;
   }
   virtual void      CopyData(const CJAVal & a) {
      m_type = a.m_type;
      m_bv = a.m_bv;
      m_iv = a.m_iv;
      m_dv = a.m_dv;
      m_prec = a.m_prec;
      m_sv = a.m_sv;
      CopyArr(a);
   }
   virtual void      CopyArr(const CJAVal & a) {
      int n = ArrayResize(m_e, ArraySize(a.m_e));
      for(int i = 0; i < n; i++) {
         m_e[i] = a.m_e[i];
         m_e[i].m_parent = GetPointer(this);
      }
   }

public:
   CJAVal            m_e[];
   string            m_key;
   string            m_lkey;
   CJAVal*           m_parent;
   enJAType          m_type;
   bool              m_bv;
   long              m_iv;
   double            m_dv;
   int               m_prec;
   string            m_sv;
   static int        code_page;

public:
                     CJAVal() {
      Clear();
   }
                     CJAVal(CJAVal * aparent, enJAType atype) {
      Clear();
      m_type = atype;
      m_parent = aparent;
   }
                     CJAVal(enJAType t, string a) {
      Clear();
      FromStr(t, a);
   }
                     CJAVal(const int a) {
      Clear();
      m_type = jtINT;
      m_iv = a;
      m_dv = (double)m_iv;
      m_sv = IntegerToString(m_iv);
      m_bv = m_iv != 0;
   }
                     CJAVal(const long a) {
      Clear();
      m_type = jtINT;
      m_iv = a;
      m_dv = (double)m_iv;
      m_sv = IntegerToString(m_iv);
      m_bv = m_iv != 0;
   }
                     CJAVal(const double a, int aprec = -100) {
      Clear();
      m_type = jtDBL;
      m_dv = a;
      if(aprec > -100)
         m_prec = aprec;
      m_iv = (long)m_dv;
      m_sv = DoubleToString(m_dv, m_prec);
      m_bv = m_iv != 0;
   }
                     CJAVal(const bool a) {
      Clear();
      m_type = jtBOOL;
      m_bv = a;
      m_iv = m_bv;
      m_dv = m_bv;
      m_sv = IntegerToString(m_iv);
   }
                     CJAVal(const CJAVal & a) {
      Clear();
      Copy(a);
   }
                    ~CJAVal() {
      Clear();
   }

public:
   int               Size() {
      return ArraySize(m_e);
   }
   virtual bool      IsNumeric() {
      return m_type == jtDBL || m_type == jtINT;
   }
   virtual CJAVal *   FindKey(string akey) {
      for(int i = Size() - 1; i >= 0; --i)
         if(m_e[i].m_key == akey)
            return GetPointer(m_e[i]);
      return NULL;
   }
   virtual CJAVal *   HasKey(string akey, enJAType atype = jtUNDEF) {
      CJAVal* e = FindKey(akey);
      if(CheckPointer(e) != POINTER_INVALID) {
         if(atype == jtUNDEF || atype == e.m_type)
            return GetPointer(e);
      }
      return NULL;
   }
   virtual CJAVal*   operator[](string akey);
   virtual CJAVal*   operator[](int i);
   void              operator=(const CJAVal & a) {
      Copy(a);
   }
   void              operator=(const int a) {
      m_type = jtINT;
      m_iv = a;
      m_dv = (double)m_iv;
      m_bv = m_iv != 0;
   }
   void              operator=(const long a) {
      m_type = jtINT;
      m_iv = a;
      m_dv = (double)m_iv;
      m_bv = m_iv != 0;
   }
   void              operator=(const double a) {
      m_type = jtDBL;
      m_dv = a;
      m_iv = (long)m_dv;
      m_bv = m_iv != 0;
   }
   void              operator=(const bool a) {
      m_type = jtBOOL;
      m_bv = a;
      m_iv = (long)m_bv;
      m_dv = (double)m_bv;
   }
   void              operator=(string a) {
      m_type = (a != NULL) ? jtSTR : jtNULL;
      m_sv = a;
      m_iv = StringToInteger(m_sv);
      m_dv = StringToDouble(m_sv);
      m_bv = a != NULL;
   }

   bool              operator==(const int a) {
      return m_iv == a;
   }
   bool              operator==(const long a) {
      return m_iv == a;
   }
   bool              operator==(const double a) {
      return m_dv == a;
   }
   bool              operator==(const bool a) {
      return m_bv == a;
   }
   bool              operator==(string a) {
      return m_sv == a;
   }

   bool              operator!=(const int a) {
      return m_iv != a;
   }
   bool              operator!=(const long a) {
      return m_iv != a;
   }
   bool              operator!=(const double a) {
      return m_dv != a;
   }
   bool              operator!=(const bool a) {
      return m_bv != a;
   }
   bool              operator!=(string a) {
      return m_sv != a;
   }

   long              ToInt() const {
      return m_iv;
   }
   double            ToDbl() const {
      return m_dv;
   }
   bool              ToBool() const {
      return m_bv;
   }
   string            ToStr() {
      return m_sv;
   }

   virtual void      FromStr(enJAType t, string a) {
      m_type = t;
      switch(m_type) {
      case jtBOOL:
         m_bv = (StringToInteger(a) != 0);
         m_iv = (long)m_bv;
         m_dv = (double)m_bv;
         m_sv = a;
         break;
      case jtINT:
         m_iv = StringToInteger(a);
         m_dv = (double)m_iv;
         m_sv = a;
         m_bv = m_iv != 0;
         break;
      case jtDBL:
         m_dv = StringToDouble(a);
         m_iv = (long)m_dv;
         m_sv = a;
         m_bv = m_iv != 0;
         break;
      case jtSTR:
         m_sv = Unescape(a);
         m_type = (m_sv != NULL) ? jtSTR : jtNULL;
         m_iv = StringToInteger(m_sv);
         m_dv = StringToDouble(m_sv);
         m_bv = m_sv != NULL;
         break;
      }
   }
   virtual string    GetStr(char& js[], int i, int slen) {
      if(slen == 0)
         return "";
      char cc[];
      ArrayCopy(cc, js, 0, i, slen);
      return CharArrayToString(cc, 0, WHOLE_ARRAY, CJAVal::code_page);
   }

   virtual void      Set(const CJAVal & a) {
      if(m_type == jtUNDEF)
         m_type = jtOBJ;
      CopyData(a);
   }
   virtual void      Set(const CJAVal& list[]);
   virtual CJAVal *   Add(const CJAVal & item) {
      if(m_type == jtUNDEF)
         m_type = jtARRAY; /*ASSERT(m_type==jtOBJ || m_type==jtARRAY);*/ return AddBase(item);   // добавление
   }
   virtual CJAVal *   Add(const int a) {
      CJAVal item(a);
      return Add(item);
   }
   virtual CJAVal *   Add(const long a) {
      CJAVal item(a);
      return Add(item);
   }
   virtual CJAVal *   Add(const double a, int aprec = -2) {
      CJAVal item(a, aprec);
      return Add(item);
   }
   virtual CJAVal *   Add(const bool a) {
      CJAVal item(a);
      return Add(item);
   }
   virtual CJAVal *   Add(string a) {
      CJAVal item(jtSTR, a);
      return Add(item);
   }
   virtual CJAVal *   AddBase(const CJAVal & item) {
      int c = Size();   // добавление
      ArrayResize(m_e, c + 1, 100);
      m_e[c] = item;
      m_e[c].m_parent = GetPointer(this);
      return GetPointer(m_e[c]);
   }
   virtual CJAVal *   New() {
      if(m_type == jtUNDEF)
         m_type = jtARRAY; /*ASSERT(m_type==jtOBJ || m_type==jtARRAY);*/ return NewBase();   // добавление
   }
   virtual CJAVal *   NewBase() {
      int c = Size();   // добавление
      ArrayResize(m_e, c + 1, 100);
      return GetPointer(m_e[c]);
   }

   virtual string    Escape(string a);
   virtual string    Unescape(string a);
public:
   virtual void      Serialize(string & js, bool bf = false, bool bcoma = false);
   virtual string    Serialize() {
      string js;
      Serialize(js);
      return js;
   }
   virtual bool      Deserialize(char& js[], int slen, int &i);
   virtual bool      ExtrStr(char& js[], int slen, int &i);
   virtual bool      Deserialize(string js, int acp = CP_ACP) {
      int i = 0;
      Clear();
      CJAVal::code_page = acp;
      char arr[];
      int slen = StringToCharArray(js, arr, 0, WHOLE_ARRAY, CJAVal::code_page);
      return Deserialize(arr, slen, i);
   }
   virtual bool      Deserialize(char& js[], int acp = CP_ACP) {
      int i = 0;
      Clear();
      CJAVal::code_page = acp;
      return Deserialize(js, ArraySize(js), i);
   }
};

int CJAVal::code_page = CP_ACP;

//------------------------------------------------------------------ operator[]
CJAVal * CJAVal::operator[](string akey) {
   if(m_type == jtUNDEF)
      m_type = jtOBJ;
   CJAVal* v = FindKey(akey);
   if(v)
      return v;
   CJAVal b(GetPointer(this), jtUNDEF);
   b.m_key = akey;
   v = Add(b);
   return v;
}
//------------------------------------------------------------------ operator[]
CJAVal * CJAVal::operator[](int i) {
   if(m_type == jtUNDEF)
      m_type = jtARRAY;
   while(i >= Size()) {
      CJAVal b(GetPointer(this), jtUNDEF);
      if(CheckPointer(Add(b)) == POINTER_INVALID)
         return NULL;
   }
   return GetPointer(m_e[i]);
}
//------------------------------------------------------------------ Set
void CJAVal::Set(const CJAVal& list[]) {
   if(m_type == jtUNDEF)
      m_type = jtARRAY;
   int n = ArrayResize(m_e, ArraySize(list), 100);
   for(int i = 0; i < n; ++i) {
      m_e[i] = list[i];
      m_e[i].m_parent = GetPointer(this);
   }
}

//------------------------------------------------------------------ Serialize
void CJAVal::Serialize(string& js, bool bkey/*=false*/, bool coma/*=false*/) {
   if(m_type == jtUNDEF)
      return;
   if(coma)
      js += ",";
   if(bkey)
      js += StringFormat("\"%s\":", m_key);
   int _n = Size();
   switch(m_type) {
   case jtNULL:
      js += "null";
      break;
   case jtBOOL:
      js += (m_bv ? "true" : "false");
      break;
   case jtINT:
      js += IntegerToString(m_iv);
      break;
   case jtDBL:
      js += DoubleToString(m_dv, m_prec);
      break;
   case jtSTR: {
      string ss = Escape(m_sv);
      if(StringLen(ss) > 0)
         js += StringFormat("\"%s\"", ss);
      else
         js += "null";
   }
   break;
   case jtARRAY:
      js += "[";
      for(int i = 0; i < _n; i++)
         m_e[i].Serialize(js, false, i > 0);
      js += "]";
      break;
   case jtOBJ:
      js += "{";
      for(int i = 0; i < _n; i++)
         m_e[i].Serialize(js, true, i > 0);
      js += "}";
      break;
   }
}

//------------------------------------------------------------------ Deserialize
bool CJAVal::Deserialize(char& js[], int slen, int &i) {
   string num = "0123456789+-.eE";
   int i0 = i;
   for(; i < slen; i++) {
      char c = js[i];
      if(c == 0)
         break;
      switch(c) {
      case '\t':
      case '\r':
      case '\n':
      case ' ': // пропускаем из имени пробелы
         i0 = i + 1;
         break;
      case '[': { // начало массива. создаём объекты и забираем из js
         i0 = i + 1;
         if(m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // если значение уже имеет тип, то это ошибка
            return false;
         }
         m_type = jtARRAY; // задали тип значения
         i++;
         CJAVal val(GetPointer(this), jtUNDEF);
         while(val.Deserialize(js, slen, i)) {
            if(val.m_type != jtUNDEF)
               Add(val);
            if(val.m_type == jtINT || val.m_type == jtDBL || val.m_type == jtARRAY)
               i++;
            val.Clear();
            val.m_parent = GetPointer(this);
            if(js[i] == ']')
               break;
            i++;
            if(i >= slen) {
               Print(m_key + " " + string(__LINE__));
               return false;
            }
         }
         return js[i] == ']' || js[i] == 0;
      }
      break;
      case ']':
         if(!m_parent)
            return false;
         return m_parent.m_type == jtARRAY; // конец массива, текущее значение должны быть массивом
      case ':': {
         if(m_lkey == "") {
            Print(m_key + " " + string(__LINE__));
            return false;
         }
         CJAVal val(GetPointer(this), jtUNDEF);
         CJAVal *oc = Add(val); // тип объекта пока не определён
         oc.m_key = m_lkey;
         m_lkey = ""; // задали имя ключа
         i++;
         if(!oc.Deserialize(js, slen, i)) {
            Print(m_key + " " + string(__LINE__));
            return false;
         }
         break;
      }
      case ',': // разделитель значений // тип значения уже должен быть определён
         i0 = i + 1;
         if(!m_parent && m_type != jtOBJ) {
            Print(m_key + " " + string(__LINE__));
            return false;
         } else if(m_parent) {
            if(m_parent.m_type != jtARRAY && m_parent.m_type != jtOBJ) {
               Print(m_key + " " + string(__LINE__));
               return false;
            }
            if(m_parent.m_type == jtARRAY && m_type == jtUNDEF)
               return true;
         }
         break;
      // примитивы могут быть ТОЛЬКО в массиве / либо самостоятельно
      case '{': // начало объекта. создаем объект и забираем его из js
         i0 = i + 1;
         if(m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // ошибка типа
            return false;
         }
         m_type = jtOBJ; // задали тип значения
         i++;
         if(!Deserialize(js, slen, i)) {
            Print(m_key + " " + string(__LINE__));   // вытягиваем его
            return false;
         }
         return js[i] == '}' || js[i] == 0;
         break;
      case '}':
         return m_type == jtOBJ; // конец объекта, текущее значение должно быть объектом
      case 't':
      case 'T': // начало true
      case 'f':
      case 'F': // начало false
         if(m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // ошибка типа
            return false;
         }
         m_type = jtBOOL; // задали тип значения
         if(i + 3 < slen) {
            if(StringCompare(GetStr(js, i, 4), "true", false) == 0) {
               m_bv = true;
               i += 3;
               return true;
            }
         }
         if(i + 4 < slen) {
            if(StringCompare(GetStr(js, i, 5), "false", false) == 0) {
               m_bv = false;
               i += 4;
               return true;
            }
         }
         Print(m_key + " " + string(__LINE__));
         return false; // не тот тип или конец строки
         break;
      case 'n':
      case 'N': // начало null
         if(m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // ошибка типа
            return false;
         }
         m_type = jtNULL; // задали тип значения
         if(i + 3 < slen)
            if(StringCompare(GetStr(js, i, 4), "null", false) == 0) {
               i += 3;
               return true;
            }
         Print(m_key + " " + string(__LINE__));
         return false; // не NULL или конец строки
         break;
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
      case '-':
      case '+':
      case '.': { // начало числа
         if(m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // ошибка типа
            return false;
         }
         bool dbl = false; // задали тип значения
         int is = i;
         while(js[i] != 0 && i < slen) {
            i++;
            if(StringFind(num, GetStr(js, i, 1)) < 0)
               break;
            if(!dbl)
               dbl = (js[i] == '.' || js[i] == 'e' || js[i] == 'E');
         }
         m_sv = GetStr(js, is, i - is);
         if(dbl) {
            m_type = jtDBL;
            m_dv = StringToDouble(m_sv);
            m_iv = (long)m_dv;
            m_bv = m_iv != 0;
         } else {
            m_type = jtINT;   // уточнии тип значения
            m_iv = StringToInteger(m_sv);
            m_dv = (double)m_iv;
            m_bv = m_iv != 0;
         }
         i--;
         return true; // отодвинулись на 1 символ назад и вышли
         break;
      }
      case '\"': // начало или конец строки
         if(m_type == jtOBJ) {  // если тип еще неопределён и ключ не задан
            i++;
            int is = i;
            if(!ExtrStr(js, slen, i)) {
               Print(m_key + " " + string(__LINE__));   // это ключ, идём до конца строки
               return false;
            }
            m_lkey = GetStr(js, is, i - is);
         } else {
            if(m_type != jtUNDEF) {
               Print(m_key + " " + string(__LINE__));   // ошибка типа
               return false;
            }
            m_type = jtSTR; // задали тип значения
            i++;
            int is = i;
            if(!ExtrStr(js, slen, i)) {
               Print(m_key + " " + string(__LINE__));
               return false;
            }
            FromStr(jtSTR, GetStr(js, is, i - is));
            return true;
         }
         break;
      }
   }
   return true;
}

//------------------------------------------------------------------ ExtrStr
bool CJAVal::ExtrStr(char& js[], int slen, int &i) {
   for(; js[i] != 0 && i < slen; i++) {
      char c = js[i];
      if(c == '\"')
         break; // конец строки
      if(c == '\\' && i + 1 < slen) {
         i++;
         c = js[i];
         switch(c) {
         case '/':
         case '\\':
         case '\"':
         case 'b':
         case 'f':
         case 'r':
         case 'n':
         case 't':
            break; // это разрешенные
         case 'u': { // \uXXXX
            i++;
            for(int j = 0; j < 4 && i < slen && js[i] != 0; j++, i++) {
               if(!((js[i] >= '0' && js[i] <= '9') || (js[i] >= 'A' && js[i] <= 'F') || (js[i] >= 'a' && js[i] <= 'f'))) {
                  Print(m_key + " " + CharToString(js[i]) + " " + string(__LINE__));   // не hex
                  return false;
               }
            }
            i--;
            break;
         }
         default:
            break; /*{ return false; } // неразрешенный символ с экранированием */
         }
      }
   }
   return true;
}
//------------------------------------------------------------------ Escape
string CJAVal::Escape(string a) {
   ushort as[], s[];
   int n = StringToShortArray(a, as);
   if(ArrayResize(s, 2 * n) != 2 * n)
      return NULL;
   int j = 0;
   for(int i = 0; i < n; i++) {
      switch(as[i]) {
      case '\\':
         s[j] = '\\';
         j++;
         s[j] = '\\';
         j++;
         break;
      case '"':
         s[j] = '\\';
         j++;
         s[j] = '"';
         j++;
         break;
      case '/':
         s[j] = '\\';
         j++;
         s[j] = '/';
         j++;
         break;
      case 8:
         s[j] = '\\';
         j++;
         s[j] = 'b';
         j++;
         break;
      case 12:
         s[j] = '\\';
         j++;
         s[j] = 'f';
         j++;
         break;
      case '\n':
         s[j] = '\\';
         j++;
         s[j] = 'n';
         j++;
         break;
      case '\r':
         s[j] = '\\';
         j++;
         s[j] = 'r';
         j++;
         break;
      case '\t':
         s[j] = '\\';
         j++;
         s[j] = 't';
         j++;
         break;
      default:
         s[j] = as[i];
         j++;
         break;
      }
   }
   a = ShortArrayToString(s, 0, j);
   return a;
}
//------------------------------------------------------------------ Unescape
string CJAVal::Unescape(string a) {
   ushort as[], s[];
   int n = StringToShortArray(a, as);
   if(ArrayResize(s, n) != n)
      return NULL;
   int j = 0, i = 0;
   while(i < n) {
      ushort c = as[i];
      if(c == '\\' && i < n - 1) {
         switch(as[i + 1]) {
         case '\\':
            c = '\\';
            i++;
            break;
         case '"':
            c = '"';
            i++;
            break;
         case '/':
            c = '/';
            i++;
            break;
         case 'b':
            c = 8; /*08='\b'*/;
            i++;
            break;
         case 'f':
            c = 12;/*0c=\f*/ i++;
            break;
         case 'n':
            c = '\n';
            i++;
            break;
         case 'r':
            c = '\r';
            i++;
            break;
         case 't':
            c = '\t';
            i++;
            break;
         case 'u': { // \uXXXX
            i += 2;
            ushort k = 0;
            for(int jj = 0; jj < 4 && i < n; jj++, i++) {
               c = as[i];
               ushort h = 0;
               if(c >= '0' && c <= '9')
                  h = c - '0';
               else if(c >= 'A' && c <= 'F')
                  h = c - 'A' + 10;
               else if(c >= 'a' && c <= 'f')
                  h = c - 'a' + 10;
               else
                  break; // не hex
               k += h * (ushort)pow(16, (3 - jj));
            }
            i--;
            c = k;
            break;
         }
         }
      }
      s[j] = c;
      j++;
      i++;
   }
   a = ShortArrayToString(s, 0, j);
   return a;
}
//+------------------------------------------------------------------+

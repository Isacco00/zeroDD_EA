//+------------------------------------------------------------------+
//|                                                       Zero DD EA |
//|                                    Copyright 2022, Zero Drawdown |
//|                                      http://www.zerodrawdown.com |
//+------------------------------------------------------------------+
#property icon "zerodd.ico"
#property copyright "Copyright©2022, ZeroDrawDown.com by F.Lenza and I.Trevisan"
#property link "https//:www.zerodrawdown.com"
#property version "3.00"
#property description "By using ZERO DD, you agree to hold Zero DrawDown Team and everybody who is involved in the production, development, distribution of Companion Expert Advisor free of any responsibility."
#property description "Any live trading you do, you are doing at your own discretion and risk. It’s to be noted carefully in this respect, that past results are not necessarily indicative of future performance."
#property strict
//Ultimo aggiornamento 01/09/2022

//+------------------------------------------------------------------+
//--- input parameters                                               |
//+------------------------------------------------------------------+

int MagicNumber                       = 100700;     // Magic Number

input string s1  = "RISK SETTING"; // RISK SETTING SECTION
input double Balance                  = 0;          // Balance (zero to use all Balance)
input bool AntimartingaleModeActive   = true;
input bool OptimizationActive         = true;
input bool MultiPairActive            = true;
input string s2  = "============================="; // ===============================================
input double RiskPercentForex         = 1.0;        // Risk Percent Forex ( % )
input double ProfitPercentForex       = 3.0;        // Profit Percent Forex ( % )
input string s3  = "============================="; // ===============================================
input double RiskPercentCommodities   = 0.5;        // Risk Percent Commodities ( % )
input double ProfitPercentCommodities = 2.5;        // Profit Percent Commodities ( % )

input string s22 = "============================="; // ===============================================
input string s23 = "BREAK EVEN"; //BE SECTION
input string VWAP_IndicatorPath       = "VWAP Level"; // VWAP Indicator Path
input bool BreakevenVwap              = true;

string s13 = "=============================";       // ===============================================
string s14 = "TRADING TIME"; // TRADING TIME SECTION
input int    StartHour                      = 2;          //Broker Time
int    StartMinute                    = 0;          //Broker Time
input int    EndHour                        = 23;         //Broker Time
int    EndMinute                      = 0;          //Broker Time

input string s16 = "============================="; // ===============================================
input string s17 = "SENTIMENT FILTER";              //SENTIMENT FILTER SECTION
input int FirstRangeSentiment     = 51;             //Umbalanced Sentiment
input int SecondRangeSentiment    = 99;             //Umbalanced Sentiment

input string s19 = "============================="; // ===============================================
input string s20 = "PAIR SETTINGS";                 //PAIR SETTINGS SECTION
input bool AUD = true;
input bool CAD = true;
input bool CHF = true;
input bool EUR = true;
input bool GBP = true;
input bool JPY = true;
input bool NZD = true;
input bool USD = true;
input string s21  = "============================="; // ===============================================
input bool XAG = true;
input bool XAU = true;
input bool OIL = true;
input string suffixPair               = ".r";
input string USOIL_Name               = "USOIL";

string s25  = "============================="; // ==============================================
string s26  = "MARKET PROFILE SETTINGS";       // MARKET PROFILE SECTION
string s27  = "============================="; // ==============================================
int SessionsToCount         = 2;               // SessionsToCount: Number of sessions to count Market Profile.
int ValueAreaPercentage     = 70;              // ValueAreaPercentage: Percentage of TPO's inside Value Area.
int TimeShiftMinutes        = -120;            // TimeShiftMinutes: shift session + to the left, - to the right.
int PointMultiplier         = 0;               // PointMultiplier: higher value = fewer objects. 0 - adaptive.
int ThrottleRedraw          = 0;               // ThrottleRedraw: delay (in seconds) for updating Market Profile.
int PointMultiplier_calculated;                // Will have to be calculated based number digits in a quote if PointMultiplier input is 0.
int DigitsM;                                   // Number of digits normalized based on PointMultiplier_calculated.
datetime StartDate;                            // Will hold either StartFromDate or iTime(pair,PERIOD_M30,0).
double onetick;                                // One normalized pip.
bool FirstRunDone = false;                     // If true - OnCalculate() was already executed once.
string Suffix = "_D";                          // Will store object name suffix depending on timeframe.
int Max_number_of_bars_in_a_session = 1;
int Timer = 0;                                 // For throttling updates of market profiles in slow systems.
double ValueAreaPercentage_double = 0.7;       // Will be calculated based on the input parameter in OnInit().
int _SessionsToCount;
// We need to know where each session starts and its price range for when RaysUntilIntersection != Stop_No_Rays.
// These are used also when RaysUntilIntersection == Stop_No_Rays for Intraday sessions counting.
double RememberSessionMax[], RememberSessionMin[];
datetime RememberSessionStart[];
string RememberSessionSuffix[];
int SessionsNumber = 0;                        // Different from _SessionsToCount when working with Intraday sessions and for RaysUntilIntersection != Stop_No_Rays.
//+------------------------------------------------------------------+
//| Class for working with a date                                    |
//+------------------------------------------------------------------+

struct SentimentHistoric {
   string            sPair;
   int               sLong;
   int               sShort;
   datetime          currDate;
};

struct Charts {
   long              chartID;
   string            cPair;
};

struct MarketProfile {
   double              topPrice;
   double              bottomPrice;
   double              mediumPrice;
};

struct PairManager {
   string            mPair;
   bool              useBreakEven;
   int               startHour;
   int               endHour;
   int               firstRangeSentiment;
   int               secondRangeSentiment;
   bool              activePair;
};

Charts charts[100];
SentimentHistoric  historicSentiment[31][50000];
MarketProfile marketProfile[];
int globalIndex;
int MA_handle;

string multipair[] = {"AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD", "CADCHF", "CADJPY", "CHFJPY",
                      "EURAUD", "EURCAD", "EURCHF", "EURGBP", "EURJPY", "EURNZD", "EURUSD", "GBPAUD", "GBPCAD", "GBPCHF",
                      "GBPJPY", "GBPNZD", "GBPUSD", "NZDCAD", "NZDCHF", "NZDJPY", "NZDUSD", "USDCAD", "USDCHF", "USDJPY"
                     };
string arrayPairs[];
//+------------------------------------------------------------------+
//|START BOT                                                         |
//+------------------------------------------------------------------+
int OnInit() {
   if(MultiPairActive) {
      ArrayInsert(arrayPairs, multipair, 0, 0, WHOLE_ARRAY);
   } else {
      ArrayResize(arrayPairs, 1);
      arrayPairs[0] = StringSubstr(Symbol(), 0, 6);
   }
   initializeSentimentDatabase();
   EventSetTimer(300); //Ogni secondi vado a ripetere l'OnTimer
   return 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void initializeSentimentDatabase() {
   for(int i = 0; i < ArraySize(arrayPairs); i++) {
      int handle;
      handle = FileOpen("ForexSentimentDB/" + StringSubstr(arrayPairs[i], 0, 6) + ".csv", FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(FileSize(handle) == 0) {
         FileClose(handle);
      }
      int j = 0;
      while(!FileIsEnding(handle)) {
         string str = FileReadString(handle);
         string result[];
         StringSplit(str, ',', result);
         historicSentiment[i][j].sPair = arrayPairs[i] + suffixPair;
         historicSentiment[i][j].sLong = (int) result[2];
         historicSentiment[i][j].sShort = (int) result[1];
         historicSentiment[i][j].currDate = StringToTime(result[3]);
         j++;
      }
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//|LOOP FUNCTION                                                     |
//+------------------------------------------------------------------+
void OnTimer() {
   setBreakEven();
   if(AntimartingaleModeActive) {
      openAntimartingale();
      closeAntimartingale();
   }
   getAllChart();
//Array che prende l'ora corrente
   int time[2];
   timeToInt(time);
   for(int i = 0; i < ArraySize(arrayPairs); i++) { //Ciclo su tutte le pair
      globalIndex = i;
      string sPair = "", orderComment = "";
      int sLong = 0, sShort = 0, adrPips = 0, stopLossPips = 0;
      double maxZone = -1.0, minZone = -1.0, marketProfileStopLossPrice = -1.0, imbalancePrice = -1.0;
      int index = findFirstAviableSentiment(globalIndex, TimeCurrent());
      if(index != -1) {
         sPair = historicSentiment[globalIndex][index].sPair;
         sLong = historicSentiment[globalIndex][index].sLong;
         sShort = historicSentiment[globalIndex][index].sShort;
         PairManager pairManager = getOptimization(arrayPairs[i] + suffixPair);
         bool canIOpenTrade = canIOpenTrade(sPair, time);
         if(canIOpenTrade) {
            //int MA_handle=iCustom(sPair,PERIOD_M30,"MarketProfile");
            //SEZIONE SHORT
            if(sLong >= pairManager.firstRangeSentiment && sLong <= pairManager.secondRangeSentiment && canITradeThisPair(sPair)) {
               FirstRunDone = false;
               calcMarketProfile(sPair, maxZone, minZone, marketProfileStopLossPrice, false, SessionsToCount);
               if(compareDoubles(maxZone, -1.0) != 0 && compareDoubles(maxZone, -1.0) != 0) {
                  int firstCloseDown = findCandleShort(sPair, minZone, PERIOD_D1); //Prima candela che chiude sotto la zona
                  int firstCloseUp = findCandleShort(sPair, maxZone, PERIOD_D1); //Prima candela che chiude sopra la zona
                  imbalancePrice = findImbalanceShort(sPair, firstCloseUp + 1, firstCloseDown, minZone, maxZone, PERIOD_D1); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                  if(compareDoubles(imbalancePrice, -1.0) != 0) {
                     orderComment = "D1, Sentiment buy " + IntegerToString(sLong);
                     stopLossPips = priceToPips(marketProfileStopLossPrice - imbalancePrice, sPair);
                     orderModifier(sPair, imbalancePrice, stopLossPips, 0, sLong, orderComment);
                  } else { //Try Find imbalance on H4
                     firstCloseDown = findCandleShort(sPair, minZone, PERIOD_H4); //Prima candela che chiude sotto la zona
                     firstCloseUp = findCandleShort(sPair, maxZone, PERIOD_H4); //Prima candela che chiude sopra la zona
                     imbalancePrice = findImbalanceShort(sPair, firstCloseUp + 1, firstCloseDown, minZone, maxZone, PERIOD_H4); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                     //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
                     if(compareDoubles(imbalancePrice, -1.0) != 0) {
                        orderComment = "H4, Sentiment buy " + IntegerToString(sLong);
                        stopLossPips = priceToPips(marketProfileStopLossPrice - imbalancePrice, sPair);
                        orderModifier(sPair, imbalancePrice, stopLossPips, 0, sLong, orderComment);
                     } else {//Try Find imbalance on H1
                        firstCloseDown = findCandleShort(sPair, minZone, PERIOD_H1); //Prima candela che chiude sotto la zona
                        firstCloseUp = findCandleShort(sPair, maxZone, PERIOD_H1); //Prima candela che chiude sopra la zona
                        imbalancePrice = findImbalanceShort(sPair, firstCloseUp + 1, firstCloseDown, minZone, maxZone, PERIOD_H1); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                        //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
                        if(compareDoubles(imbalancePrice, -1.0) != 0) {
                           orderComment = "H1, Sentiment buy " + IntegerToString(sLong);
                           stopLossPips = priceToPips(marketProfileStopLossPrice - imbalancePrice, sPair);
                           orderModifier(sPair, imbalancePrice, stopLossPips, 0, sLong, orderComment);
                        } else { //Try Find imbalance on M30
                           firstCloseDown = findCandleShort(sPair, minZone, PERIOD_M30); //Prima candela che chiude sotto la zona
                           firstCloseUp = findCandleShort(sPair, maxZone, PERIOD_M30); //Prima candela che chiude sopra la zona
                           imbalancePrice = findImbalanceShort(sPair, firstCloseUp + 1, firstCloseDown, minZone, maxZone, PERIOD_M30); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                           //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
                           if(compareDoubles(imbalancePrice, -1.0) != 0) {  //IMBALANCE NON TROVATA PASSO ALLA PAIR SUCCESSIVA
                              orderComment = "M30, Sentiment buy " + IntegerToString(sLong);
                              stopLossPips = priceToPips(marketProfileStopLossPrice - imbalancePrice, sPair);
                              orderModifier(sPair, imbalancePrice, stopLossPips, 0, sLong, orderComment);
                           } else {//Try Find imbalance on M15
                              firstCloseDown = findCandleShort(sPair, minZone, PERIOD_M15); //Prima candela che chiude sotto la zona
                              firstCloseUp = findCandleShort(sPair, maxZone, PERIOD_M15); //Prima candela che chiude sopra la zona
                              imbalancePrice = findImbalanceShort(sPair, firstCloseUp + 1, firstCloseDown, minZone, maxZone, PERIOD_M15); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                              //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
                              if(compareDoubles(imbalancePrice, -1.0) != 0) {  //IMBALANCE NON TROVATA PASSO ALLA PAIR SUCCESSIVA
                                 orderComment = "M15, Sentiment buy " + IntegerToString(sLong);
                                 stopLossPips = priceToPips(marketProfileStopLossPrice - imbalancePrice, sPair);
                                 orderModifier(sPair, imbalancePrice, stopLossPips, 0, sLong, orderComment);
                              } else { //IMBALANCE NON TROVATA PASSO ALLA PAIR SUCCESSIVA
                                 //Print("IMBALANCE NOT FOUND ON: " + sPair + " Was looking for short trade");
                                 closeTradeIfStillPending(sPair);
                              }
                           }
                        }
                     }
                  }
                  int chartIndex = findChartID(sPair);
                  if(chartIndex != -1) {
                     ObjectCreate(charts[chartIndex].chartID, "maxZone", OBJ_HLINE, 0, 0, maxZone);
                     ObjectCreate(charts[chartIndex].chartID, "minZone", OBJ_HLINE, 0, 0, minZone);
                     ObjectSetInteger(charts[chartIndex].chartID, "maxZone", OBJPROP_COLOR, clrWhite);
                     ObjectSetInteger(charts[chartIndex].chartID, "minZone", OBJPROP_COLOR, clrWhite);
                     //ObjectCreate(charts[chartIndex].chartID,"adrZone",OBJ_HLINE,0,0,adrPrice);
                  }
               } else {
                  //ZONE IS MOOVED, IMBALANCE NOT FOUND
                  //Print("IMBALANCE NOT FOUND ON: " + sPair + " Was looking for short trade");
                  closeTradeIfStillPending(sPair);
               }
            } else
               //SEZIONE LONG
               if(sShort >= pairManager.firstRangeSentiment && sShort <= pairManager.secondRangeSentiment && canITradeThisPair(sPair)) {
                  FirstRunDone = false;
                  calcMarketProfile(sPair, maxZone, minZone, marketProfileStopLossPrice, true, SessionsToCount);
                  if(compareDoubles(maxZone, -1.0) != 0 && compareDoubles(maxZone, -1.0) != 0) {
                     int firstCloseDown = findCandleLong(sPair, minZone, PERIOD_D1); //Prima candela che chiude sotto la zona
                     int firstCloseUp = findCandleLong(sPair, maxZone, PERIOD_D1); //Prima candela che chiude sotto la zona
                     imbalancePrice = findImbalanceLong(sPair, firstCloseUp, firstCloseDown + 1, minZone, maxZone, PERIOD_D1); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                     if(compareDoubles(imbalancePrice, -1.0) != 0) {
                        orderComment = "D1, Sentiment sell "  + IntegerToString(sShort);
                        stopLossPips = priceToPips(imbalancePrice - marketProfileStopLossPrice, sPair);
                        orderModifier(sPair, imbalancePrice, stopLossPips, 1, sShort, orderComment);
                     } else { //Try Find imbalance on H4
                        firstCloseDown = findCandleLong(sPair, minZone, PERIOD_H4); //Prima candela che chiude sotto la zona
                        firstCloseUp = findCandleLong(sPair, maxZone, PERIOD_H4); //Prima candela che chiude sotto la zona
                        imbalancePrice = findImbalanceLong(sPair, firstCloseUp, firstCloseDown + 1, minZone, maxZone, PERIOD_H4); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                        //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
                        if(compareDoubles(imbalancePrice, -1.0) != 0) {
                           orderComment = "H4, Sentiment sell "  + IntegerToString(sShort);
                           stopLossPips = priceToPips(imbalancePrice - marketProfileStopLossPrice, sPair);
                           orderModifier(sPair, imbalancePrice, stopLossPips, 1, sShort, orderComment);
                        } else {//Try Find imbalance on H1
                           firstCloseDown = findCandleLong(sPair, minZone, PERIOD_H1); //Prima candela che chiude sotto la zona
                           firstCloseUp = findCandleLong(sPair, maxZone, PERIOD_H1); //Prima candela che chiude sotto la zona
                           imbalancePrice = findImbalanceLong(sPair, firstCloseUp, firstCloseDown + 1, minZone, maxZone, PERIOD_H1); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                           //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
                           if(compareDoubles(imbalancePrice, -1.0) != 0) {
                              orderComment = "H1, Sentiment sell "  + IntegerToString(sShort);
                              stopLossPips = priceToPips(imbalancePrice - marketProfileStopLossPrice, sPair);
                              orderModifier(sPair, imbalancePrice, stopLossPips, 1, sShort, orderComment);
                           } else { //Try Find imbalance on M30
                              firstCloseDown = findCandleLong(sPair, minZone, PERIOD_M30); //Prima candela che chiude sotto la zona
                              firstCloseUp = findCandleLong(sPair, maxZone, PERIOD_M30); //Prima candela che chiude sotto la zona
                              imbalancePrice = findImbalanceLong(sPair, firstCloseUp, firstCloseDown + 1, minZone, maxZone, PERIOD_M30); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                              //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
                              if(compareDoubles(imbalancePrice, -1.0) != 0) {
                                 orderComment = "M30, Sentiment sell "  + IntegerToString(sShort);
                                 stopLossPips = priceToPips(imbalancePrice - marketProfileStopLossPrice, sPair);
                                 orderModifier(sPair, imbalancePrice, stopLossPips, 1, sShort, orderComment);
                              } else {//Try Find imbalance on M15
                                 firstCloseDown = findCandleLong(sPair, minZone, PERIOD_M15); //Prima candela che chiude sotto la zona
                                 firstCloseUp = findCandleLong(sPair, maxZone, PERIOD_M15); //Prima candela che chiude sotto la zona
                                 imbalancePrice = findImbalanceLong(sPair, firstCloseUp, firstCloseDown + 1, minZone, maxZone, PERIOD_M15); //DATE LE ZONE TROVIAMO FINALMENTE L'IMBALANCE
                                 //Print("------------------------------------------------------------------------------------------------------------------------------------------------------");
                                 if(compareDoubles(imbalancePrice, -1.0) != 0) {
                                    orderComment = "M15, Sentiment sell "  + IntegerToString(sShort);
                                    stopLossPips = priceToPips(imbalancePrice - marketProfileStopLossPrice, sPair);
                                    orderModifier(sPair, imbalancePrice, stopLossPips, 1, sShort, orderComment);
                                 } else { //IMBALANCE NON TROVATA PASSO ALLA PAIR SUCCESSIVA
                                    //Print("IMBALANCE NOT FOUND ON: " + sPair + " Was looking for long trade");
                                    closeTradeIfStillPending(sPair);
                                 }
                              }
                           }
                        }
                     }
                     int chartIndex = findChartID(sPair);
                     if(chartIndex != -1) {
                        ObjectCreate(charts[chartIndex].chartID, "maxZone", OBJ_HLINE, 0, 0, maxZone);
                        ObjectCreate(charts[chartIndex].chartID, "minZone", OBJ_HLINE, 0, 0, minZone);
                        ObjectSetInteger(charts[chartIndex].chartID, "maxZone", OBJPROP_COLOR, clrWhite);
                        ObjectSetInteger(charts[chartIndex].chartID, "minZone", OBJPROP_COLOR, clrWhite);
                        //ObjectCreate(charts[chartIndex].chartID,"adrZone",OBJ_HLINE,0,0,adrPrice);
                     }
                  } else {
                     //ZONE IS MOOVED, IMBALANCE NOT FOUND
                     //Print("IMBALANCE NOT FOUND ON: " + sPair + " Was looking for long trade");
                     closeTradeIfStillPending(sPair);
                  }
               } else {
                  //OUT OF RANGE SENTIMENT
                  closeTradeIfStillPending(sPair);
               }
         } else {
            closeTradeIfStillPending(sPair);
         }
      } else {
         Print("Day Not Found");
      }
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PairManager getOptimization(string pair) {
   PairManager pairManager;
   if(OptimizationActive) {
      if(StringFind(pair, "AUDCAD") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 68;
         pairManager.secondRangeSentiment = 73;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "AUDCHF") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "AUDJPY") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 51;
         pairManager.secondRangeSentiment = 88;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "AUDNZD") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "AUDUSD") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 52;
         pairManager.secondRangeSentiment = 62;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "CADCHF") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "CADJPY") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 54;
         pairManager.secondRangeSentiment = 79;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "CHFJPY") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 76;
         pairManager.secondRangeSentiment = 90;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "EURAUD") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "EURCAD") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 65;
         pairManager.secondRangeSentiment = 99;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "EURCHF") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 58;
         pairManager.secondRangeSentiment = 72;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "EURGBP") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "EURJPY") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 52;
         pairManager.secondRangeSentiment = 76;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "EURNZD") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 58;
         pairManager.secondRangeSentiment = 67;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "EURUSD") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "GBPAUD") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 62;
         pairManager.secondRangeSentiment = 82;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "GBPCAD") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 58;
         pairManager.secondRangeSentiment = 76;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "GBPCHF") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 54;
         pairManager.secondRangeSentiment = 66;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "GBPJPY") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "GBPNZD") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "GBPUSD") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 52;
         pairManager.secondRangeSentiment = 65;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "NZDCAD") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "NZDCHF") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "NZDJPY") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 57;
         pairManager.secondRangeSentiment = 98;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "NZDUSD") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 70;
         pairManager.secondRangeSentiment = 75;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "USDCAD") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "USDCHF") != -1) {
         pairManager.activePair = true;
         pairManager.firstRangeSentiment = 51;
         pairManager.secondRangeSentiment = 66;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "USDJPY") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = false;
      } else if(StringFind(pair, "XAGUSD") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "XAUUSD") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else if(StringFind(pair, "USOIL") != -1) {
         pairManager.activePair = false;
         pairManager.firstRangeSentiment = 100;
         pairManager.secondRangeSentiment = 100;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.useBreakEven = true;
      } else {
         pairManager.firstRangeSentiment = FirstRangeSentiment;
         pairManager.secondRangeSentiment = SecondRangeSentiment;
         pairManager.useBreakEven = BreakevenVwap;
         pairManager.startHour = 2;
         pairManager.endHour = 23;
         pairManager.activePair = false;
      }
   } else {
      pairManager.firstRangeSentiment = FirstRangeSentiment;
      pairManager.secondRangeSentiment = SecondRangeSentiment;
      pairManager.startHour = StartHour;
      pairManager.endHour = EndHour;
      pairManager.useBreakEven = BreakevenVwap;
   }
   return pairManager;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int findFirstAviableSentiment(int index, datetime day) {
   for(int i = 0; i < ArrayRange(historicSentiment, 1); i++) {
      if(historicSentiment[index][i].currDate >= day) {
         return i - 1;
      }
   }
   return -1;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool canITradeThisPair(string sPair) {
   bool finalDecision = true;
   PairManager pairManager = getOptimization(sPair);
   if(OptimizationActive) {
      if(finalDecision && StringFind(sPair, "AUDCAD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "AUDCHF") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "AUDJPY") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "AUDNZD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "AUDUSD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "CADCHF") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "CADJPY") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "CHFJPY") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "EURAUD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "EURCAD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "EURCHF") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "EURGBP") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "EURJPY") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "EURNZD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "EURUSD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "GBPAUD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "GBPCAD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "GBPCHF") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "GBPJPY") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "GBPNZD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "GBPUSD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "NZDCAD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "NZDCHF") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "NZDJPY") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "NZDUSD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "USDCAD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "USDCHF") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "USDJPY") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "XAGUSD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, "XAUUSD") != -1) {
         finalDecision = pairManager.activePair;
      }
      if(finalDecision && StringFind(sPair, USOIL_Name) != -1) {
         finalDecision = pairManager.activePair;
      }
   } else {
      if(finalDecision && StringFind(sPair, "XAG") != -1) {
         finalDecision = XAG;
      }
      if(finalDecision && StringFind(sPair, "XAU")  != -1) {
         finalDecision = XAU;
      }
      if(finalDecision && StringFind(sPair, "AUD") != -1) {
         finalDecision = AUD;
      }
      if(finalDecision && StringFind(sPair, "CAD") != -1) {
         finalDecision = CAD;
      }
      if(finalDecision && StringFind(sPair, "CHF") != -1) {
         finalDecision = CHF;
      }
      if(finalDecision && StringFind(sPair, "EUR") != -1) {
         finalDecision = EUR;
      }
      if(finalDecision && StringFind(sPair, "GBP") != -1) {
         finalDecision = GBP;
      }
      if(finalDecision && StringFind(sPair, "JPY") != -1) {
         finalDecision = JPY;
      }
      if(finalDecision && StringFind(sPair, "NZD") != -1) {
         finalDecision = NZD;
      }
      if(finalDecision && StringFind(sPair, "USD") != -1) {
         finalDecision = USD;
      }
   }
   return finalDecision;
}
//+------------------------------------------------------------------+
//FUNCTIONS
//+------------------------------------------------------------------+
bool canIOpenTrade(string pair, int& time[]) {
   int startHour, endHour;
   PairManager pairManager = getOptimization(pair);
   if(OptimizationActive) {
      startHour = pairManager.startHour;
      endHour = pairManager.endHour;
   } else {
      startHour = StartHour;
      endHour = EndHour;
   }
   if(startHour > endHour) {
      if(time[0] >= startHour || time[0] <= endHour) {
         if(time[0] == startHour) {
            if(time[1] >= StartMinute) {
               return true;
            } else {
               return false;
            }
         } else if(time[0] == endHour) {
            if(time[1] <= EndMinute - 1) {
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
   } else if(startHour < endHour) {
      if(time[0] >= startHour && time[0] <= endHour) {
         if(time[0] == startHour) {
            if(time[1] >= StartMinute) {
               return true;
            } else {
               return false;
            }
         } else if(time[0] == endHour) {
            if(time[1] <= EndMinute - 1) {
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
void getAllChart() {
//--- variables for chart ID
   long nextChart, firstChart = ChartFirst();
   int i = 0, limit = 100;
   charts[i].cPair = ChartSymbol(firstChart);
   charts[i].chartID = firstChart;
   while(i < limit) { // We have certainly not more than 100 open charts
      nextChart = ChartNext(firstChart); // Get the new chart ID by using the previous chart ID
      if(nextChart < 0) break;        // Have reached the end of the chart list
      charts[i].cPair = ChartSymbol(nextChart);
      charts[i].chartID = nextChart;
      firstChart = nextChart; // let's save the current chart ID for the ChartNext()
      i++;// Do not forget to increase the counter
   }
}
//+------------------------------------------------------------------+
//|Guardo se posso aprire i trade in base all'orario                 |
//+------------------------------------------------------------------+
int findChartID(string pair) {
   for(int i = 0; i < ArraySize(charts); i++) {
      if(charts[i].cPair == pair) {
         return i;
      }
   }
   return -1;
}
/*
   Input:  valore pips (int)
   Output: pips convertito in prezzo (double )

   Calcola il numero di cifre di cui è composto l'adr e lo utilizza per efettuare il calcolo e
   trasformare adr in prezzo
*/
double pipsToPrice(int pips, string pair) {
   if(StringFind(pair, "XAG", 0) != -1) {
      return pips * MathPow(10, -2);
   }
   if(StringFind(pair, "XAU", 0) != -1) {
      return pips * MathPow(10, 0);
   }
   if(StringFind(pair, USOIL_Name, 0) != -1) {
      return pips * MathPow(10, -1);
   }
   if(StringFind(pair, "JPY", 0) != -1) {
      return pips * MathPow(10, -2);
   }
   return pips * MathPow(10, -4);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int priceToPips(double price, string pair) {
   if(StringFind(pair, "XAG", 0) != -1) {
      return (int) MathRound(price / MathPow(10, -2));
   }
   if(StringFind(pair, "XAU", 0) != -1) {
      return (int) MathRound(price / MathPow(10, 0));
   }
   if(StringFind(pair, USOIL_Name, 0) != -1) {
      return (int) MathRound(price / MathPow(10, -1));
   }
   if(StringFind(pair, "JPY", 0) != -1) {
      return (int) MathRound(price / MathPow(10, -2));
   }
   return (int) MathRound(price / MathPow(10, -4));
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getNTickValue(string pair, double nTickValue) {
   if(StringFind(pair, "XAG", 0) != -1) {
      return nTickValue * 100.0;
   }
   if(StringFind(pair, "XAU", 0) != -1) {
      return nTickValue * 100.0;
   }
   if(StringFind(pair, USOIL_Name, 0) != -1) {
      return nTickValue * 100.0;
   }
   return nTickValue * 10.0;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int findCandleShort(string pair, double zone, ENUM_TIMEFRAMES tFrame) {
   int count = 0;
   while(true) { //Ciclo finchè non trovo la prima candela che esce
      double high = iHigh(pair, tFrame, count);
      if(compareDoubles(high, 0.0) != 0) {
         if(compareDoubles(high, zone) == 1) {
            return count;
         } else {
            count++;
         }
      } else {
         Print("Missing History Data on " + pair);
         break;
      }
   }
   return NULL;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int findCandleLong(string pair, double zone, ENUM_TIMEFRAMES tFrame) {
   int count = 0;
   while(true) { //Ciclo finchè non trovo la prima candela che esce
      double low = iLow(pair, tFrame, count);
      if(compareDoubles(low, 0.0) != 0) {
         if(compareDoubles(low, zone) == 2) {
            return count;
         } else {
            count++;
         }
      } else {
         Print("Missing History Data " + pair);
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
double findImbalanceShort(string pair, int firstCloseUp, int firstCloseDown, double minZone, double maxZone,  ENUM_TIMEFRAMES tFrame) {
   double imbalancePrice = -1.0;
   long imbalanceVolume = 0;
   int imbalanceBar = 0;
   int stopLossPips = 0;
   while(firstCloseUp >= firstCloseDown && firstCloseUp > 1) { //Candele + a sinistra nel grafo -> indice più elevato
      double minAlto = iLow(pair, tFrame, firstCloseUp); //minimo della candela attualmente piu in alto nella nostra zona
      bool findImbalance = true;
      int count = firstCloseUp - 2; //MI SPOSTO DI DUE PER IL CONTROLLO DAL SUCC SUCC
      while(count >= 0 && findImbalance) {  //Controllo che dalla SUCC SUCC non ci siano valori superiori alla imbalance trovata
         MqlDateTime date;
         TimeToStruct(iTime(pair, tFrame, count), date);
         int isSpreadCandle = date.hour;
         if(isSpreadCandle != 0) {
            double maxCandDoubleSucc = iHigh(pair, tFrame, count);
            if(compareDoubles(minAlto, maxCandDoubleSucc) == 2) {
               findImbalance = false;
            }
         }
         count -= 1;
      }
      if(findImbalance) {
         if(compareDoubles(minAlto, minZone) == 2 || compareDoubles(minAlto, maxZone) == 1) {
         } else {
            long volume = iVolume(pair, PERIOD_H1, firstCloseUp);
            if(imbalanceVolume <= volume) {
               imbalanceBar = firstCloseUp;
               imbalancePrice = minAlto;
               imbalanceVolume = volume;
            }
         }
      }
      firstCloseUp -= 1; // scendo di una candela e controllo la successiva (+ adestra)
   }
   if(imbalancePrice != -1) {
      //Smart StopLoss
      double previousHigh = iHigh(pair, tFrame, imbalanceBar + 1);
      double currentHigh = iHigh(pair, tFrame, imbalanceBar);
      double nextHigh = iHigh(pair, tFrame, imbalanceBar - 1);
      double stopLossPrice = 0.0;
      if(compareDoubles(previousHigh, currentHigh) == 1 && compareDoubles(previousHigh, nextHigh) == 1) {
         stopLossPrice = previousHigh;
      }
      if(compareDoubles(currentHigh, previousHigh) == 1 && compareDoubles(currentHigh, nextHigh) == 1) {
         stopLossPrice = currentHigh;
      }
      if(compareDoubles(nextHigh, previousHigh) == 1 && compareDoubles(nextHigh, currentHigh) == 1) {
         stopLossPrice = nextHigh;
      }
      stopLossPips = priceToPips(stopLossPrice - imbalancePrice, pair);
   }
   return imbalancePrice;
}
/*
   Input: pair , pos_max=numero barra limite superiore ,pos_min =numero barra limite inferiore ,Bound superiore e inferiore in cui l'imbalance trovata è accettata
   Output: imbalance(double) se trovata altrimenti -1
   Trova l'imbalance long per la zona individuata
*/
double findImbalanceLong(string pair, int firstCloseUp, int firstCloseDown, double minZone, double maxZone, ENUM_TIMEFRAMES tFrame) {
   double imbalancePrice = -1.0;
   long imbalanceVolume = 0;
   int imbalanceBar = 0, stopLossPips = 0;
   while(firstCloseDown >= firstCloseUp && firstCloseDown > 1) {
      double maxBasso = iHigh(pair, tFrame, firstCloseDown);
      bool findImbalance = true;
      int count = firstCloseDown - 2;
      while(count >= 0 && findImbalance) {
         MqlDateTime date;
         TimeToStruct(iTime(pair, tFrame, count), date);
         int isSpreadCandle = date.hour;
         if(isSpreadCandle != 0) {
            double minCandDoubleSucc = iLow(pair, tFrame, count);
            if(compareDoubles(maxBasso, minCandDoubleSucc) == 1) {
               findImbalance = false;
            }
         }
         count -= 1;
      }
      if(findImbalance) {
         if(compareDoubles(maxBasso, minZone) == 2 || compareDoubles(maxBasso, maxZone) == 1) {
         } else {
            long volume = iVolume(pair, PERIOD_H1, firstCloseDown);
            if(imbalanceVolume <= volume) {
               imbalanceBar = firstCloseDown;
               imbalanceVolume = volume;
               imbalancePrice = maxBasso;
            }
         }
      }
      firstCloseDown -= 1;
   }
   if(imbalancePrice != -1) {
      //SMART STOPLOSS
      double previousLow = iLow(pair, tFrame, imbalanceBar + 1);
      double currentLow = iLow(pair, tFrame, imbalanceBar);
      double nextLow = iLow(pair, tFrame, imbalanceBar - 1);
      double stopLossPrice = 0.0;
      if(compareDoubles(previousLow, currentLow) == 2 && compareDoubles(previousLow, nextLow) == 2) {
         stopLossPrice = previousLow;
      }
      if(compareDoubles(currentLow, previousLow) == 2 && compareDoubles(currentLow, nextLow) == 2) {
         stopLossPrice = currentLow;
      }
      if(compareDoubles(nextLow, previousLow) == 2 && compareDoubles(nextLow, currentLow) == 2) {
         stopLossPrice = nextLow;
      }
      stopLossPips = priceToPips(imbalancePrice - stopLossPrice, pair);
   }
   return imbalancePrice;
}
/*
   Input: StopLoss ->based on ADR measure
   Output: lotsize
   Calcola lotsize in base alla dimensione del conto seguendo vari fattori-> risk_for_trade /pair / balance
*/
double calculateLotSize(double SL, string pair) {
   double lotSize = 0.0, balance = 0.0;
// Value of a tick
   double nTickValue = SymbolInfoDouble(pair, SYMBOL_TRADE_TICK_VALUE);
// Normalizziamo i tick in base alle digit
   while(compareDoubles(nTickValue, 0.0) == 0) {
      nTickValue = SymbolInfoDouble(pair, SYMBOL_TRADE_TICK_VALUE);
   }
   nTickValue = getNTickValue(pair, nTickValue);
// Formula per calcolare la LotSize
   if(compareDoubles(Balance, 0) == 0) {
      balance = AccountInfoDouble(ACCOUNT_BALANCE);
   } else {
      balance = Balance;
   }
   if(StringFind(pair, USOIL_Name) != -1 || StringFind(pair, "XAG") != -1 || StringFind(pair, "XAU") != -1) {
      lotSize = (balance * RiskPercentCommodities / 100) / (SL * nTickValue);
   } else {
      lotSize = (balance * RiskPercentForex / 100) / (SL * nTickValue);
   }
   if(StringFind(pair, USOIL_Name) != -1) {
      return NormalizeDouble(lotSize, 0);
   }
   return NormalizeDouble(lotSize, 2);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeTradeIfStillPending(string pair) {
   ulong orderTicket = 0;
   for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderGetTicket(i) > 0) {
         string orderSymbol = OrderGetString(ORDER_SYMBOL);
         if(orderSymbol == pair) {
            string count[];
            int ss = StringSplit(OrderGetString(ORDER_COMMENT), ',', count);
            if(ArraySize(count) < 3) {
               orderTicket = OrderGetTicket(i);
               MqlTradeRequest request = {};
               MqlTradeResult  result = {};
               ZeroMemory(request);
               ZeroMemory(result);
               request.action = TRADE_ACTION_REMOVE;
               request.order = orderTicket;
               if(!OrderSend(request, result)) {
                  PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
               }
               break;
            }
         }
      }
   }
}
/*
   Input: pair, imbalance , long_short intero se voglio aprire SHORT=0 , se voglio aprire LONG =1
   Apre o modifica i pendenti già aperti se trova una zona migliore
*/
void orderModifier(string pair, double imbalance, int stopLossPips, int longShort, int sentimentValue, string orderComment) {
   double riskPercent = 0.0, profitPercent = 0.0;
   if(StringFind(pair, USOIL_Name) != -1 && StringFind(pair, "XAG") != -1 && StringFind(pair, "XAU") != -1) {
      riskPercent = RiskPercentCommodities;
      profitPercent = ProfitPercentCommodities;
   } else {
      riskPercent = RiskPercentForex;
      profitPercent = ProfitPercentForex;
   }
   int symbolCount = 0;
//Scan se ho già l'ordine pendente o fillato
   for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderGetTicket(i) > 0) {
         string orderSymbol = OrderGetString(ORDER_SYMBOL);
         if(orderSymbol == pair) {
            string count[];
            int ss = StringSplit(OrderGetString(ORDER_COMMENT), ',', count);
            if(ArraySize(count) < 3) {
               double orderPriceOpen = OrderGetDouble(ORDER_PRICE_OPEN);
               if(orderPriceOpen != imbalance) {
                  ulong orderTicket = OrderGetTicket(i);
                  MqlTradeRequest request = {};
                  MqlTradeResult  result = {};
                  ZeroMemory(request);
                  ZeroMemory(result);
                  request.action = TRADE_ACTION_REMOVE;
                  request.order = orderTicket;
                  if(!OrderSend(request, result)) {
                     PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
                     symbolCount += 1;
                  }
                  break;
               } else {
                  symbolCount += 1;
                  break;
               }
            }
         }
      }
   }
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionGetTicket(i) > 0) {
         string orderSymbol = PositionGetString(POSITION_SYMBOL);
         if(orderSymbol == pair) {
            symbolCount += 1;
            break;
         }
      }
   }
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_PENDING;
   request.symbol = pair;
   request.volume = calculateLotSize(stopLossPips, pair);
   request.magic  = MagicNumber;
   request.comment = orderComment;
   request.price = imbalance;
   if(symbolCount == 0) { // se non ho ordini già fillati o pending apro un nuovo ordine
      if(longShort == 0) { //SHORT
         request.sl = imbalance + pipsToPrice(stopLossPips, pair);
         request.tp = imbalance - pipsToPrice((int) (stopLossPips * profitPercent / riskPercent), pair);
         request.type = ORDER_TYPE_SELL_LIMIT;
         if(!OrderSend(request, result)) {
            PrintFormat("OrderSend error %d", GetLastError());
         }
      } else { //LONG
         request.sl = imbalance - pipsToPrice(stopLossPips, pair);
         request.tp = imbalance + pipsToPrice((int) (stopLossPips * profitPercent / riskPercent), pair);
         request.type = ORDER_TYPE_BUY_LIMIT;
         if(!OrderSend(request, result)) {
            PrintFormat("OrderSend error %d", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void timeToInt(int &time[]) {
   datetime s = TimeCurrent();
   string f = TimeToString(s);
   string h = StringSubstr(f, 11, 2) + StringSubstr(f, 14, 2);
   time[0] = (int) StringToInteger(StringSubstr(h, 0, 2));
   time[1] = (int) StringToInteger(StringSubstr(h, 2, 2));
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int compareDoubles(double n1, double n2) {
   double norm = NormalizeDouble(n1 - n2, 8);
   if(norm == 0)
      return(0); //Se uguali
   else if(norm > 0)
      return(1); //n1 > n2
   else if(norm < 0)
      return(2); //n1 < n2
   return -1;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int digitsForPairs(string sPair)  {
   return (int) SymbolInfoInteger(sPair, SYMBOL_DIGITS);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double pointsForPairs(string sPair)  {
   return SymbolInfoDouble(sPair, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|Calcolo MarketProfile                                             |
//+------------------------------------------------------------------+
int calcMarketProfile(string pair, double &upperRange, double &lowerRange, double &marketProfileStopLoss, bool isLongTrade, int sessionToCount) {
   double firstTopPrice = -1.0, nTopPrice = -1.0, firstBottomPrice = -1.0, nBottomPrice = -1.0, firstMediumPrice = -1.0, nMediumPrice = -1.0, topPrice, bottomPrice, mediumPrice;
// Sessions to count for the object creation.
   _SessionsToCount = sessionToCount;
// Adaptive point multiplier. Calculate based on number of digits in quote (before plus after the dot).
   if (PointMultiplier == 0) {
      double quote;
      bool success = SymbolInfoDouble(pair, SYMBOL_ASK, quote);
      if (!success) {
         Print("Failed to get price data. Error #", GetLastError(), ". Using PointMultiplier = 1.");
         PointMultiplier_calculated = 1;
      } else {
         string s = DoubleToString(quote, digitsForPairs(pair));
         int total_digits = StringLen(s);
         // If there is a dot in a quote.
         if (StringFind(s, ".") != -1) total_digits--; // Decrease the count of digits by one.
         if (total_digits <= 5) PointMultiplier_calculated = 1;
         else PointMultiplier_calculated = (int)MathPow(10, total_digits - 5);
      }
   } else { // Normal point multiplier.
      PointMultiplier_calculated = PointMultiplier;
   }
// Based on number of digits in PointMultiplier_calculated. -1 because if PointMultiplier_calculated < 10, it does not modify the number of digits.
   DigitsM = digitsForPairs(pair) - (StringLen(IntegerToString(PointMultiplier_calculated)) - 1);
   onetick = NormalizeDouble(pointsForPairs(pair) * PointMultiplier_calculated, DigitsM);
// Adjust for TickSize granularity if needed.
   double TickSize = SymbolInfoDouble(pair, SYMBOL_TRADE_TICK_SIZE);
   if (onetick < TickSize) {
      DigitsM = digitsForPairs(pair) - (StringLen(IntegerToString((int) MathRound(TickSize / pointsForPairs(pair)))) - 1);
      onetick = NormalizeDouble(TickSize, DigitsM);
   }
   ValueAreaPercentage_double = ValueAreaPercentage * 0.01;
// Check if user requests current session, else a specific date.
   StartDate = iTime(pair, PERIOD_M30, 0);
// Get start and end bar numbers of the given session.
   int sessionend = FindSessionEndByDate(pair, StartDate);
   int sessionstart = FindSessionStart(pair, sessionend);
   if (sessionstart == -1) {
      Print("Something went wrong! Waiting for data to load.");
      return 0;
   }
   int SessionToStart = 0;
// If all sessions have already been counted, jump to the current one.
   if (FirstRunDone) SessionToStart = _SessionsToCount - 1;
   else {
      // Move back to the oldest session to count to start from it.
      for (int i = 1; i < _SessionsToCount; i++) {
         sessionend = sessionstart + 1;
         if (sessionend >= iBars(pair, PERIOD_M30)) return 0;
         sessionstart = FindSessionStart(pair, sessionend);
      }
   }
   ArrayResize(marketProfile, _SessionsToCount);
// We begin from the oldest session coming to the current session or to StartFromDate.
   for(int i = SessionToStart; i < _SessionsToCount; i++) {
      Max_number_of_bars_in_a_session = PeriodSeconds(PERIOD_D1) / PeriodSeconds();
      // The start is on Sunday - add remaining time.
      if (TimeDayOfWeek(iTime(pair, PERIOD_M30, sessionstart)) == 0) Max_number_of_bars_in_a_session += (24 * 3600 - (TimeHour(iTime(pair, PERIOD_M30, sessionstart)) * 3600 + TimeMinute(iTime(pair, PERIOD_M30, sessionstart)) * 60)) / PeriodSeconds();
      // The end is on Saturday. +1 because even 0:00 bar deserves a bar.
      if (TimeDayOfWeek(iTime(pair, PERIOD_M30, sessionend)) == 6) Max_number_of_bars_in_a_session += ((TimeHour(iTime(pair, PERIOD_M30, sessionend)) * 3600 + TimeMinute(iTime(pair, PERIOD_M30, sessionend)) * 60)) / PeriodSeconds() + 1;
      if (!ProcessSession(pair, topPrice, bottomPrice, mediumPrice, sessionstart, sessionend, i)) return 0;
      marketProfile[i].bottomPrice = bottomPrice;
      marketProfile[i].topPrice = topPrice;
      marketProfile[i].mediumPrice = mediumPrice;
      // Go to the newer session only if there is one or more left.
      if (_SessionsToCount - i > 1) {
         sessionstart = sessionend - 1;
         sessionend = FindSessionEndByDate(pair, iTime(pair, PERIOD_M30, sessionstart));
      }
   }
   if(isLongTrade) {
      firstBottomPrice = marketProfile[ArraySize(marketProfile) - 1].bottomPrice;
      nMediumPrice =  marketProfile[0].mediumPrice;
      marketProfileStopLoss = marketProfile[0].bottomPrice;
      if(compareDoubles(firstBottomPrice, nMediumPrice) == 1) {
         upperRange = firstBottomPrice;
         lowerRange = nMediumPrice;
      } else {
         upperRange = -1;
         lowerRange = -1;
         //Print("Not the best day to trade ... " + pair + " long");
      }
   } else {
      firstTopPrice = marketProfile[ArraySize(marketProfile) - 1].topPrice;
      nMediumPrice =  marketProfile[0].mediumPrice;
      marketProfileStopLoss = marketProfile[0].topPrice;
      if(compareDoubles(nMediumPrice, firstTopPrice) == 1) {
         upperRange = nMediumPrice;
         lowerRange = firstTopPrice;
      } else {
         upperRange = -1;
         lowerRange = -1;
         //Print("Not the best day to trade ... " + pair + " short");
      }
   }
   if(compareDoubles(upperRange, -1) == 0 && compareDoubles(lowerRange, -1) == 0) {
      //calcMarketProfile(pair, upperRange, lowerRange, isLongTrade, _SessionsToCount + 1);
   }
   FirstRunDone = true;
   Timer = (int)TimeLocal();
   return 0;
}

//+------------------------------------------------------------------+
//| Finds the session's starting bar number for any given bar number.|
//| n - bar number for which to find starting bar.                   |
//+------------------------------------------------------------------+
int FindSessionStart(const string pair, const int n) {
   return FindDayStart(pair, n);
}

//+------------------------------------------------------------------+
//| Finds the day's starting bar number for any given bar number.    |
//| n - bar number for which to find starting bar.                   |
//+------------------------------------------------------------------+
int FindDayStart(const string pair, const int n) {
   if (n >= iBars(pair, PERIOD_M30)) return -1;
   int x = n;
   int time_x_day_of_week = TimeDayOfWeek(iTime(pair, PERIOD_M30, x) + TimeShiftMinutes * 60);
   int time_n_day_of_week = time_x_day_of_week;
// Condition should pass also if Append_Saturday_Sunday is on and it is Sunday or it is Friday but the bar n is on Saturday.
   while ((TimeDayOfYear(iTime(pair, PERIOD_M30, n) + TimeShiftMinutes * 60) == TimeDayOfYear(iTime(pair, PERIOD_M30, x) + TimeShiftMinutes * 60)) || (((time_x_day_of_week == 0) || ((time_x_day_of_week == 5) && (time_n_day_of_week == 6))))) {
      x++;
      if (x >= iBars(pair, PERIOD_M30)) break;
      time_x_day_of_week = TimeDayOfWeek(iTime(pair, PERIOD_M30, x) + TimeShiftMinutes * 60);
   }
   return (x - 1);
}

//+------------------------------------------------------------------+
//| Finds the session's end bar by the session's date.               |
//+------------------------------------------------------------------+
int FindSessionEndByDate(const string pair, const datetime date) {
   return FindDayEndByDate(pair, date);
}

//+------------------------------------------------------------------+
//| Finds the day's end bar by the day's date.                       |
//+------------------------------------------------------------------+
int FindDayEndByDate(const string pair, const datetime date) {
   int x = 0;
// TimeAbsoluteDay is used for cases when the given date is Dec 30 (#364) and the current date is Jan 1 (#1) for example.
   while ((x < iBars(pair, PERIOD_M30)) && (TimeAbsoluteDay(date + TimeShiftMinutes * 60) < TimeAbsoluteDay(iTime(pair, PERIOD_M30, x) + TimeShiftMinutes * 60))) {
      // Check if Append_Saturday_Sunday is on and if the found end of the day is on Saturday and the given date is the previous Friday; or it is a Monday and the sought date is the previous Sunday.
      if (((TimeDayOfWeek(iTime(pair, PERIOD_M30, x) + TimeShiftMinutes * 60) == 6) || (TimeDayOfWeek(iTime(pair, PERIOD_M30, x) + TimeShiftMinutes * 60) == 1)) && (TimeAbsoluteDay(iTime(pair, PERIOD_M30, x) + TimeShiftMinutes * 60) - TimeAbsoluteDay(date + TimeShiftMinutes * 60) == 1)) break;
      x++;
   }
   return x;
}

//+------------------------------------------------------------------+
//| Main procedure to draw the Market Profile based on a session     |
//| start bar and session end bar.                                   |
//| i - session number with 0 being the oldest one.                  |
//| Returns true on success, false - on failure.                     |
//+------------------------------------------------------------------+
bool ProcessSession(const string pair, double &topPrice, double &bottomPrice, double &mediumPrice, const int sessionstart, const int sessionend, const int i) {
   string rectangle_prefix = ""; // Only for rectangle sessions.
   if (sessionstart >= iBars(pair, PERIOD_M30)) return false; // Data not yet ready.
   double SessionMax = DBL_MIN, SessionMin = DBL_MAX;
// Find the session's high and low.
   for (int bar = sessionstart; bar >= sessionend; bar--) {
      if (iHigh(pair, PERIOD_M30, bar) > SessionMax) SessionMax = iHigh(pair, PERIOD_M30, bar);
      if (iLow(pair, PERIOD_M30, bar) < SessionMin) SessionMin = iLow(pair, PERIOD_M30, bar);
   }
   SessionMax = NormalizeDouble(SessionMax, DigitsM);
   SessionMin = NormalizeDouble(SessionMin, DigitsM);
   int session_counter = i;
// Find iTime(pair,PERIOD_M30,sessionstart) among RememberSessionStart[].
   bool need_to_increment = true;
   for (int j = 0; j < SessionsNumber; j++) {
      if (RememberSessionStart[j] == iTime(pair, PERIOD_M30, sessionstart)) {
         need_to_increment = false;
         session_counter = j; // Real number of the session.
         break;
      }
   }
// Raise the number of sessions and resize arrays.
   if (need_to_increment) {
      SessionsNumber++;
      session_counter = SessionsNumber - 1; // Newest session.
      ArrayResize(RememberSessionMax, SessionsNumber);
      ArrayResize(RememberSessionMin, SessionsNumber);
      ArrayResize(RememberSessionStart, SessionsNumber);
      ArrayResize(RememberSessionSuffix, SessionsNumber);
   }
// Adjust SessionMin, SessionMax for onetick granularity.
   SessionMax = NormalizeDouble(MathRound(SessionMax / onetick) * onetick, DigitsM);
   SessionMin = NormalizeDouble(MathRound(SessionMin / onetick) * onetick, DigitsM);
   RememberSessionMax[session_counter] = SessionMax;
   RememberSessionMin[session_counter] = SessionMin;
   RememberSessionStart[session_counter] = iTime(pair, PERIOD_M30, sessionstart);
   RememberSessionSuffix[session_counter] = Suffix;
// Used to make sure that SessionMax increments only by 'onetick' increments.
// This is needed only when updating the latest trading session and PointMultiplier_calculated > 1.
   static double PreviousSessionMax = DBL_MIN;
   static datetime PreviousSessionStartTime = 0;
// Reset PreviousSessionMax when a new session becomes the 'latest one'.
   if (iTime(pair, PERIOD_M30, sessionstart) > PreviousSessionStartTime) {
      PreviousSessionMax = DBL_MIN;
      PreviousSessionStartTime = iTime(pair, PERIOD_M30, sessionstart);
   }
   if ((FirstRunDone) && (i == _SessionsToCount - 1) && (PointMultiplier_calculated > 1)) { // Updating the latest trading session.
      if (SessionMax - PreviousSessionMax < onetick) { // SessionMax increased only slightly - too small to use the new value with the current onetick.
         SessionMax = PreviousSessionMax; // Do not update session max.
      } else {
         if (PreviousSessionMax != DBL_MIN) {
            // Calculate number of increments.
            double nc = (SessionMax - PreviousSessionMax) / onetick;
            // Adjust SessionMax.
            SessionMax = NormalizeDouble(PreviousSessionMax + MathRound(nc) * onetick, DigitsM);
         }
         PreviousSessionMax = SessionMax;
      }
   }
   int TPOperPrice[];
// Possible price levels if multiplied to integer.
   int max = (int)MathRound((SessionMax - SessionMin) / onetick + 2); // + 2 because further we will be possibly checking array at SessionMax + 1.
   ArrayResize(TPOperPrice, max);
   ArrayInitialize(TPOperPrice, 0);
   bool SinglePrintTracking_array[]; // For SinglePrint rays.
   int MaxRange = 0; // Maximum distance from session start to the drawn dot.
   double PriceOfMaxRange = 0; // Level of the maximum range, required to draw Median.
   double DistanceToCenter = DBL_MAX; // Closest distance to center for the Median.
// Right to left for the final session:
// 1. Get rightmost time.
// 2a. If it <= iTime(pair,PERIOD_M30,0) - use normal bar-walking, else:
// 2b. To "move" to the left - subtract PeriodSeconds().
// 3. Draw everything based on that Time.
// 4. Redraw everything every time the rightmost time changes.
// 5. Ray lines to the left.
// Right-to-left depiction of the rightmost session.
   datetime converted_time = 0;
   datetime converted_end_time = 0;
   datetime min_converted_end_time = UINT_MAX;
   int TotalTPO = 0; // Total amount of dots (TPO's).
// Going through all possible quotes from session's High to session's Low.
   for (double price = SessionMax; price >= SessionMin; price -= onetick) {
      price = NormalizeDouble(price, DigitsM);
      int range = 0; // Distance from first bar to the current bar.
      // Going through all bars of the session to see if the price was encountered here.
      for (int bar = sessionstart; bar >= sessionend; bar--) {
         // Price is encountered in the given bar.
         if ((price >= iLow(pair, PERIOD_M30, bar)) && (price <= iHigh(pair, PERIOD_M30, bar))) {
            // Update maximum distance from session's start to the found bar (needed for Median).
            // Using the center-most Median if there are more than one.
            if ((MaxRange < range) || ((MaxRange == range) && (MathAbs(price - (SessionMin + (SessionMax - SessionMin) / 2)) < DistanceToCenter))) {
               MaxRange = range;
               PriceOfMaxRange = price;
               DistanceToCenter = MathAbs(price - (SessionMin + (SessionMax - SessionMin) / 2));
            }
            // Remember the number of encountered bars for this price.
            int index = (int)MathRound((price - SessionMin) / onetick);
            TPOperPrice[index]++;
            range++;
            TotalTPO++;
         }
      }
   }
   double TotalTPOdouble = TotalTPO;
// Calculate amount of TPO's in the Value Area.
   int ValueControlTPO = (int)MathRound(TotalTPOdouble * ValueAreaPercentage_double);
// Start with the TPO's of the Median.
   int index = (int)((PriceOfMaxRange - SessionMin) / onetick);
   if (index < 0) return false; // Data not yet ready.
   int TPOcount = TPOperPrice[index];
// Go through the price levels above and below median adding the biggest to TPO count until the 70% of TPOs are inside the Value Area.
   int up_offset = 1;
   int down_offset = 1;
   while (TPOcount < ValueControlTPO) {
      double abovePrice = PriceOfMaxRange + up_offset * onetick;
      double belowPrice = PriceOfMaxRange - down_offset * onetick;
      // If belowPrice is out of the session's range then we should add only abovePrice's TPO's, and vice versa.
      index = (int)MathRound((abovePrice - SessionMin) / onetick);
      int index2 = (int)MathRound((belowPrice - SessionMin) / onetick);
      if (((belowPrice < SessionMin) || (TPOperPrice[index] >= TPOperPrice[index2])) && (abovePrice <= SessionMax)) {
         TPOcount += TPOperPrice[index];
         up_offset++;
      } else if (belowPrice >= SessionMin) {
         TPOcount += TPOperPrice[index2];
         down_offset++;
      }
      // Cannot proceed - too few data points.
      else if (TPOcount < ValueControlTPO) {
         break;
      }
   }
   string LastName = " " + TimeToString(iTime(pair, PERIOD_M30, sessionstart), TIME_DATE);
// Draw a new one.
   index = MathMax(sessionstart - MaxRange - 1, 0);
   datetime time_start, time_end;
   time_end = iTime(pair, PERIOD_M30, index);
   time_start = iTime(pair, PERIOD_M30, sessionstart);
   topPrice = PriceOfMaxRange + up_offset * onetick;
   bottomPrice = PriceOfMaxRange - down_offset * onetick + onetick;
   mediumPrice = PriceOfMaxRange;
   return true;
}

//+------------------------------------------------------------------+
//| Returns absolute day number.                                     |
//+------------------------------------------------------------------+
int TimeAbsoluteDay(const datetime time) {
   return ((int)time / 86400);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeDayOfWeek(const datetime time) {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.day_of_week;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeHour(const datetime time) {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.hour;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeMinute(const datetime time) {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.min;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeDay(const datetime time) {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.day;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeDayOfYear(const datetime time) {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.day_of_year;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeMonth(const datetime time) {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.mon;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TimeYear(const datetime time) {
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.year;
}
//+------------------------------------------------------------------+
//BreakEven
//+------------------------------------------------------------------+
void setBreakEven() {
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionGetTicket(i) > 0) {
         PairManager pairManager = getOptimization(PositionGetString(POSITION_SYMBOL));
         if(pairManager.useBreakEven) {
            string result[];
            StringSplit(PositionGetString(POSITION_COMMENT), ',', result);
            if(ArraySize(result) < 3) {
               ulong Ticket = PositionGetTicket(i);
               string resultComment[];
               int ss = StringSplit(PositionGetString(POSITION_COMMENT), ',', resultComment);
               ENUM_TIMEFRAMES tFrame = PERIOD_M15;
               if(ss != -1) {
                  if(StringFind(result[0], "D1") != -1) {
                     tFrame = PERIOD_D1;
                  } else if(StringFind(result[0], "H4") != -1) {
                     tFrame = PERIOD_H4;
                  } else if(StringFind(result[0], "H1") != -1) {
                     tFrame = PERIOD_H1;
                  } else if(StringFind(result[0], "M30") != -1) {
                     tFrame = PERIOD_M30;
                  } else if(StringFind(result[0], "M15") != -1) {
                     tFrame = PERIOD_M15;
                  }
               }
               SetBreakEven_VWAP_OM(i, PositionGetString(POSITION_SYMBOL), tFrame);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| SetBreakEven_VWAP_OM Function                                    |
//+------------------------------------------------------------------+
void SetBreakEven_VWAP_OM(int index, string pair, ENUM_TIMEFRAMES tFrame) {
   MqlTradeRequest request;
   MqlTradeResult  result;
   ulong Ticket = PositionGetTicket(index);
   datetime openTime = (datetime) PositionGetInteger(POSITION_TIME);
   openTime = openTime + PeriodSeconds(tFrame);
   double BE_Start_Level = 0.0;
   double BE_Level = 0.0;
   double BE_SPREAD = 1.5;
   double BE_Start_Pips = 5;
   double buf[], VWAP;
   MA_handle = iCustom(pair, PERIOD_M30, VWAP_IndicatorPath);
   if(CopyBuffer(MA_handle, 0, 0, 1, buf) > 0) {
      VWAP = buf[0];
      double P;
      int digits = (int) SymbolInfoInteger(pair, SYMBOL_DIGITS);
      if(digits == 5 || digits == 3)
         P = 10;
      else
         P = 1;
      double point = SymbolInfoDouble(pair, SYMBOL_POINT);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         if(PositionGetDouble(POSITION_SL) == 0 || (PositionGetDouble(POSITION_SL) != 0 && PositionGetDouble(POSITION_SL) < PositionGetDouble(POSITION_PRICE_OPEN))) {
            if(PositionGetDouble(POSITION_PRICE_OPEN) < VWAP) {
               BE_Start_Level = NormalizeDouble(VWAP, digits);
            } else {
               BE_Start_Level = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) + BE_Start_Pips * P * point, digits);
            }
            BE_Level = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) + BE_SPREAD * P * point, digits);
            //DrawBreakEven(BE_Start_Level);
            if(openTime < TimeCurrent() && iLow(pair, tFrame, 1) > BE_Start_Level && iClose(pair, tFrame, 1) > BE_Start_Level) {
               double beSl = PositionGetDouble(POSITION_PRICE_OPEN);
               ZeroMemory(request);
               ZeroMemory(result);
               request.action  = TRADE_ACTION_SLTP;
               request.position = Ticket;
               request.symbol = pair;
               request.sl = beSl;
               request.tp = PositionGetDouble(POSITION_TP);
               if(!OrderSend(request, result)) {
                  PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
               }
               for(int j = 0; j < PositionsTotal(); j++) {
                  if(PositionGetTicket(j) > 0) {
                     ulong ticket = PositionGetTicket(j);
                     string comment[];
                     StringSplit(PositionGetString(POSITION_COMMENT), ',', comment);
                     if(pair == PositionGetString(POSITION_SYMBOL) && ArraySize(comment) > 2) {
                        ZeroMemory(request);
                        ZeroMemory(result);
                        request.action  = TRADE_ACTION_SLTP;
                        request.position = ticket;
                        request.symbol = pair;
                        request.sl = beSl;
                        request.tp = PositionGetDouble(POSITION_TP);
                        if(!OrderSend(request, result)) {
                           PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
                        }
                     }
                  }
               }
            }
         }
      } else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
         if(PositionGetDouble(POSITION_SL) == 0 || (PositionGetDouble(POSITION_SL) != 0 && PositionGetDouble(POSITION_SL) > PositionGetDouble(POSITION_PRICE_OPEN))) {
            if(PositionGetDouble(POSITION_PRICE_OPEN) > VWAP) {
               BE_Start_Level = NormalizeDouble(VWAP, digits);
            } else {
               BE_Start_Level = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - BE_Start_Pips * P * point, digits);
            }
            BE_Level = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - BE_SPREAD  * P * point, digits);
            //DrawBreakEven(BE_Start_Level);
            double openPrice = iOpen(pair, tFrame, 2);
            double closePrice = iClose(pair, tFrame, 2);
            if(openTime < TimeCurrent() && iHigh(pair, tFrame, 1) < BE_Start_Level && iClose(pair, tFrame, 1) < BE_Start_Level) {
               double beSl = PositionGetDouble(POSITION_PRICE_OPEN);
               ZeroMemory(request);
               ZeroMemory(result);
               request.action  = TRADE_ACTION_SLTP;
               request.position = Ticket;
               request.symbol = pair;
               request.sl = beSl;
               request.tp = PositionGetDouble(POSITION_TP);
               if(!OrderSend(request, result)) {
                  PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
               }
               for(int j = 0; j < PositionsTotal(); j++) {
                  if(PositionGetTicket(j) > 0) {
                     ulong ticket = PositionGetTicket(j);
                     string comment[];
                     StringSplit(PositionGetString(POSITION_COMMENT), ',', comment);
                     if(pair == PositionGetString(POSITION_SYMBOL) && ArraySize(comment) > 2) {
                        ZeroMemory(request);
                        ZeroMemory(result);
                        request.action  = TRADE_ACTION_SLTP;
                        request.position = ticket;
                        request.symbol = pair;
                        request.sl = beSl;
                        request.tp = PositionGetDouble(POSITION_TP);
                        if(!OrderSend(request, result)) {
                           PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//Antimartingale
//+------------------------------------------------------------------+
void openAntimartingale() {
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionGetTicket(i) > 0) {
         string counterComment[];
         int ss = StringSplit(PositionGetString(POSITION_COMMENT), ',', counterComment);
         if(ArraySize(counterComment) < 3) {
            ulong Ticket = PositionGetTicket(i);
            string pair = PositionGetString(POSITION_SYMBOL);
            double orderOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double antimartingaleStopLoss = PositionGetDouble(POSITION_SL);
            double antimartingaleTakeProfit = PositionGetDouble(POSITION_TP);
            string antimartingaleComment = PositionGetString(POSITION_COMMENT);
            int antimartingalePips;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               antimartingalePips = priceToPips(antimartingaleTakeProfit - orderOpenPrice, pair) / 2;
               double antimartingalePrice = orderOpenPrice + pipsToPrice(antimartingalePips, pair);
               int symbolCount = 0;
               for(int j = 0; j < OrdersTotal(); j++) {
                  if(OrderGetTicket(j) > 0) {
                     string orderSymbol = OrderGetString(ORDER_SYMBOL);
                     string count[];
                     StringSplit(OrderGetString(ORDER_COMMENT), ',', count);
                     if(orderSymbol == pair && ArraySize(count) > 2) {
                        symbolCount += 1;
                        break;
                     }
                  }
               }
               for(int j = 0; j < PositionsTotal(); j++) {
                  if(PositionGetTicket(j) > 0) {
                     string orderSymbol = PositionGetString(POSITION_SYMBOL);
                     string resultComment[];
                     StringSplit(PositionGetString(POSITION_COMMENT), ',', resultComment);
                     if(orderSymbol == pair && ArraySize(resultComment) > 2) {
                        symbolCount += 1;
                        break;
                     }
                  }
               }
               if(symbolCount == 0) {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  ZeroMemory(request);
                  ZeroMemory(result);
                  request.action = TRADE_ACTION_PENDING;
                  request.symbol = pair;
                  antimartingalePips = priceToPips(antimartingalePrice - antimartingaleStopLoss, pair);
                  request.volume = calculateLotSize(antimartingalePips, pair);
                  request.magic  = MagicNumber;
                  request.comment = antimartingaleComment + ", TopUp";
                  request.price = antimartingalePrice;
                  request.type = ORDER_TYPE_BUY_STOP;
                  request.sl = antimartingaleStopLoss;
                  request.tp = antimartingaleTakeProfit;
                  if(!OrderSend(request, result)) {
                     PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
                  }
               }
            }
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               antimartingalePips = priceToPips(orderOpenPrice - antimartingaleTakeProfit, pair) / 2;
               double antimartingalePrice = orderOpenPrice - pipsToPrice(antimartingalePips, pair);
               int symbolCount = 0;
               for(int j = 0; j < OrdersTotal(); j++) {
                  if(OrderGetTicket(j) > 0) {
                     string orderSymbol = OrderGetString(ORDER_SYMBOL);
                     string count[];
                     StringSplit(OrderGetString(ORDER_COMMENT), ',', count);
                     if(orderSymbol == pair && ArraySize(count) > 2) {
                        symbolCount += 1;
                        break;
                     }
                  }
               }
               for(int j = 0; j < PositionsTotal(); j++) {
                  if(PositionGetTicket(j) > 0) {
                     string orderSymbol = PositionGetString(POSITION_SYMBOL);
                     string resultComment[];
                     StringSplit(PositionGetString(POSITION_COMMENT), ',', resultComment);
                     if(orderSymbol == pair && ArraySize(resultComment) > 2) {
                        symbolCount += 1;
                        break;
                     }
                  }
               }
               if(symbolCount == 0) {
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  ZeroMemory(request);
                  ZeroMemory(result);
                  request.action = TRADE_ACTION_PENDING;
                  request.symbol = pair;
                  antimartingalePips = priceToPips(antimartingaleStopLoss - antimartingalePrice, pair);
                  request.volume = calculateLotSize(antimartingalePips, pair);
                  request.magic  = MagicNumber;
                  request.comment = antimartingaleComment + ", TopUp";
                  request.price = antimartingalePrice;
                  request.type = ORDER_TYPE_SELL_STOP;
                  request.sl = antimartingaleStopLoss;
                  request.tp = antimartingaleTakeProfit;
                  if(!OrderSend(request, result)) {
                     PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
void closeAntimartingale() {
   for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderGetTicket(i) > 0) {
         ulong Ticket = OrderGetTicket(i);
         string pair = OrderGetString(ORDER_SYMBOL);
         string countComment[];
         int ss = StringSplit(OrderGetString(ORDER_COMMENT), ',', countComment);
         if(ArraySize(countComment) > 2) {
            int symbolCount = 0;
            for(int j = 0; j < PositionsTotal(); j++) {
               if(PositionGetTicket(j) > 0) {
                  if(PositionGetString(POSITION_SYMBOL) == pair) {
                     symbolCount += 1;
                     break;
                  }
               }
            }
            if(symbolCount == 0) {
               ulong orderTicket = 0;
               for(int j = 0; j < OrdersTotal(); j++) {
                  if(OrderGetTicket(j) > 0) {
                     string orderSymbol = OrderGetString(ORDER_SYMBOL);
                     if(orderSymbol == pair) {
                        orderTicket = OrderGetTicket(j);
                        MqlTradeRequest request = {};
                        MqlTradeResult  result = {};
                        ZeroMemory(request);
                        ZeroMemory(result);
                        request.action = TRADE_ACTION_REMOVE;
                        request.order = orderTicket;
                        if(!OrderSend(request, result)) {
                           PrintFormat("OrderSend error %d", GetLastError()); // if unable to send the request, output the error code
                        }
                        break;
                     }
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int DayOfWeek() {
   MqlDateTime STime;
   datetime time_current = TimeCurrent();
   datetime time_local = TimeLocal();
   TimeToStruct(time_current, STime);
   return STime.day_of_week;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//Jason Library
//+------------------------------------------------------------------+
//------------------------------------------------------------------ enum enJAType
enum enJAType { jtUNDEF, jtNULL, jtBOOL, jtINT, jtDBL, jtSTR, jtARRAY, jtOBJ };
//------------------------------------------------------------------ class CJAVal
class CJAVal {
public:
   virtual void      Clear(enJAType jt = jtUNDEF, bool savekey = false) {
      m_parent = NULL;
      if (!savekey) m_key = "";
      m_type = jt;
      m_bv = false;
      m_iv = 0;
      m_dv = 0;
      m_prec = 8;
      m_sv = "";
      ArrayResize(m_e, 0, 100);
   }
   virtual bool      Copy(const CJAVal &a) {
      m_key = a.m_key;
      CopyData(a);
      return true;
   }
   virtual void      CopyData(const CJAVal& a) {
      m_type = a.m_type;
      m_bv = a.m_bv;
      m_iv = a.m_iv;
      m_dv = a.m_dv;
      m_prec = a.m_prec;
      m_sv = a.m_sv;
      CopyArr(a);
   }
   virtual void      CopyArr(const CJAVal& a) {
      int n = ArrayResize(m_e, ArraySize(a.m_e));
      for (int i = 0; i < n; i++) {
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
   CJAVal(CJAVal* aparent, enJAType atype) {
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
      if (aprec > -100) m_prec = aprec;
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
   CJAVal(const CJAVal& a) {
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
   virtual CJAVal*   FindKey(string akey) {
      for (int i = Size() - 1; i >= 0; --i) if (m_e[i].m_key == akey) return GetPointer(m_e[i]);
      return NULL;
   }
   virtual CJAVal*   HasKey(string akey, enJAType atype = jtUNDEF) {
      CJAVal* e = FindKey(akey);
      if (CheckPointer(e) != POINTER_INVALID) {
         if (atype == jtUNDEF || atype == e.m_type) return GetPointer(e);
      }
      return NULL;
   }
   virtual CJAVal*   operator[](string akey);
   virtual CJAVal*   operator[](int i);
   void              operator=(const CJAVal &a) {
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
      switch (m_type) {
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
      if (slen == 0) return "";
      char cc[];
      ArrayCopy(cc, js, 0, i, slen);
      return CharArrayToString(cc, 0, WHOLE_ARRAY, CJAVal::code_page);
   }

   virtual void      Set(const CJAVal& a) {
      if (m_type == jtUNDEF) m_type = jtOBJ;
      CopyData(a);
   }
   virtual void      Set(const CJAVal& list[]);
   virtual CJAVal*   Add(const CJAVal& item) {
      if (m_type == jtUNDEF) m_type = jtARRAY; /*ASSERT(m_type==jtOBJ || m_type==jtARRAY);*/ return AddBase(item);   // добавление
   }
   virtual CJAVal*   Add(const int a) {
      CJAVal item(a);
      return Add(item);
   }
   virtual CJAVal*   Add(const long a) {
      CJAVal item(a);
      return Add(item);
   }
   virtual CJAVal*   Add(const double a, int aprec = -2) {
      CJAVal item(a, aprec);
      return Add(item);
   }
   virtual CJAVal*   Add(const bool a) {
      CJAVal item(a);
      return Add(item);
   }
   virtual CJAVal*   Add(string a) {
      CJAVal item(jtSTR, a);
      return Add(item);
   }
   virtual CJAVal*   AddBase(const CJAVal &item) {
      int c = Size();   // добавление
      ArrayResize(m_e, c + 1, 100);
      m_e[c] = item;
      m_e[c].m_parent = GetPointer(this);
      return GetPointer(m_e[c]);
   }
   virtual CJAVal*   New() {
      if (m_type == jtUNDEF) m_type = jtARRAY; /*ASSERT(m_type==jtOBJ || m_type==jtARRAY);*/ return NewBase();   // добавление
   }
   virtual CJAVal*   NewBase() {
      int c = Size();   // добавление
      ArrayResize(m_e, c + 1, 100);
      return GetPointer(m_e[c]);
   }

   virtual string    Escape(string a);
   virtual string    Unescape(string a);
public:
   virtual void      Serialize(string &js, bool bf = false, bool bcoma = false);
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
CJAVal* CJAVal::operator[](string akey) {
   if (m_type == jtUNDEF) m_type = jtOBJ;
   CJAVal* v = FindKey(akey);
   if (v) return v;
   CJAVal b(GetPointer(this), jtUNDEF);
   b.m_key = akey;
   v = Add(b);
   return v;
}
//------------------------------------------------------------------ operator[]
CJAVal* CJAVal::operator[](int i) {
   if (m_type == jtUNDEF) m_type = jtARRAY;
   while (i >= Size()) {
      CJAVal b(GetPointer(this), jtUNDEF);
      if (CheckPointer(Add(b)) == POINTER_INVALID) return NULL;
   }
   return GetPointer(m_e[i]);
}
//------------------------------------------------------------------ Set
void CJAVal::Set(const CJAVal & list[]) {
   if (m_type == jtUNDEF) m_type = jtARRAY;
   int n = ArrayResize(m_e, ArraySize(list), 100);
   for (int i = 0; i < n; ++i) {
      m_e[i] = list[i];
      m_e[i].m_parent = GetPointer(this);
   }
}
//------------------------------------------------------------------ Serialize
void CJAVal::Serialize(string & js, bool bkey/*=false*/, bool coma/*=false*/) {
   if (m_type == jtUNDEF) return;
   if (coma) js += ",";
   if (bkey) js += StringFormat("\"%s\":", m_key);
   int _n = Size();
   switch (m_type) {
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
      if (StringLen(ss) > 0) js += StringFormat("\"%s\"", ss);
      else js += "null";
   }
   break;
   case jtARRAY:
      js += "[";
      for (int i = 0; i < _n; i++) m_e[i].Serialize(js, false, i > 0);
      js += "]";
      break;
   case jtOBJ:
      js += "{";
      for (int i = 0; i < _n; i++) m_e[i].Serialize(js, true, i > 0);
      js += "}";
      break;
   }
}
//------------------------------------------------------------------ Deserialize
bool CJAVal::Deserialize(char& js[], int slen, int &i) {
   string num = "0123456789+-.eE";
   int i0 = i;
   for (; i < slen; i++) {
      char c = js[i];
      if (c == 0) break;
      switch (c) {
      case '\t':
      case '\r':
      case '\n':
      case ' ': // пропускаем из имени пробелы
         i0 = i + 1;
         break;
      case '[': { // начало массива. создаём объекты и забираем из js
         i0 = i + 1;
         if (m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // если значение уже имеет тип, то это ошибка
            return false;
         }
         m_type = jtARRAY; // задали тип значения
         i++;
         CJAVal val(GetPointer(this), jtUNDEF);
         while (val.Deserialize(js, slen, i)) {
            if (val.m_type != jtUNDEF) Add(val);
            if (val.m_type == jtINT || val.m_type == jtDBL || val.m_type == jtARRAY) i++;
            val.Clear();
            val.m_parent = GetPointer(this);
            if (js[i] == ']') break;
            i++;
            if (i >= slen) {
               Print(m_key + " " + string(__LINE__));
               return false;
            }
         }
         return js[i] == ']' || js[i] == 0;
      }
      break;
      case ']':
         if (!m_parent) return false;
         return m_parent.m_type == jtARRAY; // конец массива, текущее значение должны быть массивом
      case ':': {
         if (m_lkey == "") {
            Print(m_key + " " + string(__LINE__));
            return false;
         }
         CJAVal val(GetPointer(this), jtUNDEF);
         CJAVal *oc = Add(val); // тип объекта пока не определён
         oc.m_key = m_lkey;
         m_lkey = ""; // задали имя ключа
         i++;
         if (!oc.Deserialize(js, slen, i)) {
            Print(m_key + " " + string(__LINE__));
            return false;
         }
         break;
      }
      case ',': // разделитель значений // тип значения уже должен быть определён
         i0 = i + 1;
         if (!m_parent && m_type != jtOBJ) {
            Print(m_key + " " + string(__LINE__));
            return false;
         } else if (m_parent) {
            if (m_parent.m_type != jtARRAY && m_parent.m_type != jtOBJ) {
               Print(m_key + " " + string(__LINE__));
               return false;
            }
            if (m_parent.m_type == jtARRAY && m_type == jtUNDEF) return true;
         }
         break;
// примитивы могут быть ТОЛЬКО в массиве / либо самостоятельно
      case '{': // начало объекта. создаем объект и забираем его из js
         i0 = i + 1;
         if (m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // ошибка типа
            return false;
         }
         m_type = jtOBJ; // задали тип значения
         i++;
         if (!Deserialize(js, slen, i)) {
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
         if (m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // ошибка типа
            return false;
         }
         m_type = jtBOOL; // задали тип значения
         if (i + 3 < slen) {
            if (StringCompare(GetStr(js, i, 4), "true", false) == 0) {
               m_bv = true;
               i += 3;
               return true;
            }
         }
         if (i + 4 < slen) {
            if (StringCompare(GetStr(js, i, 5), "false", false) == 0) {
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
         if (m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // ошибка типа
            return false;
         }
         m_type = jtNULL; // задали тип значения
         if (i + 3 < slen) if (StringCompare(GetStr(js, i, 4), "null", false) == 0) {
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
         if (m_type != jtUNDEF) {
            Print(m_key + " " + string(__LINE__));   // ошибка типа
            return false;
         }
         bool dbl = false; // задали тип значения
         int is = i;
         while (js[i] != 0 && i < slen) {
            i++;
            if (StringFind(num, GetStr(js, i, 1)) < 0) break;
            if (!dbl) dbl = (js[i] == '.' || js[i] == 'e' || js[i] == 'E');
         }
         m_sv = GetStr(js, is, i - is);
         if (dbl) {
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
         if (m_type == jtOBJ) { // если тип еще неопределён и ключ не задан
            i++;
            int is = i;
            if (!ExtrStr(js, slen, i)) {
               Print(m_key + " " + string(__LINE__));   // это ключ, идём до конца строки
               return false;
            }
            m_lkey = GetStr(js, is, i - is);
         } else {
            if (m_type != jtUNDEF) {
               Print(m_key + " " + string(__LINE__));   // ошибка типа
               return false;
            }
            m_type = jtSTR; // задали тип значения
            i++;
            int is = i;
            if (!ExtrStr(js, slen, i)) {
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
   for (; js[i] != 0 && i < slen; i++) {
      char c = js[i];
      if (c == '\"') break; // конец строки
      if (c == '\\' && i + 1 < slen) {
         i++;
         c = js[i];
         switch (c) {
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
            for (int j = 0; j < 4 && i < slen && js[i] != 0; j++, i++) {
               if (!((js[i] >= '0' && js[i] <= '9') || (js[i] >= 'A' && js[i] <= 'F') || (js[i] >= 'a' && js[i] <= 'f'))) {
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
   if (ArrayResize(s, 2 * n) != 2 * n) return NULL;
   int j = 0;
   for (int i = 0; i < n; i++) {
      switch (as[i]) {
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
   if (ArrayResize(s, n) != n) return NULL;
   int j = 0, i = 0;
   while (i < n) {
      ushort c = as[i];
      if (c == '\\' && i < n - 1) {
         switch (as[i + 1]) {
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
            for (int jj = 0; jj < 4 && i < n; jj++, i++) {
               c = as[i];
               ushort h = 0;
               if (c >= '0' && c <= '9') h = c - '0';
               else if (c >= 'A' && c <= 'F') h = c - 'A' + 10;
               else if (c >= 'a' && c <= 'f') h = c - 'a' + 10;
               else break; // не hex
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

//+------------------------------------------------------------------+

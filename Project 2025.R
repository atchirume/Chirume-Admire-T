


# setting up database connection

library(RSQLite)
library(DBI)

# Setting path and creating the database

db_path <- "/Users/USER/Projects 2025/Project_2025_Smart_DB.sqlite"
conn <- dbConnect(RSQLite::SQLite(), dbname = db_path)

# Defining schemas

# Monetary and Financial Sector Statistics


# Daily Lending and Deposit Rates
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS DailyBankRates (
    date DATE,
    bank_name TEXT,
    lending_rate REAL,
    deposit_rate REAL,
    PRIMARY KEY(date, bank_name)
);
")

# Weekly Balances
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS WeeklyBalances (
    week_start DATE,
    bank_name TEXT,
    deposit_tenure TEXT,
    deposit_balance REAL,
    loan_balance REAL,
    nfa REAL,
    PRIMARY KEY(week_start, bank_name, deposit_tenure)
);
")

# Monthly, Quarterly, Annual Balances
for (freq in c("Monthly", "Quarterly", "Annual")) {
  dbExecute(conn, sprintf("
    CREATE TABLE IF NOT EXISTS %sBankBalances (
        period_start DATE,
        bank_name TEXT,
        deposit_balance REAL,
        loan_balance REAL,
        nfa REAL,
        PRIMARY KEY(period_start, bank_name)
    );", freq))
}

# Generating Synthetic Data and Populate Tables

set.seed(2025)


# Defining bank names in Zimbabwe
banks <- c(
  "AFC Commercial Bank Ltd",
  "African Banking Corporation Zimbabwe Ltd (BancABC)",
  "CBZ Bank Ltd",
  "Ecobank Zimbabwe Ltd",
  "FBC Bank Ltd",
  "First Capital Bank Zimbabwe Ltd",
  "Metbank Ltd",
  "Nedbank Zimbabwe Ltd",
  "NMB Bank Ltd",
  "Stanbic Bank Zimbabwe Ltd",
  "Standard Chartered Bank Zimbabwe Ltd",
  "Steward Bank Ltd",
  "ZB Bank Ltd (Zimbank)",
  "AFC Land & Development Bank of Zimbabwe Ltd"
)


# Dates
daily_dates <- seq(as.Date("2000-01-01"), as.Date("2025-12-31"), by = "day")
weekly_dates <- seq(as.Date("2000-01-03"), as.Date("2025-12-29"), by = "week")
monthly_dates <- seq(as.Date("2000-01-01"), as.Date("2025-12-01"), by = "month")

# ---- Daily Bank Rates ----
library(dplyr)
daily_bank_rates <- expand.grid(date = daily_dates, bank_name = banks) %>%
  mutate(
    lending_rate = round(runif(n(), 15, 60), 2),
    deposit_rate = round(runif(n(), 1, 20), 2)
  )

dbWriteTable(conn, "daily_bank_rates", daily_bank_rates, append = TRUE, row.names = FALSE)

# ---- Weekly Balances ----
weekly_balances <- expand.grid(week_start = weekly_dates, bank_name = banks) %>%
  mutate(
    deposit_short_term = round(runif(n(), 10e6, 100e6), 2),
    deposit_long_term = round(runif(n(), 5e6, 50e6), 2),
    loan_balance = round(runif(n(), 20e6, 200e6), 2),
    net_foreign_assets = round(runif(n(), -50e6, 100e6), 2)
  )

dbWriteTable(conn, "weekly_balances", weekly_balances, append = TRUE, row.names = FALSE)

# ---- Monthly Balances ----
monthly_balances <- expand.grid(month_start = monthly_dates, bank_name = banks) %>%
  mutate(
    total_deposits = round(runif(n(), 100e6, 1e9), 2),
    total_loans = round(runif(n(), 50e6, 800e6), 2),
    net_foreign_assets = round(runif(n(), -100e6, 200e6), 2)
  )

dbWriteTable(conn , "monthly_balances", monthly_balances, append = TRUE, row.names = FALSE)

dbListTables(conn)
dbReadTable(conn, "daily_bank_rates") %>% head()
dbReadTable(conn, "weekly_balances") %>% head()

dbDisconnect(conn)


#######################

# Reconnecting before defining the schemas
conn <- dbConnect(SQLite(), db_path)


# External Account Statistics

# Daily Exchange Rates and Commodity Prices
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS DailyExternalData (
    date DATE,
    currency TEXT,
    rate_to_usd REAL,
    gold_price REAL,
    platinum_price REAL,
    tobacco_price REAL,
    chrome_price REAL,
    copper_price REAL,
    crude_oil_price REAL,
    PRIMARY KEY(date, currency)
);
")

# Imports/Exports (Monthly, Quarterly, Annual)
for (freq in c("Monthly", "Quarterly", "Annual")) {
  dbExecute(conn, sprintf("
    CREATE TABLE IF NOT EXISTS %sTradeData (
        period_start DATE,
        category TEXT,
        subcategory TEXT,
        export_value REAL,
        import_value REAL,
        PRIMARY KEY(period_start, category, subcategory)
    );", freq))
}

# Balance of Payments: Primary, Secondary, Financial Account
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS BalanceOfPayments (
    period_start DATE,
    frequency TEXT,
    category TEXT,
    subcategory TEXT,
    value REAL,
    PRIMARY KEY(period_start, frequency, category, subcategory)
);
")

# Simulating data


library(DBI)
library(RSQLite)
library(lubridate)
set.seed(123)


# Connecting to the DB
conn <- dbConnect(RSQLite::SQLite(), "/Users/USER/Projects 2025/Project_2025_Smart_DB.sqlite")

# ---- Simulating Daily External Data ----

# Dates daily from 2000-01-01 to 2025-12-31
daily_dates <- seq.Date(from = as.Date("2000-01-01"), to = as.Date("2025-12-31"), by = "day")
currencies <- c("ZWL", "ZAR", "USD", "EUR", "GBP")  # example main trading partners' currencies

# Creating combinations of dates and currencies
daily_ext_data <- expand.grid(date = daily_dates, currency = currencies)

# Simulating exchange rates (to USD), commodity prices (in US$)
daily_ext_data$rate_to_usd <- runif(nrow(daily_ext_data), 0.001, 1.5)  # exchange rates
daily_ext_data$gold_price <- round(rnorm(nrow(daily_ext_data), mean=1500, sd=200), 2)
daily_ext_data$platinum_price <- round(rnorm(nrow(daily_ext_data), mean=1000, sd=150), 2)
daily_ext_data$tobacco_price <- round(runif(nrow(daily_ext_data), 100, 300), 2)
daily_ext_data$chrome_price <- round(runif(nrow(daily_ext_data), 150, 350), 2)
daily_ext_data$copper_price <- round(rnorm(nrow(daily_ext_data), mean=6000, sd=1000), 2)
daily_ext_data$crude_oil_price <- round(rnorm(nrow(daily_ext_data), mean=60, sd=20), 2)

# Inserting into DB in batches to avoid memory issues
batch_size <- 10000
for (i in seq(1, nrow(daily_ext_data), by = batch_size)) {
  batch <- daily_ext_data[i:min(i+batch_size-1, nrow(daily_ext_data)), ]
  dbWriteTable(conn, "DailyExternalData", batch, append=TRUE, row.names=FALSE)
}

# ---- Simulating Monthly Trade Data, Quarterly Trade Data, Annual Trade Data ----
periods <- list(
  Monthly = seq.Date(as.Date("2000-01-01"), as.Date("2025-12-01"), by = "month"),
  Quarterly = seq.Date(as.Date("2000-01-01"), as.Date("2025-10-01"), by = "quarter"),
  Annual = seq.Date(as.Date("2000-01-01"), as.Date("2025-01-01"), by = "year")
)

categories <- c("Agricultural products", "Minerals and ores", "Energy resources",
                "Forestry products", "Fish and marine products", "Consumer goods",
                "Capital goods", "Intermediate goods", "Industrial supplies",
                "Electronics and IT products", "Aerospace", "Pharmaceuticals and medical devices",
                "Scientific instruments", "Financial services", "Tourism and travel",
                "IT and software services", "Transport and logistics", "Education services",
                "Jewelry and precious metals", "Fashion and designer goods", "Art and antiques",
                "Alcoholic beverages")


subcategory <- "General"

for(freq in names(periods)) {
  period_start <- periods[[freq]]
  rows <- expand.grid(period_start = period_start, category = categories, subcategory = subcategory)
  rows$export_value <- round(runif(nrow(rows), 10000, 1000000), 2)
  rows$import_value <- round(runif(nrow(rows), 5000, 500000), 2)
  
  dbWriteTable(conn, paste0(freq, "TradeData"), rows, append = TRUE, row.names = FALSE)
}

# ---- Simulating Balance Of Payments ----
bop_freqs <- c("Monthly", "Quarterly", "Annual")
bop_categories <- c("Primary income", "Secondary income", "Financial account")
bop_subcategories <- c(
  "Compensation of Employees", "Direct investment income", "Portfolio investment income",
  "Other investment income", "Reserve asset income", "Remittances", "Current Transfers of Government",
  "Foreign aid", "Contributions to international organizations", "Other Current Transfers",
  "Direct Investment", "Portfolio Investment", "Other Investment", "Reserve Assets"
)

for(freq in bop_freqs) {
  period_start <- periods[[freq]]
  rows <- expand.grid(period_start = period_start, frequency = freq, category = bop_categories, subcategory = bop_subcategories)
  
  # Filtering subcategories by category (In accordance to BPM6)
  rows <- subset(rows, 
                 (category == "Primary income" & subcategory %in% c("Compensation of Employees", "Direct investment income", "Portfolio investment income", "Other investment income", "Reserve asset income")) |
                   (category == "Secondary income" & subcategory %in% c("Remittances", "Current Transfers of Government", "Foreign aid", "Contributions to international organizations", "Other Current Transfers")) |
                   (category == "Financial account" & subcategory %in% c("Direct Investment", "Portfolio Investment", "Other Investment", "Reserve Assets"))
  )
  
  rows$value <- round(runif(nrow(rows), 1e6, 1e9), 2)
  
  dbWriteTable(conn, "Balance Of Payments", rows, append = TRUE, row.names = FALSE)
}

dbDisconnect(conn)
##############################

# Reconnecting 
conn <- dbConnect(SQLite(), db_path)

# Domestic Production and Inflation Statistics

# Inflation
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS InflationStats (
    period_start DATE,
    frequency TEXT,
    currency TEXT,
    inflation_type TEXT,
    value REAL,
    PRIMARY KEY(period_start, frequency, currency, inflation_type)
);
")

# GDP by Sector
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS GDPStats (
    period_start DATE,
    frequency TEXT,
    sector TEXT,
    sub_sector TEXT,
    value REAL,
    PRIMARY KEY(period_start, frequency, sector, sub_sector)
);
")

# Simulating the data

library(DBI)
library(RSQLite)
library(lubridate)
set.seed(456)

# Connect to DB
conn <- dbConnect(RSQLite::SQLite(), "/Users/USER/Projects 2025/Project_2025_Smart_DB.sqlite")

# Frequencies and periods
freqs <- c("Monthly", "Quarterly", "Annual")
periods <- list(
  Monthly = seq.Date(as.Date("2000-01-01"), as.Date("2025-12-01"), by = "month"),
  Quarterly = seq.Date(as.Date("2000-01-01"), as.Date("2025-10-01"), by = "quarter"),
  Annual = seq.Date(as.Date("2000-01-01"), as.Date("2025-01-01"), by = "year")
)

# ---- Simulating Inflation Stats ----

currencies <- c("USD", "ZWL")  # US$ inflation and ZiG inflation
inflation_types <- c("Food", "Non-food")

inflation_data <- data.frame()

for(freq in freqs) {
  for(curr in currencies) {
    for(inf_type in inflation_types) {
      df <- expand.grid(
        period_start = periods[[freq]],
        frequency = freq,
        currency = curr,
        inflation_type = inf_type
      )
      # Simulating inflation values (percent change)
      base_mean <- ifelse(curr == "USD", 2, 10) # ZiG inflation higher on avg
      base_sd <- ifelse(inf_type == "Food", 2, 1)
      df$value <- round(rnorm(nrow(df), mean = base_mean, sd = base_sd), 2)
      df$value[df$value < 0] <- 0  # No negative inflation for simplicity
      
      inflation_data <- rbind(inflation_data, df)
    }
  }
}

dbWriteTable(conn, "InflationStats", inflation_data, append = TRUE, row.names = FALSE)


# ---- Simulating GDPStats ----

# Sectors and sub-sectors
sectors <- list(
  Primary = c("Agriculture", "Forestry", "Fishing"),
  Secondary = c("Manufacturing", "Electricity", "WaterSupply", "Construction"),
  Tertiary = c("WholesaleRetail", "Transportation", "Accommodation", "InformationCommunication",
               "FinancialInsurance", "RealEstate", "ProfessionalServices", "PublicAdministration",
               "Education", "HealthSocialWork", "OtherServices")
)


primary_sub_subsectors <- c(
  "Maize", "Tobacco", "Cotton", "Sugarcane", "Livestock", "Horticulture",
  "FishingAquaculture", "ForestryLogging"
)

# For Secondary, some sample sub-subsectors:
secondary_sub_subsectors <- c(
  "FoodBeverages", "TextilesClothing", "ChemicalsFertilizers", "CementSteel", "TobaccoProcessing"
)

# For Tertiary, we keep sub_sector level only for simplicity here.

gdp_data <- data.frame()

for(freq in freqs) {
  for(sector in names(sectors)) {
    if(sector == "Primary") {
      for(sub_sector in primary_sub_subsectors) {
        df <- data.frame(
          period_start = periods[[freq]],
          frequency = freq,
          sector = sector,
          sub_sector = sub_sector,
          value = round(runif(length(periods[[freq]]), 50, 500), 2) # Simulated GDP contribution in millions
        )
        gdp_data <- rbind(gdp_data, df)
      }
    } else if(sector == "Secondary") {
      for(sub_sector in secondary_sub_subsectors) {
        df <- data.frame(
          period_start = periods[[freq]],
          frequency = freq,
          sector = sector,
          sub_sector = sub_sector,
          value = round(runif(length(periods[[freq]]), 30, 400), 2)
        )
        gdp_data <- rbind(gdp_data, df)
      }
    } else {
      # Tertiary: Use sectors list sub-sectors directly
      for(sub_sector in sectors[[sector]]) {
        df <- data.frame(
          period_start = periods[[freq]],
          frequency = freq,
          sector = sector,
          sub_sector = sub_sector,
          value = round(runif(length(periods[[freq]]), 40, 600), 2)
        )
        gdp_data <- rbind(gdp_data, df)
      }
    }
  }
}

dbWriteTable(conn, "GDPStats", gdp_data, append = TRUE, row.names = FALSE)

dbDisconnect(conn)
##############################



# Reconnecting 
conn <- dbConnect(SQLite(), db_path)


# Fiscal Account Statistics

dbExecute(conn, "
CREATE TABLE IF NOT EXISTS FiscalStats (
    period_start DATE,
    frequency TEXT,
    tax_type TEXT,
    sub_type TEXT,
    amount REAL,
    PRIMARY KEY(period_start, frequency, tax_type, sub_type)
);
")

# Capital Market Statistics

# Market Size & Structure
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS MarketStructure (
    period_start DATE,
    frequency TEXT,
    market_cap REAL,
    num_listed_companies INTEGER,
    bond_market_size REAL,
    equity_outstanding REAL,
    debt_outstanding REAL,
    PRIMARY KEY(period_start, frequency)
);
")

# Activity & Liquidity
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS MarketActivity (
    period_start DATE,
    frequency TEXT,
    shares_traded_value REAL,
    shares_traded_volume INTEGER,
    turnover_ratio REAL,
    bond_turnover_value REAL,
    bond_turnover_volume INTEGER,
    transactions_count INTEGER,
    PRIMARY KEY(period_start, frequency)
);
")

# Indices & Performance
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS MarketIndices (
    period_start DATE,
    frequency TEXT,
    index_name TEXT,
    index_value REAL,
    bond_yield REAL,
    dividend_yield REAL,
    pe_ratio REAL,
    PRIMARY KEY(period_start, frequency, index_name)
);
")

# Capital Raising
dbExecute(conn, "
CREATE TABLE IF NOT EXISTS CapitalRaising (
    period_start DATE,
    frequency TEXT,
    ipo_count INTEGER,
    ipo_value REAL,
    rights_issues_value REAL,
    corp_bond_issuance REAL,
    govt_bond_issuance REAL,
    private_placements REAL,
    PRIMARY KEY(period_start, frequency)
);
")

dbDisconnect(conn)

#### Simulating the data

library(DBI)
library(RSQLite)
library(lubridate)
set.seed(789)

# Connecting to DB
conn <- dbConnect(RSQLite::SQLite(), "/Users/USER/Projects 2025/Project_2025_Smart_DB.sqlite")

freqs <- c("Monthly", "Quarterly", "Annual")
periods <- list(
  Monthly = seq.Date(as.Date("2000-01-01"), as.Date("2025-12-01"), by = "month"),
  Quarterly = seq.Date(as.Date("2000-01-01"), as.Date("2025-10-01"), by = "quarter"),
  Annual = seq.Date(as.Date("2000-01-01"), as.Date("2025-01-01"), by = "year")
)

# --- Fiscal Account Statistics ---

tax_types <- c("Direct", "Indirect", "Trade", "Other")
sub_types <- list(
  Direct = c("PIT", "CIT", "Presumptive", "CGT", "Withholding"),
  Indirect = c("VAT", "ExciseDuties", "CustomsSurtax", "CarbonTax"),
  Trade = c("CustomsDuties", "ImportVAT", "ExportDuties"),
  Other = c("IMTT", "StampDuties", "MiningRoyalties", "LicensingFees")
)

fiscal_data <- data.frame()

for(freq in freqs) {
  for(tax_type in tax_types) {
    for(sub_type in sub_types[[tax_type]]) {
      df <- data.frame(
        period_start = periods[[freq]],
        frequency = freq,
        tax_type = tax_type,
        sub_type = sub_type,
        amount = round(runif(length(periods[[freq]]), 10e6, 500e6), 2) # Amounts in Zimbabwe dollars or USD equivalent
      )
      fiscal_data <- rbind(fiscal_data, df)
    }
  }
}

dbWriteTable(conn, "FiscalStats", fiscal_data, append = TRUE, row.names = FALSE)

# --- Capital Market Statistics ---

# MarketStructure
market_structure <- data.frame()

for(freq in freqs) {
  df <- data.frame(
    period_start = periods[[freq]],
    frequency = freq,
    market_cap = round(runif(length(periods[[freq]]), 1e9, 5e9), 2),
    num_listed_companies = sample(50:150, length(periods[[freq]]), replace = TRUE),
    bond_market_size = round(runif(length(periods[[freq]]), 2e8, 1e9), 2),
    equity_outstanding = round(runif(length(periods[[freq]]), 5e8, 3e9), 2),
    debt_outstanding = round(runif(length(periods[[freq]]), 3e8, 1.5e9), 2)
  )
  market_structure <- rbind(market_structure, df)
}

dbWriteTable(conn, "MarketStructure", market_structure, append = TRUE, row.names = FALSE)

# Market Activity
market_activity <- data.frame()

for(freq in freqs) {
  df <- data.frame(
    period_start = periods[[freq]],
    frequency = freq,
    shares_traded_value = round(runif(length(periods[[freq]]), 1e7, 5e8), 2),
    shares_traded_volume = sample(1e5:1e7, length(periods[[freq]]), replace = TRUE),
    turnover_ratio = round(runif(length(periods[[freq]]), 0.01, 0.15), 4),
    bond_turnover_value = round(runif(length(periods[[freq]]), 1e6, 1e8), 2),
    bond_turnover_volume = sample(1e4:1e6, length(periods[[freq]]), replace = TRUE),
    transactions_count = sample(500:5000, length(periods[[freq]]), replace = TRUE)
  )
  market_activity <- rbind(market_activity, df)
}

dbWriteTable(conn, "MarketActivity", market_activity, append = TRUE, row.names = FALSE)

# Market Indices
index_names <- c("ZSE_ASI", "Mining", "Banking", "Industrial")

market_indices <- data.frame()

for(freq in freqs) {
  for(idx in index_names) {
    df <- data.frame(
      period_start = periods[[freq]],
      frequency = freq,
      index_name = idx,
      index_value = round(runif(length(periods[[freq]]), 1000, 15000), 2),
      bond_yield = round(runif(length(periods[[freq]]), 5, 15), 2),
      dividend_yield = round(runif(length(periods[[freq]]), 1, 5), 2),
      pe_ratio = round(runif(length(periods[[freq]]), 5, 25), 2)
    )
    market_indices <- rbind(market_indices, df)
  }
}

dbWriteTable(conn, "MarketIndices", market_indices, append = TRUE, row.names = FALSE)

# Capital Raising
capital_raising <- data.frame()

for(freq in freqs) {
  df <- data.frame(
    period_start = periods[[freq]],
    frequency = freq,
    ipo_count = sample(0:5, length(periods[[freq]]), replace = TRUE),
    ipo_value = round(runif(length(periods[[freq]]), 0, 1e8), 2),
    rights_issues_value = round(runif(length(periods[[freq]]), 0, 5e7), 2),
    corp_bond_issuance = round(runif(length(periods[[freq]]), 0, 7e7), 2),
    govt_bond_issuance = round(runif(length(periods[[freq]]), 0, 1e8), 2),
    private_placements = round(runif(length(periods[[freq]]), 0, 3e7), 2)
  )
  capital_raising <- rbind(capital_raising, df)
}

dbWriteTable(conn, "CapitalRaising", capital_raising, append = TRUE, row.names = FALSE)

dbDisconnect(conn)
#############################


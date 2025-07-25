
library(shiny)
library(DBI)
library(RSQLite)
library(ggplot2)
library(dplyr)
library(tidyr)
library(plotly)
library(ggmosaic)

# Connecting to my database
db_path <- "/Users/USER/Projects 2025/Project_2025_Smart_DB.sqlite"

# Chart type options
chart_types <- c(
  "Bar Chart" = "bar",
  "Histogram" = "histogram",
  "Pie Chart" = "pie",
  "Boxplot" = "boxplot",
  "Line Chart" = "line",
  "Dot Chart" = "dot",
  "Scatter Plot" = "scatter",
  "Density Plot" = "density",
  "QQ Plot" = "qq",
  "Violin Plot" = "violin",
  "ECDF Plot" = "ecdf",
  "Time Series Plot" = "timeseries",
  "Autocorrelation Plot" = "acf",
  "Mosaic Plot" = "mosaic"
)

ui <- fluidPage(
  titlePanel("📊 Smart ATC Interactive Macroeconomic Database Explorer"),

  sidebarLayout(
    sidebarPanel(
      selectInput("table", "Select Table", choices = NULL),
      uiOutput("date_column_ui"),
      uiOutput("var_select_ui"),
      dateRangeInput("date_range", "Select Date Range",
                     start = Sys.Date() - 365,
                     end = Sys.Date(),
                     format = "yyyy-mm-dd"),
      selectInput("chart_type", "Select Chart Type", choices = chart_types),
      actionButton("add_plot", "➕ Add Plot"),
      hr(),
      actionButton("clear_plots", "🧹 Clear All Plots")
    ),

    mainPanel(
      uiOutput("plots_ui")
    )
  )
)

server <- function(input, output, session) {
  conn <- dbConnect(SQLite(), db_path)

  observe({
    updateSelectInput(session, "table", choices = dbListTables(conn))
  })

  columns <- reactive({
    req(input$table)
    dbListFields(conn, input$table)
  })

  output$date_column_ui <- renderUI({
    req(columns())
    date_cols <- grep("date|period|_start", columns(), value = TRUE, ignore.case = TRUE)
    selectInput("date_column", "Select Date Column", choices = date_cols)
  })

  output$var_select_ui <- renderUI({
    req(columns())
    selectInput("variables", "Select Variable(s) to Plot", choices = columns(), multiple = TRUE)
  })

  plot_list <- reactiveVal(list())

  observeEvent(input$add_plot, {
    req(input$table, input$date_column, input$variables)

    df <- dbReadTable(conn, input$table)
    df[[input$date_column]] <- as.Date(df[[input$date_column]])

    df <- df %>%
      filter(between(!!sym(input$date_column), input$date_range[1], input$date_range[2])) %>%
      select(all_of(c(input$date_column, input$variables))) %>%
      pivot_longer(-all_of(input$date_column), names_to = "Variable", values_to = "Value")

    chart <- input$chart_type
    p <- NULL

    if (chart %in% c("line", "timeseries")) {
      p <- ggplot(df, aes_string(x = input$date_column, y = "Value", color = "Variable")) + geom_line()
    } else if (chart == "bar") {
      p <- ggplot(df, aes_string(x = input$date_column, y = "Value", fill = "Variable")) + geom_col(position = "dodge")
    } else if (chart == "histogram") {
      p <- ggplot(df, aes(x = Value, fill = Variable)) + geom_histogram(alpha = 0.7, bins = 30, position = "identity")
    } else if (chart == "pie") {
      df_pie <- df %>% group_by(Variable) %>% summarise(Total = sum(Value, na.rm = TRUE))
      p <- ggplot(df_pie, aes(x = "", y = Total, fill = Variable)) +
        geom_col(width = 1) + coord_polar(theta = "y") + theme_void()
    } else if (chart == "boxplot") {
      p <- ggplot(df, aes(x = Variable, y = Value, fill = Variable)) + geom_boxplot()
    } else if (chart == "dot") {
      p <- ggplot(df, aes_string(x = input$date_column, y = "Value", color = "Variable")) +
        geom_point(position = position_jitter(width = 0.1))
    } else if (chart == "scatter") {
      if (length(input$variables) == 2) {
        df_wide <- df %>%
          pivot_wider(names_from = Variable, values_from = Value) %>%
          drop_na()
        p <- ggplot(df_wide, aes_string(x = input$variables[1], y = input$variables[2])) +
          geom_point(alpha = 0.6)
      } else {
        showNotification("Scatter plot requires exactly 2 variables.", type = "error")
        return()
      }
    } else if (chart == "density") {
      p <- ggplot(df, aes(x = Value, fill = Variable)) + geom_density(alpha = 0.5)
    } else if (chart == "qq") {
      if (length(input$variables) == 1) {
        p <- ggplot(df, aes(sample = Value)) + stat_qq() + stat_qq_line()
      } else {
        showNotification("QQ plot requires exactly 1 variable.", type = "error")
        return()
      }
    } else if (chart == "violin") {
      p <- ggplot(df, aes(x = Variable, y = Value, fill = Variable)) + geom_violin()
    } else if (chart == "ecdf") {
      p <- ggplot(df, aes(x = Value, color = Variable)) + stat_ecdf(size = 1)
    } else if (chart == "acf") {
      if (length(input$variables) == 1) {
        acf_data <- acf(df$Value, plot = FALSE)
        acf_df <- with(acf_data, data.frame(Lag = lag, ACF = acf))
        p <- ggplot(acf_df, aes(x = Lag, y = ACF)) + geom_col() +
          ggtitle(paste("ACF Plot of", input$variables))
      } else {
        showNotification("Autocorrelation plot requires exactly 1 variable.", type = "error")
        return()
      }
    } else if (chart == "mosaic") {
      if (length(input$variables) == 2) {
        df_mosaic <- df %>%
          pivot_wider(names_from = Variable, values_from = Value) %>%
          mutate(across(everything(), as.factor)) %>%
          drop_na()
        p <- ggplot(data = df_mosaic) +
          geom_mosaic(aes(weight = 1, x = product(!!sym(input$variables[1])), fill = !!sym(input$variables[2])))
      } else {
        showNotification("Mosaic plot requires exactly 2 categorical variables.", type = "error")
        return()
      }
    }

    if (!is.null(p)) {
      p <- p +
        labs(
          title = paste(names(chart_types)[chart_types == chart], "of", paste(input$variables, collapse = ", ")),
          x = ifelse(chart %in% c("scatter", "mosaic", "qq", "acf", "pie"), "", input$date_column),
          y = "Value"
        ) +
        theme_minimal()
    }

    new_plot <- renderPlotly({
      ggplotly(p)
    })

    current <- plot_list()
    plot_list(append(current, list(new_plot)))
  })

  observeEvent(input$clear_plots, {
    plot_list(list())
  })

  output$plots_ui <- renderUI({
    plots <- plot_list()
    if (length(plots) == 0) {
      h4("No plots added yet. Use the ➕ Add Plot button.")
    } else {
      plot_output_list <- lapply(seq_along(plots), function(i) {
        plotlyOutput(paste0("plot_", i))
      })

      for (i in seq_along(plots)) {
        local({
          my_i <- i
          output[[paste0("plot_", my_i)]] <- plots[[my_i]]
        })
      }

      do.call(tagList, plot_output_list)
    }
  })

  onSessionEnded(function() {
    dbDisconnect(conn)
  })
}

shinyApp(ui, server)




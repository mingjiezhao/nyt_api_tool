library(shiny)
library(jsonlite)
library(tidyverse)
library(rvest)
library(httr)
library(dplyr)
library(purrr)
###############
## Note: to make the tool work, you need to put your own API key here:
default_apikey = "YOUR API KEY"

# The query_gen function sents requests to the API
query_gen = function(date,page,apikey){
  # The output field (fl) is specified, otherwise all contents would be returned.
  fl = paste(c("web_url","pub_date","lead_paragraph","headline","snippet", "news_desk",
               "section_name","byline","source","document_type","word_count","multimedia"),collapse = ",")
  
  r_query = fromJSON(paste0("http://api.nytimes.com/svc/search/v2/articlesearch.json?fq=",
                            "document_type:article%20AND%20print_page:1" , 
                            "%20AND%20pub_date:", date,
                            "&page=", page,
                            "&api-key=",apikey,
                            "&fl=",fl),flatten = TRUE)
  return (r_query$response)
}

# Main function
nyt_search = function(year, month, day, apikey=default_apikey)
{ # Date verification
  date = try(as.Date(paste(year, month, day, sep="-"),"%Y-%m-%d"))
 
  if( class(date) == "try-error" || is.na(date) ||day>31 || nchar(day)>2 ) 
  {
    stop("Your input of year/month/day is invalid because it cannot be a valid date")
  }
  else if (year<1851 || year>2019)
  {
    stop("Your input date is out of range: data are only available between Year 1851 and 2018")
  }
  
  # Initial request: count number of pages based on meta
  n_page = try(ceiling(query_gen(date,0,apikey)$meta$hits/10),silent = TRUE)
  
  #After the date has been checked, if errors are still reported, then apikey is the problem
  if (class(n_page) == "try-error"){
    warning("Your apikey input does not function, and default apikey is used instead")
    apikey = default_apikey
    n_page = ceiling( query_gen (date, 0, apikey)$meta$hits/10)
  }
  
  # Generate the combined data frame from API requests
  result = do.call(rbind,lapply(0:(n_page-1),
                                function(x){Sys.sleep(1);query_gen(date, x, apikey)$docs}))
  
  # Clean the generated data frame
  # Only return the type, url and sizes of the first multimedia file in the article
  media = do.call(rbind,lapply(1:nrow(result),
                               function(x)(result$multimedia[[x]][1,c("type","url","height","width")])))
  colnames(media) = paste0("media.", colnames(media))
  
  result = cbind(result,media) %>%
    mutate(
      # Complete the url for media images
      media.url = paste0("https://static01.nyt.com/", media.url),
      # Remove "By "s that are in front of actual author names
      byline.original = gsub("By ","", byline.original)) %>%  
    # Remove redundant variables 
    select(-c(multimedia, headline.kicker, headline.content_kicker, headline.print_headline,
              headline.name, headline.seo, headline.sub, byline.person, byline.organization)) 
  
  #Return the cleaned data frame
  return(result)
}   

# shiny app
shinyApp(
  ui = fluidPage(
    titlePanel("New York Times Articles"),
    sidebarLayout(sidebarPanel(
      fluidRow(dateInput("date", "Specify a date", value = as.Date("2018-03-25"), 
                         min = as.Date("1851-01-01"), max = Sys.Date(), format = "yyyy-mm-dd", 
                         startview = "year",weekstart = 0, language = "en"),
               checkboxInput("ifhist", "Use your API key", value = FALSE, width = NULL),
               conditionalPanel(condition = "input.ifhist == true",
                                textInput("api", h3("Enter API key"),value = "")),
               hr()),
      fluidRow(actionButton("submit", "Get Articles!"))
    ),  
    mainPanel(
      h1(paste0("Search Results"), align = "center"),
      uiOutput("links")
    ))
  ),
  server = function(input, output, session)
  { # Part 1 start by making the api call based on the function above
    # this updates at every press of the submit button
    webtable = eventReactive(input$submit,{
      
      iyear = as.numeric(substring(input$date, 1, 4))
      imon  = as.numeric(substring(input$date, 6, 7))
      iday  = as.numeric(substring(input$date, 9, 10))
      
      if(input$ifhist){
        apikeyi = substring(paste0('"',input$api), 2, nchar(paste0('"',input$api)))
      } else{
        apikeyi = default_apikey
      }
      
      webtable = suppressWarnings(nyt_search(iyear, imon, iday, apikey = apikeyi))
      return(webtable)
    }) 
    
    op_date = eventReactive(input$submit,{
      op_date = as.character(input$date)
      return(op_date)
    })
    
    # Part 2: make the output based on user's specification
    # this updates based on new api output, which follows a press of "Get Articles"
    web_url = eventReactive(webtable(),{
      web_url = list(webtable()$web_url)
      return(web_url)
    })
    
    titlei = eventReactive(webtable(),{
      titlei = list(webtable()$headline.main)
      return(titlei)
    })
    
    head_para = eventReactive(webtable(),{
      head_para = list(webtable()$snippet)
      return(head_para)
    })
    
    media = eventReactive(webtable(),{
      media = list(webtable()$media.url)
      return(media)
    })
    
    # Part 3: return search results and create pop-up windows for the links 
    observeEvent(input$submit, {
      ui_elems = map(
        seq_len(nrow(webtable())), 
        function(i) fluidRow(actionLink(paste0("link",i), paste0(i,": ",titlei()[[1]][i],".")))
      )
      
      output$links = renderUI(
        fluidPage(
          renderText({ paste("Article list for", op_date() )}),
          hr(),
          ui_elems))
      
      web_url = map(
        seq_len(nrow(webtable())),
        function(i) {
          label = paste0("link",i)
          factor = max(webtable()$media.height/500,webtable()$media.width/500)
          hei = (webtable()$media.height/factor)[i]
          wid = (webtable()$media.width/factor)[i]
          
          observeEvent(
            input[[label]],
            {showModal(modalDialog(
              title = titlei()[[1]][i],
              HTML( paste0("<img src='",media()[[1]][i],
                           "' width='",wid,"' height='",hei,"' align='middle'>") ),
              HTML( paste0("<br><font size='+1'>Head Paragraph </font><br>",
                           head_para()[[1]][i]) ),
              HTML( paste0("<br><a href='",web_url()[[1]][i],
                           "'><font size='+1'>Link </font><br>",web_url()[[1]][i]) ),
              easyClose = TRUE,
              footer = NULL
            ))
            },
            ignoreInit = TRUE) 
        }) 
    }) 
  })
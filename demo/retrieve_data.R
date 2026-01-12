# CURL request
# curl -X 'GET' \ 'https://api.cat-apps.com/visualizer/v1/retrieve_data/?geoid=36109&pollutant=98&year=2020&aggregation=16&var=emissions&covvar=pop' \ -H 'accept: text/csv'

# Translate that into R

# Let's write an R function for querying the API.
#' @param geoid 5-digit county geoid/FIPS code
#' @param pollutant EPA pollutant code. Defaults to 98, CO2 Equivalent emissions.
#' @param year vector of years, as integer
#' @param var vector of variables to extract from CAT granddata database. Frequent options include "emissions", "vehicles", "vmt", "sourcehours"
#' @param covvar vector of variables to extract from CAT census covariate database. Frequent options include "pop", "pop_black", "pop_hisplat", "pop_asian", "pop_white", etc.
#' @note Options for `covvar` include: pop, pop_women, pop_age_65_plus, pop_white, pop_black, pop_natam, pop_asian, pop_pacific, pop_hisplat, median_income, median_monthly_housing_cost
retrieve_data = function(geoid = "36109", year = 2020, var = c("emissions"), covvar = c("pop"),
                         pollutant = 98, aggregation = 16){

  # testing data
  # geoid = "36109"; year = c(2020,2050); pollutant = 98; aggregation =16; var = "emissions"; covvar = c("pop", "pop_black", "pop_asian", "pop_hisplat", "pop_white")

  # Pause for a moment, so we don't overwhelm the API
  Sys.sleep(1)
  # Build the API query URL
  base = "https://api.cat-apps.com"
  endpoint = "/visualizer/v1/retrieve_data/"
  query = paste0(
    "?geoid=", geoid, "&pollutant=", pollutant,
    "&aggregation=", aggregation,
    paste0("&year=", year, collapse = ""),
    paste0("&var=", var, collapse = ""),
    paste0("&covvar=", covvar, collapse = "")
  )

  url = paste0(base, endpoint, query)

  headers = httr::add_headers(
    "Content-Type" = "text/csv"
  )

  result = httr::GET(url = url, headers)

  if(result$status_code != 200){ return(NULL)  }

  output = result %>%
    with(content) %>%
    rawToChar() %>%
    readr::read_csv(show_col_types = FALSE)

  return(output)
}

# functions.R

# A script of functions for equity index calculator.
# Can be loaded akin to a package, by running
# source("functions.R")


#' @name retrieve_census
#' @title Retrieve Census Data
#' @description
#' Function to retrieve census data for all census tracts / geographies for one state in a given year.
#' @param state_fips:str a state FIPS code (eg. for New York, `"36"`)
#' @param year:int year of ACS-5 census data to return. For example, 2022 returns the 5-year average of 2020, 2021, 2022, 2023, and 2024.
#' @param region:str code to pass to `censusapi` to tell what type of geography to return. Eg. `"tract:*"` returns every census tract.
#' @param key:str census API key. By default, passed as environmental variable `CENSUS_API_KEY`. Can skip if already loaded as environmental variable.
#' @export
retrieve_census = function(state_fips, year, region = "tract:*", key = Sys.getenv("CENSUS_API_KEY")){
  library(dplyr, warn.conflicts = FALSE, quietly = TRUE)
  library(tidyr, warn.conflicts = FALSE, quietly = TRUE)
  library(readr, warn.conflicts = FALSE, quietly = TRUE)
  library(stringr, warn.conflicts = FALSE, quietly = TRUE)
  library(censusapi, warn.conflicts = FALSE, quietly = TRUE)
  # readRenviron(".env")
  # Sys.getenv("CENSUS_API_KEY")
  
  # censusapi::listCensusMetadata(name = "acs/acs5", vintage = year, type = "variables") %>% 
  #   saveRDS("demo/acs5metadata.rds")
  
  # meta = read_rds("demo/acs5metadata.rds")
  # meta %>% glimpse()
  # 
  # meta %>% filter(str_detect(concept, "Black"))
  
  myvars <- list(
    # 2020 ACS5 variables
    "GEO_ID" = "geoid",
    "B01003_001E" = "pop", # Total Population
    # Race
    "B02001_001E" = "pop_race",
    "B02001_002E" = "white",
    "B02001_003E" = "black",
    "B02001_004E" = "natam",
    "B02001_005E" = "asian",
    "B02001_006E" = "pacific",
    # Ethnicity
    "B03003_001E" = "pop_ethnicity",
    "B03003_003E" = "hispanic",
    # Age
    "B01001_020E" = "pop_age_65_66_male",
    "B01001_021E" = "pop_age_67_69_male",
    "B01001_022E" = "pop_age_70_74_male",
    "B01001_023E" = "pop_age_75_79_male",
    "B01001_024E" = "pop_age_80_84_male",
    "B01001_025E" = "pop_age_85_over_male",
    
    "B01001_044E" = "pop_age_65_66_female",
    "B01001_045E" = "pop_age_67_69_female",
    "B01001_046E" = "pop_age_70_74_female",
    "B01001_047E" = "pop_age_75_79_female",
    "B01001_048E" = "pop_age_80_84_female",
    "B01001_049E" = "pop_age_85_over_female",
    
    "B01001_026E" = "pop_women", # Gender
    
    #"EDUCATIONAL ATTAINMENT FOR THE POPULATION 25 YEARS AND OVER"
    "B15003_001E" = "pop_education",
    "B15003_019E" = "edu_some_college_under_1",
    "B15003_020E" = "edu_some_college_over_1",
    "B15003_021E" = "edu_associates",
    "B15003_022E" = "edu_bachelors",
    "B15003_023E" = "edu_masters",
    "B15003_024E" = "edu_professional",
    "B15003_025E" = "edu_doctoral",
    # Median household income in the past 12 months (in 2020 inflation-adjusted dollars)
    "B19013_001E" = "median_household_income",
    # FAMILY INCOME IN THE PAST 12 MONTHS (IN 2020 INFLATION-ADJUSTED DOLLARS)
    "B19101_001E" = "pop_income",	#Estimate!!Total:
    "B19101_002E" = "pop_under_10000",	#Estimate!!Total:!!Less than $10,000
    "B19101_003E" = "pop_10000_14999",	#Estimate!!Total:!!$10,000 to $14,999
    "B19101_004E" = "pop_15000_19999",	#Estimate!!Total:!!$15,000 to $19,999
    "B19101_005E" = "pop_20000_24999",	#Estimate!!Total:!!$20,000 to $24,999
    "B19101_006E" = "pop_25000_29999",	#Estimate!!Total:!!$25,000 to $29,999
    "B19101_007E" = "pop_30000_34999",	#Estimate!!Total:!!$30,000 to $34,999
    "B19101_008E" = "pop_35000_39999",	#Estimate!!Total:!!$35,000 to $39,999
    "B19101_009E" = "pop_40000_44999",	#Estimate!!Total:!!$40,000 to $44,999
    "B19101_010E" = "pop_45000_49999",	#Estimate!!Total:!!$45,000 to $49,999
    "B19101_011E" = "pop_50000_59999",	#Estimate!!Total:!!$50,000 to $59,999
    "B19101_012E" = "pop_60000_74999",	#Estimate!!Total:!!$60,000 to $74,999
    "B19101_013E" = "pop_75000_99999",	#Estimate!!Total:!!$75,000 to $99,999
    "B19101_014E" = "pop_100000_124999",	#Estimate!!Total:!!$100,000 to $124,999
    "B19101_015E" = "pop_125000_149999",	#Estimate!!Total:!!$125,000 to $149,999
    "B19101_016E" = "pop_150000_199999",	#Estimate!!Total:!!$150,000 to $199,999
    "B19101_017E" = "pop_200000_plus",	#Estimate!!Total:!!$200,000 or more
    # Gini Index of Income Inequality
    "B19083_001E" = "gini", # GINI INDEX OF INCOME INEQUALITY
    # Housing Costs
    "B25105_001E" = "median_monthly_housing_costs", # Median Monthly Housing Costs in USD
    # Employment
    "B23025_003E" = "pop_labor_force", # Estimate!!Total!!In labor force!!Civilian labor force
    "B23025_004E" = "pop_employed", #Estimate!!Total!!In labor f orce!!Civilian labor force!!Employed
    "B23025_005E" = "pop_unemployed", # Estimate!!Total:!!In labor force:!!Civilian labor force:!!Unemployed
    "B29001_001E" = "pop_voting_age" # Citizen, Voting Age Population
  ) %>%
    as_tibble() %>%
    tidyr::pivot_longer(cols = -c(), names_to = "id", values_to = "variable")
  
  
  
  data = getCensus(name = "acs/acs5", vintage = year, vars = myvars$id, 
                   key = key,
                   region = region,
                   regionin = paste0("state:", state_fips))
  
  data = data %>%
    # Keep just the rows with our specified names
    select(myvars$id) %>%
    # Rename them to simpler, more easily understandable names
    setNames(nm = c(myvars$variable)) %>%
    # better format the geoid
    mutate(geoid = str_remove(geoid, ".*US")) 
  
  data = data %>%
    # Convert subcategories into percentages
    mutate(
      women = pop_women / pop,
      white = white / pop_race,
      black = black / pop_race,
      asian = asian / pop_race,
      natam = natam / pop_race,
      pacific = pacific / pop_race,
      hisplat = hispanic / pop_ethnicity,
      unemployment = pop_unemployed / pop_labor_force * 1000,
      some_college = (edu_some_college_under_1 + edu_some_college_over_1 + edu_associates +
                        edu_bachelors + edu_masters + edu_professional + edu_doctoral) / pop_education, # % of those over 25 with ANY college education
      over_65 = (pop_age_65_66_male + pop_age_67_69_male +
                   pop_age_70_74_male + pop_age_75_79_male +
                   pop_age_80_84_male + pop_age_85_over_male +
                   pop_age_65_66_female + pop_age_67_69_female +
                   pop_age_70_74_female + pop_age_75_79_female +
                   pop_age_80_84_female + pop_age_85_over_female) / pop,
      income_0_60K = (pop_under_10000 + pop_10000_14999 +
                        pop_15000_19999 + pop_20000_24999 +
                        pop_25000_29999 + pop_30000_34999 +
                        pop_35000_39999 + pop_40000_44999 +
                        pop_45000_49999 + pop_50000_59999) / pop_income) %>%
    # Reset any nans to NA
    mutate(across(.cols = c(women, white, black, asian, natam, pacific, hisplat,
                            unemployment, some_college, over_65, income_0_60K,
                            median_household_income, median_monthly_housing_costs, gini),
                  .fns = ~if_else(is.nan(.x) | is.infinite(.x) | .x == -666666666, true = NA_real_, false = as.numeric(.x) ))) %>%
    select(geoid, pop, women, over_65, hisplat, white, black, asian, natam, pacific,
           some_college, income_0_60K, median_household_income,
           median_monthly_housing_costs, gini, unemployment) 
  return(data)
}


#' @name retrieve_census2
#' @title Retrieve Census Data
#' @description
#' Function to retrieve census data for all census tracts / geographies for one state in a given year.
#' @param state_fips:str a state FIPS code (eg. for New York, `"36"`)
#' @param year:int year of ACS-5 census data to return. For example, 2022 returns the 5-year average of 2020, 2021, 2022, 2023, and 2024.
#' @param region:str code to pass to `censusapi` to tell what type of geography to return. Eg. `"tract:*"` returns every census tract.
#' @param key:str census API key. By default, passed as environmental variable `CENSUS_API_KEY`. Can skip if already loaded as environmental variable.
#' @export
retrieve_census2 = function(state_fips, year, region = "tract:*", key = Sys.getenv("CENSUS_API_KEY")){
  library(dplyr, warn.conflicts = FALSE, quietly = TRUE)
  library(tidyr, warn.conflicts = FALSE, quietly = TRUE)
  library(readr, warn.conflicts = FALSE, quietly = TRUE)
  library(stringr, warn.conflicts = FALSE, quietly = TRUE)
  library(censusapi, warn.conflicts = FALSE, quietly = TRUE)
  
  # testint values
  # state_fips = "36"; year = 2022; region = "tract:*"; key = Sys.getenv("CENSUS_API_KEY")
  
  # Define variables for census data retrieval
  general_vars <- c(
    "geoid" = "GEO_ID",
    
    total_population = "B01003_001",  
    
    Not_Hispanic_or_Latino_Population= "B03002_002",
    Hispanic_or_Latino_Population = "B03002_012",
    
    population_by_race_White = "B02001_002", 
    population_by_race_Black_or_African_American = "B02001_003",
    population_by_race_American_Indian_and_Alaska_Native = "B02001_004",
    population_by_race_Asian = "B02001_005",
    population_by_race_Native_Hawaiian_and_Other_Pacific_Islander = "B02001_006",
    
    median_income = "B19013_001",       # Median household income
    
    population_by_gender_male = "B01001_002", # Male population (use B01001_026 for Female)
    population_by_gender_female= "B01001_026"
  )
  
  race_vars = c(
    White_alone_Not_Hispanic_or_Latino_Population = "B03002_003",
    Black_or_African_American_Not_Hispanic_or_Latino_Population = "B03002_004",
    American_Indian_and_Alaska_Not_Native_Hispanic_or_Latino_Population = "B03002_005",
    Asian_Not_Hispanic_or_Latino_Population = "B03002_006",
    Native_Hawaiian_and_Other_Pacific_Islander_Not_Latino_Population = "B03002_007",
    
    
    Asian_Hispanic_or_Latino_Population = "B03002_016",
    White_alone_Hispanic_or_Latino_Population = "B03002_013",
    Black_or_African_American_Hispanic_or_Latino_Population = "B03002_014",
    American_Indian_and_Alaska_Native_Hispanic_or_Latino_Population = "B03002_015",
    Native_Hawaiian_and_Other_Pacific_Islander_Latino_Population = "B03002_017"
  )
  
  
  # Define ACS Income Variables (B19001 - Household Income)
  income_vars <- c(
    # $0 - $24,999 (B19001_002 to B19001_005)
    "B19001_002", "B19001_003", "B19001_004", "B19001_005",
    
    # $25,000 - $49,999 (B19001_006 to B19001_010)
    "B19001_006", "B19001_007", "B19001_008", "B19001_009", "B19001_010",
    
    # $50,000 - $74,999 (B19001_011 to B19001_012)
    "B19001_011", "B19001_012",
    
    # $75,000 - $99,999 (B19001_013)
    "B19001_013",
    
    # $100,000 - $124,999 (B19001_014)
    "B19001_014",
    
    # $125,000 - $149,999 (B19001_015)
    "B19001_015",
    
    # $150,000 - $199,999 (B19001_016)
    "B19001_016",
    
    # $200,000 or more (B19001_017)
    "B19001_017"
  )
  
  
  # Define ACS Variables for New Age Groups
  age_vars <- c(
    # Under 18 (Male: 003-006, Female: 027-030)
    "B01001_003", "B01001_004", "B01001_005", "B01001_006",
    "B01001_027", "B01001_028", "B01001_029", "B01001_030",
    
    # 18-34 (Male: 007-012, Female: 031-036)
    "B01001_007", "B01001_008", "B01001_009", "B01001_010", "B01001_011", "B01001_012",
    "B01001_031", "B01001_032", "B01001_033", "B01001_034", "B01001_035", "B01001_036",
    
    # 35-64 (Male: 013-019, Female: 037-043)
    "B01001_013", "B01001_014", "B01001_015", "B01001_016", "B01001_017", "B01001_018", "B01001_019",
    "B01001_037", "B01001_038", "B01001_039", "B01001_040", "B01001_041", "B01001_042", "B01001_043",
    
    # 65 and over (Male: 020-025, Female: 044-049)
    "B01001_020", "B01001_021", "B01001_022", "B01001_023", "B01001_024", "B01001_025",
    "B01001_044", "B01001_045", "B01001_046", "B01001_047", "B01001_048", "B01001_049"
  )
  
  edu_vars = c(
    # edu_less_than_hs 
    "B15003_002", "B15003_003", "B15003_004", "B15003_005",
    "B15003_006", "B15003_007", "B15003_008", "B15003_009",
    "B15003_010", "B15003_011", "B15003_012", "B15003_013",
    "B15003_014", "B15003_015", "B15003_016",
    
    # edu_hs_grad
    "B15003_017", "B15003_018",
    
    # edu_some_college_or_more 
    "B15003_019", "B15003_020", "B15003_021",
    
    # edu_postgrad 
    "B15003_022", "B15003_023", "B15003_024", "B15003_025"
  )
  
  myvars = c(general_vars, race_vars, income_vars, age_vars, edu_vars)
  myvars = tibble(id = myvars, variable = names(myvars))
  myvars = myvars %>%
    mutate(idE = if_else(id == "GEO_ID", true = id, false = paste0(id, "E")))
  
  download = getCensus(name = "acs/acs5", vintage = year, vars = myvars$idE,
                       key = key,
                       region = region,
                       regionin = paste0("state:", state_fips))
  
  data = download %>%
    # Keep just the rows with our specified names
    select(myvars$idE) %>%
    # Rename them to simpler, more easily understandable names
    setNames(nm = c(myvars$id)) %>%
    # better format the geoid
    rename(geoid = GEO_ID) %>%
    mutate(geoid = str_remove(geoid, ".*US"))
  
  # Group and Summarize Household Income Data
  income_summary = data %>%
    select(any_of(c("geoid", income_vars))) %>%
    pivot_longer(cols = any_of(income_vars), names_to = "variable", values_to = "estimate") %>%
    group_by(geoid) %>%
    summarise(
      income_0_24999 = sum(estimate[variable %in% c("B19001_002", "B19001_003", "B19001_004", "B19001_005")]),
      income_25000_49999 = sum(estimate[variable %in% c("B19001_006", "B19001_007", "B19001_008", "B19001_009", "B19001_010")]),
      income_50000_74999 = sum(estimate[variable %in% c("B19001_011", "B19001_012")]),
      income_75000_99999 = sum(estimate[variable %in% c("B19001_013")]),
      income_100000_124999 = sum(estimate[variable %in% c("B19001_014")]),
      income_125000_149999 = sum(estimate[variable %in% c("B19001_015")]),
      income_150000_199999 = sum(estimate[variable %in% c("B19001_016")]),
      income_200000_or_more = sum(estimate[variable %in% c("B19001_017")]),
      .groups = "drop"
    )
  
  # Group and Summarize Age Data
  age_summary = data %>%
    select(any_of(c("geoid", age_vars))) %>%
    pivot_longer(cols = any_of(age_vars), names_to = "variable", values_to = "estimate") %>%
    group_by(geoid)  %>%
    summarise(
      age_under_18 = sum(estimate[variable %in% c(
        "B01001_003", "B01001_004", "B01001_005", "B01001_006",
        "B01001_027", "B01001_028", "B01001_029", "B01001_030")]),
      
      age_18_34 = sum(estimate[variable %in% c(
        "B01001_007", "B01001_008", "B01001_009", "B01001_010", "B01001_011", "B01001_012",
        "B01001_031", "B01001_032", "B01001_033", "B01001_034", "B01001_035", "B01001_036")]),
      
      age_35_64 = sum(estimate[variable %in% c(
        "B01001_013", "B01001_014", "B01001_015", "B01001_016", "B01001_017", "B01001_018", "B01001_019",
        "B01001_037", "B01001_038", "B01001_039", "B01001_040", "B01001_041", "B01001_042", "B01001_043")]),
      
      age_65_and_over = sum(estimate[variable %in% c(
        "B01001_020", "B01001_021", "B01001_022", "B01001_023", "B01001_024", "B01001_025",
        "B01001_044", "B01001_045", "B01001_046", "B01001_047", "B01001_048", "B01001_049")])
    )
  
  edu_summary = data %>%
    select(any_of(c("geoid", edu_vars))) %>%
    pivot_longer(cols = any_of(edu_vars), names_to = "variable", values_to = "estimate") %>%
    group_by(geoid)  %>%
    summarize(
      edu_less_than_hs = sum(estimate[variable %in% c(
        "B15003_002", "B15003_003", "B15003_004", "B15003_005",
        "B15003_006", "B15003_007", "B15003_008", "B15003_009",
        "B15003_010", "B15003_011", "B15003_012", "B15003_013",
        "B15003_014", "B15003_015", "B15003_016")]),
      
      edu_hs_grad = sum(estimate[variable %in% c(
        "B15003_017", "B15003_018")]),
      
      edu_some_college_or_more = sum(estimate[variable %in% c(
        "B15003_019", "B15003_020", "B15003_021")]),
      
      edu_postgrad = sum(estimate[variable %in% c(
        "B15003_022", "B15003_023", "B15003_024", "B15003_025")])
    )
  
  
  race_summary = data %>%
    select(any_of(c("geoid", race_vars)))
  
  general_summary = data %>%
    select(any_of(c("geoid", general_vars)))
  
  output = data %>%
    select(geoid) %>%
    distinct() %>%
    left_join(by = "geoid", y = age_summary) %>%
    left_join(by = "geoid", y = income_summary) %>%
    left_join(by = "geoid", y = race_summary) %>%
    left_join(by = "geoid", y = edu_summary) %>%
    left_join(by = "geoid", y = general_summary)
  
  return(output)
}

#' @name retrieve_emissions
#' @title Download many county-years of emissions data in bulk
#' @param geoid:[str] vector of county unique IDs requested (5-digit FIPS codes)
#' @param year:[int] vector of years requested
#' @param pollutant:[int] vector of EPA pollutant IDs for all pollutants requested; defaults to 98, CO2 Equivalent Emissions
#' @param aggregation:int ID of Aggregation Level (overall = `16`, by sourcetype = `8`, by fueltype = `14`, by regulatory class = `12`, overall with sourcetype = `17`, overall with regulatory class = `18`, overall with fueltype = `19`, overall with roadtype = `20`, overall with sourcetype and fueltype = `21`)
#' @param var:[str] Name(s) of variables to return for analysis. eg. `c("emissions", "vmt", "vehicles")`
#' @note Returns a `data.frame`, converted from a `json`. Queries the `/granddata-bulk-download` endpoint from CAT ANALYZER API.
#' @export
retrieve_emissions = function(geoid = "36109", year = c(2020), pollutant = 98, aggregation = 16, var = "emissions"){
  # Testing values
  # geoid = "36109"; year = c(2020); pollutant = 98; aggregation = 16
  
  # Note: you MUST have loaded your environmental variables first for this to work. 
  # readRenviron("secret/.env") 
  
  # Pause for a moment, so we don't overwhelm the API
  Sys.sleep(1)
  # Build the API query URL
  base = Sys.getenv("API_PROXY")
  endpoint = "/granddata-bulk-download"
  query = paste0(
    "?",
    "aggregation=", aggregation, 
    paste0('&var=emissions', collapse = ""),
    paste0("&geoid=", geoid, collapse = ""), 
    paste0("&year=", year, collapse = ""),
    paste0("&pollutant=", pollutant, collapse = "")
  )
  # Build URL
  url = paste0(base, endpoint, query)
  # Build headers
  headers = httr::add_headers(
    "Content-Type" = "application/json"
  )
  # Run query
  result = httr::GET(url = url, headers, encode = "json")
  # Check status
  if(result$status_code != 200){ return(NULL)  }
  # Extract from json
  output = jsonlite::fromJSON(rawToChar(result$content))
  
  return(output)
  
}

#' @name get_yearrange
#' @title Get 5-year range of years, for any year. Eg. 2022 would be `c(2020, 2025)`
get_yearrange = function(year){
  # Testing values
  #year = 2027
  
  myfloor = floor(year/10)*10
  myceiling = ceiling(year/10)*10
  
  yearnum = year - myfloor
  
  if(yearnum %in% c(0,5,10)){
    output = year
  }else if(yearnum > 0 & yearnum < 5){
    output = c(myfloor, myfloor + 5)
  }else if(yearnum > 5 & yearnum < 10){
    output = c(myfloor + 5, myceiling)
  }
  
  return(output)
}


#' @name get_state
#' @title Get state metadata given a county, tract, etc. geoid.
get_state = function(geoid){
  # geoid = "36109"
  state_geoid = stringr::str_sub(geoid, 1,2) %>% unique()
  
  result = readr::read_rds("data/states.rds") %>%
    filter(state_fips %in% state_geoid)
  return(result)
}



#' @name get_shapes_counties
#' @title Get Polygons for Counties from TIGRIS API
#' @param geoids:str vector of COUNTY geoids for which to return county polygons within those counties
get_shapes_counties = function(geoids, year = 2022){
  
  mystate = get_state(geoid = geoids)
  
  # Get all counties in new york
  counties = tigris::counties(state = mystate$state, cb = TRUE, year = year) %>%
    select(geoid = GEOID, name = NAME, area_land = ALAND, geometry) %>%
    # Filter to just geoids for which you'll make a total equity measure
    filter(geoid %in% geoids)
  return(counties)
}

#' @name get_shapes_tracts
#' @title Get Polygons for Census Tracts from TIGRIS API
#' @param geoids:str vector of COUNTY geoids for which to return tract polygons within those counties
get_shapes_tracts = function(geoids, year = 2022){
  
  mystate = get_state(geoid = geoids)
  # Get tracts from all new york counties
  tracts = tigris::tracts(state = mystate$state, county = str_sub(geoids, 3,5), cb = TRUE, year = year) %>%
    filter(ALAND > 0)  %>%
    select(geoid = GEOID, area_land = ALAND, geometry) %>%
    mutate(geoid_county = str_sub(geoid, 1,5))
  return(tracts)  
}


#' @name get_shapes_roads
#' @title Get Road Spatial Features from TIGRIS API
#' @param counties a spatial data.frame of counties
#' @param year:int year of road files to downloa
get_shapes_roads = function(counties, year = 2022){
  library(dplyr, warn.conflicts = FALSE, quietly = TRUE)
  library(sf, warn.conflicts = FALSE, quietly = TRUE)
  
  mystate = get_state(geoid = counties$geoid)
  
  roads = tigris::primary_secondary_roads(
    state = mystate$state, year = year, 
    # Cache the shapefiles
    keep_zipped_shapefile = TRUE, 
    # Don't redownload cached shapefiles (refresh = FALSE)
    refresh = FALSE) 
  
  # Get just the roads that overlap with these polygons
  roads = roads %>% 
    st_intersection(y = counties %>% select(geoid, geometry))
  
  
  # For each county, create 1 set of mega lines
  roads = roads %>%
    group_by(geoid) %>%
    summarize(geometry = st_combine(geometry), 
              .groups = "drop")
  
  # Sometimes an intersection will leave a spare point, but not a line.
  # Drop those.
  # roads = roads %>% 
  #   filter(!st_is(geometry, type = "POINT"))
  
  # roads %>% filter(geoid == "36011")
  # roads %>% saveRDS(path_shapes_roads)
  return(roads) 
}

#' @name get_shapes_buffers
#' @title Get 1km Road Buffers as Spatial Features
#' @param roads spatial data.frame of road multi-lines, made by `get_shapes_roads()`
#' @param counties spatial data.frame of county polygons, made by `get_shapes_counties()`
#' @param dist:int buffer distance in meters. Defaults to 1 km, or `dist = 1000`.
get_shapes_buffers = function(roads, counties, dist = 1000){
  # Testing values
  # roads = read_rds(path_shapes_roads); counties = read_rds(path_shapes_counties); dist = 1000
  
  
  # Create road buffers
  buffer = roads %>%
    # Create 1 km buffers around roads
    mutate(geometry = st_buffer(geometry, dist = dist))
  
  # Join in the county geometry
  buffer = buffer %>%
    left_join(by = "geoid", y = counties %>% as_tibble() %>% select(geoid, county_geometry = geometry))
  
  # now clip road buffers to the extent of each county
  buffer = buffer %>%
    group_by(geoid) %>%
    mutate(geometry = st_intersection(x = geometry, y= county_geometry) %>%
             st_make_valid() %>%
             st_cast(to = "MULTIPOLYGON") %>% 
             st_make_valid())
  
  buffer = buffer %>%
    ungroup() %>%
    select(-county_geometry)
  
  buffer %>% saveRDS(path_shapes_buffers)
  return(buffer)  
  
}


st_intersection_faster = function(x, y, ...){
  xFeatures = x
  yFeatures = y
  library(sf)
  library(dplyr)
  library(purrr)
  library(progress)
  
  intersections <- st_intersects(x = xFeatures, y = yFeatures)
  # pb <- progress_bar$new(format = "[:bar] :current/:total (:percent)", total = length(xFeatures)[1])
  
  get_inter = function(ix){
    # pb$tick()
    st_intersection(
      x = xFeatures[ ix ], 
      y = yFeatures[ intersections[[ix]] ] )
  }
  
  intersectFeatures = 1:length(xFeatures) %>%
    map_dfr(.f = ~get_inter(ix = .) %>% st_as_sf()) 
  
  return(intersectFeatures$x)
}
#' @name get_shapes_tracts_by_exposure
#' @title Get tracts, measuring for each tract the total area of exposure
#' @param tracts spatial data.frame of census tracts made by `get_shapes_tracts()`
#' @param buffer spatial data.frame of buffer zones made by `get_shapes_buffers()`
get_shapes_tracts_by_exposure = function(tracts, buffer){
  # Testing values
  # tracts = read_rds(path_shapes_tracts); buffer = read_rds(path_shapes_buffers)
  
  # tracts =  read_rds(path_shapes_tracts) %>% filter(geoid_county == "36109")
  # buffer = read_rds(path_shapes_buffers) %>% filter(geoid == "36109")
  
  poly = tracts %>% 
    left_join(
      by = c("geoid_county" = "geoid"), 
      y = buffer %>% as_tibble() %>% 
        select(geoid, buffer_geometry = geometry))
  
  
  
  
  poly2 = poly %>%
    group_by(geoid, geoid_county) %>%
    reframe(
      geometry = st_intersection_faster(x = geometry, y = buffer_geometry) %>%
        st_make_valid() %>% st_union()
    )
  
  stats_roads = poly2 %>%
    mutate(area_roads = geometry %>% st_area() %>% as.numeric() %>% {./1e6}) %>%
    as_tibble() %>%
    select(geoid, area_roads)
  
  
  stats_total = poly %>%
    as_tibble() %>%
    mutate(area_total = geometry %>% st_area() %>% as.numeric() %>% {./1e6}) %>%
    select(geoid, geoid_county, area_land, area_total)
  
  stats = stats_total %>%
    left_join(by = "geoid", y = stats_roads)
  
  return(stats)
  
  # For each tract,
  # Get all the buffer areas within that tract's polygon, and
  # consolidate buffer regions in the same tract
  # output = poly  %>%
  #   group_by(geoid, geoid_county) %>%
  #   reframe(
  #     # Get total tract area
  #     area_total = st_area(geometry) %>% as.numeric() %>% {./1e6},
  #     # Get total road buffer overlap
  #     geometry = st_intersection_faster(x = geometry, y = buffer_geometry) %>% 
  #       st_make_valid() %>% st_union(),
  #     # Get total road buffer area
  #     area_roads = st_area(geometry) %>% as.numeric() %>% {./1e6}
  #   ) %>%
  #   select(geoid, area_total, area_roads) %>%
  #   right_join(by = "geoid", y = tracts)
  
  #return(output)
}



get_shapes_tracts_by_exposure_loop = function(
    tracts = read_rds(path_shapes_tracts),
    buffer = read_rds(path_shapes_buffers)
){
  
  
  holder = tibble(
    geoid = NA_character_,
    geoid_county = NA_character_,
    area_roads = NA_real_,
    area_total = NA_real_,
    area_land = NA_real_
  ) %>% 
    slice(0)
  # tracts %>% 
  # slice(1) %>%
  # mutate(area_roads = NA_real_, 
  #        area_total = NA_real_) %>%
  # slice(0) %>%
  # select(geoid, area_total, area_roads, area_land, geoid_county, geometry)
  
  for(i in geoids){
    cat(paste0("\n", i, "\n"))
    tracts_i = tracts %>% filter(geoid_county == i)
    buffer_i = tracts %>% filter(geoid == i)
    data = get_shapes_tracts_by_exposure(tracts = tracts_i, buffer = buffer_i)
    holder = bind_rows(holder, data)
    remove(data)
  }
  remove(tracts, buffer)
  return(holder)
}


# Get back area_roads for each tract
get_area_roads = function(
    tracts = path_shapes_tracts %>% read_rds(), 
    buffers = path_shapes_buffers %>% read_rds() ){
  
  # Filter into tracts in one county
  mygeoids = unique(tracts$geoid_county)
  
  n_geoids = length(mygeoids)
  # n_geoids = 3
  output1 = 1:n_geoids %>%
    map_dfr(.f = ~{
      cat("\n---", mygeoids[.x], "\n")
      tracts_i = tracts %>% filter(geoid_county == mygeoids[.x])
      
      buffers_i = buffers %>% filter(geoid == mygeoids[.x])
      
      poly = tracts_i %>% 
        group_by(geoid) %>%
        reframe(geometry = st_intersection_faster(x = geometry, y = buffers_i$geometry) %>% 
                  st_make_valid(),
                .groups = "drop") %>%
        ungroup() %>%
        # Filter to just valid geometries
        filter(sf::st_is_valid(geometry)) %>%
        # Then for each geoid, bundle them
        group_by(geoid) %>%
        summarize(geometry = st_union(geometry), .groups = "drop")
      
      poly = poly %>%
        mutate(area_roads = geometry %>% st_area() %>% as.numeric() %>% {./1e6})
      data = poly %>% as_tibble() %>% select(geoid, area_roads)
      return(data)
    }
    )
  
  # Now return every tract, with area_roads and area_total
  output2 = tracts %>%
    mutate(area_total = geometry %>% st_area() %>% as.numeric() %>% {./1e6}) %>%
    left_join(by = "geoid", y = output1)
  
  return(output2)
}

#' @name get_viz_buffers
#' @title Get Visualization of Road Buffers 
get_viz_buffers = function(
    counties = read_rds(path_shapes_counties),
    roads = read_rds(path_shapes_roads),
    tracts = read_rds(path_shapes_tracts),
    buffers = read_rds(path_shapes_buffers)
){
  library(ggplot2, warn.conflicts = FALSE, quietly = TRUE)
  library(sf, warn.conflicts = FALSE, quietly = TRUE)
  
  # View road buffers vs counties
  ggplot() +
    geom_sf(data = counties, fill = "white", color = "black") +
    geom_sf(data = roads, color = "red", linewidth = 0.1) +
    geom_sf(data = tracts, color = 'grey', fill = NA) +
    geom_sf(data = st_as_sf(buffers), fill = "red", alpha = 0.25, color = NA) +
    geom_sf(data = counties, fill = NA, color = "black", linewidth = 0.5) +
    theme_void(base_size = 14)
  
}


get_emissions_interpolated = function(county_emissions = read_rds(path_emissions), year = 2022){
  myyear = year
  # Add in emissions data by county
  county_emissions  %>%
    group_by(geoid, pollutant) %>%
    summarize(
      emissions = lm(formula = emissions ~ year) %>% 
        predict(object = ., newdata = tibble(year = myyear)),
      .groups = "drop")
}



#' @name get_county_group_values
#' @description
#' For any set of counties and demographic groups (eg. "white", "black", "asian", etc.) provided in `tracts`,
#' return the full set of estimated emissions, affected residents, and population tallies per county and per group.
#' @param tracts spatial data.frame of tract exposure data from `path_shapes_tracts_exposure`
#' @param census_tracts data.frame of census tract covariates from `path_census_tracts`
#' @param county_emissions data.frame of county emissions data from `path_emissions`
#' @param id_var:str id variable name for census tracts. Usually `"geoid"`
#' @param id_var2:str id variable name for counties. Usually `"geoid_county"`
#' @param vars:[str] vector of variable names describing percentage of population per group. Must be present in both tract and county data.
#' @param pop_var:str name of variable describing total population. Must be present in both tract and county data.
#' @export
get_county_group_values = function(
    # Load in tracts with exposure area data
  exposure = read_rds(path_area_roads),
  census_tracts = read_rds(path_census_tracts),
  county_emissions = read_rds(path_emissions),
  
  path_census_counties = path_census_counties,
  myyear = 2022,
  .pollutant = 110,
  id_var = "geoid",
  vars = c("white", "black", "asian", "natam", "pacific"),
  pop_var = "pop",
  
  id_var2 = "geoid_county"
){
  
  # Testing values
  # exposure = read_rds(path_area_roads);
  # census_tracts = read_rds(path_census_tracts);
  # county_emissions = read_rds(path_emissions);
  # id_var = "geoid";
  # vars = c("age_under_18", "age_18_34", "age_35_64", "age_65_and_over")
  # pop_var = NULL
  # id_var2 = "geoid_county"
  # # vars = c("white", "black", "asian", "natam", "pacific");
  # pop_var = "pop";
  
  
  # Filter to the pollutant of interest
  county_emissions = county_emissions %>%
    filter(pollutant == .pollutant)
  
  # Suppose you provide a data.frame that contains
  # a tract `geoid` and some specific variables that belong together
  # Make sure the data provided includes a pop variable
  if(is.null(pop_var)){
    # If pop_var is NULL,
    # that means the values supplied aren't percentages but raw numbers.
    # You don't have to un-normalize them then!
    data = census_tracts %>%
      select(any_of(c(id_var, vars)))
    
    # Load in census data for each county
    # Make sure the data provided includes a pop variable
    census_counties = read_rds(path_census_counties) %>%
      # Keep geoid, pop_var, and grouping tallies
      select(any_of(c(id_var, vars))) %>%
      pivot_longer(cols = any_of(vars), names_to = "group", values_to = "pop")
    
    # Get the census county total
    census_counties = census_counties %>% 
      group_by(geoid) %>%
      mutate(pop_total = sum(pop, na.rm = TRUE)) %>%
      ungroup()
    
  }else{
    # Otherwise, back-transform the percentages into raw values
    data = census_tracts %>%
      mutate(across(any_of(vars), .fns = ~.x * !!sym(pop_var))) %>%
      select(any_of(c(id_var, vars)))
    
    # Make sure the data provided includes a pop variable
    census_counties = read_rds(path_census_counties) %>%
      # Convert into raw population rather than percentages
      mutate(across(any_of(vars), .fns = ~.x * !!sym(pop_var))) %>%
      # Keep geoid, pop_var, and grouping tallies
      select(any_of(c(id_var, pop_total = pop_var, vars))) %>%
      pivot_longer(cols = any_of(vars), names_to = "group", values_to = "pop")
    
  }
  
  # Obtain the area data from our census tract polygons, 
  # and then join in the census data
  tracts1 = exposure %>%
    as_tibble() %>%
    select(geoid, geoid_county, area_total, area_roads) %>%
    left_join(by = "geoid", y = data)
  
  # Estimate the total residents of group X that are in the buffer region in that tract
  tracts2 = tracts1 %>%
    pivot_longer(cols = any_of(vars), names_to = "group", values_to = "value") %>%
    mutate(affected = value * area_roads / area_total)
  
  # Calculate total affected per tract
  tracts_total = tracts2 %>%
    group_by(geoid_county) %>%
    summarize(affected_total = sum(affected, na.rm = TRUE))
  
  
  # Sum up the total folks in group X for that 
  tracts3 = tracts2 %>%
    group_by(geoid_county, group) %>%
    summarize(affected = sum(affected, na.rm = TRUE), .groups = "drop")
  
  
  # Import and interpolate emissions estimates for your year of interest
  county_emissions = get_emissions_interpolated(
    county_emissions = county_emissions,
    year = myyear) %>%
    mutate(geoid = str_pad(geoid, width = 5, side = "left", pad = "0"))
  
  
  
  # Get a geoid-by-group level dataset of all stats
  tracts4 = tracts3 %>%
    left_join(by = c("geoid_county" = "geoid"),
              y = county_emissions %>% select(geoid, emissions)) %>%
    left_join(by = c("geoid_county"),
              y = tracts_total) %>%
    # Estimate the county emissions rate by total people in exposure zone 
    # then estimate the total emissions experienced by people in each group in the exposure zone
    mutate(emissions_rate = emissions / affected_total,
           emissions_group = affected * emissions_rate) %>%
    select(geoid_county, emissions, emissions_rate, affected_total, group, affected, emissions_group) %>%
    # Join in the demographic data
    left_join(by = c("geoid_county" = "geoid", "group"),
              y = census_counties) %>%
    select(geoid_county, emissions, emissions_rate, affected_total, pop_total, group, affected, emissions_group, pop)
  
  
  return(tracts4)
  
}



#' @name get_region_group_values
#' @title Get Percentages by Region and Group
#' @param county_group_values data.frame outputted by `get_county_group_values()`. Can handle bundles of these results, if specified by a `region` variable.
#' @param region:str name of variable to use as the regional grouping variable
get_region_group_values = function(county_group_values, myvars, region = "region"){
  # Calculate region-wise statistics
  has_region = any(names(county_group_values) %in% region)
  
  if(has_region == FALSE){ 
    county_group_values$region = "region"
  }else if(has_region == TRUE){
    county_group_values = county_group_values %>% 
      rename(region = !!sym(region))
  }
  regionwise = county_group_values %>%
    group_by(region, group) %>%
    summarize(
      eshare = sum(emissions_group) / sum(emissions),
      pshare = sum(pop) / sum(pop_total),
      ashare = sum(affected) / sum(affected_total),
      .groups = "drop"
    ) %>%
    # Calculate population-adjusted eshare, called epshare  
    mutate(epshare = eshare / pshare) %>%
    mutate(epshare = if_else(is.nan(epshare) | is.infinite(epshare), true = 0, false = epshare)) %>%
    group_by(region) %>%
    mutate(epshare = epshare / sum(epshare, na.rm = TRUE))  %>%
    ungroup()
  
  
  regionwise$group = factor(regionwise$group, levels = myvars)
  
  return(regionwise)
}


get_diffmax = function(n_groups){
  # These numbers to compare are percentages,
  # naturally bounded at 1
  
  # What would the maximum  difference be?
  
  # Suppose:
  # A_e = 20%, A_p = 10%
  # B_e = 80%, B_p = 90%
  
  # Sum of Squared Differences = (.20-.10)^2 + (.80-.90)^2 = 0.02
  
  # Hypothetically the BIGGEST possible difference should be...
  
  # A_e = 100%; A_p = 0%;
  # B_e = 0%; B_p = 100%;
  # Sum of Squared Differences = (1 - 0)^2 + (1 - 0)^2 = 2
  # Given n = 2 groups
  
  
  # A_e = 100%; A_p = 0%;
  # B_e = 0%; B_p = 50%;
  # C_e = 0%; C_p = 50%;
  # Sum of Squared Differences = (1 - 0)^2 + (0.5 - 0)^2 + (0.5 - 0)^2 = 1.5
  # Given n = 3 groups
  
  # A_e = 100%; A_p = 0%;
  # B_e = 0%; B_p = 100%;
  # C_e = 0%; C_p = 0%;
  # Sum of Squared Differences = (1 - 0)^2 + (0 - 1)^2 + (0 - 0)^2 = 2
  # Given n = 3 groups
  
  x = c(1, rep(x = 0, n_groups - 1))
  y = c(rep(x = 0, n_groups - 1), 1)
  diff_max = sum((x-y)^2)
  return(diff_max)  
}

#' @examples
#' get_index(x = c(0.25, 0.25, 0.25, 0.25))
#' get_index(x = c(0.20, 0.20, 0.20, 0.20, 0.20))
get_index = function(x){ n_x = length(x); 1 - sum( abs( x - 1/n_x ) ) * ( ( n_x - 2 ) / 3 )  }

#' @name get_indicator
#' @title Calculate indicator from a data.frame of region-group values
get_indicator = function(region_group_values, type = "race"){
  # Make a 0 to 1 indicator, where 0 is perfect equity and 1 is TERRIBLE
  
  # In this function, we're going to calculate 
  # how far apart are the ACTUAL population distribution
  # and the distribution of groups affected by emissions
  
  # I'm pretty sure the maximum difference would be 2
  region_group_values %>%
    mutate(
      diff_group = eshare - pshare,
    ) %>%
    group_by(region) %>%
    summarize(
      diff_max = get_diffmax(n_groups = n()),
      #diff_max = abs(0 - 1),
      #diff_max = (1 - 1/n()) * (n() - 1),
      # Subtract from 1, so that larger differences mean lower scores
      # 1 = equity, 0 = terrible equity
      indicator1 = 1 - sum(diff_group^2) / diff_max,
      
      
      # Create an emissions share,
      # normalized by the population share
      # share of emissions per group GIVEN the share of population per group.
      # then renormalize that share
      # By default, this means 1 = perfect homophily - which in this case means inequity
      # So we should flip it so that 1 = perfect equity (heterophily) and 0 = perfect inequity
      indicator2 = get_index(x = epshare),
      
      type = type,
      .groups = "drop"
    )
}


get_bars = function(region_group_values, metric = "epshare"){
  library(ggplot2)
  library(viridis)
  ymax = max(region_group_values[[metric]])
  #metric = "epshare"
  ggplot() + 
    geom_col(data = region_group_values,
             mapping = aes(y = !!sym(metric), x = group, fill = group)) +
    facet_wrap(~region, ncol = 5, nrow = 2) +
    coord_flip() +
    viridis::scale_fill_viridis(discrete = TRUE, option = "plasma", begin = 0.1, end = 0.9, guide = "none") +
    scale_y_continuous(labels = scales::label_percent(), limits = c(0, ymax)) +
    theme_minimal(base_size = 12) +
    theme(
      panel.spacing = unit(0.5, "cm"),
      panel.border = element_rect(fill = NA, color = "#373737"),
      panel.grid = element_blank(),
      axis.line = element_blank()
    ) +
    labs(x = "Demographic Group", y = "Population-Adjusted Percentage of Emissions Exposure per Group")
}




# region_group_values %>%
#   lm(formula = epshare ~ group + region) %>%
#   summary()


#' @name get_bars2
#' @description
#' Revised function for pretty two-panel bar charts
get_bars2 = function(mylist, metric = "epshare", ylab = "Demographic Group", beta = FALSE, hjust = 0.5, xmin = 0, verbose = FALSE){
  # Testing values
  # mylist = read_rds("test/stat_income.rds"); metric = "epshare"; ylab = "Income Bracket"; beta = TRUE; hjust = 1; verbose = TRUE

  library(ggplot2)
  library(viridis)
  
  joined = mylist$joined
  region_group_values = mylist$region_group_values  
  
  # If beta = TRUE, estimate beta for each region.
  if(beta == TRUE){
    # Estimate beta per region
    mybetas = region_group_values %>% 
      group_by(region) %>%
      reframe(lm(formula = epshare ~ as.numeric(group) ) %>% broom::tidy()) %>%
      filter(term == "as.numeric(group)") %>%
      mutate(beta = scales::number(estimate, accuracy = 0.001, style_positive = "plus"))
   # Join betas into the 'joined' dataframe 
    joined = joined %>% 
      left_join(by = "region", y = mybetas %>% select(region, beta))
  }
  
  # Create rich labels for each panel
  labels = joined %>% 
    mutate(
      name = region %>% dplyr::recode(
        "Central New York" = "Central NY",
        "Western New York" = "Western NY"
      ),
      name = paste0(
        "<b>", name, "</b>", "<br>", "Index: ",
        round(indicator2, 3)
      ))
  # If beta == TRUE, add in the beta coefficients to the labels
  if(beta == TRUE){
    labels = labels %>% 
      mutate(name = paste0(name, "<br>&beta; = ", beta))
  }
  # Turn the region labels into factors
  labels = labels %>%
    select(region, name) %>%
    mutate(name = factor(name, levels = name))
  
  region_group_values = mylist$region_group_values
  
  region_group_values = region_group_values %>% 
    left_join(by = "region", y = labels) %>%
    mutate(group = group %>% dplyr::recode_factor(
      "age_under_18" = "<18",
      "age_18_34" = "18-34",
      "age_35_64" = "35-64",
      "age_65_and_over" = "65+",
      "income_0_24999" = "$0~24K", 
      "income_25000_49999" = "$25K~49K", 
      "income_50000_74999" = "$50~74K", 
      "income_75000_99999" = "$75~99K",
      "income_100000_124999" = "$100~124K", 
      "income_125000_149999" = "$125~149K",
      "income_150000_199999" = "$150~199K",  
      "income_200000_or_more" = "$200K+",
      
      "edu_less_than_hs" = "<High School",
      "edu_hs_grad" = "High School",
      "edu_some_college_or_more" = ">Some College", 
      "edu_postgrad" = "Postgrad",
      
      
      "Native_Hawaiian_and_Other_Pacific_Islander_Latino_Population" = "Pacific Latinx",
      "Asian_Hispanic_or_Latino_Population" = "Asian Latinx",
      "American_Indian_and_Alaska_Native_Hispanic_or_Latino_Population" = "Nat. Am. Latinx",
      "Black_or_African_American_Hispanic_or_Latino_Population" = "Black Latinx",
      "White_alone_Hispanic_or_Latino_Population" = "White Latinx",
      
      "Native_Hawaiian_and_Other_Pacific_Islander_Not_Latino_Population" = "Pacific",
      "Asian_Not_Hispanic_or_Latino_Population" = "Asian",
      "American_Indian_and_Alaska_Not_Native_Hispanic_or_Latino_Population" = "Nat. Am.",
      "Black_or_African_American_Not_Hispanic_or_Latino_Population" = "Black",
      "White_alone_Not_Hispanic_or_Latino_Population" = "White"
      
    ))
  
  ymax = max(region_group_values[[metric]]) + 0.025
  lines = region_group_values %>%
    group_by(region, name) %>%
    summarize(n = n(),
              benchmark = 1 / n, 
              .groups = "drop")
  
  # Run a two-way ANOVA test
  # region_group_values %>% lm(formula = epshare ~ region) %>% broom::glance()
  m = aov(formula = epshare ~ group + region, data = region_group_values) 
  
  if(verbose == TRUE){
    # Print the aov results
    print(broom::tidy(m))
    print(broom::glance(m))
  }
  
  # Convert output into a caption  
  message = tibble(
    statistic = broom::tidy(m)$statistic[1],
    p_value = broom::tidy(m)$p.value[1],
    dfresidual = broom::tidy(m)$df[3],
    broom::glance(m),
    message = paste0(
      "<i>Test</i>:",
      " <b>Two-Way ANOVA [Percent ~ Group x Region]</b> ",
      "<br>",
      "<i>Result</i>: Differences by Group: ", 
      "F = ", round(statistic, 3),
      gtools::stars.pval(p_value),
      " (df = ", dfresidual, 
      ", n = ", nobs,
      ", R<sup>2</sup> = ", round(r.squared, 2), ")",
     "<br>",
      "<i>Statistical Significance</i>: ",
      "*** p < 0.001; ** p < 0.01; * p < 0.05; . p < 0.10"
    )
  ) %>%
    with(message)
  #message
  
  if(beta == TRUE){
    message = paste0(
      "<i>Note</i>: <b>&beta;</b> shows slope of line of best fit per 1 group change, for each region.",
      "<br>",
      message
    ) 
  }
  
  
  
  get_limits = function(x){
    mysd = sd(x)/2
    myrange = range(x)
    limits = myrange + c(-mysd, mysd)  
    return(limits)
  }
  
  limits_gg2 = get_limits(region_group_values[[metric]])
  
  limits_gg1 = get_limits(x = joined$indicator2)
    
  colors = viridis::plasma(n = length(unique(region_group_values$group)), begin = 0.1, end = 0.9)
  
  #metric = "epshare"
  gg2 = ggplot() + 
    geom_hline(
      data = lines, mapping = aes(yintercept = benchmark, group = region), color = "#F0F0F0", linetype = "dashed", linewidth = 1.5) +
    geom_col(
      data = region_group_values,
      mapping = aes(y = !!sym(metric), x = group, fill = group)) 
  
  if(beta == TRUE){
  gg2 = gg2 +
    geom_smooth(
      data = region_group_values,
      mapping = aes(y = !!sym(metric), x = as.numeric(group), group = region),
      color = "white", linewidth = 1.15, se = FALSE, method = "lm", alpha = 0.5
    ) +
  geom_smooth(
      data = region_group_values,
      mapping = aes(y = !!sym(metric), x = as.numeric(group), group = region),
      color = "grey", linewidth = 1, se = FALSE, method = "lm", alpha = 0.5
    )
  }
  #limits_gg2
  
  gg2 = gg2 +
    facet_wrap(~name, ncol = 5, nrow = 2) +
    coord_flip() +
    scale_fill_manual(values = colors, guide = "none") +
    scale_y_continuous(labels = scales::label_number(accuracy = 1, scale = 100), limits = limits_gg2, oob = scales::squish, expand = expansion(c(0,0.001))) +
    theme_minimal(base_size = 12) +
    theme(
      panel.spacing = unit(0.25, "cm"),
      panel.border = element_rect(fill = NA, color = "#373737"),
      panel.grid = element_blank(),
      axis.line = element_blank(),
      axis.text.x = element_text(size = 8),
      strip.text = ggtext::element_markdown(size = 10, hjust = 0.5),
      plot.caption = ggtext::element_markdown(hjust = 0, size = 10),
      plot.title = ggtext::element_markdown(hjust = 0.5, size = 12)
    ) +
    labs(x = ylab, y = "*Population-Adjusted Percentage of Emissions Exposure per Group",
         title = paste0("Relative Emissions Exposure* by <b>", ylab, "</b> and <b>Region</b>"),
         caption = message)

  gg1 = ggplot() +
    geom_col(
      data = joined,
      mapping = aes(x = reorder(region, indicator2), y = indicator2),
      fill = colors[1]
    ) +
    shadowtext::geom_shadowtext(
      data = joined,
      mapping = aes(x = reorder(region, indicator2), y = indicator2, label = round(indicator2,3) ),
      bg.r = 0.3, bg.color = "white", color = '#373737', hjust = hjust, nudge_y = 0.00005
    ) +
    # geom_point(data = joined,
    #          mapping = aes(x = reorder(region, indicator2), y = indicator2)) +
    scale_y_continuous(limits = c(xmin,1), oob = scales::squish, expand = expansion(c(0,0)),
                       breaks = seq(from = xmin, to = 1, length.out = 5)) +
    coord_flip() +
    labs(x = NULL, y = paste0(
      ylab, " Equity Index (0 to 1)<br><sup>[Even Emissions Exposure = 1]</sup>"),
      title = paste0(ylab, " Equity by Region")) +
    theme_minimal(base_size = 12) +
    theme(panel.grid = element_blank(),plot.title.position = "plot",
          panel.border = element_rect(fill = NA, color = "black"),
          plot.title = element_text(hjust = 0.5, size = 12),
          axis.title.x = ggtext::element_markdown(size = 12, hjust = 0.5))
  
  
  output = ggpubr::ggarrange(plotlist = list(gg1, gg2), labels = c("A", "B"), ncol = 2, widths = c(0.33, 0.66))   
  return(output)
}

#' @name get_lines
#' @description
#' Visualization function for viewing the range of index scores by region
get_lines = function(stat_overall = read_rds("test/stat_overall.rds"), .dist = 300, .pollutant = 110, .year = 2022){

  # Testing Values
  # stat_overall = read_rds("test/stat_overall.rds"); .dist = 300; .pollutant = 110; .year = 2022
  
  data = stat_overall %>%
    filter(dist == .dist, pollutant == .pollutant, year == .year) %>%
    pivot_longer(cols = -c("region", "year", "pollutant", "dist"), names_to = "type", values_to = "value")
  
  bands = data %>%
    group_by(region, pollutant, year, dist) %>%
    summarize(ymin = min(value, na.rm = TRUE),
              ymax = max(value, na.rm = TRUE),
              size = ymax - ymin,
              total = value[type == "total"],
              .groups = "drop")
  
  
  limits = c(min(bands$ymin) - sd(data$value)/2, 1)
  
  data = data %>%
    left_join(by = "region", y = bands)
  
  colors = viridis::plasma(n = 5, begin = 0.1, end = 0.1)
  
  gg1 = ggplot() +
    geom_col(
      data = data %>% filter(type == "race"),
      mapping = aes(x = reorder(region, -total), y = value, fill = type),
      color = "white", 
      fill = "lightgrey",
      width = 0.25, alpha = 0.5 #position = position_nudge(x = -0.25)
    ) +
    geom_linerange(
      data = bands,
      mapping = aes(x = reorder(region, -total), ymin = ymin, ymax = ymax),
      linewidth = 5, color = "grey"
    ) +
    geom_point(
      data = data,
      mapping = aes(x = reorder(region, -total), y = value, fill = type),
      color = "white", size = 7, shape = 21, stroke = 1
    ) +
    scale_fill_viridis(
      labels = c("race" = "Race/Ethnicity",
                 "income" = "Income",
                 "edu" = "Education",
                 "age" = "Age",
                 "total" = "Overall"),
      breaks = c( "race", "income", "edu", "age", "total"),
      option = "plasma", discrete = TRUE, begin = 0.9, end = 0.1
    ) +
    scale_y_continuous(limits = limits, oob = scales::squish, expand = expansion(c(0, 0.02))) +
    coord_flip() +
    theme_minimal(base_size = 14) +
    theme(panel.border = element_rect(fill = NA, color = "#373737"),
          panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank(),
          legend.position = "bottom",       
          plot.margin = unit(x = c(0,0,0,0), units = "lines") 
          
    ) +
    labs(
      
      color = "Type of Equity",
      fill = "Type of Equity",
      x = NULL,
      title = NULL,
      y = "Relative Emissions Exposure Equity Index [0-1]")
  
  
  gg2 = ggplot() +
    geom_density(data = data, mapping = aes(x = value, y = after_stat(density), fill = type, group = type), alpha = 0.75) +  
    scale_fill_viridis(
      labels = c("total" = "Overall",
                 "income" = "Income",
                 "race" = "Race/Ethnicity",
                 "edu" = "Education",
                 "age" = "Age"),
      guide = "none",
      breaks = c("total", "income", "race", "edu", "age"),
      option = "plasma", discrete = TRUE, begin = 0.9, end = 0.1
    ) +
    scale_x_continuous(limits = limits, oob = scales::squish, expand = expansion(c(0, 0.02)))  +
    scale_y_continuous(expand = expansion(c(0,0)), trans = "sqrt") +
    theme_minimal(base_size = 14) +
    theme(panel.border = element_blank(), #element_rect(fill = NA, color = "#373737"),
          panel.grid.minor = element_blank(),
          panel.grid.major = element_blank(),
          legend.position = "bottom",
          plot.title = element_text(hjust = 0.5),
          axis.text = element_blank(),
          axis.title = element_text(),
          plot.margin = unit(x = c(0,0,0,0), units = "lines") 
    ) +
    labs(x = NULL, y = NULL, 
         title = "Regional Variation in Equity")
  
  gg = ggpubr::ggarrange(plotlist = list(gg2, NULL, gg1), ncol = 1, 
                         common.legend = TRUE, legend = "bottom", align = "hv", 
                         heights = c(2,-0.75, 5), nrow = 3)
  return(gg)
}


get_emissions_slopes = function(
    stat_overall = read_rds("test/stat_overall.rds") ,
    stat_income = read_rds("test/stat_income.rds")
){
  # Other statistics ###################################
  data = stat_overall %>%
    left_join(
      by = "region", 
      y = stat_income %>%
        with(joined) %>% select(region, emissions, total_population, median_income)) %>%
    pivot_longer(cols = c(age, income, edu, race, total),
                 names_to = "type", values_to = "value")
  data = bind_rows(
    data %>%
      select(region, ytype = type, y = value, x = emissions) %>%
      mutate(xtype = "Emissions"),
    data %>%
      mutate(rate = emissions / total_population) %>%
      select(region, ytype = type, y = value, x = rate) %>%
      mutate(xtype = "Emissions Rate (per capita)")
  )
  
  # Find significant statistics
  data %>%
    group_by(xtype, ytype) %>%
    reframe(
      lm(formula = y ~ log(x) )%>%
        broom::tidy() %>%
        filter(term == "log(x)")
    ) %>%
    filter(p.value < 0.10)
  
  message = paste0(
    "<i>Significant Findings</i>: As the natural log of emissions increases by 1, regions see...",
    "<br>",
    "increased equity <b>overall</b> (&beta; = +0.11, p < 0.001), by <b>income</b> (&beta; = +0.06, p = 0.077),",
    "<br>",
    "and by <b>race/ethnicity</b> (&beta; = +0.36, p = 0.002)."
  )
  # As emissions increases, racial/ethnicity equity increases by +0.07 (p = 0.002)
  # As emissions increases, overall equity increases by +0.02 (p = 0.001)
  
  
  # How does emissions trend with burden? 
  gg = ggplot() +
    geom_point(
      data = data, 
      mapping = aes(y = y, x = x, fill = ytype),
      shape = 21, color = "white", size = 5, stroke = 1
    ) +
    geom_smooth(
      data = data, 
      mapping = aes(y = y, x = x, group = ytype, color = ytype),
      method = "lm", formula = y ~ log(x), se = FALSE, linewidth = 2, color = "white"
    )  +
    geom_smooth(
      data = data, 
      mapping = aes(y = y, x = x, group = ytype, color = ytype),
      method = "lm", formula = y ~ log(x), se = FALSE, linewidth = 1.5
    )  +
    scale_fill_viridis(
      labels = c("total" = "Overall",
                 "income" = "Income",
                 "race" = "Race/Ethnicity",
                 "edu" = "Education",
                 "age" = "Age"),
      breaks = c("total", "income", "race", "edu", "age"),
      option = "plasma", discrete = TRUE, begin = 0.9, end = 0.1
    ) +
    scale_color_viridis(
      labels = c("total" = "Overall",
                 "income" = "Income",
                 "race" = "Race/Ethnicity",
                 "edu" = "Education",
                 "age" = "Age"),
      breaks = c("total", "income", "race", "edu", "age"),
      option = "plasma", discrete = TRUE, begin = 0.9, end = 0.1,
      guide = "none"
    ) +
    scale_x_continuous(labels = scales::label_number(scale_cut = scales::cut_si(""))) +
    facet_wrap(~xtype, scales = "free_x") +
    theme_minimal(base_size = 14) +
    theme(panel.border = element_rect(fill = NA, color = "#373737"),
          panel.grid = element_blank(),
          axis.ticks = element_blank(),
          legend.position = "bottom",
          strip.background = element_rect(fill = "black", color = "black"),
          strip.text = element_text(color = "white"),
          plot.title = element_text(hjust = 0.5),
          plot.caption = ggtext::element_markdown(hjust = 0, size = 10)) +
    labs(x = "Emissions (tons)",
         y = "Relative Emissions Exposure Equity Index [0-1]",
         color = NULL, fill = "Index Type",
         title = "Relationships between Emissions and Equity",
         caption = message)
  return(gg)
}
# We'll make several types of indicators...

get_all = function(myregions,
                   myyear = 2022,
                   index = "age",
                   myvars = c("age_under_18", "age_18_34", "age_35_64", "age_65_and_over"),
                   path_area_roads = "test/area_roads1000.rds",
                   path_census_tracts =  'test/census_tracts.rds',
                   path_census_counties = "test/census_counties.rds",
                   path_emissions = "test/emissions_all_pollutants.rds",
                   .pollutant = 98
){

  # For a bunch of counties, calculate the group values...
  county_group_values = get_county_group_values(
    # Load in tracts with exposure area data
    exposure = read_rds(path_area_roads),
    census_tracts = read_rds(path_census_tracts),
    county_emissions = read_rds(path_emissions),
    path_census_counties = path_census_counties,
    .pollutant = .pollutant,
    myyear = myyear,
    id_var = "geoid",
    vars = myvars,
    pop_var = NULL,
    # pop_var = "pop",
    id_var2 = "geoid_county"
  )
  # A LOT OF DATA where each row is a county-group (group means a demographic group - one of your `myvars`)
  # county_group_values
  
  # For a region of counties and group, get a series of percentages.
  # eshare - percentage of emissions that they were exposed to
  # pshare - percentage of population that that group makes up
  # ashare - percentage of that group that was affected (in the exposure zone)
  # epshare - ratio of eshare / pshare --> **population-adjusted share of emissions exposure by group**
  region_group_values = county_group_values %>%
    left_join(by = c("geoid_county" = "geoid"),
              y = myregions %>% select(region, geoid)) %>%
    get_region_group_values(region = "region", myvars = myvars)
  
  # region_group_values = get_region_group_values(county_group_values = county_group_values, region = "region")
  indicators = get_indicator(region_group_values, type = index)
  
  
  
  regional_stats = read_rds(path_emissions) %>%
    filter(pollutant == .pollutant) %>%
    get_emissions_interpolated(year = myyear) %>%
    left_join(by = "geoid", y = read_rds(path_census_counties)) %>%
    left_join(by = "geoid", y = myregions %>%
                select(region, geoid)) %>%
    group_by(region) %>%
    summarize(across(.cols = any_of(c("emissions", "total_population", "median_income")), .f = ~sum(.x, na.rm = TRUE) ))
  
  joined = indicators %>% 
    left_join(by = "region", y = regional_stats)
  
  output = list(
    region_group_values = region_group_values,
    indicators = indicators,
    joined = joined
  )
  return(output)
  
}



get_overall = function(myyear = 2022, pollutant = 98, dist = 1000){
  
  # Testing values
  # myyear = 2022; pollutant = 2; dist = 1000
  
  # Run this script!
  data1 = get_all(
    myregions = read_rds("data/regions_ny_data.rds"), 
    myyear = myyear,
    .pollutant = pollutant,
    path_emissions = "test/emissions_all_pollutants.rds",
    path_area_roads = paste0("test/area_roads", dist, ".rds"),
    index = "age",
    myvars =  c("age_under_18", "age_18_34", "age_35_64", "age_65_and_over"))
  
  data1 %>%
    saveRDS(paste0("test/stat_age_", myyear, "_", dist, "_", pollutant, ".rds"))
  
  
  data2 = get_all(
    myregions = read_rds("data/regions_ny_data.rds"), 
    myyear = myyear,
    .pollutant = pollutant,
    path_area_roads = paste0("test/area_roads", dist, ".rds"),
    path_emissions = "test/emissions_all_pollutants.rds",
    index = "income",
    myvars =  c("income_0_24999", "income_25000_49999", "income_50000_74999", "income_75000_99999",
                "income_100000_124999", "income_125000_149999", "income_150000_199999", "income_200000_or_more" ))
  
  data2 %>%
    saveRDS(paste0("test/stat_income_", myyear, "_", dist, "_", pollutant, ".rds"))
  
  data3 = get_all(
    myregions = read_rds("data/regions_ny_data.rds"), 
    myyear = myyear,
    .pollutant = pollutant,
    path_area_roads = paste0("test/area_roads", dist, ".rds"),
    path_emissions = "test/emissions_all_pollutants.rds",
    index = "edu",
    myvars =  c("edu_less_than_hs", "edu_hs_grad", "edu_some_college_or_more", "edu_postgrad")
  ) 
  
  data3 %>%
    saveRDS(paste0("test/stat_edu_", myyear, "_", dist, "_", pollutant, ".rds"))
  
  data4 = get_all(
    myregions = read_rds("data/regions_ny_data.rds"), 
    myyear = myyear,
    .pollutant = pollutant,
    path_area_roads = paste0("test/area_roads", dist, ".rds"),
    path_emissions = "test/emissions_all_pollutants.rds",
    index = "race",
    myvars =  c(
      "White_alone_Not_Hispanic_or_Latino_Population",
      "Black_or_African_American_Not_Hispanic_or_Latino_Population",
      "American_Indian_and_Alaska_Not_Native_Hispanic_or_Latino_Population",
      "Asian_Not_Hispanic_or_Latino_Population",
      "Native_Hawaiian_and_Other_Pacific_Islander_Not_Latino_Population",
      
      "Asian_Hispanic_or_Latino_Population",
      "White_alone_Hispanic_or_Latino_Population",
      "Black_or_African_American_Hispanic_or_Latino_Population",
      "American_Indian_and_Alaska_Native_Hispanic_or_Latino_Population",
      "Native_Hawaiian_and_Other_Pacific_Islander_Latino_Population"
    )
  )
  
  data4 %>%
    saveRDS(paste0("test/stat_race_", myyear, "_", dist, "_", pollutant, ".rds"))
  
  total = bind_rows(
    data1$indicators,
    data2$indicators,
    data3$indicators,
    data4$indicators
  ) %>%
    group_by(region) %>%
    summarize(indicator2 = mean(indicator2, na.rm = TRUE), .groups = "drop") %>%
    mutate(type = "total")
  
  edu_vars = 
    output = bind_rows(
      data1$indicators,
      data2$indicators,
      data3$indicators,
      data4$indicators,
      total
    ) %>%
    mutate(pollutant = pollutant,
           dist = dist,
           year = myyear) %>%
    tidyr::pivot_wider(id_cols = c(year, pollutant, dist, region), names_from = type, values_from = indicator2)
  return(output)
}


get_twobars = function(data_regions = read_rds("data/regions_ny_data.rds"),
                       data_emissions = read_csv("test/emissions_all_pollutants.csv"),
                       data_equity = read_rds("test/stat_overall.rds"),
                       myyear = 2022,
                       .pollutant = 110,
                       xmin = 0
){
  data  = data_regions %>%
    left_join(by = c("geoid"),
              y = data_emissions %>% 
                filter(pollutant == .pollutant) %>%
                mutate(geoid = stringr::str_pad(geoid, width = 5, side = "left", pad = "0"))) %>%
    group_by(region, pollutant, year) %>%
    summarize(emissions = sum(emissions, na.rm = TRUE)) %>%
    ungroup() %>%
    group_by(region, pollutant) %>%
    summarize(emissions = lm(formula = emissions ~ year) %>% predict(newdata = tibble(year = myyear))) %>%
    left_join(by = "region", y = data_equity)
  
  
  # ggplot() +
  #   geom_point(data = data, mapping = aes(x = emissions, y= total))
  
  emissionsrange = -range(data$emissions) %>% rev() %>% {c(.[1] - 10, .[2] + 5)}
  
  g1 = ggplot() +
    geom_col(data = data, mapping = aes(x = reorder(region, -race), y = -emissions),
             fill = "#fcac34") +
    shadowtext::geom_shadowtext(
      data = data, 
      mapping = aes(x = reorder(region, -race), y = -emissions,
                    label = scales::number(emissions, accuracy = 0.1)),
      bg.r = 0.3, bg.color = "white", color = "black", hjust = 1
    ) +
    coord_flip() +
    theme_bw(base_size = 14) +
    theme(
      panel.grid = element_blank(),
      panel.border = element_blank(),
      axis.line.x = element_line(),
      
      axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      axis.title.y = element_blank()) +
    scale_y_continuous(oob = scales::oob_squish,
                       limits = emissionsrange, 
                       expand = expansion(c(0.1,0))) +
    labs(y = "Total PM2.5 Emissions (kilotons)")
  
  
  g2 = ggplot() +
    geom_col(data = data, mapping = aes(x = reorder(region, -race), y = race),
             position = "identity", fill = "#9608ab") +
    shadowtext::geom_shadowtext(
      data = data, 
      mapping = aes(x = reorder(region, -race), y = race,
                    label = scales::number(race, accuracy = 0.001)),
      bg.r = 0.3, bg.color = "white", color = "black", hjust = 0
    ) +
    coord_flip() +
    theme_bw(base_size = 14) +
    theme(
      panel.grid = element_blank(),
      panel.border = element_blank(),
      axis.line.x = element_line(),
      axis.text.y = element_text(hjust = 0.5),
      axis.ticks = element_blank(),
      axis.title.y = element_blank()
    ) +
    scale_y_continuous(
      oob = scales::oob_squish, limits = c(xmin, 1),
      expand = expansion(c(0,0.02))) +
    labs(y = "Race/Ethnicity Equity Index (0 to 1)")
  
  gg = ggpubr::ggarrange(
    plotlist = list(g1,g2), 
    align = "h", 
    widths = c(0.4,0.55))
  
  return(gg)
}


get_corr = function(data_regions = read_rds("data/regions_ny_data.rds"),
                       data_emissions = read_csv("test/emissions_all_pollutants.csv"),
                       data_equity = read_rds("test/stat_overall.rds"),
                       myyear = 2022,
                       .pollutant = 110,
                       xmin = 0
){
  data_regions %>%
    left_join(by = c("geoid"),
              y = data_emissions %>% 
                filter(pollutant == .pollutant) %>%
                mutate(geoid = stringr::str_pad(geoid, width = 5, side = "left", pad = "0"))) %>%
    group_by(region, pollutant, year) %>%
    summarize(emissions = sum(emissions, na.rm = TRUE)) %>%
    ungroup() %>%
    group_by(region, pollutant) %>%
    summarize(emissions = lm(formula = emissions ~ year) %>% predict(newdata = tibble(year = myyear))) %>%
    left_join(by = "region", y = data_equity) %>%
    ungroup()
}

get_corr(.pollutant = 110) %>%
  summarize(r = cor(emissions, race, use = "pairwise.complete.obs"))

get_sensitivity_distance1 = function(
    sensitivity_data = read_rds("test/stat_overall_sensitivity.rds"),
    .pollutant = 110,
    .year = 2022){
  # How much do things change by distance?
  data = sensitivity_data %>%
    filter(pollutant == .pollutant) %>%
    filter(year == .year) %>% 
    group_by(region) %>%
    mutate(ymin = min(total, na.rm = TRUE))
  
  #.pollutant = 110
  gg = ggplot() +
    geom_point(
      data = data,
      mapping = aes(x = reorder(region, -ymin), y = total, color = factor(dist/1000)), size = 5) +
    geom_line(
      data = data,
      mapping = aes(x = reorder(region, -ymin), y = total, color = factor(dist/1000), group = factor(dist)), linewidth = 1.2) +
    coord_flip() +
    theme_bw(base_size = 14) +
    theme(axis.ticks = element_blank()) +
    theme(legend.position = c(0.2, 0.25)) +
    theme(panel.grid.minor.y = element_blank(), 
          panel.grid.major.y = element_blank()) +
    viridis::scale_color_viridis(option = "plasma", begin = 0.2, end = 0.8, discrete = TRUE, direction = 1) +
    labs(color = 'Exposure Zone\nRadius (km)', x = NULL, y = "Overall Equity Index (1 = perfectly even exposure)",
         title = "Sensitivity of Regional Equity Patterns",
         subtitle = "to changes in Exposure Zone Radius")
  return(gg)
  
}
get_sensitivity_distance2 = function(
    sensitivity_data = read_rds("test/stat_overall_sensitivity.rds"),
    .pollutant = 110,
    .year = 2022){
  
  # Testing values
  # sensitivity_data = read_rds("test/stat_overall_sensitivity.rds"); .pollutant = 110; .year = 2022
  
  data = sensitivity_data %>%
    filter(pollutant == .pollutant) %>%
    filter(year == .year) 
  
  lm(formula = total ~ log(dist/1000), data = data) %>% broom::tidy()
  lm(formula = total ~ log(dist/1000), data = data) %>% broom::glance()
  
  gg = ggplot() +
    geom_line(data = data, mapping = aes(x = dist/1000, y = total, group = region),
              color = "grey") +
    geom_point(data = data, mapping = aes(x = dist/1000, y = total), size = 3, color = "grey") +
    geom_smooth(data = data, mapping = aes(x = dist/1000, y = total),
                method = "lm", formula = y ~ log(x), color = "#DC267F", fill = "#DC267F33") +
    theme_bw(base_size = 14) +
    theme(axis.ticks = element_blank(),
          panel.grid.minor = element_blank()) +
    scale_y_continuous(n.breaks = 9) +
    labs(x = "Exposure Zone Buffer Radius (km)",
         y = "Overall Equity Index (0-1)")
  return(gg)
  
}


get_sensitivity_distance3 = function(
    sensitivity_data = read_rds("test/stat_overall_sensitivity.rds"),
    .metric = "total",
    pollutants = c(pm = 110, pm10 = 100, co2 = 98,  so2 = 31, nox = 3),
    .pollutant = 110,
    .year = 2022){
  
  # Show bands of variation
  data = sensitivity_data %>% 
    filter(year == .year) %>%
    filter(pollutant %in% pollutants)  %>%
    rename(y = any_of(.metric)) %>%
    mutate(dist = dist / 1000) %>%
    group_by(dist, region) %>%
    summarize(ymin = min(y, na.rm = TRUE),
              ymax = max(y, na.rm = TRUE),
              ymain = y[pollutant == 110])
  
  # How much do things change by distance?
  # data = sensitivity_data %>%
  #   filter(pollutant == .pollutant) %>%
  #   filter(year == .year) %>% 
  #   group_by(region) %>%
  #   mutate(ymin = min(total, na.rm = TRUE))
  
  #.pollutant = 110
  gg = ggplot() +
    geom_ribbon(
      data = data,
      mapping = aes(x = reorder(region, -ymin),
                    ymin = ymin, ymax = ymax, group = factor(dist), 
                    fill = factor(dist)),
      alpha = 0.5) +
    geom_point(
      data = data,
      mapping = aes(x = reorder(region, -ymin), y = ymain, color = factor(dist/1000)), size = 3) +
    geom_line(
      data = data,
      mapping = aes(x = reorder(region, -ymin), y = ymain, color = factor(dist/1000), group = factor(dist)), linewidth = 1.2) +
    coord_flip() +
    theme_bw(base_size = 14) +
    theme(axis.ticks = element_blank()) +
    theme(legend.position = c(0.2, 0.25)) +
    theme(panel.grid.minor.y = element_blank(), 
          panel.grid.major.y = element_blank()) +
    viridis::scale_fill_viridis(option = "plasma", begin = 0.2, end = 0.8, discrete = TRUE, direction = 1) +
    viridis::scale_color_viridis(option = "plasma", begin = 0.2, end = 0.8, discrete = TRUE, direction = 1, guide = "none") +
    labs(fill = 'Exposure Zone\nRadius (km)', x = NULL, y = "Overall Equity Index (1 = perfectly even exposure)",
         color = NULL,
         title = "Sensitivity of Regional Equity Patterns",
         subtitle = "to changes in Exposure Zone Radius")
  return(gg)
}
get_map = function(path_shapes_counties, path_shapes_roads, path_shapes_tracts, path_shapes_buffers, path_area_roads){
  
  library(ggplot2, warn.conflicts = FALSE, quietly = TRUE)
  library(sf, warn.conflicts = FALSE, quietly = TRUE)
  
  counties = read_rds(path_shapes_counties)
  roads = read_rds(path_shapes_roads)  %>%
    group_by(geoid) %>%
    mutate(geometry = geometry %>% st_collection_extract("LINESTRING", warn = FALSE) %>% st_combine() %>% st_cast("MULTILINESTRING")) %>%
    ungroup()
  
  
  tracts = read_rds(path_shapes_tracts)
  buffers = read_rds(path_shapes_buffers)
  
  highlight1 = counties %>%
    filter(geoid == "36001")
  
  bb = st_bbox(highlight1) %>% as.list()
  bbox = st_bbox(highlight1) %>% st_as_sfc() %>% st_as_sf()
  
  # Find us an interesting geoid
  highlight2 = read_rds(path_area_roads) %>%
    select(geoid, geoid_county, area_total, area_roads, geometry) %>%
    filter(geoid_county == "36001") %>%
    mutate(percent = area_roads / area_total) %>%
    filter(geoid == "36001014803")
  
  
  labels = read_rds(path_area_roads) %>%
    select(geoid, geoid_county, area_total, area_roads, geometry) %>%
    filter(geoid_county == "36001") %>%
    mutate(percent = scales::percent(area_roads / area_total, accuracy = 1))
  
  # View road buffers vs counties
  gg1 = ggplot() +
    geom_sf(data = counties, fill = "white", color = "black") +
    geom_sf(data = roads,  linewidth = 0.1, mapping = aes(color = "roads")) +
    geom_sf(data = tracts, color = 'grey', fill = NA, linewidth = 0.1) +
    geom_sf(data = st_as_sf(buffers), fill = "red", alpha = 0.25, color = NA) +
    geom_sf(data = counties, fill = NA, color = "#373737", linewidth = 0.25, alpha = 0.75) +
    geom_sf(data = highlight1, fill = NA, linewidth = 1.5, alpha = 0.75, mapping = aes(color = "albany")) +
    theme_bw(base_size = 14) +
    theme_void(base_size = 14) +
    theme(plot.title = ggtext::element_markdown(size = 14, hjust = 0.5),
          legend.position = "bottom") +
    ggspatial::annotation_north_arrow(height = unit(0.5, "cm"), width = unit(0.5, "cm"), pad_y = unit(15, "cm")) +
    ggspatial::annotation_scale() +
    labs(title = "<b>New York State Roadways</b><br>by County and Census Tract Boundaries",
         fill = NULL, color = NULL) +
    scale_color_manual(
      values = c("black", "red"),
      breaks = c("albany", "roads"),
      labels = c("Albany County", "Primary/Secondary Roads")
    )
  
  #gg1
  # ggsave(gg, filename = "test/plot.png", dpi = 300, width =10, height = 10)
  # browseURL("test/plot.png")
  
  # gg +
  #   coord_sf(xlim = c(-73.5,-74.5), ylim = c(42.25,43))
  
  # tracts %>%
  #   filter(geoid_county == "36001")
  #counties %>% head()
  
  
  gg2 = ggplot() +
    geom_sf(data = counties %>% st_join(bbox, left = FALSE), fill = "white", color = "black") +
    geom_sf(data = roads %>% st_join(bbox, left = FALSE), linewidth = 0.3, mapping = aes(color = "roads"), color = "red", alpha = 0.75, show.legend = FALSE) +
    geom_sf(data = tracts %>% st_join(bbox, left = FALSE), color = 'grey', fill = NA, linewidth = 0.1) +
    geom_sf(data = st_as_sf(buffers) %>% st_join(bbox, left = FALSE),  alpha = 0.25, color = NA, mapping = aes(fill = "buffer")) +
    geom_sf(data = counties %>% st_join(bbox, left = FALSE), fill = NA, color = "#373737", linewidth = 1, alpha = 0.75) +
    geom_sf(data = highlight2, fill = NA, linewidth = 2.5, mapping = aes(color = "tract")) +
    geom_sf(data = highlight1, fill = NA, linewidth = 2, mapping = aes(color = "albany"), color = "black", show.legend = FALSE) +
    geom_sf_text(data = labels, mapping = aes(label = percent), check_overlap = TRUE) +
    coord_sf(xlim = c(bb$xmin, bb$xmax), ylim = c(bb$ymin,bb$ymax)) +
    scale_color_manual(
      values = c("grey"),
      breaks = c("tract"),
      labels = c("Tract 014803")
      #labels = c(NA, "Tract 014803", NA)
    ) +
    # scale_color_manual(
    #   values = c("black", "grey", "red"),
    #   breaks = c("albany", "tract", "roads"),
    #   labels = c("Albany County", "Tract 014803", "Primary/Secondary Roads")
    #   #labels = c(NA, "Tract 014803", NA)
    # ) +
    scale_fill_manual(values = "red",
                      breaks = c("buffer"),
                      labels = c("Exposure Zone")) +
    theme_void(base_size = 14) +
    theme(plot.title = ggtext::element_markdown(size = 14, hjust = 0.5),
          panel.border = element_rect(fill = NA, color = "#373737")) +
    ggspatial::annotation_scale() +
    labs(title = "<b>% Area of Road-Adjacent Emissions Exposure</b><br>for Census Tracts in Albany County",
         fill = NULL, color = NULL) +
    theme(legend.position = "bottom") 
  #guides(color = guide_legend(override.aes = list(color = c("grey"))))
  
  
  #gg2
  #gg2
  
  gg = ggpubr::ggarrange(plotlist = list(gg1,gg2), ncol = 2, labels = c("A", "B"), common.legend = FALSE, legend = "bottom")
  return(gg)
}

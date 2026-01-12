


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
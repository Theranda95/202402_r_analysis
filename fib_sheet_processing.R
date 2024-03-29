## Load Packages --------------------------------------
install.packages("readxl")
install.packages("dplyr")
library(readxl)
library(dplyr)
library(ggbeeswarm) #needed for graphing 
library(ggplot2) #needed for graphing 
library(ggpubr)
library(purrr) #needed for function map 
library(stringr) #needed for extracting names from a string 
##-----------------------------------------------------
#This is draft 1 of my script to prepare data sheets for plotting of fibrillarin data. 
#1. Step 1: Importing fib volume spreadsheet and getting total puncta volume per nucleus  
#2. Step 2: Import the other two spreadsheets, processing and merging them together
#3. Step 3: Creating the number of nuclei for each x number of fib puncta
#4. Step 4: Creating new columns with identifiers from each image (Condition, Genotype, Image)
#5. Step 5: Creating a function to do this for all of the spreadsheets 
#6. Step 6: Creating averages and saving into a new spreadsheet - another function 
###----------Make the code above into a function -------------------------------

# Data is separated into different folders and each folder has three .csv files with common 
# identifiers fib_vol, vol_ratio and nuc_num_foci. Each folder name has three identifiers: genotype, 
# condition and image. 

#Turning the above steps into a function 
#Nested function 

#####Function trial 1 
process_folder <- function(folder_path) {
  setwd(folder_path)
  folder_name <- basename(folder_path)
  file_list <- list.files(pattern = "*.csv")
  
    for (file in file_list) { 
      if (grepl("fib_vol",file, ignore.case = TRUE)) {
      # Import spreadsheet without the first two rows
      data <- read.csv(file, skip = 3)
      
      # Rename columns and perform necessary operations
      data <- data %>%
        rename(fib_vol = Nucleus.Volume, nuc_id = CellID) %>%
        mutate(nuc_id = as.integer(nuc_id))
      
      data1 <- data %>%
        group_by(nuc_id) %>%
        summarise(fib_tot_vol = sum(as.numeric(fib_vol, na.rm = TRUE)))
    } else if (grepl("nuc_num_foci", file, ignore.case = TRUE)) {
      data2 <- read.csv(file, skip = 3) %>%
        rename(fib_count = Cell.Number.Of.Nuclei, nuc_id = ID)
    } else if (grepl("vol_ratio", file, ignore.case = TRUE)) {
      data3 <- read.csv(file, skip = 3) %>%
        rename(fib_nuc_ratio = Cell.Nucleus.to.Cytoplasm.Volume.Ratio, nuc_id = ID)
    }
  }
  
  # Combine the processed data frames
  final_data <- left_join(data2, data1, by = "nuc_id") %>%
    left_join(data3, by = "nuc_id") %>%
    select(-2:-4, -6, -9:-12) %>%
    mutate(fib_ave_vol = fib_tot_vol / fib_count) %>%
    mutate(
      condition = str_extract(folder_name, "(?<=_)[^_]+"),  # Extracts text after the first underscore
      genotype = str_extract(folder_name, "^[^_]+"),          # Extracts text before the first underscore
      image = str_extract(folder_name, "(?<=_)[^_]+$")        # Extracts text after the last underscore
    )
  
  # Create a spreadsheet that stores the number of nuclei with the same number of fib puncta 
  count_puncta <- final_data %>%
    group_by(condition, genotype, image, fib_count) %>%  # Group by these variables
    count(name = "count")  # Include the folder name in the output
  
  #count_puncta <- final_data %>%
    #count(folder_name, fib_count, name = "count")  # Include the folder name in the output
  
  # Create a spreadsheet with average numbers for each of the columns from cleaned_data spreadsheet 
  #Need to fix the code
  return(list(final_data = final_data, count_puncta = count_puncta))
}

# Specify the main folder containing subfolders with CSV files
main_folder <- "/Users/therandajashari/Documents/experiments_2024/20240124_comb_seq_comparisons/240124_fibrillarin/2402_spreadsheets"

# Get a list of subfolders
subfolders <- list.dirs(main_folder, recursive = FALSE)

# Calling the function process_folder
result_list <- lapply(subfolders, process_folder)

# Combine final_data data frames from all subfolders
all_data_grouped <- bind_rows(result_list %>% map("final_data"))
# Combine count_puncta data frames from all subfolders
all_puncta_grouped <- bind_rows(result_list %>% map("count_puncta"))

# Save the master spreadsheets
write.csv(all_data_grouped, file = "all_data_grouped.csv", row.names = FALSE)
write.csv(all_puncta_grouped, file = "all_puncta_grouped.csv", row.names = FALSE)

# Create and save average spreadsheets for each column - not really what this is doing 
##Need to check and understand it better! 
average_data <- all_data_grouped %>%
  group_by(condition, genotype, image) %>%
  summarise(across(starts_with("fib_"), mean, na.rm = TRUE))

for (subfolder in subfolders) {
  folder_name <- basename(subfolder)
  subfolder_average_data <- average_data %>%
    filter(condition == str_extract(folder_name, "(?<=_)[^_]+"),
           genotype == str_extract(folder_name, "^[^_]+"),
           image == str_extract(folder_name, "(?<=_)[^_]+$"))
  write.csv(subfolder_average_data, file = paste0(subfolder, "/average_data.csv"), row.names = FALSE)
}

# Combine average data frames from all subfolders
all_average_data <- bind_rows(result_list %>% map("average_data"))

# Save the master average spreadsheet
write.csv(average_data, file = "all_average_data.csv", row.names = FALSE)


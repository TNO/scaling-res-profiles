using DataFrames
using Dates
using CSV
using Statistics
using Pipe

# input parameters
input_file = "./inputs/list_of_files_to_scale.csv"
results_file = "./inputs/target_capacity_factors_pv.csv"
date_key = "date"
year_key = "year"
future_year_key = 2050
date_format = "y-m-d HH:MM:SS"

# read the input file
df_input_file = DataFrame(CSV.File(input_file))

# helper functions
"""
    get_input_data(df_input_file,row_number)
TBW
"""
function get_input_data(df_input_file,row_number)

    # get the input data
    file_name       = "./inputs/" * df_input_file[row_number,:file_name]
    header_row      = df_input_file[row_number,:header_row]
    time_column_key = df_input_file[row_number,:time_column_key]
    data_column_key = df_input_file[row_number,:data_column_key]

    # Load the data
    df = DataFrame(CSV.File(file_name, header=header_row))

    # Create a column with the year using DateTime
    df[!,year_key] = Dates.year.(Dates.DateTime.(df[!,time_column_key],Dates.DateFormat(date_format)))

    # get mean value by year using Pipe package
    df_grouped_by_year = @pipe df |>
                            groupby(_,year_key) |>
                            combine(_,data_column_key => mean, renamecols=false) 
    return df_grouped_by_year
end


"""
    calculate_future_capacity_factor(df_grouped_by_year,future_capacity_factors)

TBW
"""
function calculate_future_capacity_factor(df_grouped_by_year,df_input_file,row_number)

    # get the input data
    data_column_key = df_input_file[row_number,:data_column_key]
    min_target_cp   = df_input_file[row_number,:min_target_cp]
    max_target_cp   = df_input_file[row_number,:max_target_cp]

    # get the maximum and minimum capacity factors
    min_historical_capacity_factor = minimum(df_grouped_by_year[!,data_column_key])
    max_historical_capacity_factor = maximum(df_grouped_by_year[!,data_column_key])

    # determine the slope and intercept of the linear function
    slope = (max_target_cp - min_target_cp) / (max_historical_capacity_factor - min_historical_capacity_factor)
    intercept = min_target_cp - slope * min_historical_capacity_factor

    # Calculate the new values
    new_col = DataFrame(Symbol(future_year_key) => slope .* df_grouped_by_year[!,data_column_key] .+ intercept)

    # add the scaled profile to the DataFrame
    df_grouped_by_year = hcat(df_grouped_by_year,new_col)

    # drop the original column
    select!(df_grouped_by_year, Not(data_column_key))

    return df_grouped_by_year
end

# for each row in the input file
for row_number in 1:nrow(df_input_file)

    # get the input data
    df_grouped_by_year = get_input_data(df_input_file,row_number)

    # use the function to calculate the future capacity factors
    df_results = calculate_future_capacity_factor(df_grouped_by_year,df_input_file,row_number)

    #outputs file name
    output_file_name = "./inputs/target_cp_"*df_input_file[row_number,:data_column_key]*"_"*df_input_file[row_number,:file_name]

    # save the results to a csv file
    CSV.write(output_file_name,df_results)
end

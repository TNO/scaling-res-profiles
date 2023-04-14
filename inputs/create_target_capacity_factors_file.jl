using DataFrames
using Dates
using CSV
using Statistics
using Pipe

# input parameters
input_file = "./inputs/ninja_pv_country_NL_merra-2_corrected.csv"
input_file_header_row = 3
results_file = "./inputs/target_capacity_factors_pv.csv"
date_key = "date"
date_format = "y-m-d HH:MM:SS"
time_key = "time"
year_key = "year"
data_key = "national"

# dictionary with future capacity factor maximum and minimum values
future_capacity_factors = Dict{Int64, Dict{String, Float64}}(
                            2050 => Dict("min" => 0.15, "max" => 0.18)
                            )

# helper functions
"""
    calculate_future_capacity_factor(df_grouped_by_year,future_capacity_factors)

TBW
"""
function calculate_future_capacity_factor(df_grouped_by_year,future_capacity_factors)

    # get the maximum and minimum capacity factors
    min_historical_capacity_factor = minimum(df_grouped_by_year[!,data_key])
    max_historical_capacity_factor = maximum(df_grouped_by_year[!,data_key])

    for (year, future_capacity_factor) in future_capacity_factors
        # determine the slope and intercept of the linear function
        slope = (future_capacity_factor["max"] - future_capacity_factor["min"]) / (max_historical_capacity_factor - min_historical_capacity_factor)
        intercept = future_capacity_factor["min"] - slope * min_historical_capacity_factor

        # Calculate the new values
        new_col = DataFrame(Symbol(year) => slope .* df_grouped_by_year[!,data_key] .+ intercept)

        # add the scaled profile to the DataFrame
        df_grouped_by_year = hcat(df_grouped_by_year,new_col)
   
    end

    # drop the original column
    select!(df_grouped_by_year, Not(data_key))

    return df_grouped_by_year
end


# Load the data
df = DataFrame(CSV.File(input_file, header=input_file_header_row))

# Create a column with the year using DateTime
df[!,year_key] = Dates.year.(Dates.DateTime.(df[!,time_key],Dates.DateFormat(date_format)))

# get mean value by year using Pipe package
df_grouped_by_year = @pipe df |>
                        groupby(_,year_key) |>
                        combine(_,data_key => mean, renamecols=false) 


# use the function to calculate the future capacity factors
df_results = calculate_future_capacity_factor(df_grouped_by_year,future_capacity_factors)

# save the results to a csv file
CSV.write(results_file,df_results)

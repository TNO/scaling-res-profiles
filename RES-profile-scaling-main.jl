## Step 0: Activate environment - ensure consistency accross computers
using Pkg
Pkg.activate(@__DIR__) # @__DIR__ = directory this script is in
Pkg.instantiate() # Download and install this environments packages
Pkg.precompile() # Precompiles all packages in environemt

using DataFrames
using Dates
using CSV
using JuMP
using Plots
using Statistics
using AmplNLWriter, Bonmin_jll
using TOML
using Pipe

printstyled("Including the external scripts", color=Base.info_color(), bold=true)
include("constants.jl") # Include the constants script
include("functions.jl") # Include the functions script

print_message("Reading the data", level=1)
print_message("Activating the environment", level=2)

##  Step 1: Parse the input data configuration file
@time begin
    print_message("Parsing the config file")
    
    data = TOML.parsefile(CONFIG_FILE_NAME)
    inputs     = data[INPUTS_CONFIG_KEY]
    outputs    = data[OUTPUT_CONFIG_KEY]
    
    print_message("Elapsed time parsing input data", level=2)
end

## Step 2: Wrangle the data
@time begin
    print_message("Wrangling the input data")

    df = input_data_wrangle(inputs)

    df_targets, historical_years, future_years = target_data_wrangle(inputs)

    print_message("Elapsed time wrangling data", level=2)
end

## Step 3: Loop over the historical years and scale the profile for each future year
@time begin
    print_message("Scaling the profiles")

    df_scaled, df_summary = scale_profiles(df, df_targets, historical_years, future_years, inputs)

    print_message("Elapsed time scaling profiles", level=2)
end

## Step 4: Save the data
@time begin
    print_message("Saving the data")

    dir = outputs[OUTPUT_DIR_KEY]
    name_scaled_file  = "scaled_"*inputs[RES_PROFILE_CONFIG_KEY][DATA_KEY]*"_"*inputs[RES_PROFILE_CONFIG_KEY][NAME]
    name_summary_file = "summary_"*inputs[RES_PROFILE_CONFIG_KEY][DATA_KEY]*"_"*inputs[RES_PROFILE_CONFIG_KEY][NAME]
    
    # Save the scaled data
    path = append_dir(dir, name_scaled_file)
    CSV.write(path, df_scaled)

    # Save the summary data
    path = append_dir(dir, name_summary_file)
    CSV.write(path, df_summary)

    print_message("Elapsed time saving data", level=2)
end

## Step 5: Plot the data
@time begin
    print_message("Plotting the data")

    # Plot the scaled data
    plot_profiles(df_scaled, historical_years, future_years, inputs, outputs)

    print_message("Elapsed time plotting data", level=2)
end

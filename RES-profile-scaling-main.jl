# Activate environment - ensure consistency accross computers
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

# Parse the input data configuration file
@time begin
    print_message("Parsing the config file")
    
    data = TOML.parsefile(CONFIG_FILE_NAME)
    inputs     = data[INPUTS_CONFIG_KEY]
    outputs    = data[OUTPUT_CONFIG_KEY]

    # Get the directory and the name of the file
    dir       = inputs[INPUTS_DIR_KEY]
    file_name = inputs[RES_PROFILE_CONFIG_KEY][INPUTS_LIST_OF_FILES]

    # Create the full path
    path = append_dir(dir, file_name)

    df_input_list_of_files = DataFrame(CSV.File(path))
    
    print_message("Elapsed time parsing input data", level=2)
end

# main loop to scale the files
@time begin
    for row in 1:nrow(df_input_list_of_files)
        print_message("Scaling file: "*df_input_list_of_files[row,:file_name], level=1)
        
        # update the input data information
        inputs[RES_PROFILE_CONFIG_KEY][NAME] = df_input_list_of_files[row,:file_name]
        inputs[RES_PROFILE_CONFIG_KEY][HEADER_ROW] = df_input_list_of_files[row,:header_row]
        inputs[RES_PROFILE_CONFIG_KEY][TIME_KEY] = df_input_list_of_files[row,:time_column_key]
        inputs[RES_PROFILE_CONFIG_KEY][DATA_KEY] = df_input_list_of_files[row,:data_column_key]

        # uptade target_values file name
        inputs[TARGETS_CONFIG_KEY][NAME] = "target_cp_"*inputs[RES_PROFILE_CONFIG_KEY][DATA_KEY]*"_"*inputs[RES_PROFILE_CONFIG_KEY][NAME]

        # scale the list of profile files
        scale_list_of_profile_files(inputs, outputs)

    end
end

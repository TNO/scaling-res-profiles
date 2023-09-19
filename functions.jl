
"""
    print_message(text::String; level::Int=3)

Prints a message to the console. The level parameter determines the style of the message.
"""
function print_message(text::String; level::Int=3)
    if level == 1
        println()
        printstyled(text, color=Base.info_color(), bold=true)
        println()
    elseif level == 2
        println()
        printstyled(text, bold=true)
        println()
    elseif level == 3
        println(text)
    else
        println(text)
    end
end

"""
    append_dir(folder_name::String,file_name::String)
    
Joins a path and a file name into a full path.
"""
function append_dir(folder_name::String,file_name::String)
    return joinpath(".",folder_name, file_name)
end

"""
    input_data_wrangle(inputs::Dict{String,Any})

read input data from a csv file and wrangle it into a DataFrame
"""
function input_data_wrangle(inputs::Dict{String,Any})

    dir      = inputs[INPUTS_DIR_KEY]
    name     = inputs[RES_PROFILE_CONFIG_KEY][NAME]
    row      = inputs[RES_PROFILE_CONFIG_KEY][HEADER_ROW]
    time_key = inputs[RES_PROFILE_CONFIG_KEY][TIME_KEY]

    # Create the full path
    path = append_dir(dir, name)

    # Load the data
    df = DataFrame(CSV.File(path, header=row))

    # Convert the time column to a DateTime type
    df[!,DATE_KEY] = Dates.DateTime.(df[!,time_key],Dates.DateFormat(DATE_FORMAT))

    # Create a column with the year
    df[!,YEAR_KEY] = Dates.year.(df[!,DATE_KEY])

    # Create a column with the hour of the year
    df[!,HOUR_OF_YEAR_KEY] = Dates.Hour.((df[!,DATE_KEY] .- Dates.firstdayofyear.(df[!,DATE_KEY]))) .÷ Dates.Hour(1) .+ 1

    return df
end

"""
    target_data_wrangle(inputs::Dict{String,Any})

read input target data from a csv file and wrangle it into a DataFrame
"""
function target_data_wrangle(inputs::Dict{String,Any})

    dir      = inputs[INPUTS_DIR_KEY]
    name     = inputs[TARGETS_CONFIG_KEY][NAME]
    row      = inputs[TARGETS_CONFIG_KEY][HEADER_ROW]
    year_key = inputs[TARGETS_CONFIG_KEY][HISTORICAL_YEAR_KEY]

    # Create the full path
    path = append_dir(dir, name)

    # Load the data
    df = DataFrame(CSV.File(path, header=row))

    # Get historical years
    historical_years = unique(df[!,year_key])

    # Get future years
    future_years = names(select(df,Not(year_key)))

    return df, historical_years, future_years
end

"""
    scale_profiles(df::DataFrame,
                   df_targets::DataFrame,
                   historical_years::Vector,
                   future_years::Vector,
                   inputs::Dict{String,Any})

Function scale_profiles takes the input data from DataFrames, two vectors of historical and future years,
a dictionary with the inputs information, and iterates over the historical and future years to scale a profile column.
It uses the get_profile_to_scale function to get the profile to scale, runs an optimization model, calculates the scaled profile,
and adds the scaled profile and summary results to output DataFrames.
It then sorts the output DataFrame by the hour of the year column and returns the output DataFrames.
"""
function scale_profiles(df::DataFrame,
                        df_targets::DataFrame,
                        historical_years::Vector,
                        future_years::Vector,
                        inputs::Dict{String,Any})
    
    # Outputs DataFrames
    df_scaled = DataFrame()
    df_summary = DataFrame()

    # get the key for the data
    profile_key = inputs[RES_PROFILE_CONFIG_KEY][DATA_KEY]
    historical_year_key = inputs[TARGETS_CONFIG_KEY][HISTORICAL_YEAR_KEY]

    # Loop over the historical years
    for historical_year in historical_years

        # Get the profile to scale
        df_filt, profile_values, profile_mean, total_hours = get_profile_to_scale(df, historical_year, inputs)
    
        # Loop over the future years
        for future_year in future_years
            
            text_to_print = "Scaling historical year "*string(historical_year)*" to future year "*string(future_year)*"\n"
            print_message(text_to_print, level=2)

            # get the target cp for the future year
            target_cp = df_targets[df_targets[!,historical_year_key] .== historical_year, string(future_year)][1]

            # Create a model
            model, coefficient = run_optimisation(profile_values,total_hours,target_cp)

            text_to_print = "Objective function value: "*string(objective_value(model))*"\n"
            print_message(text_to_print, level=2)

            # Calculate the scaled profile
            new_col = DataFrame(Symbol(future_year) => df_filt[!,profile_key].^coefficient)

            # add the scaled profile to the DataFrame
            df_filt = hcat(df_filt,new_col)
            
            # save a summary in a df
            df_summary_future_year =
                DataFrame(
                    historical_year=[historical_year],
                    future_year    =[future_year],
                    initial_cp     =[profile_mean],
                    final_cp       =[mean(df_filt[!,future_year])],
                    target_cp      =[target_cp],
                    status         =[termination_status(model)]   
                )     

            # add the summary results to the DataFrame
            df_summary = vcat(df_summary,df_summary_future_year)

        end

        # add the scaled profiles to the output DataFrame
        df_scaled = vcat(df_scaled,df_filt)
    end

    # drop the date column
    select!(df_scaled, Not(DATE_KEY))    

    return df_scaled, df_summary
end

"""
    get_profile_to_scale(df::DataFrame, historical_year::Int, inputs::Dict{String,Any})

This function takes a DataFrame, filters it by a specified year, orders it by a specified profile column,
calculates the total hours and mean value of the profile column, and returns the filtered DataFrame, 
profile values to scale, profile mean, and total hours as a tuple.
"""
function get_profile_to_scale(df::DataFrame, historical_year::Int, inputs::Dict{String,Any})
    
    # get the profile key
    profile_key = inputs[RES_PROFILE_CONFIG_KEY][DATA_KEY]
    
    # filters the data to the year historical_year
    df_filt = df[df[!,YEAR_KEY] .== historical_year,:]

    # get the total hours in the year
    total_hours = maximum(df_filt[!,HOUR_OF_YEAR_KEY])

    # get the mean value of the profile
    profile_mean = mean(df_filt[!,profile_key])

    # get the profile values to scale
    profile_values = df_filt[!,profile_key]

    return df_filt, profile_values, profile_mean, total_hours
end

"""
    run_optimisation(profile_values::Vector{Float64},total_hours::Int,target_mean::Float64)

This function takes a vector of profile values and the total hours in the year.
It scales the profile values to the mean value of the profile and the total hours
in the year. It returns the optimization model and the coefficient of the scaling.
"""
function run_optimisation(profile_values::Vector{Float64},total_hours::Int,target_mean::Float64)
    
    # Create a model
    model = Model(() -> AmplNLWriter.Optimizer(Bonmin_jll.amplexe))

    #set_attribute(model, "nlp_log_level", 0)
    
    # Create a variable for the whole year
    @variable(model, x >= 0)

    # Create the objective function
    @NLobjective(model, Min, (sum((profile_values[i])^x for i in 1:total_hours) - target_mean*total_hours)^2)

    # print the Model
    #print(model)

    # Solve the model
    optimize!(model)

    # Get the solution
    coefficient = value.(x)
    
    # Return the model solution
    return model, coefficient
    
end


"""
    scale_profiles(df::DataFrame,
                   historical_years::Vector,
                   future_years::Vector,
                   inputs::Dict{String,Any},
                   outputs::Dict{String,Any})

Function plot_profiles takes as input data the DataFrame with the results, two vectors of historical and future years,
a dictionary with the inputs and outputs information, and iterates over the historical and future years to the profiles.
It then plots the profiles and saves the plots to the outputs folder.
"""
function plot_profiles(df::DataFrame,
                       historical_years::Vector,
                       future_years::Vector,
                       inputs::Dict{String,Any},
                       outputs::Dict{String,Any})
    
    # hours of the year to plot
    first_hour   = outputs[OUTPUT_FIRST_HOUR_PLOT]
    last_hour    = outputs[OUTPUT_LAST_HOUR_PLOT]
    display_plot = outputs[OUTPUT_DISPLAY_PLOT]

    # information from the inputs                      
    dir = outputs[OUTPUT_DIR_KEY]
    plot_name_suffix  = inputs[RES_PROFILE_CONFIG_KEY][DATA_KEY]*"_"*inputs[RES_PROFILE_CONFIG_KEY][NAME]

    # get the key for the data
    profile_key = inputs[RES_PROFILE_CONFIG_KEY][DATA_KEY]
    historical_year_key = inputs[TARGETS_CONFIG_KEY][HISTORICAL_YEAR_KEY]

    # Loop over the future years
    for future_year in future_years

        text_to_print = "Plotting profiles for future year "*string(future_year)*"\n"
        print_message(text_to_print, level=2)

        # create an empty plot
        p = plot()

        # Loop over the historical years
        for historical_year in historical_years

            # filter the df by the historical year
            df_filt = df[df[!,historical_year_key] .== historical_year,:]

            # if it is the last historical year, plot with a different label, color, and linewidth
            if historical_year == maximum(historical_years)
                plot!(df_filt[!,profile_key][first_hour:last_hour], label="unscaled", color=:grey, linewidth=2)
                plot!(df_filt[!,future_year][first_hour:last_hour], label="scaled", color=:blue, linewidth=2)
            else
                plot!(df_filt[!,profile_key][first_hour:last_hour], label="", color=:lightgrey, linewidth=0.5)
                plot!(df_filt[!,future_year][first_hour:last_hour], label="", color=:lightblue, linewidth=0.5)
            end
            
        end

        # name of the plot file
        name_plot_file = "summary_plot_"*string(future_year)*"_"*plot_name_suffix*".png"

        # Save the scaled data
        path = append_dir(dir, name_plot_file)

        plot!(size=(800,800),
              dpi=600,
              xlabel="Hour",
              ylabel="Availability p.u.",
              title="Scaled profiles for future year "*string(future_year),
              ylims=(0,1),
              #legend = :outertopright
             )
        
        # display and save
        if display_plot
            display(p)
        end
        savefig(p,path)

    end
end


"""
    scale_list_of_profile_files(inputs,outputs)

Function to scale a list of profile files.
"""
function scale_list_of_profile_files(inputs,outputs)
    
    name = inputs[RES_PROFILE_CONFIG_KEY][NAME]
    
    # Wrangle the data
    print_message("Wrangling the input data for " * name)

    df = input_data_wrangle(inputs)

    df_targets, historical_years, future_years = target_data_wrangle(inputs)

    print_message("Elapsed time wrangling data", level=2)

    # Loop over the historical years and scale the profile for each future year
    print_message("Scaling the profiles for " * name)

    df_scaled, df_summary = scale_profiles(df, df_targets, historical_years, future_years, inputs)

    print_message("Elapsed time scaling profiles", level=2)

    # Save the data
    print_message("Saving the data for " * name)

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

    # Plot the data
    print_message("Plotting the data for " * name)

    # Plot the scaled data
    plot_profiles(df_scaled, historical_years, future_years, inputs, outputs)

    print_message("Elapsed time plotting data", level=2)
end

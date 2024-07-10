# Nonlinear programming (NLP) model to scale Renewable Energy Sources (RES) profiles
This repository has an NLP optimization model to scale RES profiles from historical data to future target capacity factor.

An improved version of this methodology is available as a Julia package in the following link: [https://github.com/TulipaEnergy/TulipaProfileFitting.jl](https://github.com/TulipaEnergy/TulipaProfileFitting.jl)

## Files description
+ **[config.toml](config.toml)**: configuration file with main parameters to run the model
+ **[constants.jl](constants.jl)**: constants values in the code
+ **[functions.jl](functions.jl)**: auxiliary file with the functions is used in the code
+ **Manifest.toml**: file with dependencies for reproducibility  
+ **Project.toml**: file with dependencies for reproducibility
+ **[RES-profile-scaling-main.jl](RES-profile-scaling-main.jl)**: main file to run the model

## Inputs
The input files were generated with the [renewables ninja](https://www.renewables.ninja/) tool. However, any hourly profile following the data format from the renewable ninja is allowed.
## Outputs
The output files include the scaled profiles, a summary file, and a summary plot.
## Optimization model

$$
\begin{align}
\displaystyle {\min_{x} {\left(\sum_{h}P_{h}^{x} - FLH\right)}^{2}}
\end{align}
$$

$s.t.$

$$
\begin{align}
x \geq 0
\end{align}
$$

Where:

$x$: decision variable to scale the hourly values of the profile

$P_{h}$: profile value at hour $h$

$FLH$: target full load hours

The objective function minimizes the squared error to the target full load hours, while constraint ensures the new coefficient is positive.


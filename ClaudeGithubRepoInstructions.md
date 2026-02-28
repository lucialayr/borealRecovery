### General rules for writing R code

- Do not use `<-` fo r assignment, use `=` instead
- Use `snake_case` for variable and function names
- Be sparingly with line breaks. Reasons for a line:
  - to keep lines under 80 characters
  - after the `%>%` operator when using the tidyverse
  - after the `+` operator when building ggplot objects
  - for a new item within the `ggplot2::theme` function
  - after and before curly braces `{}` when defining functions and loops
- Whenever possible, use functions from the `tidyverse` collection of packages
- Use comments very sparingly. The ideal code does not need any comments, but it self-documenting through variable, data set and function names

### Goals for the restructured repository
- Aclear and organized folder structure separating data, scripts, and figures
- follow the logic of this repository as much as possible (https://github.com/lucialayr/disturbanceBorealLPJ) especially with regards to 
  - mapping over scenarios and other factors
  - provide the direct data that goes into plot in `data/final`, following the naming conventions of the plots
  - any `...plot.R` script should take in the final data and produce a plot, and `...final.R` script should produce the final data
- When saving intermediate data sets I am trying to strike a compromise between avoiding redundancy and keeping data sets small and easy on RAM.
- Equally, I would like each figure to have its own pipeline as much as possible while also avoiding redundancy and being frugal with regards to executing computationlly intesive processing steps multiple times

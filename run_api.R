# run_api.R — Rulează din RStudio Console cu: source("run_api.R")
#  java -jar karate.jar general_salarii.feature general_ess.feature socio_salarii.feature clustering_ess.feature llm_ess.feature
library(plumber)

pr <- plumber::plumb("C:/Users/pelle/OneDrive/Desktop/lic-test/api.R")

pr$run(
  host = "127.0.0.1",
  port = 8000,
  docs = TRUE    # Swagger UI disponibil la http://127.0.0.1:8000/__docs__/
)
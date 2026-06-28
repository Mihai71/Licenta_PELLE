message(">>> 1/2  Instalez pachetele R necesare...")

pkgs <- c(
  "shiny", "shinydashboard", "DT", "ggplot2", "dplyr", "tidyr", "stringr",
  "reticulate", "httr", "jsonlite", "plotly", "readxl", "scales", "plumber"
)
to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(to_install) > 0) {
  install.packages(to_install, repos = "https://cloud.r-project.org")
} else {
  message("    Toate pachetele R sunt deja instalate.")
}

message(">>> 2/2  Creez mediul Python izolat 'biasapp' (pandas, numpy, openpyxl)...")

library(reticulate)

pick_base_python <- function() {
  cands <- c(
    Sys.glob("C:/Users/*/AppData/Local/Programs/Python/Python3*/python.exe"),
    Sys.glob("C:/Python3*/python.exe"),
    Sys.glob("C:/Program Files/Python3*/python.exe"),
    Sys.which("python3"),
    Sys.which("python")
  )
  cands <- unique(cands[nzchar(cands) & file.exists(cands)])
  cands <- cands[!grepl("WindowsApps", cands, fixed = TRUE)]   # sare peste stub-ul Store
  if (length(cands) > 0) return(cands[[1]])
  message("    Niciun Python valid gasit; instalez unul gestionat de reticulate...")
  reticulate::install_python()
}

base_py <- pick_base_python()
message("    Python de baza ales: ", base_py)

if (virtualenv_exists("biasapp")) virtualenv_remove("biasapp", confirm = FALSE)
virtualenv_create("biasapp", python = base_py,
                  packages = c("pandas", "numpy", "openpyxl"))

message(" Setup complet.")
message(" Mediul Python 'biasapp' a fost creat din: ", base_py)
message(" Nu uita sa descarci modelul LLM in Ollama:  ollama pull qwen2.5:14b")
message(" Porneste aplicatia:  shiny::runApp(port = 3838)")
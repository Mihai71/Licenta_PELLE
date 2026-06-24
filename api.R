# api.R - REST API (plumber) peste motorul Python (logic.py)
# Pornire:  source("run_api.R")   ->  http://127.0.0.1:8000
#           Swagger UI:               http://127.0.0.1:8000/__docs__/

library(plumber)
library(reticulate)
library(jsonlite)

# Acelasi backend ca aplicatia Shiny
reticulate::source_python("logic.py")
reticulate::source_python("clustering.py")
source("R/standards.R")
source("llm.R")

# Store in memorie: file_id -> cale CSV temporara
.FILES <- new.env(parent = emptyenv())

new_file_id <- function()
  paste0("f_", format(Sys.time(), "%H%M%S"), "_",
         paste(sample(c(0:9, letters), 6, TRUE), collapse = ""))

.write_temp <- function(df) {
  tmp <- tempfile(fileext = ".csv")
  write.csv(df, tmp, row.names = FALSE)
  tmp
}

.path_of <- function(file_id) {
  p <- .FILES[[file_id]]
  if (is.null(p) || !file.exists(p)) NULL else p
}
# Rezumat statistic pe grupuri (N, medie, mediana, SD) pentru socio-demografic
.socio_summary <- function(values, groups) {
  groups <- as.character(groups)
  lv <- sort(unique(groups[!is.na(groups) & nzchar(groups) & groups != "NA"]))
  lapply(lv, function(g) {
    v <- values[which(groups == g & !is.na(values))]
    list(Grup = g, N = length(v),
         Media   = if (length(v)) round(mean(v), 2)   else NA,
         Mediana = if (length(v)) round(median(v), 2) else NA,
         SD      = if (length(v) > 1) round(sd(v), 2) else 0)
  })
}
# Curata coloana de coduri speciale (ex: gndr=9) si intoarce o cale noua
.apply_exclude <- function(path, col, exclude_values) {
  if (is.null(exclude_values) || length(exclude_values) == 0 ||
      identical(as.character(exclude_values), "")) return(path)
  df <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  if (!col %in% names(df)) return(path)
  excl <- trimws(strsplit(as.character(exclude_values), ",")[[1]])
  keep <- !(as.character(df[[col]]) %in% excl)
  .write_temp(df[keep, , drop = FALSE])
}

#* @apiTitle API Detectarea Disparitatilor Socio-Economice
#* @apiDescription Endpoint-uri REST peste motorul Python (logic.py)

#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods", "*")
    res$setHeader("Access-Control-Allow-Headers",
                  req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS)
    res$status <- 200
    return(list())
  }
  plumber::forward()
}

#* Verificare stare server
#* @get /health
#* @serializer unboxedJSON
function() list(status = "ok", time = as.character(Sys.time()))

#* Incarca un fisier CSV, intoarce file_id
#* @post /upload
#* @parser multi
#* @serializer unboxedJSON
function(req, res) {
  f <- req$body$file
  if (is.null(f)) { res$status <- 400; return(list(error = "Lipseste 'file'")) }
  fid  <- new_file_id()
  path <- tryCatch({
    if (is.data.frame(f)) {
      .write_temp(f)
    } else if (is.list(f) && !is.null(f$parsed) && is.data.frame(f$parsed)) {
      .write_temp(f$parsed)
    } else {
      raw_val <- if (is.list(f) && !is.null(f$value)) f$value else f
      tmp <- tempfile(fileext = ".csv")
      writeBin(as.raw(raw_val), tmp)
      tmp
    }
  }, error = function(e) NULL)
  if (is.null(path)) { res$status <- 500; return(list(error = "Salvare esuata")) }
  .FILES[[fid]] <- path
  list(file_id = fid)
}

#* Previzualizare primele N randuri
#* @get /files/<file_id>/preview
#* @param n:int Numar de randuri (default 5)
#* @serializer json
function(file_id, n = 5, res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  head(read.csv(p, check.names = FALSE), as.integer(n))
}

#* Profilare coloane (tipuri + candidati sensibili/financiari)
#* @post /profile
#* @param file_id
#* @serializer unboxedJSON
function(file_id, res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  profile_data(p)
}

#* Metrici target numeric (Cohen's d, t-test, ANOVA)
#* @post /metrics/numeric
#* @param file_id
#* @param sensitive_col
#* @param target_col
#* @param exclude_values Valori de exclus din coloana sensibila (ex: 9), separate prin virgula
#* @serializer unboxedJSON
function(file_id, sensitive_col, target_col, exclude_values = "", res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  p2 <- .apply_exclude(p, sensitive_col, exclude_values)
  compute_numeric_metrics(p2, sensitive_col, target_col)
}

#* Metrici target binar (SPD, Disparate Impact)
#* @post /metrics/binary
#* @param file_id
#* @param sensitive_col
#* @param target_col
#* @param exclude_values
#* @serializer unboxedJSON
function(file_id, sensitive_col, target_col, exclude_values = "", res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  p2 <- .apply_exclude(p, sensitive_col, exclude_values)
  compute_binary_metrics(p2, sensitive_col, target_col)
}

#* Alerte distributionale (skewness, outlieri)
#* @post /distribution-alerts
#* @param file_id
#* @param col
#* @serializer unboxedJSON
function(file_id, col, res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  compute_distribution_alerts(p, col)
}

#* Dezechilibru de reprezentare pe grupuri
#* @post /group-imbalance
#* @param file_id
#* @param col
#* @param exclude_values
#* @serializer unboxedJSON
function(file_id, col, exclude_values = "", res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  p2 <- .apply_exclude(p, col, exclude_values)
  compute_group_imbalance(p2, col)
}

#* Bias Score global (calculeaza efect + dezechilibru intern)
#* @post /bias-score
#* @param file_id
#* @param sensitive_col
#* @param target_col
#* @param exclude_values
#* @serializer unboxedJSON
function(file_id, sensitive_col, target_col, exclude_values = "", res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  p2   <- .apply_exclude(p, sensitive_col, exclude_values)
  prof <- profile_data(p2)
  t_type <- prof$types[[target_col]]
  if (identical(as.character(t_type), "Numerica")) {
    mr <- compute_numeric_metrics(p2, sensitive_col, target_col)
    effect <- if (!is.null(mr$cohen_d)) as.numeric(mr$cohen_d) else 0
  } else {
    mr <- compute_binary_metrics(p2, sensitive_col, target_col)
    effect <- if (!is.null(mr$spd)) abs(as.numeric(mr$spd)) else 0
  }
  df    <- read.csv(p2, check.names = FALSE)
  tbl   <- table(df[[sensitive_col]])
  props <- as.numeric(tbl / sum(tbl))
  compute_bias_score(effect, props)
}
#* Analiza socio-demografica (grupare varsta / educatie / regiuni) pe un indicator financiar
#* @post /socio
#* @param file_id
#* @param type Tipul gruparii: age | edu | nuts
#* @param target_col Indicatorul financiar (in lei)
#* @param ref_country Referinta de comparat: RO | RO_BRUT | EU | DE | FR | HU | BG | NONE
#* @serializer unboxedJSON
function(file_id, type, target_col, ref_country = "NONE", res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  df   <- read.csv(p, check.names = FALSE, stringsAsFactors = FALSE)
  if (!target_col %in% names(df)) {
    res$status <- 422; return(list(error = paste("Coloana tinta inexistenta:", target_col)))
  }
  vals <- suppressWarnings(as.numeric(df[[target_col]]))
  nm   <- tolower(names(df))
  
  grp <- NULL
  if (type == "age") {
    idx <- grep("v[âa]rst|agea|^age$", nm)
    if (!length(idx)) { res$status <- 422; return(list(error = "Nu s-a detectat o coloana de varsta")) }
    grp <- cut(suppressWarnings(as.numeric(df[[idx[1]]])),
               breaks = age_bins, labels = age_labels, include.lowest = TRUE)
  } else if (type == "edu") {
    idx <- grep("educa|studi|eisced", nm)
    if (!length(idx)) { res$status <- 422; return(list(error = "Nu s-a detectat o coloana de educatie")) }
    grp <- classify_education(df[[idx[1]]])
  } else {
    idx <- grep("regiu|jude|nuts|localit|zona|domicil", nm)
    if (!length(idx)) { res$status <- 422; return(list(error = "Nu s-a detectat o coloana de regiune")) }
    grp <- as.character(df[[idx[1]]])
  }
  
  groups  <- .socio_summary(vals, grp)
  overall <- round(mean(vals, na.rm = TRUE), 2)
  out <- list(type = type, target_col = target_col,
              n_groups = length(groups), overall_mean = overall, groups = groups)
  
  if (!identical(ref_country, "NONE")) {
    refv <- tryCatch(reference_data$salary[[ref_country]], error = function(e) NULL)
    if (!is.null(refv)) {
      out$ref_country   <- ref_country
      out$ref_value     <- as.numeric(refv)
      out$difference    <- round(overall - as.numeric(refv), 2)
      out$difference_pct <- round((overall - as.numeric(refv)) / as.numeric(refv) * 100, 1)
    }
  }
  out
}

#* Metoda Elbow: sugereaza numarul optim de clustere (k)
#* @post /elbow
#* @param file_id
#* @param col_sex
#* @param col_age
#* @param col_edu
#* @param col_env
#* @param col_income
#* @param col_extra_json Coloane suplimentare ca JSON (ex: ["cntry"])
#* @serializer unboxedJSON
function(file_id, col_sex, col_age, col_edu, col_env, col_income,
         col_extra_json = "[]", res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  compute_elbow(p, col_sex, col_age, col_edu, col_env, col_income,
                col_extra_json = col_extra_json)
}

#* Clustering K-Means + profile + bias intra-cluster
#* @post /clustering
#* @param file_id
#* @param col_sex
#* @param col_age
#* @param col_edu
#* @param col_env
#* @param col_income
#* @param n_clusters:int Numar de clustere (2-8)
#* @param col_extra_json Coloane suplimentare ca JSON (ex: ["cntry"])
#* @serializer unboxedJSON
function(file_id, col_sex, col_age, col_edu, col_env, col_income,
         n_clusters = 4, col_extra_json = "[]", res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  out <- run_clustering(p, col_sex, col_age, col_edu, col_env, col_income,
                        col_extra_json = col_extra_json,
                        n_clusters = as.integer(n_clusters))
  # Nu trimitem datele de plot (mari, doar pentru graficele Shiny)
  if (is.list(out)) out$pca_data <- NULL
  out
}
#* Interpretare LLM a rezultatelor de clustering (via Ollama, local)
#* @post /llm/interpret
#* @param file_id
#* @param col_sex
#* @param col_age
#* @param col_edu
#* @param col_env
#* @param col_income
#* @param n_clusters:int
#* @param col_extra_json
#* @serializer unboxedJSON
function(file_id, col_sex, col_age, col_edu, col_env, col_income,
         n_clusters = 3, col_extra_json = "[]", res) {
  p <- .path_of(file_id)
  if (is.null(p)) { res$status <- 404; return(list(error = "file_id necunoscut")) }
  if (!check_ollama()) {
    res$status <- 503
    return(list(error = paste("Ollama indisponibil la", LLM_DEFAULT_URL)))
  }
  cr <- run_clustering(p, col_sex, col_age, col_edu, col_env, col_income,
                       col_extra_json = col_extra_json,
                       n_clusters = as.integer(n_clusters))
  if (!is.null(cr$error)) { res$status <- 422; return(list(error = cr$error)) }
  
  prompt <- build_results_prompt(NULL, NULL, NULL, cr, NULL, NULL)
  user_msg <- paste0(prompt,
                     "\n\nAnalizeaza aceste rezultate de clustering si explica ce ",
                     "disparitati exista, ce tipuri de bias ar putea indica si ce ",
                     "limitari trebuie avute in vedere.")
  resp <- call_ollama(list(
    list(role = "system", content = .LLM_SYSTEM),
    list(role = "user",   content = user_msg)
  ))
  if (!is.null(resp$error)) { res$status <- 502; return(list(error = resp$error)) }
  list(text = resp$text)
}

#* Chat liber cu LLM-ul (intrebare custom, ex: "Ce este biasul intersectional?")
#* @post /llm/chat
#* @param message Intrebarea utilizatorului
#* @serializer unboxedJSON
function(message, res) {
  if (is.null(message) || !nzchar(message)) {
    res$status <- 400; return(list(error = "Lipseste 'message'"))
  }
  if (!check_ollama()) {
    res$status <- 503
    return(list(error = paste("Ollama indisponibil la", LLM_DEFAULT_URL)))
  }
  sys <- paste0("Esti un asistent care explica pe scurt, in limba romana, ",
                "concepte legate de bias si disparitati in date socioeconomice.")
  resp <- call_ollama(list(
    list(role = "system", content = sys),
    list(role = "user",   content = message)
  ))
  if (!is.null(resp$error)) { res$status <- 502; return(list(error = resp$error)) }
  list(text = resp$text)
}
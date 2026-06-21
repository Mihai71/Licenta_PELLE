# llm.R: Interpretare LLM via Ollama (local, GDPR compliant)

LLM_DEFAULT_MODEL <- "qwen2.5:14b"
LLM_DEFAULT_URL   <- "http://localhost:11434"

.LLM_SYSTEM <- paste0(
  "Ești un asistent analitic integrat într-o aplicație de detectare a aspectelor ",
  "pártinitoare (bias) în seturi de date socioeconomice publice. ",
  "Interpretezi rezultatele statistice deja calculate și le explici în română, ",
  "limbaj accesibil, fără jargon neexplicat, cu exprimare corectă gramatical și ortografic.\n\n",
  " Maxim 2-3 propoziții per tip de bias.\n",
  " NU folosi caracterele *, #, = sau alte simboluri de formatare (Markdown) în răspuns.\n\n",
  "PRINCIPIU CENTRAL:\n",
  "Variabila-rezultat a întregii analize este VENITUL. Aici 'bias' înseamnă că anumite ",
  "grupuri au venituri sistematic mai mici (sau mai mari) decât altele. Evaluează FIECARE ",
  "tip de bias prin efectul său asupra disparităților de venit dintre grupuri și menționează ",
  "mereu cifrele de venit relevante: mediile pe grup, diferența absolută și procentuală, ",
  "folosind rezumatul disparității de venit primit în date.\n\n",
  "ROLUL TĂU DE INTERPRET:\n",
  "Tu ești cel care interpretează datele. Primești cifre brute (statistici pe grupuri, profiluri ",
  "de clustere, alerte de calitate). Decizi singur, pe baza lor, care este atributul sensibil, ",
  "dacă există bias, de ce tip și cât de puternic. Nu primești și nu trebuie să aplici praguri ",
  "fixe care să decidă în locul tău ce contează drept bias: cântărește semnalele și formulează ",
  "concluzii proporționale cu mărimea lor. Fiecare cifră vine deja însoțită de eticheta ei de ",
  "interpretare (de pildă mic, mediu, mare, moderat), pe care o poți folosi ca reper.\n\n",
  
  "PROCESUL TĂU DE ANALIZĂ: parcurge fiecare tip în ordine:\n\n",
  
  "TIPURILE DE BIAS DE ACOPERIT (definiții neutre; tu hotărăști dacă și unde apar în date):\n",
  "Bias de reprezentare: un grup apare în date mult sub ponderea unei distribuții echitabile.\n",
  "Bias de proxy: clustere formate fără atributul sensibil ajung totuși dominate de un grup, ...\n",
  "Bias de agregare: o medie globală echilibrată ascunde disparități mari la nivel de subgrupuri sau clustere.\n",
  "Bias intersecțional: dezavantajul rezultă din combinarea mai multor dimensiuni simultan, ...\n",
  "Bias istoric: disparitățile observate sunt consistente cu inegalități socioeconomice cunoscute; ...\n",
  "Bias de eșantionare: proporțiile grupurilor din date nu reflectă populația reală ...\n",
  "Bias de măsurare: probleme de calitate a datelor ... afectează celelalte analize.\n\n",
  
  "REGULI STRICTE:\n",
  "- Scrie EXCLUSIV în română.\n",
  "- NU stabili relații cauzale deoarece datele observaționale nu permit asta.\n",
  "- Semnalează disparitățile ca ipoteze de investigat, nu verdicte.\n",
  "- Dacă datele lipsesc pentru un tip de bias, scrie explicit 'date insuficiente'.\n",
  "- Maxim 2-3 propoziții per tip de bias.\n\n",
  
  "FORMATUL RĂSPUNSULUI:\n",
  "Nu folosi caracterele *, #, = sau alte simboluri Markdown. ",
  "Scrie titlurile secțiunilor ca text simplu, fiecare pe un rând separat.\n",
  "Parcurge cele șapte tipuri de bias în ordinea de mai sus, apoi secțiunea Limitări. ",
  "Folosește exact aceste titluri, ca text simplu:\n",
  "Bias de reprezentare\n",
  "Bias de proxy\n",
  "Bias de agregare\n",
  "Bias intersecțional\n",
  "Bias istoric\n",
  "Bias de eșantionare\n",
  "Bias de măsurare\n",
  "Limitări\n\n",
  "DETALIAZĂ doar tipurile de bias pentru care există semnal real în datele primite. ",
  "Pentru un tip detaliat, scrie sub titlu două paragrafe scurte, separate de un rând gol:\n",
  "  Ce este: o propoziție care definește pe scurt tipul de bias și cum apare în practică.\n",
  "  Ce arată datele: 1-2 propoziții care interpretează semnalele din date PRIN PRISMA ",
  "VENITULUI (care grup câștigă mai puțin sau mai mult), citând cifre concrete: diferența ",
  "de venit absolută și procentuală, Cohen's d, SPD, bias score etc.\n",
  "Pentru tipurile FĂRĂ semnal în datele primite, scrie doar titlul urmat de o singură ",
  "propoziție: 'Date insuficiente pentru evaluare.', fără a mai defini tipul de bias.\n",
  "Secțiunea Limitări: 1-2 propoziții despre ce nu se poate concluziona din datele disponibile.\n"
)
build_results_prompt <- function(mr, dal, br, cr, socio_res = NULL, ctx = NULL) {
  out <- "CONTEXT ANALIZĂ\n"
  
  if (!is.null(ctx)) {
    if (!is.null(ctx$n_rows) && !is.null(ctx$n_cols))
      out <- paste0(out, sprintf("Set de date: %s rânduri active, %d coloane\n",
                                 format(ctx$n_rows, big.mark = "."), as.integer(ctx$n_cols)))
    if (!is.null(ctx$sensitive))
      out <- paste0(out, sprintf("Atribut sensibil selectat: '%s'%s\n", ctx$sensitive,
                                 if (!is.null(ctx$sensitive_type))
                                   paste0(" (tip ", ctx$sensitive_type, ")") else ""))
    if (!is.null(ctx$target))
      out <- paste0(out, sprintf("Variabilă țintă (target): '%s'%s\n", ctx$target,
                                 if (!is.null(ctx$target_type))
                                   paste0(" (tip ", ctx$target_type, ")") else ""))
    if (!is.null(ctx$columns) && length(ctx$columns) > 0)
      out <- paste0(out, "Coloane disponibile: ", paste(ctx$columns, collapse = ", "), "\n")
    if (!is.null(ctx$warnings) && length(ctx$warnings) > 0) {
      out <- paste0(out, "AVERTISMENTE CALITATE DATE (menționează-le în interpretare):\n")
      for (w in ctx$warnings) out <- paste0(out, "  - ", w, "\n")
    }
  }
  
  #Alerte distribuționale 
  if (!is.null(dal)) {
    sk <- dal$skewness
    if (!is.null(sk) && !is.null(sk$skewness))
      out <- paste0(out, sprintf("Asimetrie distribuție target: %.4f\n", as.numeric(sk$skewness)))
    if (!is.null(sk) && !is.null(sk$outliers_pct))
      out <- paste0(out, sprintf("Outlieri: %s valori (%.1f%%) în afara IQR\n",
                                 sk$outliers_count, as.numeric(sk$outliers_pct)))
    imb <- dal$imbalance
    if (!is.null(imb) && length(imb) > 0) {
      serious  <- Filter(function(x) !is.null(x$severity) && x$severity == "serious",  imb)
      moderate <- Filter(function(x) !is.null(x$severity) && x$severity == "moderate", imb)
      if (length(serious) > 0) {
        grps <- sapply(serious, function(x) sprintf("%s (%.1f%%)", x$group, as.numeric(x$pct)))
        out  <- paste0(out, "Subreprezentare SERIOASĂ (sub 0,5/k, sub jumătate din cota echitabilă): ",
                       paste(grps, collapse = ", "), "\n")
      }
      if (length(moderate) > 0) {
        grps <- sapply(moderate, function(x) sprintf("%s (%.1f%%)", x$group, as.numeric(x$pct)))
        out  <- paste0(out, "Subreprezentare moderată (sub 0,75/k): ",
                       paste(grps, collapse = ", "), "\n")
      }
    }
  }
  
  #Analiza generală 
  if (!is.null(mr) && !is.null(mr$summary)) {
    s_lbl <- if (!is.null(ctx) && !is.null(ctx$sensitive)) ctx$sensitive else "atribut sensibil"
    t_lbl <- if (!is.null(ctx) && !is.null(ctx$target))    ctx$target    else "target"
    grp_names <- sapply(mr$summary, function(g) as.character(g$Grup))
    shown <- if (length(grp_names) > 15)
      c(grp_names[1:15], sprintf("(+%d altele)", length(grp_names) - 15)) else grp_names
    
    out <- paste0(out, sprintf("\nANALIZA GENERALĂ ('%s' -> '%s', %d grupuri: %s)\n",
                               s_lbl, t_lbl, length(grp_names), paste(shown, collapse = ", ")))
    
    if (is.null(mr$spd)) {
      # target numeric
      g_means <- suppressWarnings(sapply(mr$summary, function(g) as.numeric(g$Media)))
      g_nms   <- sapply(mr$summary, function(g) as.character(g$Grup))
      if (length(g_means) >= 2 && all(is.finite(g_means))) {
        i_lo <- which.min(g_means); i_hi <- which.max(g_means)
        gap_abs <- g_means[i_hi] - g_means[i_lo]
        gap_pct <- if (g_means[i_lo] != 0) gap_abs / g_means[i_lo] * 100 else NA_real_
        out <- paste0(out, sprintf(
          "REZUMAT DISPARITATE DE VENIT: cel mai mic venit mediu -> grupul '%s' (%.2f); cel mai mare -> grupul '%s' (%.2f). Diferență: %.2f%s.\n",
          g_nms[i_lo], g_means[i_lo], g_nms[i_hi], g_means[i_hi], gap_abs,
          if (!is.na(gap_pct)) sprintf(" (grupul '%s' are cu %.1f%% mai mult decât '%s')",
                                       g_nms[i_hi], gap_pct, g_nms[i_lo]) else ""))
      }
      for (g in mr$summary)
        out <- paste0(out, sprintf("  Grup '%s': N=%d, medie=%.2f, mediană=%.2f, SD=%.2f\n",
                                   g$Grup, as.integer(g$N), as.numeric(g$Media),
                                   as.numeric(g$Mediana), as.numeric(g$SD)))
      if (!is.null(mr$mean_diff))
        out <- paste0(out, sprintf("Diferența mediilor: %.2f\n", as.numeric(mr$mean_diff)))
      if (!is.null(mr$pct_diff))
        out <- paste0(out, sprintf("Diferența procentuală: %.1f%%\n", as.numeric(mr$pct_diff)))
      if (!is.null(mr$cohen_d))
        out <- paste0(out, sprintf("Cohen's d = %.4f (%s)\n",
                                   as.numeric(mr$cohen_d), mr$cohen_d_interpretation))
      if (!is.null(mr$t_stat))
        out <- paste0(out, sprintf("Welch t = %.4f, p = %.6f\n",
                                   as.numeric(mr$t_stat), as.numeric(mr$p_value_ttest)))
      if (!is.null(mr$f_stat))
        out <- paste0(out, sprintf("ANOVA F = %.4f, p = %.6f\n",
                                   as.numeric(mr$f_stat), as.numeric(mr$p_value_anova)))
      if (!is.null(mr$eta_squared))
        out <- paste0(out, sprintf("Eta² = %.4f\n", as.numeric(mr$eta_squared)))
    } else {
      # target binar
      for (g in mr$summary)
        out <- paste0(out, sprintf("  Grup '%s': %d/%d (%.1f%% rată succes)\n",
                                   g$Grup, as.integer(g$Succese), as.integer(g$Total),
                                   as.numeric(g$Rata_Succes) * 100))
      out <- paste0(out, sprintf("SPD = %.4f %s\n", as.numeric(mr$spd),
                                 if (abs(as.numeric(mr$spd)) < 0.1) "[ECHITABIL]" else "[INECHITABIL]"))
      if (!is.null(mr$disparate_impact))
        out <- paste0(out, sprintf("DI = %.4f - %s\n",
                                   as.numeric(mr$disparate_impact), mr$di_interpretation))
      if (!is.null(mr$risk_ratio))
        out <- paste0(out, sprintf("Risk Ratio = %.4f\n", as.numeric(mr$risk_ratio)))
    }
  }
  
  if (!is.null(br))
    out <- paste0(out, sprintf("\nBIAS SCORE GLOBAL: %.4f - %s (efect 70%% + dezechilibru 30%%)\n",
                               as.numeric(br$bias_score), br$severity))
  
  # --- Analiza socio-demografică ---
  if (!is.null(socio_res) && !is.null(socio_res$df) && nrow(socio_res$df) > 0) {
    sdf <- socio_res$df
    type_lbl <- switch(as.character(socio_res$type),
                       age  = "grupe de vârstă standardizate",
                       edu  = "nivel de educație (ISCED)",
                       nuts = "regiuni (NUTS România)",
                       as.character(socio_res$type))
    out <- paste0(out, sprintf("\n=== ANALIZA SOCIO-DEMOGRAFICĂ (grupare: %s, indicator: '%s') ===\n",
                               type_lbl, socio_res$target_col))
    out <- paste0(out, "NOTĂ IMPORTANTĂ: acest modul presupune valori monetare în RON (lei). ",
                  "Dacă indicatorul NU este exprimat în RON, comparațiile cu referințele ",
                  "naționale/europene NU au sens și trebuie semnalat acest lucru.\n")
    
    n_show <- min(nrow(sdf), 20)
    for (i in seq_len(n_show))
      out <- paste0(out, sprintf("  Grup '%s': N=%s, medie=%.2f, mediană=%.2f, SD=%.2f\n",
                                 as.character(sdf$Grup[i]), as.character(sdf$N[i]),
                                 as.numeric(sdf$Media[i]), as.numeric(sdf[["Mediană"]][i]),
                                 as.numeric(sdf$SD[i])))
    if (nrow(sdf) > n_show)
      out <- paste0(out, sprintf("  ... (+%d grupuri suplimentare)\n", nrow(sdf) - n_show))
    
    if (!is.null(socio_res$ref_val) && !is.na(socio_res$ref_val)) {
      ref_lbl <- switch(as.character(socio_res$ref_country),
                        RO = "Media României (salariu net)",
                        RO_BRUT = "Media României (salariu brut)", EU = "Media UE (brut)",
                        DE = "Germania (brut)", FR = "Franța (brut)",
                        HU = "Ungaria (brut)",  BG = "Bulgaria (brut)",
                        as.character(socio_res$ref_country))
      overall <- mean(as.numeric(sdf$Media), na.rm = TRUE)
      out <- paste0(out, sprintf("Comparație: media în date = %.0f vs %s = %.0f RON\n",
                                 overall, ref_lbl, as.numeric(socio_res$ref_val)))
    }
  }
  
  #Clustering
  if (!is.null(cr) && is.null(cr$error)) {
    out <- paste0(out, sprintf("\nCLUSTERING K-MEANS (k=%d, %s rânduri)\n",
                               as.integer(cr$n_clusters),
                               format(as.integer(cr$n_rows_used), big.mark = ".")))
    for (p in cr$profiles) {
      lbl   <- if (!is.null(p$label)) as.character(p$label) else sprintf("Cluster %d", as.integer(p$cluster_id))
      age_s <- if (!is.null(p$age_mean))    sprintf(", vârstă med.=%.0f", as.numeric(p$age_mean))    else ""
      inc_s <- if (!is.null(p$income_mean)) sprintf(", venit med.=%.0f",  as.numeric(p$income_mean)) else ""
      med_s <- if (!is.null(p$income_median)) sprintf(" (median %.0f)", as.numeric(p$income_median)) else ""
      sex_s <- if (!is.null(p$female_pct)) sprintf(", sex: %s%%F/%s%%M", p$female_pct, p$male_pct)   else ""
      edu_s <- if (isTRUE(p$edu_is_text) && !is.null(p$edu_mode_text))
        paste0(", edu: ", as.character(p$edu_mode_text))
      else if (!is.null(p$edu_mean)) sprintf(", edu med.=%.2f", as.numeric(p$edu_mean)) else ""
      env_s <- if (!is.null(p$env_top))
        paste0(", mediu: ", paste(names(p$env_top), unlist(p$env_top), sep = ":", collapse = "|"))
      else if (!is.null(p$env_mean)) sprintf(", mediu med.=%.2f", as.numeric(p$env_mean)) else ""
      
      out <- paste0(out, sprintf("  C%d [%s]: %d pers. (%.1f%%)%s%s%s%s%s%s\n",
                                 as.integer(p$cluster_id), lbl, as.integer(p$n),
                                 as.numeric(p$pct), age_s, inc_s, med_s, sex_s, edu_s, env_s))
    }
    
    out <- paste0(out, "Bias intra-cluster (fiecare cluster vs restul populației, per atribut):\n")
    for (bc in cr$bias_per_cluster) {
      if (!is.null(bc$bias_score))
        out <- paste0(out, sprintf("  Cluster C%d: bias score=%.4f (%s)\n",
                                   as.integer(bc$cluster_id), as.numeric(bc$bias_score), bc$severity))
      if (!is.null(bc$analyses)) {
        for (a in bc$analyses) {
          cd <- if (!is.null(a$cohen_d)) sprintf("%.3f", as.numeric(a$cohen_d)) else "n/a"
          lb <- if (!is.null(a$cohen_d_label)) as.character(a$cohen_d_label) else ""
          pd <- if (!is.null(a$pct_diff)) sprintf(", diferență=%.1f%%", as.numeric(a$pct_diff)) else ""
          is_eta  <- (!is.null(a$metric) && identical(as.character(a$metric), "eta2")) ||
            grepl("Multi-grup|η²", lb)
          metric_name <- if (is_eta) "eta patrat" else "Cohen's d"
          out <- paste0(out, sprintf("    %s: %s=%s (%s)%s\n",
                                     as.character(a$attribute), metric_name, cd, lb, pd))
        }
      }
    }
  }
  
  #Descrierea graficelor vizibile
  has_mr <- !is.null(mr) && !is.null(mr$summary)
  has_cr <- !is.null(cr) && is.null(cr$error)
  if (has_mr || has_cr) {
    out <- paste0(out, "\nGRAFICE VIZIBILE ÎN APLICAȚIE\n")
    if (has_mr) {
      s_lbl <- if (!is.null(ctx) && !is.null(ctx$sensitive)) ctx$sensitive else "atributul sensibil"
      t_lbl <- if (!is.null(ctx) && !is.null(ctx$target))    ctx$target    else "target"
      out <- paste0(out, sprintf(
        "- Tab 'Vizualizare': boxplot, grafic de densitate și barplot al diferențelor față de media globală, toate pentru '%s' împărțit pe grupurile lui '%s'.\n",
        t_lbl, s_lbl))
    }
    if (has_cr) {
      n_cl <- as.integer(cr$n_clusters)
      pal_names <- c("albastru", "roșu", "verde", "portocaliu",
                     "mov", "turcoaz", "portocaliu închis", "gri-albastru")
      cols_used <- paste(sprintf("C%d=%s", 0:(n_cl - 1),
                                 pal_names[((0:(n_cl - 1)) %% 8) + 1]), collapse = ", ")
      out <- paste0(out,
                    "- Tab 'Clustere AI': scatter PCA 2D (fiecare punct = o persoană, culoarea = clusterul), ",
                    "grafice Vârstă/Educație/Mediu vs indicatorul financiar și boxplot al venitului pe clustere.\n")
      out <- paste0(out, "  Culorile clusterelor în toate graficele: ", cols_used, ".\n")
    }
  }
  
  out
}

check_ollama <- function(url = LLM_DEFAULT_URL) {
  tryCatch({
    r <- httr::GET(url, httr::timeout(3))
    httr::status_code(r) == 200
  }, error = function(e) FALSE)
}

call_ollama <- function(messages, model = LLM_DEFAULT_MODEL, url = LLM_DEFAULT_URL) {
  body <- list(
    model   = model,
    messages = messages,
    stream  = FALSE,
    options = list(temperature = 0.3, num_ctx = 8192, num_predict = 900)
  )
  tryCatch({
    resp <- httr::POST(
      url  = paste0(url, "/api/chat"),
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      httr::content_type_json(),
      httr::timeout(300)
    )
    if (httr::status_code(resp) != 200)
      return(list(error = paste("Eroare Ollama:", httr::status_code(resp))))
    parsed <- jsonlite::fromJSON(
      httr::content(resp, as = "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    )
    list(text = parsed$message$content, error = NULL)
  }, error = function(e) {
    list(error = paste("Nu s-a putut contacta Ollama:", conditionMessage(e)))
  })
}
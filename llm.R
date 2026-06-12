# llm.R — Interpretare LLM via Ollama (local, GDPR compliant)

LLM_DEFAULT_MODEL <- "llama3.1:8b"
LLM_DEFAULT_URL   <- "http://localhost:11434"

.LLM_SYSTEM <- paste0(
  "Ești un asistent analitic integrat într-o aplicație de detectare a aspectelor ",
  "pártinitoare (bias) în seturi de date socioeconomice publice. ",
  "Interpretezi rezultatele statistice deja calculate și le explici în română, ",
  "limbaj accesibil, fără jargon neexplicat.\n\n",
  
  "PRAGURI DE REFERINȚĂ:\n",
  "Cohen's d/η²: <0.2=neglijabil | 0.2-0.5=mic | 0.5-0.8=mediu | >0.8=mare\n",
  "SPD: |SPD|<0.1=echitabil | >=0.1=inechitabil\n",
  "DI: 0.8-1.25=echitabil | <0.8=risc discriminare | >1.25=favorizare inversă\n",
  "Bias Score: <0.20=neglijabil | 0.20-0.50=moderat | >=0.50=ridicat\n",
  "Reprezentare: un grup e subreprezent dacă are sub 0.5/k din total (k=nr. grupuri)\n\n",
  
  "PROCESUL TĂU DE ANALIZĂ — parcurge fiecare tip în ordine:\n\n",
  
  "1. BIAS DE REPREZENTARE\n",
  "   Semnal: există grupuri marcate ca subreprezentate în alerte? ",
  "   Grupul subreprezent are și medii mai mici la target? ",
  "   Dacă un grup mic are și rezultate mai proaste, subreprezentarea amplifică biasul.\n\n",
  
  "2. BIAS DE PROXY\n",
  "   Semnal: clusterele K-Means (care NU au folosit atributul sensibil ca feature) ",
  "   au o concentrare mare pe atributul sensibil? ",
  "   Exemplu: un cluster cu >65% femei format pe baza venitului/educației/regiunii ",
  "   arată că acele variabile sunt proxy pentru gen. ",
  "   Caută profiluri de cluster cu >60-65% dintr-un grup sensibil.\n\n",
  
  "3. BIAS DE AGREGARE\n",
  "   Semnal: bias score global pare moderat sau mic, dar unele clustere au bias score ridicat? ",
  "   Sau media globală pare echilibrată dar subgrupuri (clustere) arată disparități mari? ",
  "   Disparitatea e reală dar ascunsă de agregare.\n\n",
  
  "4. BIAS INTERSECȚIONAL\n",
  "   Semnal: un cluster are concomitent: concentrare pe atribut sensibil (>60%) + ",
  "   educație scăzută + mediu rural + venit scăzut. ",
  "   Nu un singur atribut, ci combinația a 2-3 dimensiuni dezavantajoase simultan.\n\n",
  
  "5. BIAS ISTORIC\n",
  "   Semnal: disparitățile găsite urmează tipare socioeconomice cunoscute ",
  "   (femei/minorități cu venituri sistematic mai mici, educație mai scăzută, ",
  "   regiuni defavorizate). NU afirma cauzalitate — semnalează consistența cu ",
  "   inegalitățile structurale istorice.\n\n",
  
  "6. BIAS DE EȘANTIONARE\n",
  "   Semnal: proporțiile grupurilor sensibile din date reflectă realitatea populației? ",
  "   Dacă un grup e mult sub-/supra-reprezentat față de populația generală, ",
  "   concluziile pot fi distorsionate. Verifică alertele de reprezentare.\n\n",
  
  "7. BIAS DE MĂSURARE\n",
  "   Semnal: avertismente despre >20% valori lipsă la target, coloană de vârstă/educație ",
  "   nedetectată, sau indicator socio care nu pare monetar (relevant doar în tab socio). ",
  "   Aceste probleme de calitate a datelor afectează toate celelalte analize.\n\n",
  
  "REGULI STRICTE:\n",
  "- Scrie EXCLUSIV în română.\n",
  "- NU stabili relații cauzale — datele observaționale nu permit asta.\n",
  "- Semnalează disparitățile ca ipoteze de investigat, nu verdicte.\n",
  "- Dacă datele lipsesc pentru un tip de bias, scrie explicit 'date insuficiente'.\n",
  "- Maxim 2-3 propoziții per tip de bias.\n\n",
  
  "FORMATUL OBLIGATORIU AL RĂSPUNSULUI:\n",
  "Structurează ÎNTOTDEAUNA răspunsul tău cu exact aceste secțiuni, în această ordine:\n",
  "## Bias de reprezentare\n",
  "## Bias de proxy\n",
  "## Bias de agregare\n",
  "## Bias intersecțional\n",
  "## Bias istoric\n",
  "## Bias de eșantionare\n",
  "## Bias de măsurare\n",
  "## Limitări\n",
  "Fiecare secțiune: 2-3 propoziții concise bazate strict pe datele primite.\n"
)
build_results_prompt <- function(mr, dal, br, cr, socio_res = NULL, ctx = NULL) {
  out <- "=== CONTEXT ANALIZĂ ===\n"
  
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
  
  # --- Alerte distribuționale ---
  if (!is.null(dal)) {
    sk <- dal$skewness
    if (!is.null(sk) && !is.null(sk$skewness))
      out <- paste0(out, sprintf("Asimetrie distribuție target: %.4f\n", as.numeric(sk$skewness)))
    if (!is.null(sk) && !is.null(sk$outliers_pct))
      out <- paste0(out, sprintf("Outlieri: %s valori (%.1f%%) în afara IQR\n",
                                 sk$outliers_count, as.numeric(sk$outliers_pct)))
    imb <- dal$imbalance
    if (!is.null(imb) && length(imb) > 0) {
      grps <- sapply(imb, function(x) sprintf("%s (%.1f%%)", x$group, as.numeric(x$pct)))
      out  <- paste0(out, "Grupuri subreprezentate (sub pragul dinamic 0,5/k): ",
                     paste(grps, collapse = ", "), "\n")
    }
  }
  
  # --- Analiza generală ---
  if (!is.null(mr) && !is.null(mr$summary)) {
    s_lbl <- if (!is.null(ctx) && !is.null(ctx$sensitive)) ctx$sensitive else "atribut sensibil"
    t_lbl <- if (!is.null(ctx) && !is.null(ctx$target))    ctx$target    else "target"
    grp_names <- sapply(mr$summary, function(g) as.character(g$Grup))
    shown <- if (length(grp_names) > 15)
      c(grp_names[1:15], sprintf("(+%d altele)", length(grp_names) - 15)) else grp_names
    
    out <- paste0(out, sprintf("\n=== ANALIZA GENERALĂ ('%s' -> '%s', %d grupuri: %s) ===\n",
                               s_lbl, t_lbl, length(grp_names), paste(shown, collapse = ", ")))
    
    if (is.null(mr$spd)) {
      # target numeric
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
        out <- paste0(out, sprintf("DI = %.4f — %s\n",
                                   as.numeric(mr$disparate_impact), mr$di_interpretation))
      if (!is.null(mr$risk_ratio))
        out <- paste0(out, sprintf("Risk Ratio = %.4f\n", as.numeric(mr$risk_ratio)))
    }
  }
  
  if (!is.null(br))
    out <- paste0(out, sprintf("\nBIAS SCORE GLOBAL: %.4f — %s (efect 70%% + dezechilibru 30%%)\n",
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
                        RO = "Media României (salariu net)", EU = "Media UE (brut)",
                        DE = "Germania (brut)", FR = "Franța (brut)",
                        HU = "Ungaria (brut)",  BG = "Bulgaria (brut)",
                        as.character(socio_res$ref_country))
      overall <- mean(as.numeric(sdf$Media), na.rm = TRUE)
      out <- paste0(out, sprintf("Comparație: media în date = %.0f vs %s = %.0f RON\n",
                                 overall, ref_lbl, as.numeric(socio_res$ref_val)))
    }
  }
  
  # --- Clustering ---
  if (!is.null(cr) && is.null(cr$error)) {
    out <- paste0(out, sprintf("\n=== CLUSTERING K-MEANS (k=%d, %s rânduri) ===\n",
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
          cd <- if (!is.null(a$cohen_d)) sprintf("%.3f", as.numeric(a$cohen_d)) else "–"
          lb <- if (!is.null(a$cohen_d_label)) as.character(a$cohen_d_label) else ""
          pd <- if (!is.null(a$pct_diff)) sprintf(", diferență=%.1f%%", as.numeric(a$pct_diff)) else ""
          out <- paste0(out, sprintf("    %s: Cohen's d=%s (%s)%s\n",
                                     as.character(a$attribute), cd, lb, pd))
        }
      }
    }
  }
  
  # --- Descrierea graficelor vizibile ---
  has_mr <- !is.null(mr) && !is.null(mr$summary)
  has_cr <- !is.null(cr) && is.null(cr$error)
  if (has_mr || has_cr) {
    out <- paste0(out, "\n=== GRAFICE VIZIBILE ÎN APLICAȚIE ===\n")
    if (has_mr) {
      s_lbl <- if (!is.null(ctx) && !is.null(ctx$sensitive)) ctx$sensitive else "atributul sensibil"
      t_lbl <- if (!is.null(ctx) && !is.null(ctx$target))    ctx$target    else "target"
      out <- paste0(out, sprintf(
        "- Tab 'Vizualizare': boxplot, grafic de densitate și barplot al diferențelor față de media globală — toate pentru '%s' împărțit pe grupurile lui '%s'.\n",
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
    options = list(temperature = 0.3, num_ctx = 8192)
  )
  tryCatch({
    resp <- httr::POST(
      url  = paste0(url, "/api/chat"),
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      httr::content_type_json(),
      httr::timeout(180)
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
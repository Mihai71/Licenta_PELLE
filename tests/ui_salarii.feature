Feature: UI automation - flux vizual in dashboard (Shiny, set salarii)
# java -jar karate.jar ui_salarii.feature - cu asta porneste!!! 
# setul 'salarii' are deja 5 duplicate, deci ascunderea duplicatelor se vede oricum.

Background:
  * configure driver = { type: 'chrome', showDriverLog: true }

Scenario: Flux complet vizual (date + analiza generala)
  # Deschide aplicatia
  * driver appUrl
  * waitFor('#file')

  # 1) Upload fisier salarii
  * input('#file', salariiPath)
  * waitFor('.info-box')
  * delay(2000)

  # 2) Ascunde duplicatele (setul are 5 randuri duplicate)
  * waitFor('#remove_duplicates')
  * click('#remove_duplicates')
  * delay(1500)

  # 3) Pune un filtru (pe 'mediu'), apoi se reseteaza
  * script("$('#filter_col')[0].selectize.setValue('mediu')")
  * delay(1500)
  * click('#reset_filter')
  * delay(1200)

  # 4) Selecteaza atribut sensibil (gen) si tinta binara (promovat)
  * script("$('#sensitive')[0].selectize.setValue('gen')")
  * delay(400)
  * script("$('#target')[0].selectize.setValue('promovat')")
  * delay(600)

  # 5) Ruleaza analiza
  * click('#run')
  * delay(2500)

  # 6) Tab Analiza Generala (Bias Score, SPD, Disparate Impact)
  * click("a[data-value='tab_bias']")
  * delay(2500)

  # 7) Tab Vizualizare, panoul de Proportii
  * click("a[data-value='tab_viz']")
  * delay(1200)
  * click('{^}Propor')
  * delay(2000)

  # 8) Descarca graficul de proportii (PNG, in Downloads)
  * waitFor('#dl_parity')
  * click('#dl_parity')
  * delay(2500)
Feature: UI automation - flux vizual ESS (Cohen's d, curatare gndr=9)
# java -jar karate.jar ui_ess.feature asa rulez!!!
# Cand se opreste la upload, se selecteaza MANUAL fisierul ESS_training_clean.csv.
# Restul fluxului (filtru de curatare, override tip, analiza, descarcare) e automat.

Background:
  * configure driver = { type: 'chrome', showDriverLog: true }
  * configure retry = { count: 25, interval: 3000 }

Scenario: Curatare gndr=9 si analiza Cohen's d (gndr -> hinctnta)
  * driver appUrl
  * waitFor('#file')

  # 1) Upload
  * retry(25, 3000).waitFor('.info-box')
  * delay(1500)

  # 4) Atribut sensibil = gndr, tinta numerica = hinctnta
  * script("$('#sensitive')[0].selectize.setValue('gndr')")
  * delay(400)
  * script("$('#target')[0].selectize.setValue('hinctnta')")
  * delay(600)

  # 5) Ruleaza analiza
  * click('#run')
  * delay(3000)

  # 6) Tab Analiza Generala (Cohen's d, Bias Score)
  * click("a[data-value='tab_bias']")
  * delay(3500)

  # 7) Tab Vizualizare, panoul density plot
  * click("a[data-value='tab_viz']")
  * delay(1200)
  * click('{^}Density')
  * delay(2500)

  # 8) Descarca boxplot-ul (PNG, in Downloads)
  * waitFor('#dl_density')
  * click('#dl_density')
  * delay(2500)
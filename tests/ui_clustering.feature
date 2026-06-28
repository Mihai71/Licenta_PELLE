@ui
Feature: UI automation - clustering K-Means (ESS) - elbow, clustering, atribut cntry
#java -jar karate.jar ui_clustering.feature
# Necesita Chrome + aplicatia Shiny pe portul 3838.
# La upload, selecteaza MANUAL fisierul ESS_training_clean.csv (cel original, cu gndr=9).

Background:
  * configure driver = { type: 'chrome', showDriverLog: true }
  * configure retry = { count: 25, interval: 3000 }

Scenario: Elbow -> clustering k -> reclustering cu cntry
  * driver appUrl
  * waitFor('#file')

  # 1) Upload: selecteaza MANUAL ESS_training_clean.csv
  * retry(25, 3000).waitFor('.info-box')
  * delay(1500)

  # 2) Tab Clustere AI
  * click("a[data-value='tab_clustering']")
  * delay(1500)

  # 3) Mapare coloane (explicit, ca sa fie sigur)
  * script("$('#cl_col_sex')[0].selectize.setValue('gndr')")
  * script("$('#cl_col_age')[0].selectize.setValue('agea')")
  * script("$('#cl_col_edu')[0].selectize.setValue('eisced')")
  * script("$('#cl_col_env')[0].selectize.setValue('domicil')")
  * script("$('#cl_col_income')[0].selectize.setValue('hinctnta')")
  * delay(1000)

  # 4) Metoda Elbow 
  * click('#run_elbow')
  * delay(5000)

  # 5) Clustering 
  * click('#run_clustering')
  * delay(3000)
  * delay(10000)

  # 6) Adauga atribut suplimentar cntry (tara) si reclusterizeaza
  * script("$('#cl_col_extra')[0].selectize.addItem('cntry')")
  * delay(2000)
  * click('#run_clustering')
  * delay(5000)
  * delay(25000)
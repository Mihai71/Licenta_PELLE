@ui
Feature: UI automation - socio-demografic (varsta / educatie / regiuni)
# java -jar karate.jar ui_socio.feature
# La upload, manual fisierul salarii_ro_demo.csv.

Background:
  * configure driver = { type: 'chrome', showDriverLog: true }
  * configure retry = { count: 25, interval: 3000 }

Scenario: Socio pe varsta, educatie si regiuni - fiecare ~3 secunde
  * driver appUrl
  * waitFor('#file')

  # 1) Upload
  * retry(25, 3000).waitFor('.info-box')
  * delay(1500)

  # 2) Mergi pe tab-ul Socio-Demografic
  * click("a[data-value='tab_socio']")
  * delay(1500)
  # asigura indicatorul financiar si referinta (media Romaniei, net)
  * script("$('#socio_target_col')[0].selectize.setValue('salariu_lunar_net_lei')")
  * delay(300)
  * script("$('#socio_ref_country')[0].selectize.setValue('RO')")
  * delay(300)

  # 3) VARSTA 
  * script("$('#socio_type')[0].selectize.setValue('age')")
  * delay(500)
  * click('#run_socio')
  * delay(5000)

  # 4) EDUCATIE
  * script("$('#socio_type')[0].selectize.setValue('edu')")
  * delay(500)
  * click('#run_socio')
  * delay(5000)

  # 5) REGIUNI (NUTS Romania) - ramane ~5s
  * script("$('#socio_type')[0].selectize.setValue('nuts')")
  * delay(500)
  * click('#run_socio')
  * delay(5000)
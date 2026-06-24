Feature: Flux socio-demografic (varsta / educatie / regiuni) - salarii
# java -jar karate.jar socio_salarii.feature pornirea
Background:
  * url baseUrl

Scenario: Grupare pe varsta, educatie si regiuni pe salariu (in lei)
  # Upload
  Given path 'upload'
  And multipart file file = { read: 'file:C:/Users/pelle/Downloads/salarii_ro_demo.csv', filename: 'salarii_ro_demo.csv', contentType: 'text/csv' }
  When method post
  Then status 200
  * def fid = response.file_id

  # 1) Varsta (grupe standardizate)
  Given path 'socio'
  And form field file_id = fid
  And form field type = 'age'
  And form field target_col = 'salariu_lunar_net_lei'
  When method post
  Then status 200
  And assert response.n_groups >= 3
  And match response.groups == '#[_ > 0]'
  And match response.overall_mean == '#number'

  # 2) Educatie (clasificare ISCED: Primara / Secundara / Tertiara)
  Given path 'socio'
  And form field file_id = fid
  And form field type = 'edu'
  And form field target_col = 'salariu_lunar_net_lei'
  When method post
  Then status 200
  And match response.n_groups == 3

  # 3) Regiuni (NUTS), comparatie cu media Romaniei (net)
  Given path 'socio'
  And form field file_id = fid
  And form field type = 'nuts'
  And form field target_col = 'salariu_lunar_net_lei'
  And form field ref_country = 'RO'
  When method post
  Then status 200
  And match response.n_groups == 8
  And match response.ref_value == '#number'
  And match response.difference == '#number'
  And match response.difference_pct == '#number'
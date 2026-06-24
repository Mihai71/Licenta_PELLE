Feature: Flux analiza generala - ESS curatat (Cohen's d, gndr -> hinctnta)

Background:
  * url baseUrl

Scenario: Upload ESS curatat si metrici numerice gndr -> hinctnta
  # 1) Upload 
  Given path 'upload'
  And multipart file file = { read: 'file:C:/Users/pelle/Downloads/ESS_DATA_CLEAN.csv', filename: 'ESS_DATA_CLEAN.csv', contentType: 'text/csv' }
  When method post
  Then status 200
  * def fid = response.file_id

  # 2) gndr are 2 valori (1, 2), Cohen's d
  Given path 'metrics', 'numeric'
  And form field file_id = fid
  And form field sensitive_col = 'gndr'
  And form field target_col = 'hinctnta'
  When method post
  Then status 200
  And match response.n_groups == 2
  And match response.cohen_d == '#number'
  And match response.cohen_d_interpretation == '#present'

  # 3) Alerta distributionala pe target
  Given path 'distribution-alerts'
  And form field file_id = fid
  And form field col = 'hinctnta'
  When method post
  Then status 200
  And match response.skewness == '#present'

  # 4) Dezechilibru de reprezentare pe gndr
  Given path 'group-imbalance'
  And form field file_id = fid
  And form field col = 'gndr'
  When method post
  Then status 200